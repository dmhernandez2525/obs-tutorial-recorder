import Foundation
import Cocoa
import AVFoundation

// MARK: - OBS Source Manager

class OBSSourceManager {
    static let shared = OBSSourceManager()

    /// Cached result of Source Record plugin check
    private var sourceRecordPluginInstalled: Bool?

    private init() {}

    // MARK: - Plugin Verification

    /// Check if the Source Record plugin is installed
    /// This plugin is REQUIRED for ISO recording (separate files per source)
    func isSourceRecordPluginInstalled() -> Bool {
        // Return cached result if available
        if let cached = sourceRecordPluginInstalled {
            return cached
        }

        let pluginPath = NSHomeDirectory() + "/Library/Application Support/obs-studio/plugins/source-record.plugin"
        let exists = FileManager.default.fileExists(atPath: pluginPath)

        // Also check system-wide plugin location
        let systemPluginPath = "/Library/Application Support/obs-studio/plugins/source-record.plugin"
        let systemExists = FileManager.default.fileExists(atPath: systemPluginPath)

        sourceRecordPluginInstalled = exists || systemExists

        if exists {
            logInfo("Source Record plugin found at: \(pluginPath)")
        } else if systemExists {
            logInfo("Source Record plugin found at: \(systemPluginPath)")
        } else {
            logWarning("Source Record plugin NOT FOUND - ISO recording will not work!")
            logWarning("Install via: OBS > Tools > Scripts > Get More Scripts > Search 'Source Record'")
        }

        return sourceRecordPluginInstalled ?? false
    }

    /// Clear the cached plugin check (call when user says they installed it)
    func clearPluginCache() {
        sourceRecordPluginInstalled = nil
    }

    /// Check all core dependencies and return status
    func checkCoreDependencies() -> (sourceRecord: Bool, whisper: Bool, ffmpeg: Bool, websocat: Bool) {
        let sourceRecord = isSourceRecordPluginInstalled()

        let whisperResult = runShellCommand("which whisper-cli 2>/dev/null", timeout: 5)
        let whisper = whisperResult.success && !whisperResult.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let ffmpegResult = runShellCommand("which ffmpeg 2>/dev/null", timeout: 5)
        let ffmpeg = ffmpegResult.success && !ffmpegResult.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let websocatResult = runShellCommand("which websocat 2>/dev/null", timeout: 5)
        let websocat = websocatResult.success && !websocatResult.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        logInfo("=== Core Dependencies Check ===")
        logInfo("  Source Record Plugin: \(sourceRecord ? "INSTALLED" : "MISSING")")
        logInfo("  whisper-cli: \(whisper ? "INSTALLED" : "MISSING")")
        logInfo("  ffmpeg: \(ffmpeg ? "INSTALLED" : "MISSING")")
        logInfo("  websocat: \(websocat ? "INSTALLED" : "MISSING")")
        logInfo("================================")

        return (sourceRecord, whisper, ffmpeg, websocat)
    }

    /// Show alert if Source Record plugin is not installed
    func showSourceRecordPluginAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Source Record Plugin Required"
            alert.informativeText = """
            The Source Record plugin is required for ISO recording (separate files for each source).

            Without this plugin, you will only get a single composite recording.

            To install:
            1. Open OBS
            2. Go to Tools > Scripts > Get More Scripts
            3. Search for "Source Record"
            4. Click Install
            5. Restart OBS

            See CORE_DEPENDENCIES.md for more information.
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Continue Anyway")
            alert.addButton(withTitle: "Open OBS")

            let response = alert.runModal()

            if response == .alertSecondButtonReturn {
                // Open OBS
                if let obsURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.obsproject.obs-studio") {
                    NSWorkspace.shared.openApplication(at: obsURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
                }
            }
        }
    }

    // MARK: - Device UID Resolution

    /// Get the device UID for a camera by its display name
    /// OBS requires the device UID (unique identifier), not the display name
    private func getVideoDeviceUID(for deviceName: String) -> String {
        logInfo("Looking up device UID for: '\(deviceName)'")

        // Use AVFoundation to get all video capture devices
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )

        for device in discoverySession.devices {
            logInfo("  Found camera: '\(device.localizedName)' with UID: '\(device.uniqueID)'")
            if device.localizedName.lowercased().contains(deviceName.lowercased()) ||
               deviceName.lowercased().contains(device.localizedName.lowercased()) {
                logInfo("  → Matched! Using UID: '\(device.uniqueID)'")
                return device.uniqueID
            }
        }

        // If no match found, try exact match
        for device in discoverySession.devices {
            if device.localizedName == deviceName {
                return device.uniqueID
            }
        }

        // Fallback: return the first available camera's UID
        if let firstDevice = discoverySession.devices.first {
            logWarning("No exact match for '\(deviceName)', using first available camera: '\(firstDevice.localizedName)'")
            return firstDevice.uniqueID
        }

        logWarning("No cameras found, returning device name as-is")
        return deviceName
    }

    /// Get the device UID for an audio input by its display name
    private func getAudioDeviceUID(for deviceName: String) -> String {
        logInfo("Looking up audio device UID for: '\(deviceName)'")

        // Use system_profiler to get audio devices - AVFoundation audio device enumeration
        // is more complex, so we'll use the device name for now
        // OBS's coreaudio_input_capture typically accepts device names or IDs

        // For built-in microphone, the device_id is often "default" or the actual device name
        if deviceName.lowercased().contains("built-in") || deviceName.lowercased().contains("microphone") {
            logInfo("  Using 'default' for built-in microphone")
            return "default"
        }

        return deviceName
    }

    // MARK: - Verify and Fix Input Settings

    /// Verify that all inputs in a scene have their devices properly configured
    /// Returns true if all inputs are properly configured, false if any needed fixing
    func verifyAndFixInputSettings(sceneName: String, config: ProfileConfiguration) -> Bool {
        logInfo("Verifying input settings for scene '\(sceneName)'...")
        var allConfigured = true

        // Check and fix camera inputs
        for cameraName in config.cameras {
            if !verifyAndFixCameraInput(inputName: cameraName) {
                allConfigured = false
            }
        }

        // Check and fix audio inputs
        for audioName in config.audioInputs {
            if !verifyAndFixAudioInput(inputName: audioName, deviceName: audioName) {
                allConfigured = false
            }
        }

        return allConfigured
    }

    /// Verify a camera input has a device selected, fix if not
    private func verifyAndFixCameraInput(inputName: String) -> Bool {
        logInfo("Checking camera input settings: '\(inputName)'")

        // Get the correct device UID first
        let expectedUID = getVideoDeviceUID(for: inputName)
        logInfo("Expected device UID for '\(inputName)': '\(expectedUID)'")

        // Get current input settings
        let getResult = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"GetInputSettings","requestId":"getsettings1","requestData":{"inputName":"\(inputName)"}}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        logInfo("GetInputSettings response: \(String(getResult.output.prefix(600)))")

        // Extract the current device value
        var currentDevice = ""
        let devicePattern = #"\"device\":\"([^\"]*)\""#
        if let regex = try? NSRegularExpression(pattern: devicePattern),
           let match = regex.firstMatch(in: getResult.output, range: NSRange(getResult.output.startIndex..., in: getResult.output)),
           let range = Range(match.range(at: 1), in: getResult.output) {
            currentDevice = String(getResult.output[range])
        }

        logInfo("Current device setting: '\(currentDevice)'")
        logInfo("Expected device UID: '\(expectedUID)'")

        // Check if current device matches the expected UID
        // Device names like "FaceTime HD Camera" are NOT valid - only UIDs work
        if currentDevice == expectedUID {
            logSuccess("✓ Camera '\(inputName)' already has correct device UID: '\(currentDevice)'")
            return true
        }

        // Device is not set correctly - fix it
        logWarning("Camera '\(inputName)' has wrong device ('\(currentDevice)'), setting to UID '\(expectedUID)'...")

        // Update the input settings with the correct device UID
        let setResult = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"SetInputSettings","requestId":"setsettings1","requestData":{"inputName":"\(inputName)","inputSettings":{"device":"\(expectedUID)"}}}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        logInfo("SetInputSettings response: \(String(setResult.output.prefix(400)))")

        if setResult.output.contains("\"code\":100") || setResult.output.contains("\"result\":true") {
            logSuccess("✓ Fixed camera '\(inputName)' - set device to UID '\(expectedUID)'")
            return true
        } else {
            logError("❌ Failed to fix camera '\(inputName)'")
            return false
        }
    }

    /// Verify an audio input has a device selected, fix if not
    private func verifyAndFixAudioInput(inputName: String, deviceName: String) -> Bool {
        logInfo("Checking audio input settings: '\(inputName)'")

        // Get current input settings
        let getResult = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"GetInputSettings","requestId":"getsettings1","requestData":{"inputName":"\(inputName)"}}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        logInfo("GetInputSettings response: \(String(getResult.output.prefix(600)))")

        // Check if device_id is set
        let hasDevice = getResult.output.contains("\"device_id\":\"") &&
                       !getResult.output.contains("\"device_id\":\"\"")

        if hasDevice {
            logSuccess("✓ Audio input '\(inputName)' has device configured")
            return true
        }

        // Device not set - fix it
        logWarning("Audio input '\(inputName)' has no device selected, fixing...")

        let audioDeviceID = getAudioDeviceUID(for: deviceName)

        let setResult = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"SetInputSettings","requestId":"setsettings1","requestData":{"inputName":"\(inputName)","inputSettings":{"device_id":"\(audioDeviceID)"}}}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        logInfo("SetInputSettings response: \(String(setResult.output.prefix(400)))")

        if setResult.output.contains("\"code\":100") || setResult.output.contains("\"result\":true") {
            logSuccess("✓ Fixed audio input '\(inputName)' - set device to '\(audioDeviceID)'")
            return true
        } else {
            logError("❌ Failed to fix audio input '\(inputName)'")
            return false
        }
    }

    // MARK: - Get Available Sources from OBS

    func getAvailableDisplays() -> [String] {
        logInfo("Getting available displays from OBS...")

        // Get display capture inputs
        let result = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"GetInputKindList","requestId":"inputkinds1"}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        logInfo("Input kinds response: \(String(result.output.prefix(200)))")

        // For macOS, display capture is typically "screen_capture" or "display_capture"
        let displayCount = NSScreen.screens.count
        var displays: [String] = []

        for i in 1...displayCount {
            displays.append("Display \(i)")
        }

        logInfo("Found \(displays.count) displays")
        return displays
    }

    func getAvailableCameras() -> [String] {
        logInfo("Getting available cameras from OBS...")

        // Query video capture devices
        let result = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"GetInputList","requestId":"inputlist1"}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        logInfo("Input list response: \(String(result.output.prefix(200)))")

        // Also check system_profiler as fallback
        let sysResult = runShellCommand("system_profiler SPCameraDataType 2>/dev/null | grep 'Model ID:' | sed 's/.*Model ID: //'", timeout: 10)

        var cameras = sysResult.output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if cameras.isEmpty {
            cameras = ["FaceTime HD Camera", "External Camera"]
        }

        logInfo("Found \(cameras.count) cameras")
        return cameras
    }

    func getAvailableAudioInputs() -> [String] {
        logInfo("Getting available audio inputs from OBS...")

        let result = runShellCommand("system_profiler SPAudioDataType 2>/dev/null | grep 'Device Name:' | sed 's/.*Device Name: //'", timeout: 10)

        var inputs = result.output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if inputs.isEmpty {
            inputs = ["Built-in Microphone", "External Microphone"]
        }

        logInfo("Found \(inputs.count) audio inputs")
        return inputs
    }

    // MARK: - Configure OBS Profile

    func configureProfile(profileName: String, config: ProfileConfiguration) {
        logInfo("Configuring OBS profile: \(profileName)")
        logInfo("  Displays: \(config.displays.joined(separator: ", "))")
        logInfo("  Cameras: \(config.cameras.joined(separator: ", "))")
        logInfo("  Audio: \(config.audioInputs.joined(separator: ", "))")

        // Switch to the profile first
        switchToProfile(profileName)
        Thread.sleep(forTimeInterval: 2.0)

        // Create scene with same name as profile
        let sceneName = profileName
        logInfo("Creating/configuring scene: \(sceneName)")
        createScene(sceneName)
        Thread.sleep(forTimeInterval: 1.0)

        // Set as current scene
        setCurrentScene(sceneName)
        Thread.sleep(forTimeInterval: 1.0)

        // Clear all existing sources from the scene
        logInfo("Clearing existing sources from scene '\(sceneName)'...")
        removeAllSceneItems(sceneName: sceneName)
        Thread.sleep(forTimeInterval: 1.0)

        // Add display captures
        for (index, _) in config.displays.enumerated() {
            let displayIndex = index + 1
            let sourceName = "Screen \(displayIndex)"
            createDisplayCapture(sourceName: sourceName, displayIndex: displayIndex, sceneName: sceneName)
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Add cameras
        for camera in config.cameras {
            let sourceName = camera
            createVideoCapture(sourceName: sourceName, deviceName: camera, sceneName: sceneName)
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Add audio inputs
        for audio in config.audioInputs {
            let sourceName = "\(audio)"
            createAudioCapture(sourceName: sourceName, deviceName: audio, sceneName: sceneName)
            Thread.sleep(forTimeInterval: 0.5)
        }

        logSuccess("Profile \(profileName) configured with \(config.displays.count) displays, \(config.cameras.count) cameras, \(config.audioInputs.count) audio sources")
    }

    // MARK: - OBS WebSocket Commands

    private func removeAllSceneItems(sceneName: String) {
        logInfo("Removing all scene items from: \(sceneName)")

        // Get list of scene items
        let listResult = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"GetSceneItemList","requestId":"itemlist1","requestData":{"sceneName":"\(sceneName)"}}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        // Extract scene item IDs from response
        // Response format: "sceneItems":[{"sceneItemId":1,...},{"sceneItemId":2,...}]
        let pattern = #"\"sceneItemId\":\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            logWarning("Could not create regex for scene item extraction")
            return
        }

        let matches = regex.matches(in: listResult.output, options: [], range: NSRange(location: 0, length: listResult.output.utf16.count))
        let itemIds = matches.compactMap { match -> Int? in
            guard match.numberOfRanges > 1 else { return nil }
            let range = match.range(at: 1)
            guard let swiftRange = Range(range, in: listResult.output) else { return nil }
            return Int(String(listResult.output[swiftRange]))
        }

        logInfo("Found \(itemIds.count) scene items to remove")

        // Remove each scene item
        for itemId in itemIds {
            let removeResult = runShellCommand("""
                {
                    sleep 0.3
                    echo '{"op":1,"d":{"rpcVersion":1}}'
                    sleep 0.3
                    echo '{"op":6,"d":{"requestType":"RemoveSceneItem","requestId":"remove1","requestData":{"sceneName":"\(sceneName)","sceneItemId":\(itemId)}}}'
                    sleep 0.3
                } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
            """, timeout: 10)

            if removeResult.output.contains("\"code\":100") || removeResult.output.contains("\"result\":true") {
                logInfo("Removed scene item ID: \(itemId)")
            } else {
                logWarning("Failed to remove scene item ID: \(itemId) - Response: \(String(removeResult.output.prefix(300)))")
            }
            Thread.sleep(forTimeInterval: 0.2)
        }

        logSuccess("Cleared all sources from scene: \(sceneName)")
    }

    private func switchToProfile(_ profileName: String) {
        logInfo("Switching to profile: \(profileName)")

        let result = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"SetCurrentProfile","requestId":"setprof1","requestData":{"profileName":"\(profileName)"}}}'
                sleep 1.0
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        if result.output.contains("\"status\":200") {
            logSuccess("Switched to profile: \(profileName)")
        } else {
            logWarning("Profile switch response: \(String(result.output.prefix(200)))")
        }
    }

    private func createScene(_ sceneName: String) {
        logInfo("Creating scene: \(sceneName)")

        let result = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"CreateScene","requestId":"scene1","requestData":{"sceneName":"\(sceneName)"}}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        if result.output.contains("\"status\":200") || result.output.contains("already exists") {
            logInfo("Scene created or already exists: \(sceneName)")
        } else {
            logInfo("Create scene response: \(String(result.output.prefix(200)))")
        }
    }

    private func setCurrentScene(_ sceneName: String) {
        logInfo("Setting current scene: \(sceneName)")

        let result = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"SetCurrentProgramScene","requestId":"setscene1","requestData":{"sceneName":"\(sceneName)"}}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        if result.output.contains("\"status\":200") {
            logSuccess("Set current scene: \(sceneName)")
        }
    }

    private func createDisplayCapture(sourceName: String, displayIndex: Int, sceneName: String) {
        logInfo("Creating display capture: \(sourceName) (Display \(displayIndex))")

        // macOS uses "screen_capture" input kind
        // display parameter: 0 = Display 1, 1 = Display 2, etc.
        let displayParam = displayIndex - 1

        // Try to create the input and add to scene
        logInfo("Creating input '\(sourceName)' with sceneName '\(sceneName)'...")
        let result = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"CreateInput","requestId":"input1","requestData":{"sceneName":"\(sceneName)","inputName":"\(sourceName)","inputKind":"screen_capture","inputSettings":{"display":\(displayParam),"show_cursor":true}}}}'
                sleep 1.0
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        logInfo("CreateInput response: \(String(result.output.prefix(500)))")
        if result.output.contains("\"status\":200") || result.output.contains("\"result\":true") {
            logSuccess("✓ Created display capture: \(sourceName)")
        } else if result.output.contains("\"code\":601") {
            // Input already exists globally, try adding it to the scene instead
            logWarning("Input '\(sourceName)' already exists, adding it to scene '\(sceneName)'...")
            let addResult = runShellCommand("""
                {
                    sleep 0.3
                    echo '{"op":1,"d":{"rpcVersion":1}}'
                    sleep 0.3
                    echo '{"op":6,"d":{"requestType":"CreateSceneItem","requestId":"item1","requestData":{"sceneName":"\(sceneName)","sourceName":"\(sourceName)"}}}'
                    sleep 0.5
                } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
            """, timeout: 10)

            logInfo("CreateSceneItem response: \(String(addResult.output.prefix(500)))")
            if addResult.output.contains("\"status\":200") || addResult.output.contains("\"result\":true") {
                logSuccess("✓ Added existing display capture '\(sourceName)' to scene")
            } else {
                logError("❌ Failed to add existing source '\(sourceName)' to scene")
            }
        } else {
            logWarning("Create display capture response: \(String(result.output.prefix(300)))")
        }
    }

    private func createVideoCapture(sourceName: String, deviceName: String, sceneName: String) {
        logInfo("Creating video capture: \(sourceName)")

        // Get the device UID from macOS - OBS requires UID, not display name
        let deviceUID = getVideoDeviceUID(for: deviceName)
        logInfo("Device '\(deviceName)' resolved to UID: '\(deviceUID)'")

        // macOS uses "av_capture_input_v2" for cameras in OBS 28+
        logInfo("Creating input '\(sourceName)' with sceneName '\(sceneName)'...")
        let result = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"CreateInput","requestId":"input1","requestData":{"sceneName":"\(sceneName)","inputName":"\(sourceName)","inputKind":"av_capture_input_v2","inputSettings":{"device":"\(deviceUID)"}}}}'
                sleep 1.0
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        logInfo("CreateInput response: \(String(result.output.prefix(500)))")
        if result.output.contains("\"status\":200") || result.output.contains("\"result\":true") {
            logSuccess("✓ Created video capture: \(sourceName)")
        } else if result.output.contains("\"code\":601") {
            // Input already exists globally, try adding it to the scene instead
            logWarning("Input '\(sourceName)' already exists, adding it to scene '\(sceneName)'...")
            let addResult = runShellCommand("""
                {
                    sleep 0.3
                    echo '{"op":1,"d":{"rpcVersion":1}}'
                    sleep 0.3
                    echo '{"op":6,"d":{"requestType":"CreateSceneItem","requestId":"item1","requestData":{"sceneName":"\(sceneName)","sourceName":"\(sourceName)"}}}'
                    sleep 0.5
                } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
            """, timeout: 10)

            logInfo("CreateSceneItem response: \(String(addResult.output.prefix(500)))")
            if addResult.output.contains("\"status\":200") || addResult.output.contains("\"result\":true") {
                logSuccess("✓ Added existing video capture '\(sourceName)' to scene")
            } else {
                logError("❌ Failed to add existing source '\(sourceName)' to scene")
            }
        } else {
            logWarning("Create video capture response: \(String(result.output.prefix(300)))")
        }
    }

    private func createAudioCapture(sourceName: String, deviceName: String, sceneName: String) {
        logInfo("Creating audio capture: \(sourceName)")

        // Get the device ID for audio - OBS coreaudio_input_capture uses device_id
        let audioDeviceID = getAudioDeviceUID(for: deviceName)
        logInfo("Audio device '\(deviceName)' resolved to ID: '\(audioDeviceID)'")

        // macOS uses "coreaudio_input_capture" for audio inputs
        logInfo("Creating input '\(sourceName)' with sceneName '\(sceneName)'...")
        let result = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"CreateInput","requestId":"input1","requestData":{"sceneName":"\(sceneName)","inputName":"\(sourceName)","inputKind":"coreaudio_input_capture","inputSettings":{"device_id":"\(audioDeviceID)"}}}}'
                sleep 1.0
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        logInfo("CreateInput response: \(String(result.output.prefix(500)))")
        if result.output.contains("\"status\":200") || result.output.contains("\"result\":true") {
            logSuccess("✓ Created audio capture: \(sourceName)")
        } else if result.output.contains("\"code\":601") {
            // Input already exists globally, try adding it to the scene instead
            logWarning("Input '\(sourceName)' already exists, adding it to scene '\(sceneName)'...")
            let addResult = runShellCommand("""
                {
                    sleep 0.3
                    echo '{"op":1,"d":{"rpcVersion":1}}'
                    sleep 0.3
                    echo '{"op":6,"d":{"requestType":"CreateSceneItem","requestId":"item1","requestData":{"sceneName":"\(sceneName)","sourceName":"\(sourceName)"}}}'
                    sleep 0.5
                } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
            """, timeout: 10)

            logInfo("CreateSceneItem response: \(String(addResult.output.prefix(500)))")
            if addResult.output.contains("\"status\":200") || addResult.output.contains("\"result\":true") {
                logSuccess("✓ Added existing audio capture '\(sourceName)' to scene")
            } else {
                logError("❌ Failed to add existing source '\(sourceName)' to scene")
            }
        } else {
            logWarning("Create audio capture response: \(String(result.output.prefix(300)))")
        }
    }

    // MARK: - Enable ISO Recording

    /// Add Source Record filters to each input source for ISO recording
    /// This creates separate recording files for each source
    /// REQUIRES: Source Record plugin to be installed in OBS
    func enableISORecording(sceneName: String, recordPath: String) {
        logInfo("============================================")
        logInfo("CONFIGURING ISO RECORDING")
        logInfo("============================================")
        logInfo("Scene: \(sceneName)")
        logInfo("Recording path: \(recordPath)")

        // CRITICAL: Check if Source Record plugin is installed
        if !isSourceRecordPluginInstalled() {
            logError("!!! SOURCE RECORD PLUGIN NOT INSTALLED !!!")
            logError("ISO recording will NOT work without this plugin!")
            logError("Install via: OBS > Tools > Scripts > Get More Scripts > 'Source Record'")
            logError("See CORE_DEPENDENCIES.md for detailed instructions")

            // Show user alert (non-blocking, on main thread)
            showSourceRecordPluginAlert()

            // Continue anyway - the filter creation will fail gracefully
            logWarning("Continuing without ISO recording capability...")
        } else {
            logSuccess("Source Record plugin is installed - ISO recording enabled")
        }

        // Get list of sources in the scene
        let listResult = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"GetSceneItemList","requestId":"itemlist1","requestData":{"sceneName":"\(sceneName)"}}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        // Extract source names
        let sourcePattern = #"\"sourceName\":\"([^\"]+)\""#
        guard let regex = try? NSRegularExpression(pattern: sourcePattern) else {
            logError("Failed to create regex for source extraction")
            return
        }

        let matches = regex.matches(in: listResult.output, range: NSRange(listResult.output.startIndex..., in: listResult.output))
        let sourceNames = matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: listResult.output) else { return nil }
            return String(listResult.output[range])
        }

        logInfo("Found \(sourceNames.count) sources to configure for ISO recording")

        var successCount = 0
        for sourceName in sourceNames {
            if addSourceRecordFilter(to: sourceName, recordPath: recordPath) {
                successCount += 1
            }
        }

        logInfo("============================================")
        if successCount == sourceNames.count {
            logSuccess("ISO RECORDING FULLY CONFIGURED")
            logSuccess("  \(successCount)/\(sourceNames.count) sources will record separately")
        } else if successCount > 0 {
            logWarning("ISO RECORDING PARTIALLY CONFIGURED")
            logWarning("  \(successCount)/\(sourceNames.count) sources configured")
        } else {
            logError("ISO RECORDING FAILED")
            logError("  No sources configured - check Source Record plugin installation")
        }
        logInfo("Output files will be saved to: \(recordPath)")
        logInfo("============================================")
    }

    /// Add a Source Record filter to an input source
    /// Returns true if filter was added successfully
    @discardableResult
    private func addSourceRecordFilter(to sourceName: String, recordPath: String) -> Bool {
        logInfo("Adding Source Record filter to '\(sourceName)'...")

        // Create a safe filename from the source name (without extension - Source Record adds it)
        let safeFilename = sourceName.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")

        // Check if filter already exists
        let checkResult = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"GetSourceFilterList","requestId":"getfilters1","requestData":{"sourceName":"\(sourceName)"}}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        let filterName = "ISO_Record"

        // Source Record plugin settings (from source-record.c):
        // - record_mode: 3 = OUTPUT_MODE_RECORDING (record when OBS is recording)
        // - path: directory path (not full file path!)
        // - filename_formatting: the filename template (e.g., "Screen_1")
        // - rec_format: container format (e.g., "mov")
        let filterSettings = [
            "record_mode": 3,  // OUTPUT_MODE_RECORDING - sync with OBS recording
            "path": recordPath,  // Directory only, not full path
            "filename_formatting": safeFilename,  // Filename without extension
            "rec_format": "mov"  // Container format
        ] as [String: Any]

        // Convert to JSON string for the WebSocket message
        let settingsJSON = "{\"record_mode\":3,\"path\":\"\(recordPath)\",\"filename_formatting\":\"\(safeFilename)\",\"rec_format\":\"mov\"}"

        if checkResult.output.contains("\"\(filterName)\"") {
            logInfo("Source Record filter already exists on '\(sourceName)', updating settings...")
            // Update the filter settings with new path and correct recording mode
            let updateResult = runShellCommand("""
                {
                    sleep 0.3
                    echo '{"op":1,"d":{"rpcVersion":1}}'
                    sleep 0.3
                    echo '{"op":6,"d":{"requestType":"SetSourceFilterSettings","requestId":"setfilter1","requestData":{"sourceName":"\(sourceName)","filterName":"\(filterName)","filterSettings":\(settingsJSON)}}}'
                    sleep 0.5
                } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
            """, timeout: 10)

            if updateResult.output.contains("\"code\":100") || updateResult.output.contains("\"result\":true") {
                logSuccess("✓ Updated Source Record for '\(sourceName)' → \(safeFilename).mov (record_mode=3)")
                return true
            }
            logWarning("Update response: \(String(updateResult.output.prefix(300)))")
            return false  // Update failed
        }

        // Add the Source Record filter with correct settings
        // Note: source_record_filter requires the Source Record plugin to be installed
        let result = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"CreateSourceFilter","requestId":"createfilter1","requestData":{"sourceName":"\(sourceName)","filterName":"\(filterName)","filterKind":"source_record_filter","filterSettings":\(settingsJSON)}}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        logInfo("CreateSourceFilter response: \(String(result.output.prefix(400)))")

        if result.output.contains("\"code\":100") || result.output.contains("\"result\":true") {
            logSuccess("✓ Added Source Record filter to '\(sourceName)' → \(safeFilename).mov")
            return true
        } else if result.output.contains("filter kind") || result.output.contains("not found") || result.output.contains("600") {
            logError("!!! SOURCE RECORD PLUGIN NOT INSTALLED OR NOT LOADED !!!")
            logError("The 'source_record_filter' filter kind was not recognized by OBS")
            logError("")
            logError("TO FIX THIS:")
            logError("  1. Open OBS")
            logError("  2. Go to Tools > Scripts > Get More Scripts")
            logError("  3. Search for 'Source Record'")
            logError("  4. Click Install")
            logError("  5. RESTART OBS completely")
            logError("  6. Try recording again")
            logError("")
            logError("See CORE_DEPENDENCIES.md for detailed instructions")
            return false
        } else {
            logWarning("Failed to add Source Record filter to '\(sourceName)'")
            logWarning("Response: \(String(result.output.prefix(200)))")
            return false
        }
    }

    /// Remove Source Record filters from sources (to stop ISO recording)
    func disableISORecording(sceneName: String) {
        logInfo("Disabling ISO recording for scene: \(sceneName)")

        // Get list of sources
        let listResult = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"GetSceneItemList","requestId":"itemlist1","requestData":{"sceneName":"\(sceneName)"}}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        let sourcePattern = #"\"sourceName\":\"([^\"]+)\""#
        guard let regex = try? NSRegularExpression(pattern: sourcePattern) else { return }

        let matches = regex.matches(in: listResult.output, range: NSRange(listResult.output.startIndex..., in: listResult.output))
        for match in matches {
            guard let range = Range(match.range(at: 1), in: listResult.output) else { continue }
            let sourceName = String(listResult.output[range])

            // Remove the filter
            let _ = runShellCommand("""
                {
                    sleep 0.3
                    echo '{"op":1,"d":{"rpcVersion":1}}'
                    sleep 0.3
                    echo '{"op":6,"d":{"requestType":"RemoveSourceFilter","requestId":"removefilter1","requestData":{"sourceName":"\(sourceName)","filterName":"ISO_Record"}}}'
                    sleep 0.3
                } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
            """, timeout: 10)
        }

        logSuccess("ISO recording disabled")
    }
}
