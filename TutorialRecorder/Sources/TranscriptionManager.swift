import Cocoa

// MARK: - Transcription Configuration

struct TranscriptionConfig: Codable {
    var enabled: Bool
    var model: String
    var outputFormat: String
    var language: String

    enum CodingKeys: String, CodingKey {
        case enabled
        case model
        case outputFormat = "output_format"
        case language
    }

    static var `default`: TranscriptionConfig {
        TranscriptionConfig(
            enabled: true,
            model: "small",
            outputFormat: "txt",
            language: "en"
        )
    }
}

// MARK: - Transcription Model

enum TranscriptionModel: String, CaseIterable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"

    var displayName: String {
        switch self {
        case .tiny: return "Tiny (75MB, fastest)"
        case .base: return "Base (150MB, fast)"
        case .small: return "Small (500MB, recommended)"
        case .medium: return "Medium (1.5GB, highest accuracy)"
        }
    }

    var modelFilename: String {
        "ggml-\(rawValue).en.bin"
    }
}

// MARK: - Transcription Status

enum TranscriptionStatus {
    case idle
    case transcribing(file: String)
    case completed(transcript: String)
    case error(String)

    var isTranscribing: Bool {
        if case .transcribing = self { return true }
        return false
    }
}

// MARK: - Whisper Status

enum WhisperStatus {
    case notInstalled
    case noModel
    case ready

    var displayText: String {
        switch self {
        case .notInstalled: return "Not installed"
        case .noModel: return "Model not downloaded"
        case .ready: return "Ready"
        }
    }
}

// MARK: - Transcription Manager

class TranscriptionManager {
    static let shared = TranscriptionManager()

    private(set) var status: TranscriptionStatus = .idle
    private(set) var lastTranscription: String?

    var onStatusChanged: ((TranscriptionStatus) -> Void)?
    var onProgress: ((String) -> Void)?

    private let configPath = Paths.configDir + "/transcription-config.json"
    private let modelsDir = NSHomeDirectory() + "/.cache/whisper"

    private init() {
        try? FileManager.default.createDirectory(atPath: modelsDir, withIntermediateDirectories: true)
    }

    // MARK: - Configuration

    func loadConfig() -> TranscriptionConfig {
        guard FileManager.default.fileExists(atPath: configPath) else {
            return .default
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            return try JSONDecoder().decode(TranscriptionConfig.self, from: data)
        } catch {
            logError("Failed to load transcription config: \(error.localizedDescription)")
            return .default
        }
    }

    func saveConfig(_ config: TranscriptionConfig) -> Bool {
        do {
            let configDir = (configPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: URL(fileURLWithPath: configPath))
            logInfo("Transcription configuration saved")
            return true
        } catch {
            logError("Failed to save transcription config: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Whisper Status

    func checkWhisperStatus() -> WhisperStatus {
        // Check if whisper-cli is installed (Homebrew package is whisper-cpp but binary is whisper-cli)
        let whisperCheck = runShellCommand("which whisper-cli 2>/dev/null || which /opt/homebrew/bin/whisper-cli 2>/dev/null", timeout: 5)
        guard whisperCheck.success && !whisperCheck.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .notInstalled
        }

        // Check if model exists
        let config = loadConfig()
        let modelPath = getModelPath(for: config.model)
        guard FileManager.default.fileExists(atPath: modelPath) else {
            return .noModel
        }

        return .ready
    }

    func getWhisperPath() -> String? {
        // Try common locations - binary is whisper-cli, not whisper-cpp
        let paths = [
            "/opt/homebrew/bin/whisper-cli",
            "/usr/local/bin/whisper-cli"
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try which command
        let result = runShellCommand("which whisper-cli 2>/dev/null", timeout: 5)
        if result.success && !result.output.isEmpty {
            return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    func getModelPath(for model: String) -> String {
        return modelsDir + "/ggml-\(model).en.bin"
    }

    func getAvailableModels() -> [String] {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: modelsDir) else {
            return []
        }

        return contents
            .filter { $0.hasPrefix("ggml-") && $0.hasSuffix(".bin") }
            .map { filename in
                let model = filename
                    .replacingOccurrences(of: "ggml-", with: "")
                    .replacingOccurrences(of: ".en.bin", with: "")
                    .replacingOccurrences(of: ".bin", with: "")
                return model
            }
    }

    // MARK: - Transcription

    func transcribe(audioPath: String, outputDir: String, completion: ((Bool, String?) -> Void)? = nil) {
        let config = loadConfig()

        guard config.enabled else {
            logInfo("Transcription disabled")
            completion?(false, nil)
            return
        }

        guard let whisperPath = getWhisperPath() else {
            logError("whisper-cli not found")
            status = .error("whisper-cli not installed")
            onStatusChanged?(status)
            completion?(false, nil)
            return
        }

        let modelPath = getModelPath(for: config.model)
        guard FileManager.default.fileExists(atPath: modelPath) else {
            logError("Whisper model not found: \(modelPath)")
            status = .error("Model not downloaded")
            onStatusChanged?(status)
            completion?(false, nil)
            return
        }

        guard FileManager.default.fileExists(atPath: audioPath) else {
            logError("Audio file not found: \(audioPath)")
            status = .error("Audio file not found")
            onStatusChanged?(status)
            completion?(false, nil)
            return
        }

        let outputBasePath = outputDir + "/transcript"
        let audioFilename = (audioPath as NSString).lastPathComponent

        logInfo("Starting transcription of: \(audioFilename)")
        status = .transcribing(file: audioFilename)
        onStatusChanged?(status)
        onProgress?("Transcribing audio...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Whisper only supports WAV format, convert AAC to WAV first
            let wavPath = outputDir + "/audio_temp.wav"
            let ffmpegPath = "/opt/homebrew/bin/ffmpeg"

            // Convert to 16kHz mono WAV (optimal for Whisper)
            let convertCommand = "\"\(ffmpegPath)\" -i \"\(audioPath)\" -ar 16000 -ac 1 -c:a pcm_s16le \"\(wavPath)\" -y 2>&1"
            logInfo("Converting audio to WAV: \(convertCommand)")
            let convertResult = runShellCommand(convertCommand, timeout: 120)

            guard FileManager.default.fileExists(atPath: wavPath) else {
                logError("Failed to convert audio to WAV: \(convertResult.output)")
                DispatchQueue.main.async {
                    self?.status = .error("Audio conversion failed")
                    self?.onStatusChanged?(self?.status ?? .idle)
                    completion?(false, nil)
                }
                return
            }

            // Build whisper command using the WAV file
            var command = "\"\(whisperPath)\" -m \"\(modelPath)\" -f \"\(wavPath)\""

            // Add output format flags
            switch config.outputFormat {
            case "txt":
                command += " -otxt"
            case "srt":
                command += " -osrt"
            case "vtt":
                command += " -ovtt"
            case "both":
                command += " -otxt -osrt"
            default:
                command += " -otxt"
            }

            command += " -of \"\(outputBasePath)\""

            // Add language
            if config.language != "auto" {
                command += " -l \(config.language)"
            }

            logInfo("Running: \(command)")

            // Run transcription with generous timeout (10 minutes for long recordings)
            let result = runShellCommand(command, timeout: 600)

            DispatchQueue.main.async {
                let txtPath = outputBasePath + ".txt"
                let srtPath = outputBasePath + ".srt"

                var transcriptPath: String?
                if FileManager.default.fileExists(atPath: txtPath) {
                    transcriptPath = txtPath
                } else if FileManager.default.fileExists(atPath: srtPath) {
                    transcriptPath = srtPath
                }

                // Clean up temp WAV file
                try? FileManager.default.removeItem(atPath: wavPath)

                if let path = transcriptPath {
                    let transcript = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
                    self?.lastTranscription = transcript
                    self?.status = .completed(transcript: transcript)
                    self?.onStatusChanged?(self?.status ?? .idle)
                    logSuccess("Transcription completed: \((path as NSString).lastPathComponent)")
                    showSystemNotification(title: "Transcription Complete", body: "Audio transcribed successfully")
                    completion?(true, transcript)
                } else {
                    self?.status = .error("Transcription failed")
                    self?.onStatusChanged?(self?.status ?? .idle)
                    logError("Transcription failed: \(result.output)")
                    completion?(false, nil)
                }
            }
        }
    }

    func transcribeLastRecording() {
        // Find the most recent recording session
        let fileManager = FileManager.default
        let recordingsPath = Paths.recordingsBase

        guard let projects = try? fileManager.contentsOfDirectory(atPath: recordingsPath) else {
            logError("No recordings found")
            return
        }

        let sortedProjects = projects.filter { $0.hasPrefix("20") }.sorted().reversed()

        for projectName in sortedProjects {
            let rawPath = recordingsPath + "/" + projectName + "/raw"

            guard let sessions = try? fileManager.contentsOfDirectory(atPath: rawPath) else { continue }

            for session in sessions.sorted().reversed() {
                let sessionPath = rawPath + "/" + session
                let audioPath = sessionPath + "/audio.aac"

                if fileManager.fileExists(atPath: audioPath) {
                    // Check if transcript already exists
                    let transcriptPath = sessionPath + "/transcript.txt"
                    if fileManager.fileExists(atPath: transcriptPath) {
                        logInfo("Transcript already exists for: \(session)")

                        let alert = NSAlert()
                        alert.messageText = "Transcript Exists"
                        alert.informativeText = "A transcript already exists for this recording. Do you want to re-transcribe?"
                        alert.addButton(withTitle: "Re-transcribe")
                        alert.addButton(withTitle: "Cancel")

                        if alert.runModal() != .alertFirstButtonReturn {
                            return
                        }
                    }

                    transcribe(audioPath: audioPath, outputDir: sessionPath)
                    return
                }
            }
        }

        logWarning("No audio file found for transcription")
        showSystemNotification(title: "No Audio Found", body: "Could not find audio file to transcribe")
    }

    // MARK: - Model Download

    func downloadModel(_ model: TranscriptionModel, progress: ((String) -> Void)? = nil, completion: @escaping (Bool) -> Void) {
        let modelPath = getModelPath(for: model.rawValue)

        if FileManager.default.fileExists(atPath: modelPath) {
            logInfo("Model already exists: \(model.rawValue)")
            completion(true)
            return
        }

        let url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(model.modelFilename)"

        logInfo("Downloading model: \(model.rawValue)")
        progress?("Downloading \(model.displayName)...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            try? FileManager.default.createDirectory(atPath: self.modelsDir, withIntermediateDirectories: true)

            let command = "curl -L \"\(url)\" -o \"\(modelPath)\" --progress-bar 2>&1"
            let result = runShellCommand(command, timeout: 600)

            DispatchQueue.main.async {
                if FileManager.default.fileExists(atPath: modelPath) {
                    logSuccess("Model downloaded: \(model.rawValue)")
                    progress?("Model downloaded successfully")
                    completion(true)
                } else {
                    logError("Failed to download model: \(result.output)")
                    progress?("Download failed")
                    completion(false)
                }
            }
        }
    }

    // MARK: - Reset

    func reset() {
        status = .idle
        lastTranscription = nil
        onStatusChanged?(status)
    }
}
