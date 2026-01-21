import Cocoa

// MARK: - First Time Setup Wizard

class FirstTimeSetupWizard: NSObject, NSWindowDelegate {
    private var window: NSWindow!
    private var currentStep = 0
    private var contentView: NSView!

    private var configurations: [ProfileConfiguration] = []
    private var currentConfig: ProfileConfiguration?

    // Current page selections
    private var selectedDisplays: Set<String> = []
    private var selectedCameras: Set<String> = []
    private var selectedAudio: Set<String> = []

    // Available sources
    private var availableDisplays: [String] = []
    private var availableCameras: [String] = []
    private var availableAudio: [String] = []

    // UI Elements
    private var nextButton: NSButton!
    private var backButton: NSButton!
    private var skipButton: NSButton!

    var onComplete: (([ProfileConfiguration]) -> Void)?
    var onSkip: (() -> Void)?

    override init() {
        super.init()
        detectSources()
        setupWindow()
    }

    // MARK: - Window Setup

    private func setupWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 550),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Tutorial Recorder"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = .floating

        contentView = NSView(frame: window.contentView!.bounds)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.white.cgColor
        window.contentView = contentView

        showWelcomePage()
    }

    // MARK: - Pages

    private func showWelcomePage() {
        clearContent()
        currentStep = 0

        // Welcome icon
        let iconView = NSImageView(frame: NSRect(x: 300, y: 380, width: 100, height: 100))
        if let img = NSImage(systemSymbolName: "video.circle.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 80, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.systemBlue]))
            iconView.image = img.withSymbolConfiguration(config)
        }
        contentView.addSubview(iconView)

        // Welcome title
        let titleLabel = NSTextField(labelWithString: "Welcome to Tutorial Recorder!")
        titleLabel.frame = NSRect(x: 50, y: 340, width: 600, height: 32)
        titleLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.alignment = .center
        contentView.addSubview(titleLabel)

        // Description
        let descLabel = NSTextField(labelWithString: "Let's set up your recording profiles. You can configure different setups for different recording scenarios.")
        descLabel.frame = NSRect(x: 50, y: 270, width: 600, height: 60)
        descLabel.font = NSFont.systemFont(ofSize: 14)
        descLabel.alignment = .center
        descLabel.textColor = .secondaryLabelColor
        descLabel.lineBreakMode = .byWordWrapping
        descLabel.maximumNumberOfLines = 3
        contentView.addSubview(descLabel)

        // Features list
        let features = [
            "📺 Configure multiple display setups",
            "📷 Select cameras for each profile",
            "🎤 Choose audio inputs",
            "🎬 Automatic OBS configuration"
        ]

        var y: CGFloat = 210
        for feature in features {
            let featureLabel = NSTextField(labelWithString: feature)
            featureLabel.frame = NSRect(x: 200, y: y, width: 300, height: 20)
            featureLabel.font = NSFont.systemFont(ofSize: 13)
            featureLabel.alignment = .left
            contentView.addSubview(featureLabel)
            y -= 30
        }

        // Buttons
        addNavigationButtons(showBack: false, showSkip: true, nextTitle: "Get Started")
    }

    private func showProfileSelectionPage() {
        clearContent()
        currentStep = 1

        // Title
        let titleLabel = NSTextField(labelWithString: "Choose Your First Profile")
        titleLabel.frame = NSRect(x: 50, y: 480, width: 600, height: 28)
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .semibold)
        titleLabel.alignment = .center
        contentView.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Select the profile that best matches your current setup:")
        subtitleLabel.frame = NSRect(x: 50, y: 450, width: 600, height: 20)
        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        contentView.addSubview(subtitleLabel)

        // Profile cards
        let profiles: [(name: String, icon: String, desc: String, profileName: String)] = [
            ("Mac Multi-Screen", "rectangle.3.group", "Multiple displays with various cameras", "Mac-MultiScreen"),
            ("MacBook Single", "laptopcomputer", "Built-in display and FaceTime camera", "MacBook-Single"),
            ("PC 10 Cameras", "video.badge.plus", "Single display with many cameras", "PC-10Cameras")
        ]

        var x: CGFloat = 50
        for (index, profile) in profiles.enumerated() {
            let card = createProfileCard(
                title: profile.name,
                icon: profile.icon,
                description: profile.desc,
                profileName: profile.profileName,
                tag: index
            )
            card.frame = NSRect(x: x, y: 180, width: 190, height: 240)
            contentView.addSubview(card)
            x += 210
        }

        // Or create custom
        let customLabel = NSTextField(labelWithString: "or")
        customLabel.frame = NSRect(x: 310, y: 140, width: 80, height: 20)
        customLabel.font = NSFont.systemFont(ofSize: 12)
        customLabel.textColor = .tertiaryLabelColor
        customLabel.alignment = .center
        contentView.addSubview(customLabel)

        let customButton = NSButton(title: "+ Create Custom Profile", target: self, action: #selector(createCustomProfileClicked))
        customButton.frame = NSRect(x: 250, y: 100, width: 200, height: 32)
        customButton.bezelStyle = .rounded
        customButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        contentView.addSubview(customButton)

        addNavigationButtons(showBack: true, showSkip: true, nextTitle: "Next", nextEnabled: false)
    }

    private func createProfileCard(title: String, icon: String, description: String, profileName: String, tag: Int) -> NSView {
        let card = NSView(frame: NSRect(x: 0, y: 0, width: 190, height: 240))
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor(white: 0.98, alpha: 1.0).cgColor
        card.layer?.cornerRadius = 12
        card.layer?.borderWidth = 2
        card.layer?.borderColor = NSColor.clear.cgColor

        // Icon
        let iconView = NSImageView(frame: NSRect(x: 55, y: 150, width: 80, height: 80))
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 60, weight: .light)
                .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.systemBlue]))
            iconView.image = img.withSymbolConfiguration(config)
        }
        card.addSubview(iconView)

        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.frame = NSRect(x: 10, y: 120, width: 170, height: 22)
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.alignment = .center
        card.addSubview(titleLabel)

        // Description
        let descLabel = NSTextField(labelWithString: description)
        descLabel.frame = NSRect(x: 10, y: 70, width: 170, height: 40)
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .center
        descLabel.lineBreakMode = .byWordWrapping
        descLabel.maximumNumberOfLines = 2
        card.addSubview(descLabel)

        // Select button
        let selectButton = NSButton(title: "Select", target: self, action: #selector(profileCardSelected(_:)))
        selectButton.frame = NSRect(x: 45, y: 20, width: 100, height: 32)
        selectButton.bezelStyle = .rounded
        selectButton.tag = tag
        selectButton.setButtonType(.momentaryPushIn)
        card.addSubview(selectButton)

        // Store profile name as identifier
        card.identifier = NSUserInterfaceItemIdentifier(profileName)

        return card
    }

    private func showSourceSelectionPage() {
        guard let config = currentConfig else { return }

        clearContent()
        currentStep = 2

        // Title
        let titleLabel = NSTextField(labelWithString: "Configure: \(config.profileName)")
        titleLabel.frame = NSRect(x: 50, y: 480, width: 600, height: 28)
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .semibold)
        contentView.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Select the sources you want to use for this profile:")
        subtitleLabel.frame = NSRect(x: 50, y: 450, width: 600, height: 20)
        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        contentView.addSubview(subtitleLabel)

        // Three columns for sources
        let columnWidth: CGFloat = 200
        let columnHeight: CGFloat = 320
        let spacing: CGFloat = 20
        let startX: CGFloat = (700 - (columnWidth * 3 + spacing * 2)) / 2

        // Displays column
        createSourceColumn(
            title: "📺 Displays",
            sources: availableDisplays,
            selectedSources: selectedDisplays,
            x: startX,
            y: 100,
            width: columnWidth,
            height: columnHeight,
            tag: 0
        )

        // Cameras column
        createSourceColumn(
            title: "📷 Cameras",
            sources: availableCameras,
            selectedSources: selectedCameras,
            x: startX + columnWidth + spacing,
            y: 100,
            width: columnWidth,
            height: columnHeight,
            tag: 1
        )

        // Audio column
        createSourceColumn(
            title: "🎤 Audio",
            sources: availableAudio,
            selectedSources: selectedAudio,
            x: startX + (columnWidth + spacing) * 2,
            y: 100,
            width: columnWidth,
            height: columnHeight,
            tag: 2
        )

        addNavigationButtons(showBack: true, showSkip: false, nextTitle: "Save & Continue")
    }

    private func createSourceColumn(title: String, sources: [String], selectedSources: Set<String>, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, tag: Int) {
        // Column container
        let column = NSView(frame: NSRect(x: x, y: y, width: width, height: height))
        column.wantsLayer = true
        contentView.addSubview(column)

        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.frame = NSRect(x: 0, y: height - 25, width: width, height: 20)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        column.addSubview(titleLabel)

        // Scroll view for checkboxes
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: height - 30))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true

        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: width - 20, height: CGFloat(sources.count * 30)))

        var checkY: CGFloat = CGFloat(sources.count * 30) - 25
        for source in sources {
            let checkbox = NSButton(checkboxWithTitle: source, target: self, action: #selector(sourceCheckboxToggled(_:)))
            checkbox.frame = NSRect(x: 5, y: checkY, width: width - 30, height: 20)
            checkbox.tag = tag * 1000 + sources.firstIndex(of: source)!
            checkbox.state = selectedSources.contains(source) ? .on : .off
            documentView.addSubview(checkbox)
            checkY -= 30
        }

        scrollView.documentView = documentView
        column.addSubview(scrollView)
    }

    private func showCompletionPage() {
        clearContent()
        currentStep = 3

        // Success icon
        let iconView = NSImageView(frame: NSRect(x: 300, y: 380, width: 100, height: 100))
        if let img = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 80, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.systemGreen]))
            iconView.image = img.withSymbolConfiguration(config)
        }
        contentView.addSubview(iconView)

        // Title
        let titleLabel = NSTextField(labelWithString: "Setup Complete!")
        titleLabel.frame = NSRect(x: 50, y: 340, width: 600, height: 32)
        titleLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.alignment = .center
        contentView.addSubview(titleLabel)

        // Summary
        let summaryText = "You've configured \(configurations.count) profile(s). You can always add more profiles or modify existing ones from the menu."
        let summaryLabel = NSTextField(labelWithString: summaryText)
        summaryLabel.frame = NSRect(x: 100, y: 270, width: 500, height: 60)
        summaryLabel.font = NSFont.systemFont(ofSize: 14)
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.alignment = .center
        summaryLabel.lineBreakMode = .byWordWrapping
        summaryLabel.maximumNumberOfLines = 3
        contentView.addSubview(summaryLabel)

        // List configured profiles
        var y: CGFloat = 220
        for config in configurations {
            let profileLabel = NSTextField(labelWithString: "✓ \(config.profileName) - \(config.displays.count) displays, \(config.cameras.count) cameras, \(config.audioInputs.count) audio")
            profileLabel.frame = NSRect(x: 150, y: y, width: 400, height: 20)
            profileLabel.font = NSFont.systemFont(ofSize: 12)
            profileLabel.textColor = .secondaryLabelColor
            contentView.addSubview(profileLabel)
            y -= 25
        }

        // Add another button
        let addAnotherButton = NSButton(title: "+ Configure Another Profile", target: self, action: #selector(addAnotherProfileClicked))
        addAnotherButton.frame = NSRect(x: 250, y: 120, width: 200, height: 32)
        addAnotherButton.bezelStyle = .rounded
        contentView.addSubview(addAnotherButton)

        addNavigationButtons(showBack: false, showSkip: false, nextTitle: "Finish")
    }

    // MARK: - Navigation

    private func addNavigationButtons(showBack: Bool, showSkip: Bool, nextTitle: String, nextEnabled: Bool = true) {
        // Next/Finish button
        nextButton = NSButton(title: nextTitle, target: self, action: #selector(nextClicked))
        nextButton.frame = NSRect(x: 580, y: 20, width: 100, height: 32)
        nextButton.bezelStyle = .rounded
        nextButton.keyEquivalent = "\r"
        nextButton.isEnabled = nextEnabled
        contentView.addSubview(nextButton)

        // Back button
        if showBack {
            backButton = NSButton(title: "Back", target: self, action: #selector(backClicked))
            backButton.frame = NSRect(x: 470, y: 20, width: 100, height: 32)
            backButton.bezelStyle = .rounded
            contentView.addSubview(backButton)
        }

        // Skip button
        if showSkip {
            skipButton = NSButton(title: "Skip Setup", target: self, action: #selector(skipClicked))
            skipButton.frame = NSRect(x: 20, y: 20, width: 100, height: 32)
            skipButton.bezelStyle = .rounded
            contentView.addSubview(skipButton)
        }
    }

    private func clearContent() {
        contentView.subviews.forEach { $0.removeFromSuperview() }
    }

    // MARK: - Actions

    @objc private func nextClicked() {
        switch currentStep {
        case 0: // Welcome -> Profile Selection
            showProfileSelectionPage()
        case 1: // Profile Selection -> Source Selection (should not reach here without selection)
            break
        case 2: // Source Selection -> Save and either show completion or add another
            saveCurrentConfiguration()
            showCompletionPage()
        case 3: // Completion -> Finish
            complete()
        default:
            break
        }
    }

    @objc private func backClicked() {
        switch currentStep {
        case 1: // Profile Selection -> Welcome
            showWelcomePage()
        case 2: // Source Selection -> Profile Selection
            currentConfig = nil
            selectedDisplays.removeAll()
            selectedCameras.removeAll()
            selectedAudio.removeAll()
            showProfileSelectionPage()
        default:
            break
        }
    }

    @objc private func skipClicked() {
        onSkip?()
        hide()
    }

    @objc private func profileCardSelected(_ sender: NSButton) {
        // Find the card
        guard let card = sender.superview,
              let profileName = card.identifier?.rawValue else { return }

        // Create configuration
        currentConfig = ProfileConfiguration(
            profileName: profileName,
            displays: [],
            cameras: [],
            audioInputs: [],
            isConfigured: false
        )

        // Highlight selected card
        for subview in contentView.subviews {
            if let cardView = subview as? NSView, cardView.layer?.cornerRadius == 12 {
                cardView.layer?.borderColor = NSColor.clear.cgColor
                cardView.layer?.borderWidth = 2
            }
        }
        card.layer?.borderColor = NSColor.systemBlue.cgColor
        card.layer?.borderWidth = 3

        // Enable next button
        nextButton?.isEnabled = true

        // Auto-advance after selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showSourceSelectionPage()
        }
    }

    @objc private func createCustomProfileClicked() {
        let alert = NSAlert()
        alert.messageText = "Create Custom Profile"
        alert.informativeText = "Enter a name for your custom recording profile:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "e.g., Studio Setup, Home Office, etc."
        alert.accessoryView = textField

        let response = alert.runModal()

        if response == .alertFirstButtonReturn && !textField.stringValue.isEmpty {
            let customName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            currentConfig = ProfileConfiguration(
                profileName: customName,
                displays: [],
                cameras: [],
                audioInputs: [],
                isConfigured: false
            )

            showSourceSelectionPage()
        }
    }

    @objc private func sourceCheckboxToggled(_ sender: NSButton) {
        let category = sender.tag / 1000
        let index = sender.tag % 1000

        switch category {
        case 0: // Displays
            let source = availableDisplays[index]
            if sender.state == .on {
                selectedDisplays.insert(source)
            } else {
                selectedDisplays.remove(source)
            }
        case 1: // Cameras
            let source = availableCameras[index]
            if sender.state == .on {
                selectedCameras.insert(source)
            } else {
                selectedCameras.remove(source)
            }
        case 2: // Audio
            let source = availableAudio[index]
            if sender.state == .on {
                selectedAudio.insert(source)
            } else {
                selectedAudio.remove(source)
            }
        default:
            break
        }
    }

    @objc private func addAnotherProfileClicked() {
        // Reset selections
        currentConfig = nil
        selectedDisplays.removeAll()
        selectedCameras.removeAll()
        selectedAudio.removeAll()

        // Go back to profile selection
        showProfileSelectionPage()
    }

    private func saveCurrentConfiguration() {
        guard var config = currentConfig else { return }

        config.displays = Array(selectedDisplays)
        config.cameras = Array(selectedCameras)
        config.audioInputs = Array(selectedAudio)
        config.isConfigured = true

        configurations.append(config)

        logSuccess("Saved configuration for \(config.profileName): \(config.displays.count) displays, \(config.cameras.count) cameras, \(config.audioInputs.count) audio")

        // Reset selections for next profile
        selectedDisplays.removeAll()
        selectedCameras.removeAll()
        selectedAudio.removeAll()
    }

    private func complete() {
        onComplete?(configurations)
        hide()
    }

    // MARK: - Source Detection

    private func detectSources() {
        // Detect displays
        let displayCount = NSScreen.screens.count
        availableDisplays = (1...displayCount).map { "Display \($0)" }

        // Detect cameras
        let result = runShellCommand("system_profiler SPCameraDataType 2>/dev/null | grep 'Model ID:' | sed 's/.*Model ID: //'", timeout: 10)
        availableCameras = result.output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if availableCameras.isEmpty {
            availableCameras = ["FaceTime HD Camera", "External Camera"]
        }

        // Detect audio
        let audioResult = runShellCommand("system_profiler SPAudioDataType 2>/dev/null | grep 'Device Name:' | sed 's/.*Device Name: //'", timeout: 10)
        availableAudio = audioResult.output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if availableAudio.isEmpty {
            availableAudio = ["Built-in Microphone", "External Microphone"]
        }

        logInfo("Detected sources: \(availableDisplays.count) displays, \(availableCameras.count) cameras, \(availableAudio.count) audio inputs")
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
