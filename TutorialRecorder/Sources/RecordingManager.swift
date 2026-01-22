import Cocoa

// MARK: - Recording State

enum RecordingState {
    case idle
    case starting
    case recording
    case stopping
}

// MARK: - Setup Type

enum SetupType: String, Codable {
    case macSetup = "Mac Setup (Multiple Screens)"
    case macBookSetup = "MacBook Setup (One Screen, Native Camera)"
    case pcSetup = "PC Setup (One Screen, 10 Cameras)"

    var displayName: String {
        return self.rawValue
    }

    var obsProfileName: String {
        switch self {
        case .macSetup:
            return "Mac-MultiScreen"
        case .macBookSetup:
            return "MacBook-Single"
        case .pcSetup:
            return "PC-10Cameras"
        }
    }
}

// MARK: - Session Info

struct SessionInfo {
    let projectPath: String
    let projectName: String
    let startTime: Date
    let setupType: SetupType
}

// MARK: - Recording Manager

class RecordingManager {
    static let shared = RecordingManager()

    private(set) var state: RecordingState = .idle
    private(set) var currentSession: SessionInfo?
    private(set) var obsLaunchedByApp = false

    var isRecording: Bool { state == .recording }

    // Callbacks
    var onStateChanged: ((RecordingState) -> Void)?
    var onProgress: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let sessionFile = "/tmp/obs-tutorial-session.txt"
    private let startTimeFile = "/tmp/obs-tutorial-start-time.txt"
    private let activeFile = "/tmp/obs-recording-active.txt"

    private init() {}

    // MARK: - Session Management

    func checkExistingSession() {
        guard FileManager.default.fileExists(atPath: activeFile),
              let path = try? String(contentsOfFile: sessionFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) else {
            return
        }

        let name = (path as NSString).lastPathComponent
        // Default to macSetup for existing sessions (or could load from metadata.json)
        let setupType: SetupType = .macSetup
        currentSession = SessionInfo(projectPath: path, projectName: name, startTime: Date(), setupType: setupType)
        state = .recording
        onStateChanged?(.recording)
    }

    func getExistingProjects() -> [(name: String, path: String)] {
        var projects: [(String, String)] = []
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: Paths.recordingsBase) else {
            return projects
        }

        for item in contents.sorted().reversed() {
            if item.hasPrefix("20") {
                let fullPath = Paths.recordingsBase + "/" + item
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                    projects.append((item, fullPath))
                }
            }
        }
        return Array(projects.prefix(10))
    }

    // MARK: - Project Creation

    func createProjectFolder(name: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let datePrefix = formatter.string(from: Date())

        let safeName = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()

        var projectPath = "\(Paths.recordingsBase)/\(datePrefix)_\(safeName)"
        var counter = 1
        while FileManager.default.fileExists(atPath: projectPath) {
            projectPath = "\(Paths.recordingsBase)/\(datePrefix)_\(safeName)-\(counter)"
            counter += 1
        }

        try? FileManager.default.createDirectory(atPath: projectPath + "/raw", withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: projectPath + "/exports", withIntermediateDirectories: true)

        let metadata = """
        {
          "projectName": "\(name)",
          "dateCreated": "\(ISO8601DateFormatter().string(from: Date()))",
          "recordings": []
        }
        """
        try? metadata.write(toFile: projectPath + "/metadata.json", atomically: true, encoding: .utf8)

        return projectPath
    }

    // MARK: - Recording Control

    func startRecording(projectPath: String, projectName: String, setupType: SetupType) {
        guard state == .idle else {
            onError?("Already recording or in progress")
            return
        }

        state = .starting
        onStateChanged?(.starting)

        // Initialize session
        let startTime = Date()
        currentSession = SessionInfo(projectPath: projectPath, projectName: projectName, startTime: startTime, setupType: setupType)

        // Initialize session log
        let logHeader = """
        =============================================
        Session started: \(startTime)
        Project: \(projectPath)
        Setup: \(setupType.displayName)
        =============================================
        """
        try? logHeader.write(toFile: projectPath + "/session.log", atomically: true, encoding: .utf8)
        Logger.shared.setSessionLog(path: projectPath + "/session.log")

        logInfo("Starting recording for project: \(projectName)")
        logInfo("Project path: \(projectPath)")
        logInfo("Setup type: \(setupType.displayName)")

        // Write session files
        try? projectPath.write(toFile: sessionFile, atomically: true, encoding: .utf8)
        try? String(Int(startTime.timeIntervalSince1970)).write(toFile: startTimeFile, atomically: true, encoding: .utf8)
        FileManager.default.createFile(atPath: activeFile, contents: nil)

        onProgress?("Starting recording...")

        // Check if OBS is running
        let workspace = NSWorkspace.shared
        let obsRunning = workspace.runningApplications.contains { $0.bundleIdentifier == "com.obsproject.obs-studio" }

        if !obsRunning {
            obsLaunchedByApp = true
            logInfo("OBS not running, launching...")
            onProgress?("Launching OBS...")

            // Launch OBS normally (--profile argument doesn't work on macOS)
            let obsURL = URL(fileURLWithPath: "/Applications/OBS.app")
            workspace.openApplication(at: obsURL, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
                if let error = error {
                    logError("Failed to launch OBS: \(error.localizedDescription)")
                    self?.handleStartError("Failed to launch OBS")
                    return
                }

                logInfo("OBS launched, waiting for WebSocket...")
                self?.onProgress?("Waiting for OBS to start...")

                // Wait longer to ensure OBS is fully started before connecting
                DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
                    self?.connectAndStartRecording(projectPath: projectPath)
                }
            }
        } else {
            obsLaunchedByApp = false
            logInfo("OBS already running, will switch profile via WebSocket...")
            onProgress?("Connecting to OBS...")
            connectAndStartRecording(projectPath: projectPath)
        }
    }

    private func connectAndStartRecording(projectPath: String) {
        let rawDir = projectPath + "/raw"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            logInfo("Connecting to OBS WebSocket...")
            self?.onProgress?("Connecting to OBS WebSocket...")

            // Try to connect
            var connected = false
            for i in 1...30 {
                self?.onProgress?("Connecting to OBS... (attempt \(i)/30)")

                let checkResult = runShellCommand("""
                    echo '{"op":1,"d":{"rpcVersion":1}}' | timeout 2 websocat "ws://localhost:4455" 2>/dev/null | grep -q "obsStudioVersion" && echo "OK"
                """, timeout: 5)

                if checkResult.output.contains("OK") {
                    connected = true
                    break
                }
                Thread.sleep(forTimeInterval: 1)
            }

            guard connected else {
                logError("Could not connect to OBS WebSocket after 30 attempts")
                DispatchQueue.main.async {
                    self?.handleStartError("Could not connect to OBS WebSocket")
                }
                return
            }

            logInfo("Connected to OBS WebSocket")

            // Ensure all required profiles exist and get current profile
            self?.onProgress?("Checking OBS profiles...")
            let currentProfile = self?.ensureProfilesExist()

            // Verify and switch to the appropriate OBS profile
            if let session = self?.currentSession {
                let targetProfile = session.setupType.obsProfileName
                self?.onProgress?("Verifying OBS profile...")
                logInfo("Target profile: \(targetProfile)")
                logInfo("Current OBS profile: \(currentProfile ?? "unknown")")

                // Only switch if we're not already on the correct profile
                if currentProfile != targetProfile {
                    self?.onProgress?("Switching to \(session.setupType.displayName) profile...")
                    logInfo("Switching OBS profile from '\(currentProfile ?? "unknown")' to '\(targetProfile)'")

                    let profileResult = runShellCommand("""
                        {
                            sleep 0.3
                            echo '{"op":1,"d":{"rpcVersion":1}}'
                            sleep 0.3
                            echo '{"op":6,"d":{"requestType":"SetCurrentProfile","requestId":"profile1","requestData":{"profileName":"\(targetProfile)"}}}'
                            sleep 1.5
                        } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
                    """, timeout: 10)

                    if profileResult.output.contains("\"status\":200") || profileResult.output.contains("\"op\":7") {
                        logSuccess("Successfully switched to profile: \(targetProfile)")
                    } else {
                        logWarning("Profile switch response: \(String(profileResult.output.prefix(200)))")
                        if profileResult.output.contains("No such profile") {
                            logError("Profile '\(targetProfile)' does not exist in OBS!")
                            logError("Please create this profile in OBS: Profile > New > \(targetProfile)")
                        } else {
                            logWarning("Continuing with current profile...")
                        }
                    }

                    // Wait for profile to fully load before continuing
                    self?.onProgress?("Profile switched, waiting for OBS to stabilize...")
                    Thread.sleep(forTimeInterval: 3.0)
                } else {
                    logSuccess("Already on correct profile: \(targetProfile)")
                }

                // Ensure profile is configured with correct sources
                self?.onProgress?("Configuring profile sources...")
                self?.ensureProfileConfigured(targetProfile: targetProfile, setupType: session.setupType)
                Thread.sleep(forTimeInterval: 2.0)

                // Verify what sources are in the current scene (scene name = profile name)
                self?.verifySceneSources(sceneName: targetProfile)
            }

            // Set record directory
            self?.onProgress?("Setting up recording...")
            logInfo("Setting record directory to: \(rawDir)")

            let dirResult = runShellCommand("""
                {
                    sleep 0.3
                    echo '{"op":1,"d":{"rpcVersion":1}}'
                    sleep 0.3
                    echo '{"op":6,"d":{"requestType":"SetRecordDirectory","requestId":"dir1","requestData":{"recordDirectory":"\(rawDir)"}}}'
                    sleep 0.5
                } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
            """, timeout: 10)
            logInfo("SetRecordDirectory result: \(String(dirResult.output.prefix(200)))")

            Thread.sleep(forTimeInterval: 0.5)

            // Enable ISO recording - add Source Record filters to each source
            if let session = self?.currentSession {
                let sceneName = session.setupType.obsProfileName
                self?.onProgress?("Configuring ISO recording...")
                logInfo("Setting up ISO recording (Source Record filters)...")
                OBSSourceManager.shared.enableISORecording(sceneName: sceneName, recordPath: rawDir)
                Thread.sleep(forTimeInterval: 1.0)
            }

            // Start recording
            self?.onProgress?("Starting recording...")
            logInfo("Sending StartRecord command...")

            let result = runShellCommand("""
                {
                    sleep 0.3
                    echo '{"op":1,"d":{"rpcVersion":1}}'
                    sleep 0.3
                    echo '{"op":6,"d":{"requestType":"StartRecord","requestId":"rec1"}}'
                    sleep 0.5
                } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
            """, timeout: 10)
            logInfo("StartRecord result: \(String(result.output.prefix(200)))")

            DispatchQueue.main.async {
                if result.output.contains("\"result\":true") || result.output.contains("\"op\":7") {
                    logSuccess("Recording started successfully")
                    self?.state = .recording
                    self?.onStateChanged?(.recording)
                    showSystemNotification(title: "Recording Started", body: "Recording to \((rawDir as NSString).lastPathComponent)")
                } else {
                    logWarning("Recording status unclear - check OBS")
                    self?.state = .recording
                    self?.onStateChanged?(.recording)
                    showSystemNotification(title: "Recording", body: "Started - check OBS for status")
                }
            }
        }
    }

    private func handleStartError(_ message: String) {
        state = .idle
        currentSession = nil
        onStateChanged?(.idle)
        onError?(message)
        cleanupSessionFiles()
        Logger.shared.clearSessionLog()
    }

    func stopRecording(completion: @escaping (String?) -> Void) {
        guard state == .recording else {
            completion(nil)
            return
        }

        state = .stopping
        onStateChanged?(.stopping)
        logInfo("Stop recording requested")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.onProgress?("Sending stop command...")
            logInfo("Sending StopRecord command...")

            _ = runShellCommand("""
                {
                    sleep 0.3
                    echo '{"op":1,"d":{"rpcVersion":1}}'
                    sleep 0.3
                    echo '{"op":6,"d":{"requestType":"StopRecord","requestId":"stop1"}}'
                    sleep 0.5
                } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
            """, timeout: 10)

            self?.onProgress?("Waiting for files to finish...")
            logInfo("Waiting 3 seconds for files to finish writing...")
            Thread.sleep(forTimeInterval: 3)

            var projectPath: String?
            if let session = self?.currentSession {
                self?.onProgress?("Collecting recordings...")
                logInfo("Collecting recordings from ~/Movies to project folder...")
                self?.collectRecordings(projectPath: session.projectPath)
                projectPath = session.projectPath
            }

            DispatchQueue.main.async {
                logSuccess("Recording stopped and files collected")
                self?.state = .idle
                self?.currentSession = nil
                self?.onStateChanged?(.idle)
                self?.cleanupSessionFiles()
                Logger.shared.clearSessionLog()
                completion(projectPath)
            }
        }
    }

    private func cleanupSessionFiles() {
        try? FileManager.default.removeItem(atPath: sessionFile)
        try? FileManager.default.removeItem(atPath: startTimeFile)
        try? FileManager.default.removeItem(atPath: activeFile)
    }

    // MARK: - File Collection

    private func collectRecordings(projectPath: String) {
        let rawDir = projectPath + "/raw"
        let moviesDir = Paths.home + "/Movies"

        logInfo("Collecting recordings to: \(rawDir)")

        let startTime: TimeInterval
        if let startTimeStr = try? String(contentsOfFile: startTimeFile, encoding: .utf8),
           let timestamp = Double(startTimeStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
            startTime = timestamp
            logInfo("Session start time: \(Date(timeIntervalSince1970: startTime))")
        } else {
            startTime = Date().timeIntervalSince1970 - 1800
            logWarning("No start time found, using 30 minutes ago")
        }

        let fileManager = FileManager.default
        let videoExtensions = ["mov", "mkv", "mp4"]
        var collectedFiles: [(path: String, name: String)] = []
        var sessionTimestamp: String?

        // Find all files from this session
        for searchDir in [moviesDir, rawDir] {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: searchDir) else {
                continue
            }

            logInfo("Searching \(searchDir): found \(contents.count) items")

            for filename in contents {
                let ext = (filename as NSString).pathExtension.lowercased()
                guard videoExtensions.contains(ext) else { continue }

                let filePath = searchDir + "/" + filename
                guard let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                      let modDate = attrs[.modificationDate] as? Date else { continue }

                if modDate.timeIntervalSince1970 >= startTime {
                    collectedFiles.append((path: filePath, name: filename))

                    // Extract timestamp from filename
                    if sessionTimestamp == nil {
                        let pattern = #"^(\d{4}-\d{2}-\d{2} \d{2}-\d{2}-\d{2})"#
                        if let range = filename.range(of: pattern, options: .regularExpression) {
                            sessionTimestamp = String(filename[range])
                        }
                    }
                }
            }
        }

        guard !collectedFiles.isEmpty else {
            logWarning("No recordings found from this session")
            return
        }

        // Create timestamp folder
        let folderName = sessionTimestamp ?? {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
            return formatter.string(from: Date())
        }()

        let sessionDir = rawDir + "/" + folderName
        try? fileManager.createDirectory(atPath: sessionDir, withIntermediateDirectories: true)
        logInfo("Created session folder: \(folderName)")

        // Move files with cleaner names
        var collectedCount = 0
        for (filePath, filename) in collectedFiles {
            var cleanName = filename
            if let timestamp = sessionTimestamp {
                cleanName = filename.replacingOccurrences(of: timestamp + " ", with: "")
                if cleanName == filename {
                    cleanName = filename.replacingOccurrences(of: timestamp, with: "composite")
                }
            }

            let destPath = sessionDir + "/" + cleanName

            if filePath == destPath {
                logInfo("Already in session folder: \(cleanName)")
                collectedCount += 1
                continue
            }

            if fileManager.fileExists(atPath: destPath) {
                logInfo("File already exists: \(cleanName)")
                collectedCount += 1
                continue
            }

            do {
                try fileManager.moveItem(atPath: filePath, toPath: destPath)
                logSuccess("Collected: \(cleanName)")
                collectedCount += 1
            } catch {
                logError("Failed to move \(filename): \(error.localizedDescription)")
            }
        }

        logInfo("Total files collected: \(collectedCount) into \(folderName)/")

        // Extract audio
        extractAudio(sessionDir: sessionDir)
    }

    private func extractAudio(sessionDir: String) {
        let fileManager = FileManager.default
        let contents = (try? fileManager.contentsOfDirectory(atPath: sessionDir)) ?? []

        // Find source file (prefer composite)
        var sourceFile: String?
        for file in contents {
            if file.lowercased().contains("composite") {
                sourceFile = sessionDir + "/" + file
                break
            }
        }

        if sourceFile == nil {
            for file in contents {
                let ext = (file as NSString).pathExtension.lowercased()
                if ["mov", "mkv", "mp4"].contains(ext) {
                    sourceFile = sessionDir + "/" + file
                    break
                }
            }
        }

        guard let source = sourceFile else {
            logWarning("No video file found to extract audio from")
            return
        }

        let audioFile = sessionDir + "/audio.aac"

        if fileManager.fileExists(atPath: audioFile) {
            logInfo("Audio file already exists")
            return
        }

        logInfo("Extracting audio from: \((source as NSString).lastPathComponent)")

        let result = runShellCommand("/opt/homebrew/bin/ffmpeg -i \"\(source)\" -vn -acodec copy \"\(audioFile)\" -y 2>&1", timeout: 120)

        if fileManager.fileExists(atPath: audioFile) {
            logSuccess("Audio extracted: audio.aac")

            // Trigger auto-transcription if enabled
            let transcriptionConfig = TranscriptionManager.shared.loadConfig()
            if transcriptionConfig.enabled {
                logInfo("Starting auto-transcription...")
                TranscriptionManager.shared.transcribe(audioPath: audioFile, outputDir: sessionDir)
            }
        } else {
            logWarning("Could not extract audio: \(String(result.output.prefix(100)))")
        }
    }

    // MARK: - OBS Control

    func closeOBS(force: Bool = false) {
        guard force || obsLaunchedByApp else {
            logInfo("OBS left open (was already running and auto-close is off)")
            obsLaunchedByApp = false
            return
        }

        logInfo("Closing OBS...")
        if let obsApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.obsproject.obs-studio" }) {
            obsApp.terminate()
            logSuccess("OBS closed")
        }
        obsLaunchedByApp = false
    }

    // MARK: - Helper Methods

    private func ensureProfileConfigured(targetProfile: String, setupType: SetupType) {
        logInfo("===============================================")
        logInfo("ENSURING PROFILE '\(targetProfile)' IS CONFIGURED")
        logInfo("===============================================")

        // Load saved configuration from disk
        let configPath = Paths.configDir + "/profile-configs.json"
        var savedConfig: ProfileConfiguration?

        if FileManager.default.fileExists(atPath: configPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           let configs = try? JSONDecoder().decode([String: ProfileConfiguration].self, from: data) {
            savedConfig = configs[targetProfile]
            if let config = savedConfig {
                logInfo("Found saved configuration for '\(targetProfile)':")
                logInfo("  Displays: \(config.displays.joined(separator: ", "))")
                logInfo("  Cameras: \(config.cameras.joined(separator: ", "))")
                logInfo("  Audio: \(config.audioInputs.joined(separator: ", "))")
                logInfo("  Configured: \(config.isConfigured)")
            } else {
                logWarning("No saved configuration found for '\(targetProfile)'")
            }
        } else {
            logWarning("No profile configurations file found at: \(configPath)")
        }

        // If no saved config or not configured, create default config
        if savedConfig == nil || savedConfig?.isConfigured == false {
            logWarning("Profile '\(targetProfile)' has no configuration - creating default config")
            savedConfig = createDefaultConfiguration(for: setupType)
            logInfo("Created default configuration:")
            if let config = savedConfig {
                logInfo("  Displays: \(config.displays.joined(separator: ", "))")
                logInfo("  Cameras: \(config.cameras.joined(separator: ", "))")
                logInfo("  Audio: \(config.audioInputs.joined(separator: ", "))")
            }
        }

        // Check if profile is already configured correctly
        if let config = savedConfig {
            // Scene name should match profile name
            let sceneName = targetProfile

            // Check if scene exists and has correct sources
            let isConfigured = checkIfProfileConfigured(sceneName: sceneName, expectedConfig: config)

            if isConfigured {
                logSuccess("✓ Profile '\(targetProfile)' is already configured correctly!")
                logInfo("Scene '\(sceneName)' exists with all expected sources")

                // Verify that input settings (devices) are properly configured
                logInfo("Verifying input device settings...")
                _ = OBSSourceManager.shared.verifyAndFixInputSettings(sceneName: sceneName, config: config)

                logInfo("Setting scene as current...")
                // Just set the scene as current
                let setSceneResult = runShellCommand("""
                    {
                        sleep 0.3
                        echo '{"op":1,"d":{"rpcVersion":1}}'
                        sleep 0.3
                        echo '{"op":6,"d":{"requestType":"SetCurrentProgramScene","requestId":"setscene1","requestData":{"sceneName":"\(sceneName)"}}}'
                        sleep 0.5
                    } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
                """, timeout: 10)

                if setSceneResult.output.contains("\"code\":100") || setSceneResult.output.contains("\"result\":true") {
                    logSuccess("Scene '\(sceneName)' selected")
                }
            } else {
                logWarning("Profile '\(targetProfile)' needs (re)configuration")
                logInfo("Configuring profile with correct sources...")
                OBSSourceManager.shared.configureProfile(profileName: targetProfile, config: config)
                logSuccess("Profile '\(targetProfile)' configured successfully")
            }
        } else {
            logError("Failed to get or create configuration for '\(targetProfile)'")
        }

        logInfo("===============================================")
    }

    private func checkIfProfileConfigured(sceneName: String, expectedConfig: ProfileConfiguration) -> Bool {
        logInfo("Checking if scene '\(sceneName)' exists with correct sources...")

        // Check if scene exists
        let sceneListResult = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"GetSceneList","requestId":"scenelist1"}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        // Check if our scene exists
        if !sceneListResult.output.contains("\"\(sceneName)\"") {
            logInfo("Scene '\(sceneName)' does not exist - needs configuration")
            return false
        }

        logInfo("Scene '\(sceneName)' exists - checking sources...")

        // Get sources in the scene
        let itemsResult = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"GetSceneItemList","requestId":"itemlist1","requestData":{"sceneName":"\(sceneName)"}}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        // Extract source names
        let sourcePattern = #"\"sourceName\":\s*\"([^\"]+)\""#
        guard let sourceRegex = try? NSRegularExpression(pattern: sourcePattern, options: []) else {
            logWarning("Could not create source name regex")
            return false
        }

        let sourceMatches = sourceRegex.matches(in: itemsResult.output, options: [], range: NSRange(location: 0, length: itemsResult.output.utf16.count))
        let actualSources = sourceMatches.compactMap { match -> String? in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: itemsResult.output) else {
                return nil
            }
            return String(itemsResult.output[range])
        }

        logInfo("Found \(actualSources.count) source(s) in scene:")
        for source in actualSources {
            logInfo("  - \(source)")
        }

        // Build expected source names
        var expectedSources: [String] = []

        // Add displays
        for (index, _) in expectedConfig.displays.enumerated() {
            expectedSources.append("Screen \(index + 1)")
        }

        // Add cameras
        expectedSources.append(contentsOf: expectedConfig.cameras)

        // Add audio
        expectedSources.append(contentsOf: expectedConfig.audioInputs)

        logInfo("Expected \(expectedSources.count) source(s):")
        for source in expectedSources {
            logInfo("  - \(source)")
        }

        // Check if all expected sources are present
        let actualSourcesSet = Set(actualSources)
        let expectedSourcesSet = Set(expectedSources)

        let missingExpected = expectedSourcesSet.subtracting(actualSourcesSet)
        let extraActual = actualSourcesSet.subtracting(expectedSourcesSet)

        if !missingExpected.isEmpty {
            logWarning("Missing expected sources:")
            for source in missingExpected {
                logWarning("  - \(source)")
            }
            return false
        }

        if !extraActual.isEmpty {
            logWarning("Extra sources found (not in config):")
            for source in extraActual {
                logWarning("  - \(source)")
            }
            return false
        }

        logSuccess("✓ All sources match expected configuration!")
        return true
    }

    private func createDefaultConfiguration(for setupType: SetupType) -> ProfileConfiguration {
        logInfo("Creating default configuration for: \(setupType.displayName)")

        switch setupType {
        case .macBookSetup:
            return ProfileConfiguration(
                profileName: setupType.obsProfileName,
                displays: ["Display 1"],
                cameras: ["FaceTime HD Camera"],
                audioInputs: ["Built-in Microphone"],
                isConfigured: true
            )

        case .macSetup:
            return ProfileConfiguration(
                profileName: setupType.obsProfileName,
                displays: ["Display 1", "Display 2", "Display 3"],
                cameras: ["External Camera"],
                audioInputs: ["External Microphone"],
                isConfigured: true
            )

        case .pcSetup:
            return ProfileConfiguration(
                profileName: setupType.obsProfileName,
                displays: ["Display 1"],
                cameras: Array(1...10).map { "Camera \($0)" },
                audioInputs: ["Microphone"],
                isConfigured: true
            )
        }
    }

    private func verifySceneSources(sceneName: String) {
        logInfo("=========================================")
        logInfo("VERIFYING SCENE SOURCES BEFORE RECORDING")
        logInfo("=========================================")
        logInfo("Scene to verify: \(sceneName)")

        // Get scene items
        let itemsResult = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"GetSceneItemList","requestId":"itemlist1","requestData":{"sceneName":"\(sceneName)"}}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        logInfo("GetSceneItemList response: \(String(itemsResult.output.prefix(1000)))")

        // Extract source names
        let sourcePattern = #"\"sourceName\":\s*\"([^\"]+)\""#
        guard let sourceRegex = try? NSRegularExpression(pattern: sourcePattern, options: []) else {
            logWarning("Could not create source name regex")
            return
        }

        let sourceMatches = sourceRegex.matches(in: itemsResult.output, options: [], range: NSRange(location: 0, length: itemsResult.output.utf16.count))
        let sources = sourceMatches.compactMap { match -> String? in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: itemsResult.output) else {
                return nil
            }
            return String(itemsResult.output[range])
        }

        if sources.isEmpty {
            logWarning("⚠️  NO SOURCES FOUND IN SCENE '\(sceneName)'!")
            logWarning("⚠️  This profile may not be configured correctly.")
        } else {
            logInfo("Found \(sources.count) source(s) in scene '\(sceneName)':")
            for (index, source) in sources.enumerated() {
                logInfo("  [\(index + 1)] \(source)")
            }
        }

        // Check if sources match expected setup
        if let session = currentSession {
            logInfo("Expected setup: \(session.setupType.displayName)")
            logInfo("Expected profile: \(session.setupType.obsProfileName)")

            switch session.setupType {
            case .macBookSetup:
                logInfo("Expected sources for MacBook Setup:")
                logInfo("  - 1 display (e.g., Screen 1)")
                logInfo("  - FaceTime HD Camera (or similar)")
                logInfo("  - Built-in Microphone (or similar)")

                let hasMultipleScreens = sources.filter { $0.contains("Screen") }.count > 1
                let hasExternalCamera = sources.contains { $0.contains("ZV-E") || $0.contains("External") }
                let hasExternalMic = sources.contains { $0.contains("FIFINE") || ($0.contains("Microphone") && !$0.contains("Built-in")) }

                if hasMultipleScreens {
                    logError("❌ MISMATCH: Found multiple screens, but MacBook Setup should have only 1!")
                }
                if hasExternalCamera {
                    logError("❌ MISMATCH: Found external camera, but MacBook Setup should use FaceTime camera!")
                }
                if hasExternalMic {
                    logError("❌ MISMATCH: Found external microphone, but MacBook Setup should use built-in!")
                }

                if hasMultipleScreens || hasExternalCamera || hasExternalMic {
                    logError("============================================")
                    logError("SOURCE MISMATCH DETECTED!")
                    logError("Profile '\(session.setupType.obsProfileName)' has sources from a different setup.")
                    logError("Please reconfigure this profile via 'Configure Profiles...' (Cmd+P)")
                    logError("============================================")
                }

            case .macSetup:
                logInfo("Expected sources for Mac Multi-Screen Setup:")
                logInfo("  - Multiple displays (e.g., Screen 1, 2, 3)")
                logInfo("  - External camera (e.g., ZV-E1)")
                logInfo("  - External microphone (e.g., FIFINE)")

            case .pcSetup:
                logInfo("Expected sources for PC Setup:")
                logInfo("  - 1 display")
                logInfo("  - Multiple cameras")
            }
        }

        logInfo("=========================================")
    }

    private func extractProfileName(from websocketOutput: String) -> String? {
        // Look for "currentProfileName":"SomeProfile" in the GetCurrentProfile response
        let pattern = #"\"currentProfileName\":\s*\"([^\"]+)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: websocketOutput, options: [], range: NSRange(location: 0, length: websocketOutput.utf16.count)),
              match.numberOfRanges > 1 else {
            return nil
        }

        let range = match.range(at: 1)
        if let swiftRange = Range(range, in: websocketOutput) {
            return String(websocketOutput[swiftRange])
        }

        return nil
    }

    private func getProfileList() -> (profiles: [String], currentProfile: String?) {
        logInfo("Fetching profile list from OBS...")

        let result = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"GetProfileList","requestId":"proflist1"}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        logInfo("GetProfileList response: \(String(result.output.prefix(300)))")

        // Extract current profile name
        let currentProfile = extractProfileName(from: result.output)

        // Extract profile names from response like: "profiles":["Profile1","Profile2"]
        let pattern = #"\"profiles\":\s*\[(.*?)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: result.output, options: [], range: NSRange(location: 0, length: result.output.utf16.count)),
              match.numberOfRanges > 1 else {
            logWarning("Could not parse profile list")
            return ([], currentProfile)
        }

        let range = match.range(at: 1)
        guard let swiftRange = Range(range, in: result.output) else {
            return ([], currentProfile)
        }

        let profilesString = String(result.output[swiftRange])
        // Extract individual profile names from "Profile1","Profile2"
        let namePattern = #"\"([^\"]+)\""#
        guard let nameRegex = try? NSRegularExpression(pattern: namePattern, options: []) else {
            return ([], currentProfile)
        }

        let matches = nameRegex.matches(in: profilesString, options: [], range: NSRange(location: 0, length: profilesString.utf16.count))
        let profiles = matches.compactMap { match -> String? in
            guard match.numberOfRanges > 1 else { return nil }
            let range = match.range(at: 1)
            guard let swiftRange = Range(range, in: profilesString) else { return nil }
            return String(profilesString[swiftRange])
        }

        logInfo("Found \(profiles.count) profiles: \(profiles.joined(separator: ", "))")
        logInfo("Current profile from list: \(currentProfile ?? "unknown")")
        return (profiles, currentProfile)
    }

    private func createProfile(name: String) -> Bool {
        logInfo("Creating OBS profile: \(name)")

        let result = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"CreateProfile","requestId":"createprof1","requestData":{"profileName":"\(name)"}}}'
                sleep 1.0
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        logInfo("CreateProfile response: \(String(result.output.prefix(200)))")

        if result.output.contains("\"status\":200") || result.output.contains("\"op\":7") {
            logSuccess("Successfully created profile: \(name)")
            return true
        } else if result.output.contains("Profile already exists") {
            logInfo("Profile already exists: \(name)")
            return true
        } else {
            logError("Failed to create profile: \(name)")
            logError("Response: \(String(result.output.prefix(300)))")
            return false
        }
    }

    private func ensureProfilesExist() -> String? {
        logInfo("Ensuring all required OBS profiles exist...")

        let (existingProfiles, currentProfile) = getProfileList()
        let requiredProfiles = [
            SetupType.macSetup.obsProfileName,
            SetupType.macBookSetup.obsProfileName,
            SetupType.pcSetup.obsProfileName
        ]

        for profileName in requiredProfiles {
            if !existingProfiles.contains(profileName) {
                logWarning("Profile '\(profileName)' not found, creating it...")
                _ = createProfile(name: profileName)
            } else {
                logInfo("Profile '\(profileName)' already exists")
            }
        }

        logSuccess("All required profiles are ready")
        return currentProfile
    }
}
