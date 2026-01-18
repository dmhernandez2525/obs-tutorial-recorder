import Foundation

// MARK: - Sync Configuration Model

struct SyncConfig: Codable {
    var rcloneRemote: String
    var localPath: String
    var remotePath: String
    var autoSync: Bool
    var syncExportsOnly: Bool
    var excludePatterns: [String]
    var additionalFolders: [SyncFolder]

    enum CodingKeys: String, CodingKey {
        case rcloneRemote = "rclone_remote"
        case localPath = "local_path"
        case remotePath = "remote_path"
        case autoSync = "auto_sync"
        case syncExportsOnly = "sync_exports_only"
        case excludePatterns = "exclude_patterns"
        case additionalFolders = "additional_folders"
    }

    static var `default`: SyncConfig {
        SyncConfig(
            rcloneRemote: "tutorial-recordings",
            localPath: Paths.recordingsBase,
            remotePath: "Tutorial Recordings",
            autoSync: false,
            syncExportsOnly: false,
            excludePatterns: ["*.tmp", "*.part", ".DS_Store", "Thumbs.db"],
            additionalFolders: []
        )
    }
}

struct SyncFolder: Codable {
    var local: String
    var remote: String
    var excludes: [String]
}

// MARK: - Sync Status

struct SyncStatus {
    var lastSyncTime: Date?
    var filesTransferred: Int = 0
    var bytesTransferred: Int64 = 0
    var filesPending: Int = 0
    var currentFile: String = ""
    var isRunning: Bool = false
    var lastError: String?
    var output: String = ""
}

// MARK: - Rclone Status

enum RcloneStatus {
    case notInstalled
    case notConfigured
    case ready

    var displayText: String {
        switch self {
        case .notInstalled: return "Not installed"
        case .notConfigured: return "Not configured"
        case .ready: return "Ready"
        }
    }
}

// MARK: - Sync Manager

class SyncManager {
    static let shared = SyncManager()

    private(set) var syncStatus = SyncStatus()
    var onSyncProgress: ((SyncStatus) -> Void)?

    private let lastSyncKey = "lastSyncTime"

    private init() {
        // Load last sync time
        if let timestamp = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            syncStatus.lastSyncTime = timestamp
        }
    }

    // MARK: - Rclone Status

    func checkRcloneStatus() -> RcloneStatus {
        let rcloneCheck = runShellCommand("which rclone", timeout: 5)
        guard rcloneCheck.success && !rcloneCheck.output.isEmpty else {
            logInfo("rclone not found in PATH")
            return .notInstalled
        }

        let remotes = runShellCommand("rclone listremotes 2>/dev/null", timeout: 10)
        logInfo("rclone remotes: \(remotes.output)")
        if remotes.output.contains("tutorial-recordings:") {
            return .ready
        }

        return .notConfigured
    }

    func installRclone(completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = runShellCommand("/opt/homebrew/bin/brew install rclone 2>&1 || /usr/local/bin/brew install rclone 2>&1", timeout: 300)
            DispatchQueue.main.async {
                completion(result.success, result.output)
            }
        }
    }

    func configureRclone(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
            tell application "Terminal"
                activate
                do script "rclone config create tutorial-recordings drive scope=drive && echo '\\n\\nConfiguration complete! You can close this window.'"
            end tell
            """

            let result = runShellCommand("osascript -e '\(script.replacingOccurrences(of: "'", with: "'\\''"))'", timeout: 10)
            DispatchQueue.main.async {
                completion(result.success)
            }
        }
    }

    // MARK: - Configuration

    func loadConfig() -> SyncConfig {
        guard FileManager.default.fileExists(atPath: Paths.syncConfigPath) else {
            logInfo("No sync config file found at \(Paths.syncConfigPath)")
            return .default
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: Paths.syncConfigPath))
            let config = try JSONDecoder().decode(SyncConfig.self, from: data)
            logInfo("Loaded sync config: autoSync=\(config.autoSync), localPath=\(config.localPath)")
            return config
        } catch {
            logError("Failed to load sync config: \(error.localizedDescription)")
            return .default
        }
    }

    func saveConfig(_ config: SyncConfig) -> Bool {
        do {
            let configDir = (Paths.syncConfigPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: URL(fileURLWithPath: Paths.syncConfigPath))
            logInfo("Sync configuration saved: autoSync=\(config.autoSync)")
            return true
        } catch {
            logError("Failed to save sync config: \(error.localizedDescription)")
            return false
        }
    }

    func addFolder(localPath: String, remotePath: String) -> Bool {
        var config = loadConfig()
        config.additionalFolders.append(SyncFolder(local: localPath, remote: remotePath, excludes: []))
        return saveConfig(config)
    }

    // MARK: - Sync Operations

    func syncRecordings(progress: ((String) -> Void)? = nil, completion: @escaping (Bool, String) -> Void) {
        let status = checkRcloneStatus()
        guard status == .ready else {
            logError("Cannot sync: rclone status is \(status.displayText)")
            completion(false, "rclone not configured")
            return
        }

        let config = loadConfig()
        logInfo("Starting sync: \(config.localPath) -> \(config.rcloneRemote):\(config.remotePath)")

        syncStatus.isRunning = true
        syncStatus.filesTransferred = 0
        syncStatus.lastError = nil
        syncStatus.output = ""

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Build rclone command with progress output
            var excludeArgs = "--exclude .DS_Store --exclude '*.tmp' --exclude '*.part'"
            if config.syncExportsOnly {
                excludeArgs += " --exclude 'raw/'"
            }

            let command = "rclone sync '\(config.localPath)' '\(config.rcloneRemote):\(config.remotePath)' \(excludeArgs) --progress --stats-one-line 2>&1"

            logInfo("Running: \(command)")

            let result = runShellCommand(command, timeout: 600)
            let output = result.output

            // Parse output for stats
            self?.parseRcloneOutput(output)

            DispatchQueue.main.async {
                self?.syncStatus.isRunning = false
                self?.syncStatus.output = output

                let success = !output.lowercased().contains("error") &&
                              !output.lowercased().contains("failed") &&
                              result.exitCode == 0

                if success {
                    self?.syncStatus.lastSyncTime = Date()
                    UserDefaults.standard.set(Date(), forKey: self?.lastSyncKey ?? "lastSyncTime")
                    logSuccess("Sync completed successfully")
                } else {
                    self?.syncStatus.lastError = "Sync failed"
                    logError("Sync failed: \(output)")
                }

                completion(success, output)
            }
        }
    }

    private func parseRcloneOutput(_ output: String) {
        // Parse rclone progress output
        // Format: "Transferred: X / Y, ETA: Z"
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.contains("Transferred:") {
                // Extract file count
                if let match = line.range(of: #"(\d+) / (\d+)"#, options: .regularExpression) {
                    let numbers = String(line[match]).components(separatedBy: " / ")
                    if numbers.count == 2 {
                        syncStatus.filesTransferred = Int(numbers[0]) ?? 0
                        syncStatus.filesPending = (Int(numbers[1]) ?? 0) - syncStatus.filesTransferred
                    }
                }
            }
        }
    }

    func testSync(completion: @escaping (Bool, String) -> Void) {
        let config = loadConfig()
        logInfo("Testing sync (dry run): \(config.localPath) -> \(config.rcloneRemote):\(config.remotePath)")

        DispatchQueue.global(qos: .userInitiated).async {
            let command = "rclone sync '\(config.localPath)' '\(config.rcloneRemote):\(config.remotePath)' --dry-run --progress 2>&1 | tail -20"
            let result = runShellCommand(command, timeout: 60)
            DispatchQueue.main.async {
                completion(result.success, result.output)
            }
        }
    }

    // MARK: - File Comparison

    func getLocalFiles() -> [String] {
        let config = loadConfig()
        var files: [String] = []

        let fileManager = FileManager.default
        if let enumerator = fileManager.enumerator(atPath: config.localPath) {
            while let file = enumerator.nextObject() as? String {
                // Skip hidden files and excluded patterns
                if !file.hasPrefix(".") && !file.contains(".DS_Store") {
                    files.append(file)
                }
            }
        }

        return files
    }

    func getRemoteFiles(completion: @escaping ([String]) -> Void) {
        let config = loadConfig()

        DispatchQueue.global(qos: .userInitiated).async {
            let result = runShellCommand("rclone lsf '\(config.rcloneRemote):\(config.remotePath)' --recursive 2>/dev/null", timeout: 60)
            let files = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            DispatchQueue.main.async {
                completion(files)
            }
        }
    }

    func getPendingFiles(completion: @escaping ([(file: String, size: String)]) -> Void) {
        let config = loadConfig()

        DispatchQueue.global(qos: .userInitiated).async {
            // Use rclone check to find differences
            let result = runShellCommand("rclone check '\(config.localPath)' '\(config.rcloneRemote):\(config.remotePath)' --one-way --combined - 2>/dev/null | grep '^+' | head -50", timeout: 60)

            var pending: [(String, String)] = []
            for line in result.output.components(separatedBy: "\n") {
                if line.hasPrefix("+ ") {
                    let file = String(line.dropFirst(2))
                    pending.append((file, ""))
                }
            }

            DispatchQueue.main.async {
                completion(pending)
            }
        }
    }

    // MARK: - Status Info

    func getStatusInfo() -> (rcloneInstalled: Bool, remoteConfigured: Bool, driveUsage: String, config: SyncConfig) {
        let rcloneCheck = runShellCommand("which rclone", timeout: 5)
        let hasRclone = rcloneCheck.success && !rcloneCheck.output.isEmpty

        var remoteConfigured = false
        var driveUsage = ""

        if hasRclone {
            let remotes = runShellCommand("rclone listremotes 2>/dev/null", timeout: 10)
            remoteConfigured = remotes.output.contains("tutorial-recordings:")

            if remoteConfigured {
                let usage = runShellCommand("rclone about tutorial-recordings: 2>/dev/null | grep 'Used:' | head -1", timeout: 30)
                driveUsage = usage.output
            }
        }

        let config = loadConfig()
        return (hasRclone, remoteConfigured, driveUsage, config)
    }

    func getLastSyncTimeFormatted() -> String {
        guard let lastSync = syncStatus.lastSyncTime else {
            return "Never"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
}
