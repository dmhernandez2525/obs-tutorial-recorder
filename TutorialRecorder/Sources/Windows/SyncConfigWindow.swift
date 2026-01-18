import Cocoa

// MARK: - Sync Configuration Window Controller

class SyncConfigWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow!
    private var localPathField: NSTextField!
    private var remotePathField: NSTextField!
    private var autoSyncCheckbox: NSButton!
    private var exportsOnlyCheckbox: NSButton!
    private var statusLabel: NSTextField!
    private var rcloneStatusLabel: NSTextField!
    private var configureRcloneButton: NSButton!
    private var additionalFoldersTable: NSTableView!
    private var additionalFolders: [SyncFolder] = []

    // Transcription settings
    private var autoTranscribeCheckbox: NSButton!
    private var transcriptionModelPopup: NSPopUpButton!
    private var whisperStatusLabel: NSTextField!
    private var downloadModelButton: NSButton!

    var onSave: (() -> Void)?
    var onDismiss: (() -> Void)?

    override init() {
        super.init()
        setupWindow()
    }

    // MARK: - Window Setup

    private func setupWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.wantsLayer = true

        var y = 520

        // ===========================================
        // Transcription Section
        // ===========================================
        let transTitle = createLabel("Transcription Settings", bold: true)
        transTitle.frame = NSRect(x: 20, y: y, width: 460, height: 20)
        contentView.addSubview(transTitle)
        y -= 35

        // Whisper status row
        let whisperLabel = createLabel("Whisper Status:")
        whisperLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        contentView.addSubview(whisperLabel)

        whisperStatusLabel = createLabel("Checking...")
        whisperStatusLabel.frame = NSRect(x: 120, y: y, width: 200, height: 20)
        contentView.addSubview(whisperStatusLabel)

        downloadModelButton = NSButton(title: "Download Model", target: self, action: #selector(downloadModelClicked))
        downloadModelButton.frame = NSRect(x: 340, y: y - 2, width: 140, height: 24)
        downloadModelButton.bezelStyle = .rounded
        contentView.addSubview(downloadModelButton)
        y -= 35

        // Auto-transcribe checkbox
        autoTranscribeCheckbox = NSButton(checkboxWithTitle: "Auto-transcribe recordings after completion", target: nil, action: nil)
        autoTranscribeCheckbox.frame = NSRect(x: 20, y: y, width: 350, height: 20)
        contentView.addSubview(autoTranscribeCheckbox)
        y -= 30

        // Model selection
        let modelLabel = createLabel("Transcription Model:")
        modelLabel.frame = NSRect(x: 20, y: y, width: 130, height: 20)
        contentView.addSubview(modelLabel)

        transcriptionModelPopup = NSPopUpButton(frame: NSRect(x: 150, y: y - 2, width: 330, height: 24))
        for model in TranscriptionModel.allCases {
            transcriptionModelPopup.addItem(withTitle: model.displayName)
        }
        contentView.addSubview(transcriptionModelPopup)
        y -= 35

        // Separator
        contentView.addSubview(createSeparator(y: y))
        y -= 25

        // ===========================================
        // Cloud Sync Section
        // ===========================================
        let titleLabel = createLabel("Google Drive Sync Settings", bold: true)
        titleLabel.frame = NSRect(x: 20, y: y, width: 460, height: 20)
        contentView.addSubview(titleLabel)
        y -= 35

        // rclone status row
        let rcloneLabel = createLabel("rclone Status:")
        rcloneLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        contentView.addSubview(rcloneLabel)

        rcloneStatusLabel = createLabel("Checking...")
        rcloneStatusLabel.frame = NSRect(x: 120, y: y, width: 200, height: 20)
        contentView.addSubview(rcloneStatusLabel)

        configureRcloneButton = NSButton(title: "Configure rclone", target: self, action: #selector(configureRcloneClicked))
        configureRcloneButton.frame = NSRect(x: 340, y: y - 2, width: 140, height: 24)
        configureRcloneButton.bezelStyle = .rounded
        contentView.addSubview(configureRcloneButton)
        y -= 40

        // Separator
        contentView.addSubview(createSeparator(y: y))
        y -= 25

        // Local folder
        let localLabel = createLabel("Local Recordings Folder:")
        localLabel.frame = NSRect(x: 20, y: y, width: 200, height: 17)
        contentView.addSubview(localLabel)
        y -= 25

        localPathField = NSTextField(frame: NSRect(x: 20, y: y, width: 370, height: 24))
        localPathField.placeholderString = "~/Desktop/Tutorial Recordings"
        contentView.addSubview(localPathField)

        let browseLocalButton = NSButton(title: "Browse...", target: self, action: #selector(browseLocalClicked))
        browseLocalButton.frame = NSRect(x: 400, y: y, width: 80, height: 24)
        browseLocalButton.bezelStyle = .rounded
        contentView.addSubview(browseLocalButton)
        y -= 35

        // Remote folder
        let remoteLabel = createLabel("Google Drive Folder:")
        remoteLabel.frame = NSRect(x: 20, y: y, width: 200, height: 17)
        contentView.addSubview(remoteLabel)
        y -= 25

        remotePathField = NSTextField(frame: NSRect(x: 20, y: y, width: 460, height: 24))
        remotePathField.placeholderString = "Tutorial Recordings"
        contentView.addSubview(remotePathField)
        y -= 35

        // Options
        autoSyncCheckbox = NSButton(checkboxWithTitle: "Auto-sync after recording stops", target: nil, action: nil)
        autoSyncCheckbox.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        contentView.addSubview(autoSyncCheckbox)
        y -= 25

        exportsOnlyCheckbox = NSButton(checkboxWithTitle: "Only sync exports folder (skip raw files)", target: nil, action: nil)
        exportsOnlyCheckbox.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        contentView.addSubview(exportsOnlyCheckbox)
        y -= 30

        // Separator
        contentView.addSubview(createSeparator(y: y))
        y -= 25

        // Additional folders section
        let additionalLabel = createLabel("Additional Folders to Sync:")
        additionalLabel.frame = NSRect(x: 20, y: y, width: 200, height: 17)
        contentView.addSubview(additionalLabel)

        let addFolderButton = NSButton(title: "+", target: self, action: #selector(addFolderClicked))
        addFolderButton.frame = NSRect(x: 430, y: y - 2, width: 25, height: 22)
        addFolderButton.bezelStyle = .rounded
        contentView.addSubview(addFolderButton)

        let removeFolderButton = NSButton(title: "-", target: self, action: #selector(removeFolderClicked))
        removeFolderButton.frame = NSRect(x: 455, y: y - 2, width: 25, height: 22)
        removeFolderButton.bezelStyle = .rounded
        contentView.addSubview(removeFolderButton)
        y -= 85

        // Folders table
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: y, width: 460, height: 70))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        additionalFoldersTable = NSTableView()
        let localColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("local"))
        localColumn.title = "Local Path"
        localColumn.width = 250
        let remoteColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("remote"))
        remoteColumn.title = "Remote Path"
        remoteColumn.width = 180
        additionalFoldersTable.addTableColumn(localColumn)
        additionalFoldersTable.addTableColumn(remoteColumn)
        additionalFoldersTable.delegate = self
        additionalFoldersTable.dataSource = self
        scrollView.documentView = additionalFoldersTable
        contentView.addSubview(scrollView)
        y -= 30

        // Status label
        statusLabel = createLabel("")
        statusLabel.frame = NSRect(x: 20, y: y, width: 460, height: 17)
        statusLabel.textColor = .secondaryLabelColor
        contentView.addSubview(statusLabel)

        // Bottom buttons
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        cancelButton.frame = NSRect(x: 300, y: 15, width: 80, height: 32)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveClicked))
        saveButton.frame = NSRect(x: 390, y: 15, width: 90, height: 32)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)

        let testButton = NSButton(title: "Test Sync", target: self, action: #selector(testSyncClicked))
        testButton.frame = NSRect(x: 20, y: 15, width: 100, height: 32)
        testButton.bezelStyle = .rounded
        contentView.addSubview(testButton)

        window.contentView = contentView
    }

    // MARK: - Helper Methods

    private func createLabel(_ text: String, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        if bold {
            label.font = NSFont.boldSystemFont(ofSize: 14)
        }
        return label
    }

    private func createSeparator(y: Int) -> NSBox {
        let separator = NSBox(frame: NSRect(x: 20, y: y, width: 460, height: 1))
        separator.boxType = .separator
        return separator
    }

    // MARK: - Public Methods

    func show() {
        loadConfig()
        refreshRcloneStatus()
        refreshWhisperStatus()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func loadConfig() {
        // Load sync config
        let syncConfig = SyncManager.shared.loadConfig()
        localPathField.stringValue = syncConfig.localPath
        remotePathField.stringValue = syncConfig.remotePath
        autoSyncCheckbox.state = syncConfig.autoSync ? .on : .off
        exportsOnlyCheckbox.state = syncConfig.syncExportsOnly ? .on : .off
        additionalFolders = syncConfig.additionalFolders
        additionalFoldersTable.reloadData()

        // Load transcription config
        let transConfig = TranscriptionManager.shared.loadConfig()
        autoTranscribeCheckbox.state = transConfig.enabled ? .on : .off

        // Select the correct model in popup
        let modelIndex = TranscriptionModel.allCases.firstIndex { $0.rawValue == transConfig.model } ?? 2
        transcriptionModelPopup.selectItem(at: modelIndex)
    }

    func refreshRcloneStatus() {
        rcloneStatusLabel.stringValue = "Checking..."
        rcloneStatusLabel.textColor = .secondaryLabelColor

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let status = SyncManager.shared.checkRcloneStatus()

            DispatchQueue.main.async {
                guard let self = self else { return }

                switch status {
                case .notInstalled:
                    self.rcloneStatusLabel.stringValue = "Not installed"
                    self.rcloneStatusLabel.textColor = .systemRed
                    self.configureRcloneButton.title = "Install rclone"

                case .notConfigured:
                    self.rcloneStatusLabel.stringValue = "Not configured"
                    self.rcloneStatusLabel.textColor = .systemOrange
                    self.configureRcloneButton.title = "Configure rclone"

                case .ready:
                    self.rcloneStatusLabel.stringValue = "Ready"
                    self.rcloneStatusLabel.textColor = .systemGreen
                    self.configureRcloneButton.title = "Reconfigure"
                }
            }
        }
    }

    func refreshWhisperStatus() {
        whisperStatusLabel.stringValue = "Checking..."
        whisperStatusLabel.textColor = .secondaryLabelColor

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let status = TranscriptionManager.shared.checkWhisperStatus()

            DispatchQueue.main.async {
                guard let self = self else { return }

                switch status {
                case .notInstalled:
                    self.whisperStatusLabel.stringValue = "Not installed"
                    self.whisperStatusLabel.textColor = .systemRed
                    self.downloadModelButton.title = "Install Whisper"
                    self.downloadModelButton.isEnabled = true

                case .noModel:
                    self.whisperStatusLabel.stringValue = "Model needed"
                    self.whisperStatusLabel.textColor = .systemOrange
                    self.downloadModelButton.title = "Download Model"
                    self.downloadModelButton.isEnabled = true

                case .ready:
                    self.whisperStatusLabel.stringValue = "Ready"
                    self.whisperStatusLabel.textColor = .systemGreen
                    self.downloadModelButton.title = "Re-download"
                    self.downloadModelButton.isEnabled = true
                }
            }
        }
    }

    // MARK: - Button Actions

    @objc private func browseLocalClicked() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if !localPathField.stringValue.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: localPathField.stringValue)
        }
        panel.prompt = "Select Folder"

        if panel.runModal() == .OK, let url = panel.url {
            localPathField.stringValue = url.path
        }
    }

    @objc private func configureRcloneClicked() {
        let status = SyncManager.shared.checkRcloneStatus()

        switch status {
        case .notInstalled:
            statusLabel.stringValue = "Installing rclone via Homebrew..."
            configureRcloneButton.isEnabled = false

            SyncManager.shared.installRclone { [weak self] success, output in
                self?.configureRcloneButton.isEnabled = true

                if success {
                    self?.statusLabel.stringValue = "rclone installed! Click Configure again."
                } else {
                    self?.statusLabel.stringValue = "Install failed. Run: brew install rclone"
                    logError("rclone install failed: \(output)")
                }
                self?.refreshRcloneStatus()
            }

        case .notConfigured, .ready:
            statusLabel.stringValue = "Opening browser for Google authentication..."

            SyncManager.shared.configureRclone { [weak self] success in
                if success {
                    self?.statusLabel.stringValue = "Complete setup in Terminal, then click Save."
                } else {
                    self?.statusLabel.stringValue = "Could not open Terminal. Run: rclone config"
                }

                // Check status after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    self?.refreshRcloneStatus()
                }
            }
        }
    }

    @objc private func addFolderClicked() {
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
                let folder = SyncFolder(local: url.path, remote: input.stringValue, excludes: [])
                additionalFolders.append(folder)
                additionalFoldersTable.reloadData()
            }
        }
    }

    @objc private func removeFolderClicked() {
        let selectedRow = additionalFoldersTable.selectedRow
        if selectedRow >= 0 && selectedRow < additionalFolders.count {
            additionalFolders.remove(at: selectedRow)
            additionalFoldersTable.reloadData()
        }
    }

    @objc private func testSyncClicked() {
        statusLabel.stringValue = "Testing sync (dry run)..."

        SyncManager.shared.testSync { [weak self] success, output in
            if output.contains("dry run") || output.contains("Transferred") {
                self?.statusLabel.stringValue = "Test complete - no errors found"
            } else if output.contains("error") || output.contains("failed") {
                self?.statusLabel.stringValue = "Test failed - check rclone configuration"
            } else {
                self?.statusLabel.stringValue = "Test complete"
            }
        }
    }

    @objc private func downloadModelClicked() {
        let whisperStatus = TranscriptionManager.shared.checkWhisperStatus()

        if whisperStatus == .notInstalled {
            // Install whisper-cpp
            statusLabel.stringValue = "Installing whisper-cpp via Homebrew..."
            downloadModelButton.isEnabled = false

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = runShellCommand("/opt/homebrew/bin/brew install whisper-cpp 2>&1 || /usr/local/bin/brew install whisper-cpp 2>&1", timeout: 300)

                DispatchQueue.main.async {
                    self?.downloadModelButton.isEnabled = true
                    if result.success {
                        self?.statusLabel.stringValue = "whisper-cpp installed! Click Download Model."
                    } else {
                        self?.statusLabel.stringValue = "Install failed. Run: brew install whisper-cpp"
                    }
                    self?.refreshWhisperStatus()
                }
            }
        } else {
            // Download the selected model
            let selectedIndex = transcriptionModelPopup.indexOfSelectedItem
            guard selectedIndex >= 0 && selectedIndex < TranscriptionModel.allCases.count else { return }
            let model = TranscriptionModel.allCases[selectedIndex]

            statusLabel.stringValue = "Downloading \(model.rawValue) model..."
            downloadModelButton.isEnabled = false

            TranscriptionManager.shared.downloadModel(model, progress: { [weak self] message in
                DispatchQueue.main.async {
                    self?.statusLabel.stringValue = message
                }
            }) { [weak self] success in
                DispatchQueue.main.async {
                    self?.downloadModelButton.isEnabled = true
                    if success {
                        self?.statusLabel.stringValue = "Model downloaded successfully!"
                    } else {
                        self?.statusLabel.stringValue = "Download failed. Check internet connection."
                    }
                    self?.refreshWhisperStatus()
                }
            }
        }
    }

    @objc private func saveClicked() {
        // Save sync config
        let syncConfig = SyncConfig(
            rcloneRemote: "tutorial-recordings",
            localPath: localPathField.stringValue,
            remotePath: remotePathField.stringValue,
            autoSync: autoSyncCheckbox.state == .on,
            syncExportsOnly: exportsOnlyCheckbox.state == .on,
            excludePatterns: ["*.tmp", "*.part", ".DS_Store", "Thumbs.db"],
            additionalFolders: additionalFolders
        )

        // Save transcription config
        let selectedModelIndex = transcriptionModelPopup.indexOfSelectedItem
        let selectedModel = selectedModelIndex >= 0 && selectedModelIndex < TranscriptionModel.allCases.count
            ? TranscriptionModel.allCases[selectedModelIndex].rawValue
            : "small"

        let transConfig = TranscriptionConfig(
            enabled: autoTranscribeCheckbox.state == .on,
            model: selectedModel,
            outputFormat: "txt",
            language: "en"
        )

        let syncSaved = SyncManager.shared.saveConfig(syncConfig)
        let transSaved = TranscriptionManager.shared.saveConfig(transConfig)

        if syncSaved && transSaved {
            statusLabel.stringValue = "Configuration saved!"
            onSave?()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.window.close()
            }
        } else {
            statusLabel.stringValue = "Failed to save configuration"
        }
    }

    @objc private func cancelClicked() {
        window.close()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        onDismiss?()
    }
}

// MARK: - NSTableViewDelegate & NSTableViewDataSource

extension SyncConfigWindowController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return additionalFolders.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < additionalFolders.count else { return nil }

        let folder = additionalFolders[row]
        let text: String

        if tableColumn?.identifier.rawValue == "local" {
            text = folder.local
        } else {
            text = folder.remote
        }

        let textField = NSTextField(labelWithString: text)
        textField.lineBreakMode = .byTruncatingMiddle
        return textField
    }
}
