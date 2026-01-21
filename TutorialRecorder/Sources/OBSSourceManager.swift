import Foundation
import Cocoa

// MARK: - OBS Source Manager

class OBSSourceManager {
    static let shared = OBSSourceManager()

    private init() {}

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

        // Create or get the default scene
        let sceneName = "Tutorial Recording"
        createScene(sceneName)
        Thread.sleep(forTimeInterval: 1.0)

        // Set as current scene
        setCurrentScene(sceneName)
        Thread.sleep(forTimeInterval: 1.0)

        // Clear all existing sources from the scene
        logInfo("Clearing existing sources from scene...")
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

            if removeResult.output.contains("\"status\":200") {
                logInfo("Removed scene item ID: \(itemId)")
            } else {
                logWarning("Failed to remove scene item ID: \(itemId)")
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

        let result = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"CreateInput","requestId":"input1","requestData":{"sceneName":"\(sceneName)","inputName":"\(sourceName)","inputKind":"screen_capture","inputSettings":{"display":\(displayParam),"show_cursor":true}}}}'
                sleep 1.0
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        if result.output.contains("\"status\":200") {
            logSuccess("Created display capture: \(sourceName)")
        } else if result.output.contains("already exists") {
            logInfo("Display capture already exists: \(sourceName)")
        } else {
            logWarning("Create display capture response: \(String(result.output.prefix(300)))")
        }
    }

    private func createVideoCapture(sourceName: String, deviceName: String, sceneName: String) {
        logInfo("Creating video capture: \(sourceName)")

        // macOS uses "av_capture_input" for cameras
        let result = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"CreateInput","requestId":"input1","requestData":{"sceneName":"\(sceneName)","inputName":"\(sourceName)","inputKind":"av_capture_input","inputSettings":{"device_name":"\(deviceName)"}}}}'
                sleep 1.0
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        if result.output.contains("\"status\":200") {
            logSuccess("Created video capture: \(sourceName)")
        } else if result.output.contains("already exists") {
            logInfo("Video capture already exists: \(sourceName)")
        } else {
            logWarning("Create video capture response: \(String(result.output.prefix(300)))")
        }
    }

    private func createAudioCapture(sourceName: String, deviceName: String, sceneName: String) {
        logInfo("Creating audio capture: \(sourceName)")

        // macOS uses "coreaudio_input_capture" for audio inputs
        let result = runShellCommand("""
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"CreateInput","requestId":"input1","requestData":{"sceneName":"\(sceneName)","inputName":"\(sourceName)","inputKind":"coreaudio_input_capture","inputSettings":{"device_id":"\(deviceName)"}}}}'
                sleep 1.0
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
        """, timeout: 10)

        if result.output.contains("\"status\":200") {
            logSuccess("Created audio capture: \(sourceName)")
        } else if result.output.contains("already exists") {
            logInfo("Audio capture already exists: \(sourceName)")
        } else {
            logWarning("Create audio capture response: \(String(result.output.prefix(300)))")
        }
    }

    // MARK: - Enable ISO Recording

    func enableISORecording(profileName: String) {
        logInfo("Configuring ISO recording for profile: \(profileName)")

        // Note: ISO recording configuration typically requires direct file manipulation
        // or specific OBS settings. This is a placeholder for that functionality.
        // In practice, you may need to modify the OBS profile configuration files directly.

        logWarning("ISO recording configuration needs to be set manually in OBS Settings > Output > Recording")
        logInfo("Set Recording Mode to 'Advanced' and enable 'Advanced Recording' for multiple tracks")
    }
}
