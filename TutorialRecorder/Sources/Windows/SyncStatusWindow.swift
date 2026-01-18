import Cocoa

// MARK: - Sync Status Window Controller

class SyncStatusWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow!
    private var statusLabel: NSTextField!
    private var lastSyncLabel: NSTextField!
    private var driveUsageLabel: NSTextField!
    private var localFolderLabel: NSTextField!
    private var remoteFolderLabel: NSTextField!
    private var autoSyncLabel: NSTextField!
    private var pendingFilesTable: NSTableView!
    private var syncedFoldersTable: NSTableView!
    private var refreshButton: NSButton!
    private var syncNowButton: NSButton!
    private var outputTextView: NSTextView!

    private var pendingFiles: [(file: String, size: String)] = []
    private var syncedFolders: [(name: String, status: String)] = []

    var onSyncRequested: (() -> Void)?

    override init() {
        super.init()
        setupWindow()
    }

    private func setupWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Cloud Sync Status"
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 500, height: 400)

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.wantsLayer = true

        var y = 480

        // Status header
        let titleLabel = createLabel("Sync Status", bold: true, size: 16)
        titleLabel.frame = NSRect(x: 20, y: y, width: 200, height: 24)
        contentView.addSubview(titleLabel)

        statusLabel = createLabel("Checking...")
        statusLabel.frame = NSRect(x: 200, y: y, width: 380, height: 24)
        contentView.addSubview(statusLabel)
        y -= 30

        // Last sync
        let lastSyncTitle = createLabel("Last Sync:")
        lastSyncTitle.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        contentView.addSubview(lastSyncTitle)

        lastSyncLabel = createLabel("Never")
        lastSyncLabel.frame = NSRect(x: 120, y: y, width: 200, height: 20)
        lastSyncLabel.textColor = .secondaryLabelColor
        contentView.addSubview(lastSyncLabel)

        // Drive usage
        let driveTitle = createLabel("Drive Usage:")
        driveTitle.frame = NSRect(x: 340, y: y, width: 100, height: 20)
        contentView.addSubview(driveTitle)

        driveUsageLabel = createLabel("Unknown")
        driveUsageLabel.frame = NSRect(x: 440, y: y, width: 140, height: 20)
        driveUsageLabel.textColor = .secondaryLabelColor
        contentView.addSubview(driveUsageLabel)
        y -= 30

        // Separator
        contentView.addSubview(createSeparator(y: y))
        y -= 20

        // Configuration section
        let configTitle = createLabel("Configuration", bold: true)
        configTitle.frame = NSRect(x: 20, y: y, width: 200, height: 20)
        contentView.addSubview(configTitle)
        y -= 25

        // Local folder
        let localTitle = createLabel("Local Folder:")
        localTitle.frame = NSRect(x: 20, y: y, width: 100, height: 17)
        contentView.addSubview(localTitle)

        localFolderLabel = createLabel("~/Desktop/Tutorial Recordings")
        localFolderLabel.frame = NSRect(x: 120, y: y, width: 460, height: 17)
        localFolderLabel.textColor = .secondaryLabelColor
        localFolderLabel.lineBreakMode = .byTruncatingMiddle
        contentView.addSubview(localFolderLabel)
        y -= 22

        // Remote folder
        let remoteTitle = createLabel("Google Drive:")
        remoteTitle.frame = NSRect(x: 20, y: y, width: 100, height: 17)
        contentView.addSubview(remoteTitle)

        remoteFolderLabel = createLabel("Tutorial Recordings")
        remoteFolderLabel.frame = NSRect(x: 120, y: y, width: 300, height: 17)
        remoteFolderLabel.textColor = .secondaryLabelColor
        contentView.addSubview(remoteFolderLabel)

        // Auto-sync
        let autoTitle = createLabel("Auto-sync:")
        autoTitle.frame = NSRect(x: 400, y: y, width: 80, height: 17)
        contentView.addSubview(autoTitle)

        autoSyncLabel = createLabel("Off")
        autoSyncLabel.frame = NSRect(x: 480, y: y, width: 100, height: 17)
        autoSyncLabel.textColor = .secondaryLabelColor
        contentView.addSubview(autoSyncLabel)
        y -= 25

        // Separator
        contentView.addSubview(createSeparator(y: y))
        y -= 20

        // Synced folders section
        let foldersTitle = createLabel("Synced Folders", bold: true)
        foldersTitle.frame = NSRect(x: 20, y: y, width: 200, height: 20)
        contentView.addSubview(foldersTitle)
        y -= 75

        let foldersScroll = NSScrollView(frame: NSRect(x: 20, y: y, width: 560, height: 60))
        foldersScroll.hasVerticalScroller = true
        foldersScroll.borderType = .bezelBorder

        syncedFoldersTable = NSTableView()
        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Folder"
        nameCol.width = 400
        let statusCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusCol.title = "Status"
        statusCol.width = 130
        syncedFoldersTable.addTableColumn(nameCol)
        syncedFoldersTable.addTableColumn(statusCol)
        syncedFoldersTable.delegate = self
        syncedFoldersTable.dataSource = self
        syncedFoldersTable.tag = 1
        foldersScroll.documentView = syncedFoldersTable
        contentView.addSubview(foldersScroll)
        y -= 25

        // Separator
        contentView.addSubview(createSeparator(y: y))
        y -= 20

        // Pending files section
        let pendingTitle = createLabel("Pending Files (not yet synced)", bold: true)
        pendingTitle.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        contentView.addSubview(pendingTitle)
        y -= 105

        let pendingScroll = NSScrollView(frame: NSRect(x: 20, y: y, width: 560, height: 90))
        pendingScroll.hasVerticalScroller = true
        pendingScroll.borderType = .bezelBorder

        pendingFilesTable = NSTableView()
        let fileCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        fileCol.title = "File"
        fileCol.width = 530
        pendingFilesTable.addTableColumn(fileCol)
        pendingFilesTable.delegate = self
        pendingFilesTable.dataSource = self
        pendingFilesTable.tag = 2
        pendingScroll.documentView = pendingFilesTable
        contentView.addSubview(pendingScroll)
        y -= 25

        // Separator
        contentView.addSubview(createSeparator(y: y))
        y -= 20

        // Output section
        let outputTitle = createLabel("Last Sync Output", bold: true)
        outputTitle.frame = NSRect(x: 20, y: y, width: 200, height: 20)
        contentView.addSubview(outputTitle)
        y -= 75

        let outputScroll = NSScrollView(frame: NSRect(x: 20, y: y, width: 560, height: 60))
        outputScroll.hasVerticalScroller = true
        outputScroll.borderType = .bezelBorder

        outputTextView = NSTextView(frame: outputScroll.bounds)
        outputTextView.isEditable = false
        outputTextView.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        outputTextView.textColor = .secondaryLabelColor
        outputScroll.documentView = outputTextView
        contentView.addSubview(outputScroll)

        // Bottom buttons
        refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshClicked))
        refreshButton.frame = NSRect(x: 20, y: 15, width: 100, height: 32)
        refreshButton.bezelStyle = .rounded
        contentView.addSubview(refreshButton)

        syncNowButton = NSButton(title: "Sync Now", target: self, action: #selector(syncNowClicked))
        syncNowButton.frame = NSRect(x: 480, y: 15, width: 100, height: 32)
        syncNowButton.bezelStyle = .rounded
        contentView.addSubview(syncNowButton)

        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeClicked))
        closeButton.frame = NSRect(x: 370, y: 15, width: 100, height: 32)
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(closeButton)

        window.contentView = contentView
    }

    private func createLabel(_ text: String, bold: Bool = false, size: CGFloat = 13) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        if bold {
            label.font = NSFont.boldSystemFont(ofSize: size)
        } else {
            label.font = NSFont.systemFont(ofSize: size)
        }
        return label
    }

    private func createSeparator(y: Int) -> NSBox {
        let separator = NSBox(frame: NSRect(x: 20, y: y, width: 560, height: 1))
        separator.boxType = .separator
        return separator
    }

    // MARK: - Public Methods

    func show() {
        refresh()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh() {
        statusLabel.stringValue = "Checking..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let (rcloneInstalled, remoteConfigured, driveUsage, config) = SyncManager.shared.getStatusInfo()
            let lastSync = SyncManager.shared.getLastSyncTimeFormatted()
            let syncOutput = SyncManager.shared.syncStatus.output

            // Get pending files
            SyncManager.shared.getPendingFiles { pending in
                self?.pendingFiles = pending
                DispatchQueue.main.async {
                    self?.pendingFilesTable.reloadData()
                }
            }

            DispatchQueue.main.async {
                guard let self = self else { return }

                // Update status
                if !rcloneInstalled {
                    self.statusLabel.stringValue = "rclone not installed"
                    self.statusLabel.textColor = .systemRed
                } else if !remoteConfigured {
                    self.statusLabel.stringValue = "Google Drive not configured"
                    self.statusLabel.textColor = .systemOrange
                } else {
                    self.statusLabel.stringValue = "Ready"
                    self.statusLabel.textColor = .systemGreen
                }

                // Update labels
                self.lastSyncLabel.stringValue = lastSync
                self.driveUsageLabel.stringValue = driveUsage.isEmpty ? "Unknown" : driveUsage
                self.localFolderLabel.stringValue = config.localPath
                self.remoteFolderLabel.stringValue = config.remotePath
                self.autoSyncLabel.stringValue = config.autoSync ? "On" : "Off"
                self.autoSyncLabel.textColor = config.autoSync ? .systemGreen : .secondaryLabelColor

                // Update folders list
                self.syncedFolders = [(name: config.localPath, status: "Main")]
                for folder in config.additionalFolders {
                    self.syncedFolders.append((name: folder.local, status: "Additional"))
                }
                self.syncedFoldersTable.reloadData()

                // Update output
                if !syncOutput.isEmpty {
                    self.outputTextView.string = syncOutput
                } else {
                    self.outputTextView.string = "No sync has been performed yet."
                }
            }
        }
    }

    func updateSyncingState(_ isSyncing: Bool) {
        DispatchQueue.main.async { [weak self] in
            if isSyncing {
                self?.statusLabel.stringValue = "Syncing..."
                self?.statusLabel.textColor = .systemBlue
                self?.syncNowButton.isEnabled = false
            } else {
                self?.syncNowButton.isEnabled = true
                self?.refresh()
            }
        }
    }

    // MARK: - Actions

    @objc private func refreshClicked() {
        refresh()
    }

    @objc private func syncNowClicked() {
        onSyncRequested?()
    }

    @objc private func closeClicked() {
        window.close()
    }
}

// MARK: - NSTableViewDelegate & NSTableViewDataSource

extension SyncStatusWindowController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView.tag == 1 {
            return syncedFolders.count
        } else {
            return pendingFiles.count
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView.tag == 1 {
            // Synced folders table
            guard row < syncedFolders.count else { return nil }
            let folder = syncedFolders[row]

            if tableColumn?.identifier.rawValue == "name" {
                let label = NSTextField(labelWithString: folder.name)
                label.lineBreakMode = .byTruncatingMiddle
                return label
            } else {
                let label = NSTextField(labelWithString: folder.status)
                label.textColor = .secondaryLabelColor
                return label
            }
        } else {
            // Pending files table
            guard row < pendingFiles.count else { return nil }
            let file = pendingFiles[row]

            let label = NSTextField(labelWithString: file.file)
            label.lineBreakMode = .byTruncatingMiddle
            label.textColor = .secondaryLabelColor
            return label
        }
    }
}
