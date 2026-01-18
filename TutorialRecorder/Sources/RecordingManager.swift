import Cocoa

// MARK: - Recording State

enum RecordingState {
    case idle
    case starting
    case recording
    case stopping
}

// MARK: - Session Info

struct SessionInfo {
    let projectPath: String
    let projectName: String
    let startTime: Date
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
        currentSession = SessionInfo(projectPath: path, projectName: name, startTime: Date())
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

    func startRecording(projectPath: String, projectName: String) {
        guard state == .idle else {
            onError?("Already recording or in progress")
            return
        }

        state = .starting
        onStateChanged?(.starting)

        // Initialize session
        let startTime = Date()
        currentSession = SessionInfo(projectPath: projectPath, projectName: projectName, startTime: startTime)

        // Initialize session log
        let logHeader = """
        =============================================
        Session started: \(startTime)
        Project: \(projectPath)
        =============================================
        """
        try? logHeader.write(toFile: projectPath + "/session.log", atomically: true, encoding: .utf8)
        Logger.shared.setSessionLog(path: projectPath + "/session.log")

        logInfo("Starting recording for project: \(projectName)")
        logInfo("Project path: \(projectPath)")

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

            let obsURL = URL(fileURLWithPath: "/Applications/OBS.app")
            workspace.openApplication(at: obsURL, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
                if let error = error {
                    logError("Failed to launch OBS: \(error.localizedDescription)")
                    self?.handleStartError("Failed to launch OBS")
                    return
                }

                logInfo("OBS launched, waiting for WebSocket...")
                self?.onProgress?("Waiting for OBS to start...")

                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    self?.connectAndStartRecording(projectPath: projectPath)
                }
            }
        } else {
            obsLaunchedByApp = false
            logInfo("OBS already running")
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
}
