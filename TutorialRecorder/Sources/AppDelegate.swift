import Cocoa

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var progressWindow = ProgressWindowController()
    private var syncConfigWindow: SyncConfigWindowController?
    private var mainPanel: MainPanelController?

    private var isSyncing = false
    private var syncAnimationTimer: Timer?
    private var animationFrame = 0

    // Settings
    private var autoCloseOBS: Bool {
        get { UserDefaults.standard.bool(forKey: "autoCloseOBS") }
        set { UserDefaults.standard.set(newValue, forKey: "autoCloseOBS") }
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create recordings folder
        try? FileManager.default.createDirectory(atPath: Paths.recordingsBase, withIntermediateDirectories: true)

        // Setup status bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()
        setupMenu()

        // Setup recording manager callbacks
        setupRecordingCallbacks()

        // Setup main panel
        setupMainPanel()

        // Check for existing session
        RecordingManager.shared.checkExistingSession()
        updateStatusIcon()
        setupMenu()
    }

    // MARK: - Main Panel Setup

    private func setupMainPanel() {
        mainPanel = MainPanelController()

        mainPanel?.onSyncRequested = { [weak self] in
            self?.syncRecordings()
        }

        mainPanel?.onStopSyncRequested = { [weak self] in
            self?.isSyncing = false
            self?.mainPanel?.updateSyncingState(false)
        }

        mainPanel?.onOpenRecordings = { [weak self] in
            self?.openRecordingsFolder()
        }

        mainPanel?.onOpenOBS = { [weak self] in
            self?.openOBS()
        }

        mainPanel?.onStartRecording = { [weak self] in
            self?.showStartDialog()
        }

        mainPanel?.onStopRecording = { [weak self] in
            self?.stopRecording()
        }

        mainPanel?.onConfigureSync = { [weak self] in
            self?.configureCloudSync()
        }

        mainPanel?.onAddFolder = { [weak self] in
            self?.addSyncFolder()
        }

        mainPanel?.onTranscribeRecording = { [weak self] in
            self?.transcribeLastRecording()
        }
    }

    // MARK: - Recording Callbacks

    private func setupRecordingCallbacks() {
        let manager = RecordingManager.shared

        manager.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.updateStatusIcon()
                self?.setupMenu()

                switch state {
                case .starting:
                    break
                case .recording:
                    self?.progressWindow.hide()
                case .stopping:
                    break
                case .idle:
                    self?.progressWindow.hide()
                }
            }
        }

        manager.onProgress = { [weak self] message in
            self?.progressWindow.update(message: message)
        }

        manager.onError = { [weak self] message in
            self?.progressWindow.hide()
            showSystemNotification(title: "Error", body: message)
        }
    }

    // MARK: - Status Icon

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }

        if RecordingManager.shared.isRecording {
            if let image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording") {
                let config = NSImage.SymbolConfiguration(paletteColors: [.red])
                button.image = image.withSymbolConfiguration(config)
            }
        } else if isSyncing {
            // Animated sync icon
            let icons = ["arrow.triangle.2.circlepath", "arrow.triangle.2.circlepath.circle", "arrow.triangle.2.circlepath.circle.fill"]
            let iconName = icons[animationFrame % icons.count]
            if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Syncing") {
                let config = NSImage.SymbolConfiguration(paletteColors: [.systemBlue])
                button.image = image.withSymbolConfiguration(config)
            }
        } else {
            button.image = NSImage(systemSymbolName: "video.circle", accessibilityDescription: "Tutorial Recorder")
            button.image?.isTemplate = true
        }
    }

    private func startSyncIconAnimation() {
        guard syncAnimationTimer == nil else { return }
        syncAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.animationFrame += 1
            self?.updateStatusIcon()
        }
    }

    private func stopSyncIconAnimation() {
        syncAnimationTimer?.invalidate()
        syncAnimationTimer = nil
        animationFrame = 0
        updateStatusIcon()
    }

    // MARK: - Menu

    private func setupMenu() {
        let menu = NSMenu()
        let manager = RecordingManager.shared

        // Recording section
        if manager.isRecording {
            if let session = manager.currentSession {
                let recordingItem = NSMenuItem(title: "Recording: \(session.projectName)", action: nil, keyEquivalent: "")
                recordingItem.isEnabled = false
                menu.addItem(recordingItem)
            }
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "s"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Open Project Folder", action: #selector(openCurrentProject), keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "Start Recording...", action: #selector(showStartDialog), keyEquivalent: "r"))
        }

        menu.addItem(NSMenuItem.separator())

        // Cloud Sync section - clicking shows the panel
        if isSyncing {
            let syncingItem = NSMenuItem(title: "Syncing...", action: #selector(showSyncPanel), keyEquivalent: "")
            if let icon = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(paletteColors: [.systemBlue])
                syncingItem.image = icon.withSymbolConfiguration(config)
            }
            menu.addItem(syncingItem)
        } else {
            menu.addItem(NSMenuItem(title: "Sync Now", action: #selector(syncRecordings), keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem(title: "Sync Status & Activity...", action: #selector(showSyncPanel), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // Quick settings
        let autoCloseItem = NSMenuItem(title: "Auto-close OBS after recording", action: #selector(toggleAutoCloseOBS), keyEquivalent: "")
        autoCloseItem.state = autoCloseOBS ? .on : .off
        menu.addItem(autoCloseItem)

        let config = SyncManager.shared.loadConfig()
        let autoSyncItem = NSMenuItem(title: "Auto-sync after recording", action: #selector(toggleAutoSync), keyEquivalent: "")
        autoSyncItem.state = config.autoSync ? .on : .off
        menu.addItem(autoSyncItem)

        menu.addItem(NSMenuItem.separator())

        // Transcription
        let transcriptionItem = NSMenuItem(title: "Transcribe Last Recording", action: #selector(transcribeLastRecording), keyEquivalent: "t")
        if TranscriptionManager.shared.status.isTranscribing {
            transcriptionItem.title = "Transcribing..."
            transcriptionItem.isEnabled = false
        }
        menu.addItem(transcriptionItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open OBS", action: #selector(openOBS), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open Recordings Folder", action: #selector(openRecordingsFolder), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    // MARK: - Recording Actions

    @objc private func showStartDialog() {
        let existingProjects = RecordingManager.shared.getExistingProjects()

        let alert = NSAlert()
        alert.messageText = "Start Tutorial Recording"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Start Recording")
        alert.addButton(withTitle: "Cancel")

        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: existingProjects.isEmpty ? 60 : 120))

        let newLabel = NSTextField(labelWithString: "New project name:")
        newLabel.frame = NSRect(x: 0, y: containerView.frame.height - 20, width: 350, height: 17)
        containerView.addSubview(newLabel)

        let nameField = NSTextField(frame: NSRect(x: 0, y: containerView.frame.height - 45, width: 350, height: 24))
        nameField.placeholderString = "Enter project name..."
        containerView.addSubview(nameField)

        var projectPopup: NSPopUpButton?
        if !existingProjects.isEmpty {
            let existingLabel = NSTextField(labelWithString: "Or continue existing project:")
            existingLabel.frame = NSRect(x: 0, y: 30, width: 350, height: 17)
            containerView.addSubview(existingLabel)

            let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 350, height: 25))
            popup.addItem(withTitle: "-- Select existing project --")
            for project in existingProjects {
                popup.addItem(withTitle: project.name)
            }
            containerView.addSubview(popup)
            projectPopup = popup
        }

        alert.accessoryView = containerView
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            var projectPath: String?
            var projectName: String?

            if let popup = projectPopup, popup.indexOfSelectedItem > 0 {
                let selectedIndex = popup.indexOfSelectedItem - 1
                if selectedIndex < existingProjects.count {
                    projectPath = existingProjects[selectedIndex].path
                    projectName = existingProjects[selectedIndex].name
                }
            }

            if projectPath == nil {
                let name = nameField.stringValue.isEmpty ? "Untitled Tutorial" : nameField.stringValue
                projectName = name
                projectPath = RecordingManager.shared.createProjectFolder(name: name)
            }

            if let path = projectPath, let name = projectName {
                progressWindow.show(message: "Starting recording...")
                showSystemNotification(title: "Starting Recording", body: "Project: \(name)")
                RecordingManager.shared.startRecording(projectPath: path, projectName: name)
            }
        }
    }

    @objc private func stopRecording() {
        progressWindow.show(message: "Stopping recording...")

        RecordingManager.shared.stopRecording { [weak self] projectPath in
            self?.progressWindow.hide()
            showSystemNotification(title: "Recording Stopped", body: "Files collected to project folder")

            if let path = projectPath {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            }

            // Check auto-sync
            let config = SyncManager.shared.loadConfig()
            logInfo("Checking auto-sync after recording: autoSync=\(config.autoSync)")
            if config.autoSync {
                logInfo("Auto-sync enabled, starting sync...")
                showSystemNotification(title: "Auto-Sync", body: "Starting cloud sync...")
                self?.syncRecordings()
            }

            // Close OBS
            RecordingManager.shared.closeOBS(force: self?.autoCloseOBS ?? false)
        }
    }

    @objc private func openCurrentProject() {
        if let session = RecordingManager.shared.currentSession {
            NSWorkspace.shared.open(URL(fileURLWithPath: session.projectPath))
        }
    }

    // MARK: - Cloud Sync Actions

    @objc private func showSyncPanel() {
        mainPanel?.show(near: statusItem)
    }

    @objc private func syncRecordings() {
        guard !isSyncing else { return }

        let status = SyncManager.shared.checkRcloneStatus()
        guard status == .ready else {
            showSystemNotification(title: "Sync Not Configured", body: "Configure Google Drive first")
            configureCloudSync()
            return
        }

        isSyncing = true
        startSyncIconAnimation()
        setupMenu()
        mainPanel?.updateSyncingState(true)

        showSystemNotification(title: "Syncing", body: "Uploading to Google Drive...")

        SyncManager.shared.syncRecordings { [weak self] success, output in
            self?.isSyncing = false
            self?.stopSyncIconAnimation()
            self?.setupMenu()
            self?.mainPanel?.updateSyncingState(false)

            if success {
                showSystemNotification(title: "Sync Complete", body: "All files uploaded")
                logSuccess("Sync completed: \(output.prefix(100))")
            } else {
                showSystemNotification(title: "Sync Failed", body: "Check sync status for details")
                logError("Sync failed: \(output)")
            }
        }
    }

    @objc private func configureCloudSync() {
        if syncConfigWindow == nil {
            syncConfigWindow = SyncConfigWindowController()
            syncConfigWindow?.onSave = {
                logInfo("Cloud sync configuration saved")
            }
        }
        syncConfigWindow?.show()
    }

    @objc private func addSyncFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder to Sync"

        if panel.runModal() == .OK, let url = panel.url {
            let alert = NSAlert()
            alert.messageText = "Google Drive Destination"
            alert.informativeText = "Enter the folder name on Google Drive:"
            alert.addButton(withTitle: "Add")
            alert.addButton(withTitle: "Cancel")

            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            input.stringValue = url.lastPathComponent
            alert.accessoryView = input

            if alert.runModal() == .alertFirstButtonReturn && !input.stringValue.isEmpty {
                if SyncManager.shared.addFolder(localPath: url.path, remotePath: input.stringValue) {
                    showSystemNotification(title: "Folder Added", body: "Added: \(url.lastPathComponent)")
                }
            }
        }
    }

    // MARK: - Settings Actions

    @objc private func toggleAutoCloseOBS() {
        autoCloseOBS = !autoCloseOBS
        setupMenu()
        logInfo("Auto-close OBS: \(autoCloseOBS)")
    }

    @objc private func toggleAutoSync() {
        var config = SyncManager.shared.loadConfig()
        config.autoSync = !config.autoSync
        _ = SyncManager.shared.saveConfig(config)
        setupMenu()
        logInfo("Auto-sync: \(config.autoSync)")
    }

    // MARK: - Utility Actions

    @objc private func transcribeLastRecording() {
        let status = TranscriptionManager.shared.checkWhisperStatus()

        guard status == .ready else {
            let alert = NSAlert()
            alert.messageText = "Transcription Not Available"

            switch status {
            case .notInstalled:
                alert.informativeText = "whisper-cpp is not installed.\n\nInstall with: brew install whisper-cpp"
            case .noModel:
                alert.informativeText = "Whisper model not downloaded.\n\nOpen Preferences to download the model."
            case .ready:
                break
            }

            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Preferences")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                configureCloudSync()
            }
            return
        }

        TranscriptionManager.shared.transcribeLastRecording()
        setupMenu()
    }

    @objc private func openOBS() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/OBS.app"))
    }

    @objc private func openRecordingsFolder() {
        try? FileManager.default.createDirectory(atPath: Paths.recordingsBase, withIntermediateDirectories: true)
        NSWorkspace.shared.open(URL(fileURLWithPath: Paths.recordingsBase))
    }

    @objc private func quitApp() {
        if RecordingManager.shared.isRecording {
            let alert = NSAlert()
            alert.messageText = "Recording in Progress"
            alert.informativeText = "Stop recording before quitting?"
            alert.addButton(withTitle: "Stop and Quit")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                progressWindow.show(message: "Stopping recording...")
                RecordingManager.shared.stopRecording { _ in
                    NSApp.terminate(nil)
                }
            }
        } else {
            NSApp.terminate(nil)
        }
    }
}
