import Cocoa

// MARK: - Profile Configuration

struct ProfileConfiguration: Codable {
    let profileName: String
    var displays: [String]  // Display names to capture
    var cameras: [String]   // Camera device names
    var audioInputs: [String]  // Audio input names
    var isConfigured: Bool
}

// MARK: - Profile Setup Window Controller

class ProfileSetupWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow!
    private var configurations: [SetupType: ProfileConfiguration] = [:]
    private var selectedProfile: SetupType = .macBookSetup

    // UI Elements
    private var profileSelector: NSSegmentedControl!
    private var displayList: NSTableView!
    private var cameraList: NSTableView!
    private var audioList: NSTableView!

    // Data
    private var availableDisplays: [String] = []
    private var availableCameras: [String] = []
    private var availableAudio: [String] = []

    // Callbacks
    var onSave: (([SetupType: ProfileConfiguration]) -> Void)?

    override init() {
        super.init()
        setupWindow()
        loadConfigurations()
        detectAvailableSources()
    }

    // MARK: - Window Setup

    private func setupWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Configure Recording Profiles"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = .floating

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.white.cgColor

        buildLayout(in: contentView)
        window.contentView = contentView
    }

    private func buildLayout(in container: NSView) {
        let bounds = container.bounds

        // Title
        let titleLabel = NSTextField(labelWithString: "Configure Recording Profiles")
        titleLabel.frame = NSRect(x: 20, y: bounds.height - 40, width: 400, height: 24)
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        container.addSubview(titleLabel)

        // Instructions
        let instructionsLabel = NSTextField(labelWithString: "Select sources for each recording setup. These will be automatically configured when you start a recording.")
        instructionsLabel.frame = NSRect(x: 20, y: bounds.height - 70, width: bounds.width - 40, height: 32)
        instructionsLabel.font = NSFont.systemFont(ofSize: 12)
        instructionsLabel.textColor = .secondaryLabelColor
        instructionsLabel.lineBreakMode = .byWordWrapping
        instructionsLabel.maximumNumberOfLines = 2
        container.addSubview(instructionsLabel)

        // Profile Selector
        profileSelector = NSSegmentedControl(frame: NSRect(x: 20, y: bounds.height - 115, width: bounds.width - 40, height: 32))
        profileSelector.segmentCount = 3
        profileSelector.setLabel(SetupType.macSetup.displayName, forSegment: 0)
        profileSelector.setLabel(SetupType.macBookSetup.displayName, forSegment: 1)
        profileSelector.setLabel(SetupType.pcSetup.displayName, forSegment: 2)
        profileSelector.selectedSegment = 1
        profileSelector.target = self
        profileSelector.action = #selector(profileChanged(_:))
        container.addSubview(profileSelector)

        // Source Lists
        let listY = bounds.height - 150
        let listHeight = listY - 80
        let listWidth = (bounds.width - 60) / 3

        // Displays
        let displaysLabel = NSTextField(labelWithString: "📺 Displays")
        displaysLabel.frame = NSRect(x: 20, y: listY - 25, width: listWidth, height: 20)
        displaysLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        container.addSubview(displaysLabel)

        let displaysScroll = createSourceListScroll(frame: NSRect(x: 20, y: 80, width: listWidth, height: listHeight))
        container.addSubview(displaysScroll)

        // Cameras
        let camerasLabel = NSTextField(labelWithString: "📷 Cameras")
        camerasLabel.frame = NSRect(x: 30 + listWidth, y: listY - 25, width: listWidth, height: 20)
        camerasLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        container.addSubview(camerasLabel)

        let camerasScroll = createSourceListScroll(frame: NSRect(x: 30 + listWidth, y: 80, width: listWidth, height: listHeight))
        container.addSubview(camerasScroll)

        // Audio
        let audioLabel = NSTextField(labelWithString: "🎤 Audio Inputs")
        audioLabel.frame = NSRect(x: 40 + listWidth * 2, y: listY - 25, width: listWidth, height: 20)
        audioLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        container.addSubview(audioLabel)

        let audioScroll = createSourceListScroll(frame: NSRect(x: 40 + listWidth * 2, y: 80, width: listWidth, height: listHeight))
        container.addSubview(audioScroll)

        // Buttons
        let saveButton = NSButton(title: "Save Configuration", target: self, action: #selector(saveClicked))
        saveButton.frame = NSRect(x: bounds.width - 180, y: 20, width: 160, height: 32)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        container.addSubview(saveButton)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        cancelButton.frame = NSRect(x: bounds.width - 260, y: 20, width: 70, height: 32)
        cancelButton.bezelStyle = .rounded
        container.addSubview(cancelButton)

        // Detect Sources button
        let detectButton = NSButton(title: "🔄 Refresh Sources", target: self, action: #selector(detectSourcesClicked))
        detectButton.frame = NSRect(x: 20, y: 20, width: 150, height: 32)
        detectButton.bezelStyle = .rounded
        container.addSubview(detectButton)
    }

    private func createSourceListScroll(frame: NSRect) -> NSScrollView {
        let scrollView = NSScrollView(frame: frame)
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let tableView = NSTableView(frame: scrollView.bounds)
        tableView.headerView = nil

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("source"))
        column.width = frame.width - 20
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        return scrollView
    }

    // MARK: - Data

    private func loadConfigurations() {
        // Load saved configurations or create defaults
        let configPath = Paths.configDir + "/profile-configs.json"

        if let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           let saved = try? JSONDecoder().decode([String: ProfileConfiguration].self, from: data) {
            for (key, config) in saved {
                if let setupType = SetupType(rawValue: key) {
                    configurations[setupType] = config
                }
            }
        } else {
            // Create default configurations
            configurations[.macSetup] = ProfileConfiguration(
                profileName: "Mac-MultiScreen",
                displays: [],
                cameras: [],
                audioInputs: [],
                isConfigured: false
            )
            configurations[.macBookSetup] = ProfileConfiguration(
                profileName: "MacBook-Single",
                displays: [],
                cameras: [],
                audioInputs: [],
                isConfigured: false
            )
            configurations[.pcSetup] = ProfileConfiguration(
                profileName: "PC-10Cameras",
                displays: [],
                cameras: [],
                audioInputs: [],
                isConfigured: false
            )
        }
    }

    private func saveConfigurations() {
        let configPath = Paths.configDir + "/profile-configs.json"
        let dict = configurations.mapKeys { $0.rawValue }

        if let data = try? JSONEncoder().encode(dict) {
            try? data.write(to: URL(fileURLWithPath: configPath))
        }
    }

    private func detectAvailableSources() {
        logInfo("Detecting available sources...")

        // Detect displays
        availableDisplays = detectDisplays()
        logInfo("Found \(availableDisplays.count) displays: \(availableDisplays.joined(separator: ", "))")

        // Detect cameras
        availableCameras = detectCameras()
        logInfo("Found \(availableCameras.count) cameras: \(availableCameras.joined(separator: ", "))")

        // Detect audio inputs
        availableAudio = detectAudioInputs()
        logInfo("Found \(availableAudio.count) audio inputs: \(availableAudio.joined(separator: ", "))")
    }

    private func detectDisplays() -> [String] {
        var displays: [String] = []
        let maxDisplays = NSScreen.screens.count

        for i in 1...maxDisplays {
            displays.append("Display \(i)")
        }

        return displays
    }

    private func detectCameras() -> [String] {
        // Use system_profiler to detect cameras
        let result = runShellCommand("system_profiler SPCameraDataType 2>/dev/null | grep 'Model ID:' | sed 's/.*Model ID: //'", timeout: 10)

        var cameras = result.output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if cameras.isEmpty {
            // Default fallback cameras
            cameras = ["FaceTime HD Camera", "Camera - ZV-E1"]
        }

        return cameras
    }

    private func detectAudioInputs() -> [String] {
        // Use system_profiler to detect audio inputs
        let result = runShellCommand("system_profiler SPAudioDataType 2>/dev/null | grep -A 5 'Input' | grep 'Device Name:' | sed 's/.*Device Name: //'", timeout: 10)

        var inputs = result.output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if inputs.isEmpty {
            // Default fallback
            inputs = ["Built-in Microphone", "Microphone - FIFINE"]
        }

        return inputs
    }

    // MARK: - Actions

    @objc private func profileChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0: selectedProfile = .macSetup
        case 1: selectedProfile = .macBookSetup
        case 2: selectedProfile = .pcSetup
        default: break
        }

        // Reload UI with selected profile's configuration
        logInfo("Selected profile: \(selectedProfile.displayName)")
    }

    @objc private func detectSourcesClicked() {
        detectAvailableSources()
        // Reload table views
        logInfo("Sources refreshed")
    }

    @objc private func saveClicked() {
        saveConfigurations()
        logSuccess("Profile configurations saved")
        onSave?(configurations)
        hide()
    }

    @objc private func cancelClicked() {
        hide()
    }

    // MARK: - Public Methods

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window.close()
    }
}

// MARK: - Dictionary Extension

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
}
