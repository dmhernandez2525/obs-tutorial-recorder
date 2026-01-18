import Cocoa

// MARK: - Google-Style Colors

struct GoogleColors {
    // Primary
    static let blue = NSColor(red: 0.10, green: 0.45, blue: 0.91, alpha: 1.0)        // #1A73E8
    static let blueLight = NSColor(red: 0.91, green: 0.94, blue: 0.99, alpha: 1.0)   // #E8F0FE
    static let blueHover = NSColor(red: 0.08, green: 0.34, blue: 0.69, alpha: 1.0)   // #1557B0

    // Status
    static let green = NSColor(red: 0.20, green: 0.66, blue: 0.33, alpha: 1.0)       // #34A853
    static let yellow = NSColor(red: 0.98, green: 0.74, blue: 0.02, alpha: 1.0)      // #FBBC04
    static let yellowBg = NSColor(red: 1.0, green: 0.97, blue: 0.88, alpha: 1.0)     // #FEF7E0
    static let red = NSColor(red: 0.92, green: 0.26, blue: 0.21, alpha: 1.0)         // #EA4335

    // Neutral
    static let textPrimary = NSColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1.0) // #202124
    static let textSecondary = NSColor(red: 0.37, green: 0.38, blue: 0.41, alpha: 1.0) // #5F6368
    static let textTertiary = NSColor(red: 0.50, green: 0.53, blue: 0.55, alpha: 1.0) // #80868B
    static let border = NSColor(red: 0.85, green: 0.87, blue: 0.88, alpha: 1.0)      // #DADCE0
    static let bgSecondary = NSColor(red: 0.95, green: 0.96, blue: 0.96, alpha: 1.0) // #F1F3F4
    static let bgHover = NSColor(red: 0.91, green: 0.92, blue: 0.93, alpha: 1.0)     // #E8EAED
}

// MARK: - Navigation

enum NavigationItem: String, CaseIterable {
    case home = "Home"
    case syncActivity = "Sync activity"
    case notifications = "Notifications"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .syncActivity: return "arrow.triangle.2.circlepath"
        case .notifications: return "bell.fill"
        }
    }
}

// MARK: - File Activity

struct FileActivityItem {
    let id: UUID
    let filename: String
    let path: String
    let size: Int64
    let status: FileStatus
    let timestamp: Date

    enum FileStatus {
        case pending
        case uploading(progress: Double)
        case uploaded
        case error(String)

        var icon: String {
            switch self {
            case .pending: return "clock.fill"
            case .uploading: return "arrow.up.circle.fill"
            case .uploaded: return "checkmark.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            }
        }

        var color: NSColor {
            switch self {
            case .pending: return GoogleColors.textTertiary
            case .uploading, .uploaded: return GoogleColors.blue
            case .error: return GoogleColors.red
            }
        }

        var text: String {
            switch self {
            case .pending: return "Pending"
            case .uploading(let progress): return "\(Int(progress * 100))% uploaded"
            case .uploaded: return "100% uploaded"
            case .error(let msg): return msg
            }
        }
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - App Notification

struct AppNotification {
    let id: UUID
    let type: NotificationType
    let title: String
    let body: String
    let timestamp: Date
    var isRead: Bool
    var primaryAction: (title: String, action: () -> Void)?
    var secondaryAction: (title: String, action: () -> Void)?

    enum NotificationType {
        case info, success, warning, error

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "exclamationmark.circle.fill"
            }
        }

        var color: NSColor {
            switch self {
            case .info: return GoogleColors.blue
            case .success: return GoogleColors.green
            case .warning: return GoogleColors.yellow
            case .error: return GoogleColors.red
            }
        }
    }
}

// MARK: - Main Panel Controller

class MainPanelController: NSObject, NSWindowDelegate {
    private var window: NSPanel!
    private var contentContainer: NSView!
    private var sidebarView: NSView!
    private var headerView: NSView!

    // Navigation
    private var selectedNav: NavigationItem = .home
    private var navButtons: [NavigationItem: NSButton] = [:]

    // Data
    private var fileActivities: [FileActivityItem] = []
    private var notifications: [AppNotification] = []
    private var unreadCount: Int = 0

    // Sync state
    private var isSyncing = false
    private var isPaused = false
    private var syncFileCount = 0
    private var syncErrorCount = 0

    // Animation
    private var syncAnimationTimer: Timer?
    private var animationAngle: CGFloat = 0

    // Header buttons
    private var pauseButton: NSButton!
    private var settingsButton: NSButton!

    // Callbacks
    var onSyncRequested: (() -> Void)?
    var onStopSyncRequested: (() -> Void)?
    var onOpenRecordings: (() -> Void)?
    var onOpenOBS: (() -> Void)?
    var onStartRecording: (() -> Void)?
    var onStopRecording: (() -> Void)?
    var onConfigureSync: (() -> Void)?
    var onAddFolder: (() -> Void)?
    var onTranscribeRecording: (() -> Void)?

    override init() {
        super.init()
        setupWindow()
        loadData()
    }

    // MARK: - Window Setup

    private func setupWindow() {
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Tutorial Recorder"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
        window.backgroundColor = .white
        window.minSize = NSSize(width: 600, height: 400)
        window.isMovableByWindowBackground = true

        let mainView = NSView(frame: window.contentView!.bounds)
        mainView.wantsLayer = true
        mainView.layer?.backgroundColor = NSColor.white.cgColor
        window.contentView = mainView

        buildLayout(in: mainView)
    }

    private func buildLayout(in container: NSView) {
        // Clear existing
        container.subviews.forEach { $0.removeFromSuperview() }

        let bounds = container.bounds

        // Header (56px)
        headerView = buildHeader()
        headerView.frame = NSRect(x: 0, y: bounds.height - 56, width: bounds.width, height: 56)
        headerView.autoresizingMask = [.width, .minYMargin]
        container.addSubview(headerView)

        // Sidebar (200px)
        sidebarView = buildSidebar()
        sidebarView.frame = NSRect(x: 0, y: 0, width: 200, height: bounds.height - 56)
        sidebarView.autoresizingMask = [.height]
        container.addSubview(sidebarView)

        // Content area
        contentContainer = NSView(frame: NSRect(x: 200, y: 0, width: bounds.width - 200, height: bounds.height - 56))
        contentContainer.wantsLayer = true
        contentContainer.autoresizingMask = [.width, .height]
        container.addSubview(contentContainer)

        // Show initial screen
        showScreen(selectedNav)
    }

    // MARK: - Header

    private func buildHeader() -> NSView {
        let header = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 56))
        header.wantsLayer = true
        header.layer?.backgroundColor = NSColor.white.cgColor

        // Bottom border
        let border = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 1))
        border.wantsLayer = true
        border.layer?.backgroundColor = GoogleColors.border.cgColor
        border.autoresizingMask = [.width]
        header.addSubview(border)

        // App icon
        let appIcon = NSImageView(frame: NSRect(x: 20, y: 14, width: 28, height: 28))
        if let img = NSImage(systemSymbolName: "video.circle.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 24, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [GoogleColors.blue]))
            appIcon.image = img.withSymbolConfiguration(config)
        }
        header.addSubview(appIcon)

        // App title
        let title = NSTextField(labelWithString: "Tutorial Recorder")
        title.frame = NSRect(x: 54, y: 18, width: 140, height: 20)
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        title.textColor = GoogleColors.textPrimary
        header.addSubview(title)

        // Right side buttons
        var rightX: CGFloat = 680

        // Settings button
        settingsButton = createIconButton(icon: "gearshape.fill", action: #selector(settingsClicked))
        settingsButton.frame = NSRect(x: rightX - 32, y: 12, width: 32, height: 32)
        settingsButton.autoresizingMask = [.minXMargin]
        header.addSubview(settingsButton)
        rightX -= 40

        // Pause button
        pauseButton = createIconButton(icon: isPaused ? "play.circle" : "pause.circle", action: #selector(pauseClicked))
        pauseButton.frame = NSRect(x: rightX - 32, y: 12, width: 32, height: 32)
        pauseButton.autoresizingMask = [.minXMargin]
        pauseButton.toolTip = isPaused ? "Resume syncing" : "Pause syncing"
        header.addSubview(pauseButton)

        return header
    }

    private func createIconButton(icon: String, action: Selector) -> NSButton {
        let btn = NSButton(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.target = self
        btn.action = action

        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [GoogleColors.textSecondary]))
            btn.image = img.withSymbolConfiguration(config)
        }

        // Hover tracking
        let trackingArea = NSTrackingArea(
            rect: btn.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: btn,
            userInfo: nil
        )
        btn.addTrackingArea(trackingArea)

        return btn
    }

    // MARK: - Sidebar

    private func buildSidebar() -> NSView {
        let sidebar = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 500))
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = NSColor.white.cgColor

        var y = sidebar.frame.height - 20

        // Open Recordings button
        let openBtn = NSButton(frame: NSRect(x: 10, y: y - 36, width: 180, height: 36))
        openBtn.title = "  Open Recordings"
        openBtn.bezelStyle = .rounded
        openBtn.target = self
        openBtn.action = #selector(openRecordingsClicked)
        openBtn.font = NSFont.systemFont(ofSize: 13, weight: .medium)

        if let img = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [GoogleColors.textSecondary]))
            openBtn.image = img.withSymbolConfiguration(config)
            openBtn.imagePosition = .imageLeft
        }

        sidebar.addSubview(openBtn)
        y -= 56

        // Navigation items
        navButtons.removeAll()

        for item in NavigationItem.allCases {
            let navBtn = createNavButton(item: item)
            navBtn.frame = NSRect(x: 10, y: y - 36, width: 180, height: 36)
            sidebar.addSubview(navBtn)
            navButtons[item] = navBtn
            y -= 40
        }

        updateNavSelection()

        return sidebar
    }

    private func createNavButton(item: NavigationItem) -> NSButton {
        let btn = NSButton(frame: NSRect(x: 0, y: 0, width: 180, height: 36))
        btn.title = "  \(item.rawValue)"
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.target = self
        btn.action = #selector(navItemClicked(_:))
        btn.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        btn.alignment = .left
        btn.tag = NavigationItem.allCases.firstIndex(of: item) ?? 0

        btn.wantsLayer = true
        btn.layer?.cornerRadius = 18

        if let img = NSImage(systemSymbolName: item.icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            btn.image = img.withSymbolConfiguration(config)
            btn.imagePosition = .imageLeft
        }

        return btn
    }

    private func updateNavSelection() {
        for (item, btn) in navButtons {
            let isSelected = item == selectedNav

            if isSelected {
                btn.layer?.backgroundColor = GoogleColors.blueLight.cgColor
                btn.contentTintColor = GoogleColors.blue

                if let img = NSImage(systemSymbolName: item.icon, accessibilityDescription: nil) {
                    let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                        .applying(NSImage.SymbolConfiguration(paletteColors: [GoogleColors.blue]))
                    btn.image = img.withSymbolConfiguration(config)
                }

                // Update title color
                let attrStr = NSMutableAttributedString(string: "  \(item.rawValue)")
                attrStr.addAttributes([
                    .foregroundColor: GoogleColors.blue,
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium)
                ], range: NSRange(location: 0, length: attrStr.length))
                btn.attributedTitle = attrStr
            } else {
                btn.layer?.backgroundColor = NSColor.clear.cgColor
                btn.contentTintColor = GoogleColors.textSecondary

                if let img = NSImage(systemSymbolName: item.icon, accessibilityDescription: nil) {
                    let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                        .applying(NSImage.SymbolConfiguration(paletteColors: [GoogleColors.textSecondary]))
                    btn.image = img.withSymbolConfiguration(config)
                }

                let attrStr = NSMutableAttributedString(string: "  \(item.rawValue)")
                attrStr.addAttributes([
                    .foregroundColor: GoogleColors.textSecondary,
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium)
                ], range: NSRange(location: 0, length: attrStr.length))
                btn.attributedTitle = attrStr
            }
        }
    }

    // MARK: - Screen Content

    private func showScreen(_ screen: NavigationItem) {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }

        switch screen {
        case .home:
            buildHomeScreen()
        case .syncActivity:
            buildSyncActivityScreen()
        case .notifications:
            buildNotificationsScreen()
        }
    }

    // MARK: - Home Screen

    private func buildHomeScreen() {
        let bounds = contentContainer.bounds
        let mainWidth: CGFloat = bounds.width - 200
        let sidebarWidth: CGFloat = 200

        // Main content area
        let mainArea = NSView(frame: NSRect(x: 20, y: 0, width: mainWidth - 40, height: bounds.height))
        mainArea.autoresizingMask = [.width, .height]
        contentContainer.addSubview(mainArea)

        // Right sidebar for quick links
        let rightSidebar = NSView(frame: NSRect(x: bounds.width - sidebarWidth - 10, y: 0, width: sidebarWidth, height: bounds.height))
        rightSidebar.autoresizingMask = [.minXMargin, .height]
        contentContainer.addSubview(rightSidebar)

        var mainY = bounds.height - 30

        // Sync status header
        let (statusView, statusHeight) = buildSyncStatusHeader(width: mainWidth - 60)
        statusView.frame = NSRect(x: 0, y: mainY - statusHeight, width: mainWidth - 60, height: statusHeight)
        mainArea.addSubview(statusView)
        mainY -= statusHeight + 20

        // Error banner (if errors)
        if syncErrorCount > 0 {
            let banner = buildErrorBanner(errorCount: syncErrorCount, width: mainWidth - 60)
            banner.frame = NSRect(x: 0, y: mainY - 40, width: mainWidth - 60, height: 40)
            mainArea.addSubview(banner)
            mainY -= 50
        }

        // Recent files
        let recentLabel = NSTextField(labelWithString: "Recent files")
        recentLabel.frame = NSRect(x: 0, y: mainY - 20, width: 200, height: 20)
        recentLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        recentLabel.textColor = GoogleColors.textSecondary
        mainArea.addSubview(recentLabel)
        mainY -= 30

        // File rows
        let displayFiles = Array(fileActivities.prefix(5))
        for file in displayFiles {
            let row = buildFileRow(file: file, width: mainWidth - 60)
            row.frame = NSRect(x: 0, y: mainY - 52, width: mainWidth - 60, height: 52)
            mainArea.addSubview(row)
            mainY -= 52
        }

        // View all button
        if fileActivities.count > 5 {
            let viewAllBtn = createTextButton(title: "View all", action: #selector(viewAllFilesClicked))
            viewAllBtn.frame = NSRect(x: 0, y: mainY - 35, width: 80, height: 32)
            mainArea.addSubview(viewAllBtn)
            mainY -= 45
        }

        // Recording card (if recording or to start)
        let recordingCard = buildRecordingCard(width: mainWidth - 60)
        recordingCard.frame = NSRect(x: 0, y: mainY - 100, width: mainWidth - 60, height: 90)
        mainArea.addSubview(recordingCard)

        // Right sidebar - Quick links
        var rightY = bounds.height - 30

        let quickLinksLabel = NSTextField(labelWithString: "Quick links")
        quickLinksLabel.frame = NSRect(x: 0, y: rightY - 20, width: 180, height: 20)
        quickLinksLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        quickLinksLabel.textColor = GoogleColors.textSecondary
        rightSidebar.addSubview(quickLinksLabel)
        rightY -= 35

        let quickLinks: [(title: String, icon: String, action: Selector)] = [
            ("Transcribe recording", "waveform", #selector(transcribeRecordingClicked)),
            ("Add folders to sync", "plus", #selector(addFolderClicked)),
            ("Open Drive web", "arrow.up.right", #selector(openDriveWebClicked)),
            ("Open OBS", "camera.fill", #selector(openOBSClicked)),
            ("Preferences", "gearshape", #selector(settingsClicked))
        ]

        for link in quickLinks {
            let btn = buildQuickLinkButton(title: link.title, icon: link.icon, action: link.action)
            btn.frame = NSRect(x: 0, y: rightY - 40, width: 180, height: 40)
            rightSidebar.addSubview(btn)
            rightY -= 45
        }
    }

    private func buildSyncStatusHeader(width: CGFloat) -> (NSView, CGFloat) {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 60))

        // Sync icon
        let iconView = NSImageView(frame: NSRect(x: 0, y: 20, width: 32, height: 32))
        let iconName = isSyncing ? "arrow.triangle.2.circlepath" : (isPaused ? "pause.circle.fill" : "checkmark.circle.fill")
        let iconColor = isSyncing ? GoogleColors.blue : (isPaused ? GoogleColors.textTertiary : GoogleColors.green)

        if let img = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 28, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [iconColor]))
            iconView.image = img.withSymbolConfiguration(config)
        }
        container.addSubview(iconView)

        // Status text
        let statusText: String
        if isSyncing {
            statusText = "Syncing..."
        } else if isPaused {
            statusText = "Paused"
        } else {
            statusText = "Up to date"
        }

        let statusLabel = NSTextField(labelWithString: statusText)
        statusLabel.frame = NSRect(x: 42, y: 30, width: 200, height: 24)
        statusLabel.font = NSFont.systemFont(ofSize: 22, weight: .regular)
        statusLabel.textColor = GoogleColors.textPrimary
        container.addSubview(statusLabel)

        // Subtitle
        let subtitleText: String
        if isSyncing {
            subtitleText = "\(syncFileCount) files"
        } else {
            let lastSync = SyncManager.shared.getLastSyncTimeFormatted()
            subtitleText = "Last sync: \(lastSync)"
        }

        let subtitleLabel = NSTextField(labelWithString: subtitleText)
        subtitleLabel.frame = NSRect(x: 42, y: 10, width: 200, height: 16)
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = GoogleColors.textSecondary
        container.addSubview(subtitleLabel)

        return (container, 60)
    }

    private func buildErrorBanner(errorCount: Int, width: CGFloat) -> NSView {
        let banner = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 40))
        banner.wantsLayer = true
        banner.layer?.backgroundColor = GoogleColors.yellowBg.cgColor
        banner.layer?.cornerRadius = 8

        // Warning icon
        let icon = NSImageView(frame: NSRect(x: 12, y: 10, width: 20, height: 20))
        if let img = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [GoogleColors.yellow]))
            icon.image = img.withSymbolConfiguration(config)
        }
        banner.addSubview(icon)

        // Text
        let label = NSTextField(labelWithString: "\(errorCount) errors")
        label.frame = NSRect(x: 40, y: 11, width: 100, height: 18)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = GoogleColors.red
        banner.addSubview(label)

        // View link
        let viewBtn = createTextButton(title: "View", action: #selector(viewErrorsClicked))
        viewBtn.frame = NSRect(x: width - 60, y: 4, width: 50, height: 32)
        banner.addSubview(viewBtn)

        return banner
    }

    private func buildFileRow(file: FileActivityItem, width: CGFloat) -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 52))
        row.wantsLayer = true

        // File icon
        let iconView = NSImageView(frame: NSRect(x: 0, y: 14, width: 24, height: 24))
        let ext = (file.filename as NSString).pathExtension.lowercased()
        let iconName: String
        switch ext {
        case "mkv", "mov", "mp4": iconName = "film"
        case "aac", "mp3", "wav": iconName = "waveform"
        case "txt", "srt", "vtt": iconName = "doc.text"
        default: iconName = "doc"
        }
        if let img = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [GoogleColors.textSecondary]))
            iconView.image = img.withSymbolConfiguration(config)
        }
        row.addSubview(iconView)

        // Filename
        let nameLabel = NSTextField(labelWithString: file.filename)
        nameLabel.frame = NSRect(x: 34, y: 28, width: width - 150, height: 18)
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        nameLabel.textColor = GoogleColors.textPrimary
        nameLabel.lineBreakMode = .byTruncatingMiddle
        row.addSubview(nameLabel)

        // Size and status text
        let statusText = "\(file.formattedSize), \(file.status.text)"
        let statusLabel = NSTextField(labelWithString: statusText)
        statusLabel.frame = NSRect(x: 34, y: 8, width: width - 150, height: 16)
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = GoogleColors.textSecondary
        row.addSubview(statusLabel)

        // Status icon (blue upload circle)
        let statusIcon = NSImageView(frame: NSRect(x: width - 60, y: 14, width: 24, height: 24))
        if let img = NSImage(systemSymbolName: file.status.icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [file.status.color]))
            statusIcon.image = img.withSymbolConfiguration(config)
        }
        row.addSubview(statusIcon)

        // Menu button
        let menuBtn = createIconButton(icon: "ellipsis", action: #selector(fileMenuClicked(_:)))
        menuBtn.frame = NSRect(x: width - 28, y: 12, width: 24, height: 24)
        menuBtn.tag = fileActivities.firstIndex(where: { $0.id == file.id }) ?? 0
        row.addSubview(menuBtn)

        return row
    }

    private func buildRecordingCard(width: CGFloat) -> NSView {
        let card = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 90))
        card.wantsLayer = true
        card.layer?.backgroundColor = GoogleColors.bgSecondary.cgColor
        card.layer?.cornerRadius = 12

        let isRecording = RecordingManager.shared.isRecording
        let transcriptionStatus = TranscriptionManager.shared.status

        if isRecording {
            // Recording indicator
            let recIcon = NSImageView(frame: NSRect(x: 16, y: 33, width: 24, height: 24))
            if let img = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
                    .applying(NSImage.SymbolConfiguration(paletteColors: [GoogleColors.red]))
                recIcon.image = img.withSymbolConfiguration(config)
            }
            card.addSubview(recIcon)

            let projectName = RecordingManager.shared.currentSession?.projectName ?? "Recording"

            let titleLabel = NSTextField(labelWithString: "Recording: \(projectName)")
            titleLabel.frame = NSRect(x: 48, y: 50, width: width - 150, height: 20)
            titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
            titleLabel.textColor = GoogleColors.textPrimary
            card.addSubview(titleLabel)

            let subtitleLabel = NSTextField(labelWithString: "Recording in progress...")
            subtitleLabel.frame = NSRect(x: 48, y: 30, width: width - 150, height: 16)
            subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            subtitleLabel.textColor = GoogleColors.textSecondary
            card.addSubview(subtitleLabel)

            let stopBtn = NSButton(title: "Stop Recording", target: self, action: #selector(stopRecordingClicked))
            stopBtn.frame = NSRect(x: width - 130, y: 30, width: 110, height: 30)
            stopBtn.bezelStyle = .rounded
            card.addSubview(stopBtn)
        } else if transcriptionStatus.isTranscribing {
            // Transcription in progress
            let transIcon = NSImageView(frame: NSRect(x: 16, y: 33, width: 24, height: 24))
            if let img = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
                    .applying(NSImage.SymbolConfiguration(paletteColors: [GoogleColors.blue]))
                transIcon.image = img.withSymbolConfiguration(config)
            }
            card.addSubview(transIcon)

            let titleLabel = NSTextField(labelWithString: "Transcribing audio...")
            titleLabel.frame = NSRect(x: 48, y: 50, width: width - 100, height: 20)
            titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
            titleLabel.textColor = GoogleColors.textPrimary
            card.addSubview(titleLabel)

            if case .transcribing(let file) = transcriptionStatus {
                let subtitleLabel = NSTextField(labelWithString: "Processing: \(file)")
                subtitleLabel.frame = NSRect(x: 48, y: 30, width: width - 100, height: 16)
                subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
                subtitleLabel.textColor = GoogleColors.textSecondary
                subtitleLabel.lineBreakMode = .byTruncatingMiddle
                card.addSubview(subtitleLabel)
            }
        } else {
            let titleLabel = NSTextField(labelWithString: "Start a recording")
            titleLabel.frame = NSRect(x: 16, y: 50, width: width - 150, height: 20)
            titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
            titleLabel.textColor = GoogleColors.textPrimary
            card.addSubview(titleLabel)

            let subtitleLabel = NSTextField(labelWithString: "Record your tutorial with OBS")
            subtitleLabel.frame = NSRect(x: 16, y: 30, width: width - 150, height: 16)
            subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            subtitleLabel.textColor = GoogleColors.textSecondary
            card.addSubview(subtitleLabel)

            let startBtn = NSButton(title: "Start Recording", target: self, action: #selector(startRecordingClicked))
            startBtn.frame = NSRect(x: width - 130, y: 30, width: 110, height: 30)
            startBtn.bezelStyle = .rounded
            card.addSubview(startBtn)
        }

        return card
    }

    private func buildQuickLinkButton(title: String, icon: String, action: Selector) -> NSButton {
        let btn = NSButton(frame: NSRect(x: 0, y: 0, width: 180, height: 40))
        btn.title = "  \(title)"
        btn.bezelStyle = .rounded
        btn.target = self
        btn.action = action
        btn.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        btn.alignment = .left

        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [GoogleColors.textSecondary]))
            btn.image = img.withSymbolConfiguration(config)
            btn.imagePosition = .imageLeft
        }

        return btn
    }

    private func createTextButton(title: String, action: Selector) -> NSButton {
        let btn = NSButton(frame: NSRect(x: 0, y: 0, width: 80, height: 32))
        btn.title = title
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.target = self
        btn.action = action
        btn.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        btn.contentTintColor = GoogleColors.blue

        return btn
    }

    // MARK: - Sync Activity Screen

    private func buildSyncActivityScreen() {
        let bounds = contentContainer.bounds
        var y = bounds.height - 30

        // Sync status header
        let (statusView, statusHeight) = buildSyncStatusHeader(width: bounds.width - 40)
        statusView.frame = NSRect(x: 20, y: y - statusHeight, width: bounds.width - 40, height: statusHeight)
        contentContainer.addSubview(statusView)
        y -= statusHeight + 20

        // Error banner
        if syncErrorCount > 0 {
            let banner = buildErrorBanner(errorCount: syncErrorCount, width: bounds.width - 40)
            banner.frame = NSRect(x: 20, y: y - 40, width: bounds.width - 40, height: 40)
            contentContainer.addSubview(banner)
            y -= 50
        }

        // Table header
        let headerBg = NSView(frame: NSRect(x: 20, y: y - 30, width: bounds.width - 40, height: 30))
        headerBg.wantsLayer = true

        let nameHeader = NSTextField(labelWithString: "Name")
        nameHeader.frame = NSRect(x: 34, y: 5, width: 200, height: 20)
        nameHeader.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        nameHeader.textColor = GoogleColors.textSecondary
        headerBg.addSubview(nameHeader)

        let sizeHeader = NSTextField(labelWithString: "File size")
        sizeHeader.frame = NSRect(x: bounds.width - 180, y: 5, width: 80, height: 20)
        sizeHeader.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        sizeHeader.textColor = GoogleColors.textSecondary
        headerBg.addSubview(sizeHeader)

        let statusHeader = NSTextField(labelWithString: "Status")
        statusHeader.frame = NSRect(x: bounds.width - 90, y: 5, width: 60, height: 20)
        statusHeader.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        statusHeader.textColor = GoogleColors.textSecondary
        headerBg.addSubview(statusHeader)

        contentContainer.addSubview(headerBg)
        y -= 35

        // Scroll view for files
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 20, width: bounds.width - 40, height: y - 20))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]

        let clipView = NSClipView()
        clipView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: bounds.width - 40, height: CGFloat(fileActivities.count) * 52))
        scrollView.contentView = clipView

        // File rows
        var fileY = CGFloat(fileActivities.count) * 52
        for file in fileActivities {
            fileY -= 52
            let row = buildFileRowForTable(file: file, width: bounds.width - 60)
            row.frame = NSRect(x: 0, y: fileY, width: bounds.width - 60, height: 52)
            clipView.documentView?.addSubview(row)
        }

        contentContainer.addSubview(scrollView)
    }

    private func buildFileRowForTable(file: FileActivityItem, width: CGFloat) -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 52))
        row.wantsLayer = true

        // File icon
        let iconView = NSImageView(frame: NSRect(x: 0, y: 14, width: 24, height: 24))
        let ext = (file.filename as NSString).pathExtension.lowercased()
        let iconName: String
        switch ext {
        case "mkv", "mov", "mp4": iconName = "film"
        case "aac", "mp3", "wav": iconName = "waveform"
        case "txt", "srt", "vtt": iconName = "doc.text"
        default: iconName = "doc"
        }
        if let img = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [GoogleColors.textSecondary]))
            iconView.image = img.withSymbolConfiguration(config)
        }
        row.addSubview(iconView)

        // Filename
        let nameLabel = NSTextField(labelWithString: file.filename)
        nameLabel.frame = NSRect(x: 34, y: 28, width: width - 200, height: 18)
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        nameLabel.textColor = GoogleColors.textPrimary
        nameLabel.lineBreakMode = .byTruncatingMiddle
        row.addSubview(nameLabel)

        // Size and status text
        let statusText = "\(file.formattedSize), \(file.status.text)"
        let statusLabel = NSTextField(labelWithString: statusText)
        statusLabel.frame = NSRect(x: 34, y: 8, width: width - 200, height: 16)
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = GoogleColors.textSecondary
        row.addSubview(statusLabel)

        // File size column
        let sizeLabel = NSTextField(labelWithString: file.formattedSize)
        sizeLabel.frame = NSRect(x: width - 160, y: 18, width: 80, height: 16)
        sizeLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        sizeLabel.textColor = GoogleColors.textSecondary
        row.addSubview(sizeLabel)

        // Status icon
        let statusIcon = NSImageView(frame: NSRect(x: width - 65, y: 14, width: 24, height: 24))
        if let img = NSImage(systemSymbolName: file.status.icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [file.status.color]))
            statusIcon.image = img.withSymbolConfiguration(config)
        }
        row.addSubview(statusIcon)

        // Menu button
        let menuBtn = createIconButton(icon: "ellipsis", action: #selector(fileMenuClicked(_:)))
        menuBtn.frame = NSRect(x: width - 30, y: 14, width: 24, height: 24)
        row.addSubview(menuBtn)

        return row
    }

    // MARK: - Notifications Screen

    private func buildNotificationsScreen() {
        let bounds = contentContainer.bounds
        var y = bounds.height - 30

        // Title
        let titleLabel = NSTextField(labelWithString: "Notifications")
        titleLabel.frame = NSRect(x: 20, y: y - 28, width: 200, height: 28)
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .regular)
        titleLabel.textColor = GoogleColors.textPrimary
        contentContainer.addSubview(titleLabel)
        y -= 50

        if notifications.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No notifications")
            emptyLabel.frame = NSRect(x: 20, y: y - 20, width: 200, height: 20)
            emptyLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
            emptyLabel.textColor = GoogleColors.textSecondary
            contentContainer.addSubview(emptyLabel)
        } else {
            for notification in notifications {
                let card = buildNotificationCard(notification: notification, width: bounds.width - 40)
                card.frame = NSRect(x: 20, y: y - 100, width: bounds.width - 40, height: 90)
                contentContainer.addSubview(card)
                y -= 100
            }
        }
    }

    private func buildNotificationCard(notification: AppNotification, width: CGFloat) -> NSView {
        let card = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 90))
        card.wantsLayer = true
        card.layer?.backgroundColor = GoogleColors.bgSecondary.cgColor
        card.layer?.cornerRadius = 8

        // Icon
        let iconView = NSImageView(frame: NSRect(x: 16, y: 55, width: 24, height: 24))
        if let img = NSImage(systemSymbolName: notification.type.icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [notification.type.color]))
            iconView.image = img.withSymbolConfiguration(config)
        }
        card.addSubview(iconView)

        // Title
        let titleLabel = NSTextField(labelWithString: notification.title)
        titleLabel.frame = NSRect(x: 48, y: 60, width: width - 100, height: 18)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = GoogleColors.textPrimary
        card.addSubview(titleLabel)

        // Body
        let bodyLabel = NSTextField(labelWithString: notification.body)
        bodyLabel.frame = NSRect(x: 48, y: 35, width: width - 100, height: 20)
        bodyLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        bodyLabel.textColor = GoogleColors.textSecondary
        bodyLabel.lineBreakMode = .byTruncatingTail
        card.addSubview(bodyLabel)

        // Dismiss button
        let dismissBtn = createIconButton(icon: "xmark", action: #selector(dismissNotificationClicked(_:)))
        dismissBtn.frame = NSRect(x: width - 36, y: 55, width: 24, height: 24)
        dismissBtn.tag = notifications.firstIndex(where: { $0.id == notification.id }) ?? 0
        card.addSubview(dismissBtn)

        // Action buttons
        var btnX: CGFloat = width - 20

        if let secondary = notification.secondaryAction {
            let btn = createTextButton(title: secondary.title, action: #selector(notificationSecondaryClicked(_:)))
            btn.frame = NSRect(x: btnX - 80, y: 5, width: 80, height: 28)
            btn.tag = notifications.firstIndex(where: { $0.id == notification.id }) ?? 0
            card.addSubview(btn)
            btnX -= 85
        }

        if let primary = notification.primaryAction {
            let btn = createTextButton(title: primary.title, action: #selector(notificationPrimaryClicked(_:)))
            btn.frame = NSRect(x: btnX - 100, y: 5, width: 100, height: 28)
            btn.tag = notifications.firstIndex(where: { $0.id == notification.id }) ?? 0
            card.addSubview(btn)
        }

        return card
    }

    // MARK: - Data Loading

    private func loadData() {
        loadFileActivities()
        loadSyncStatus()
        addSampleNotifications()
    }

    private func loadFileActivities() {
        fileActivities.removeAll()

        let fileManager = FileManager.default
        let recordingsPath = Paths.recordingsBase

        guard let projects = try? fileManager.contentsOfDirectory(atPath: recordingsPath) else { return }

        let sortedProjects = projects.filter { $0.hasPrefix("20") }.sorted().reversed()

        for projectName in sortedProjects.prefix(5) {
            let projectPath = recordingsPath + "/" + projectName
            let rawPath = projectPath + "/raw"

            if let sessions = try? fileManager.contentsOfDirectory(atPath: rawPath) {
                for session in sessions.sorted().reversed().prefix(2) {
                    let sessionPath = rawPath + "/" + session

                    if let files = try? fileManager.contentsOfDirectory(atPath: sessionPath) {
                        for file in files {
                            let ext = (file as NSString).pathExtension.lowercased()
                            if ["mkv", "mov", "mp4", "aac", "txt", "srt"].contains(ext) {
                                let filePath = sessionPath + "/" + file

                                var size: Int64 = 0
                                if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                                   let fileSize = attrs[.size] as? Int64 {
                                    size = fileSize
                                }

                                fileActivities.append(FileActivityItem(
                                    id: UUID(),
                                    filename: file,
                                    path: filePath,
                                    size: size,
                                    status: .uploaded,
                                    timestamp: Date()
                                ))
                            }
                        }
                    }
                }
            }

            if fileActivities.count >= 20 { break }
        }
    }

    private func loadSyncStatus() {
        _ = SyncManager.shared.checkRcloneStatus()
        syncFileCount = fileActivities.count
        syncErrorCount = 0 // Would come from actual sync errors
    }

    private func addSampleNotifications() {
        // Add sample notification if recording just completed
        if let session = RecordingManager.shared.currentSession {
            notifications.append(AppNotification(
                id: UUID(),
                type: .success,
                title: "Recording completed",
                body: "Project '\(session.projectName)' finished recording.",
                timestamp: Date(),
                isRead: false,
                primaryAction: (title: "Open Folder", action: { [weak self] in
                    self?.onOpenRecordings?()
                }),
                secondaryAction: (title: "Dismiss", action: {})
            ))
        }
    }

    // MARK: - Public Methods

    func show(near statusItem: NSStatusItem) {
        loadData()
        buildLayout(in: window.contentView!)

        if let button = statusItem.button, let buttonWindow = button.window {
            let buttonFrame = button.convert(button.bounds, to: nil)
            let screenFrame = buttonWindow.convertToScreen(buttonFrame)
            let windowFrame = window.frame

            var x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.minY - windowFrame.height - 5

            if let screen = NSScreen.main {
                let screenRight = screen.visibleFrame.maxX
                if x + windowFrame.width > screenRight {
                    x = screenRight - windowFrame.width - 10
                }
                if x < screen.visibleFrame.minX {
                    x = screen.visibleFrame.minX + 10
                }
            }

            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window.orderOut(nil)
    }

    func updateSyncingState(_ syncing: Bool) {
        isSyncing = syncing
        if window.isVisible {
            showScreen(selectedNav)
        }

        if syncing {
            startSyncAnimation()
        } else {
            stopSyncAnimation()
        }
    }

    private func startSyncAnimation() {
        guard syncAnimationTimer == nil else { return }
        syncAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.animationAngle += 15
            // Could update sync icon rotation here
        }
    }

    private func stopSyncAnimation() {
        syncAnimationTimer?.invalidate()
        syncAnimationTimer = nil
        animationAngle = 0
    }

    // MARK: - Actions

    @objc private func navItemClicked(_ sender: NSButton) {
        guard let item = NavigationItem.allCases[safe: sender.tag] else { return }
        selectedNav = item
        updateNavSelection()
        showScreen(item)
    }

    @objc private func openRecordingsClicked() {
        onOpenRecordings?()
    }

    @objc private func pauseClicked() {
        isPaused = !isPaused

        let iconName = isPaused ? "play.circle" : "pause.circle"
        if let img = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [GoogleColors.textSecondary]))
            pauseButton.image = img.withSymbolConfiguration(config)
        }
        pauseButton.toolTip = isPaused ? "Resume syncing" : "Pause syncing"

        showScreen(selectedNav)
    }

    @objc private func settingsClicked() {
        showSettingsMenu()
    }

    private func showSettingsMenu() {
        let menu = NSMenu()

        let prefsItem = NSMenuItem(title: "Preferences", action: #selector(preferencesClicked), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        if syncErrorCount > 0 {
            let errorsItem = NSMenuItem(title: "Error list (\(syncErrorCount))", action: #selector(viewErrorsClicked), keyEquivalent: "")
            errorsItem.target = self
            menu.addItem(errorsItem)
        }

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About Tutorial Recorder", action: #selector(aboutClicked), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let helpItem = NSMenuItem(title: "Help", action: #selector(helpClicked), keyEquivalent: "?")
        helpItem.target = self
        menu.addItem(helpItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Show menu below the settings button
        let location = NSPoint(x: settingsButton.frame.origin.x, y: settingsButton.frame.origin.y)
        menu.popUp(positioning: nil, at: location, in: headerView)
    }

    @objc private func preferencesClicked() {
        onConfigureSync?()
    }

    @objc private func aboutClicked() {
        let alert = NSAlert()
        alert.messageText = "Tutorial Recorder"
        alert.informativeText = "Version 1.0\n\nAutomated OBS Studio setup for recording coding tutorials with ISO recordings.\n\nFeatures:\n• One-click session start\n• ISO recordings per source\n• Automatic cloud sync to Google Drive\n• Project organization"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func helpClicked() {
        if let url = URL(string: "https://github.com/YOUR_USERNAME/obs-tutorial-recorder") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }

    @objc private func viewAllFilesClicked() {
        selectedNav = .syncActivity
        updateNavSelection()
        showScreen(.syncActivity)
    }

    @objc private func viewErrorsClicked() {
        // Show errors - navigate to sync activity
        selectedNav = .syncActivity
        updateNavSelection()
        showScreen(.syncActivity)
    }

    @objc private func startRecordingClicked() {
        hide()
        onStartRecording?()
    }

    @objc private func stopRecordingClicked() {
        onStopRecording?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.loadData()
            self?.showScreen(self?.selectedNav ?? .home)
        }
    }

    @objc private func addFolderClicked() {
        onAddFolder?()
    }

    @objc private func openOBSClicked() {
        onOpenOBS?()
    }

    @objc private func openDriveWebClicked() {
        if let url = URL(string: "https://drive.google.com") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func transcribeRecordingClicked() {
        onTranscribeRecording?()
    }

    @objc private func fileMenuClicked(_ sender: NSButton) {
        guard sender.tag < fileActivities.count else { return }
        let file = fileActivities[sender.tag]

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show in Finder", action: #selector(showFileInFinder(_:)), keyEquivalent: ""))
        menu.items.last?.representedObject = file.path
        menu.items.last?.target = self

        menu.addItem(NSMenuItem(title: "Copy Path", action: #selector(copyFilePath(_:)), keyEquivalent: ""))
        menu.items.last?.representedObject = file.path
        menu.items.last?.target = self

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @objc private func showFileInFinder(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    @objc private func copyFilePath(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    @objc private func dismissNotificationClicked(_ sender: NSButton) {
        guard sender.tag < notifications.count else { return }
        notifications.remove(at: sender.tag)
        showScreen(.notifications)
    }

    @objc private func notificationPrimaryClicked(_ sender: NSButton) {
        guard sender.tag < notifications.count else { return }
        notifications[sender.tag].primaryAction?.action()
    }

    @objc private func notificationSecondaryClicked(_ sender: NSButton) {
        guard sender.tag < notifications.count else { return }
        notifications[sender.tag].secondaryAction?.action()
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
