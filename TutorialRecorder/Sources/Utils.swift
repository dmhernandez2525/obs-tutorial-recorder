import Foundation

// MARK: - Shell Command Execution

struct ShellResult {
    let output: String
    let exitCode: Int32
    var success: Bool { exitCode == 0 }
}

func runShellCommand(_ command: String, timeout: TimeInterval = 30) -> ShellResult {
    let process = Process()
    let pipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\"; " + command]
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()

        // Add timeout handling
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }

        if process.isRunning {
            process.terminate()
            return ShellResult(output: "Command timed out", exitCode: -1)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ShellResult(output: output, exitCode: process.terminationStatus)
    } catch {
        return ShellResult(output: error.localizedDescription, exitCode: -1)
    }
}

// MARK: - Logging

class Logger {
    static let shared = Logger()

    private let globalLogPath: String
    private var sessionLogPath: String?

    private init() {
        let configDir = NSHomeDirectory() + "/.config/tutorial-recorder"
        try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
        globalLogPath = configDir + "/app.log"
    }

    func setSessionLog(path: String) {
        sessionLogPath = path
    }

    func clearSessionLog() {
        sessionLogPath = nil
    }

    func log(_ level: LogLevel, _ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logLine = "[\(timestamp)] [\(level.rawValue)] \(message)\n"

        // Write to session log if available
        if let sessionPath = sessionLogPath {
            appendToFile(logLine, path: sessionPath)
        }

        // Always write to global log
        appendToFile(logLine, path: globalLogPath)

        // Print to console for debugging
        #if DEBUG
        print("[\(level.rawValue)] \(message)")
        #endif
    }

    private func appendToFile(_ text: String, path: String) {
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            if let data = text.data(using: .utf8) {
                handle.write(data)
            }
            try? handle.close()
        } else {
            try? text.write(toFile: path, atomically: false, encoding: .utf8)
        }
    }

    enum LogLevel: String {
        case info = "INFO"
        case success = "SUCCESS"
        case warning = "WARNING"
        case error = "ERROR"
    }
}

// Convenience functions
func logInfo(_ message: String) { Logger.shared.log(.info, message) }
func logSuccess(_ message: String) { Logger.shared.log(.success, message) }
func logWarning(_ message: String) { Logger.shared.log(.warning, message) }
func logError(_ message: String) { Logger.shared.log(.error, message) }

// MARK: - Notifications

func showSystemNotification(title: String, body: String) {
    let script = "display notification \"\(body)\" with title \"\(title)\" sound name \"Glass\""
    _ = runShellCommand("osascript -e '\(script)'")
}

// MARK: - Path Utilities

struct Paths {
    static let home = NSHomeDirectory()
    static let recordingsBase = home + "/Desktop/Tutorial Recordings"
    static let configDir = home + "/.config/tutorial-recorder"
    static let syncConfigPath = configDir + "/sync-config.json"
    static let appLogPath = configDir + "/app.log"

    static var scriptsPath: String {
        let execPath = Bundle.main.executablePath ?? ""
        let basePath = (execPath as NSString).deletingLastPathComponent
        let relativeScripts = (basePath as NSString).appendingPathComponent("../../scripts")

        if FileManager.default.fileExists(atPath: relativeScripts + "/start-tutorial.sh") {
            return relativeScripts
        }
        return home + "/Projects/obs-tutorial-recorder/scripts"
    }
}
