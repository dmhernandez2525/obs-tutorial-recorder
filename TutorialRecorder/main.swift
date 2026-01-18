import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var isRecording = false
    var isPaused = false
    var currentProject: String?
    var scriptsPath: String = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Find scripts directory
        let bundle = Bundle.main
        if let resourcePath = bundle.resourcePath {
            scriptsPath = (resourcePath as NSString).deletingLastPathComponent + "/scripts"
        }
        if !FileManager.default.fileExists(atPath: scriptsPath + "/start-tutorial.sh") {
            // Try relative to executable
            let execPath = bundle.executablePath ?? ""
            let basePath = (execPath as NSString).deletingLastPathComponent
            scriptsPath = (basePath as NSString).appendingPathComponent("../scripts")

            if !FileManager.default.fileExists(atPath: scriptsPath + "/start-tutorial.sh") {
                // Default fallback
                scriptsPath = NSHomeDirectory() + "/Projects/obs-tutorial-recorder/scripts"
            }
        }

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        updateStatusIcon()
        setupMenu()

        // Check for existing recording session
        checkExistingSession()
    }

    func updateStatusIcon() {
        if let button = statusItem.button {
            if isRecording {
                if isPaused {
                    button.image = NSImage(systemSymbolName: "pause.circle.fill", accessibilityDescription: "Paused")
                    button.image?.isTemplate = false
                } else {
                    button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
                    button.image?.isTemplate = false
                    // Tint red for recording
                    if let image = button.image {
                        let config = NSImage.SymbolConfiguration(paletteColors: [.red])
                        button.image = image.withSymbolConfiguration(config)
                    }
                }
            } else {
                button.image = NSImage(systemSymbolName: "video.circle", accessibilityDescription: "Tutorial Recorder")
                button.image?.isTemplate = true
            }
        }
    }

    func setupMenu() {
        let menu = NSMenu()

        if isRecording {
            if let project = currentProject {
                let projectItem = NSMenuItem(title: "Recording: \(project)", action: nil, keyEquivalent: "")
                projectItem.isEnabled = false
                menu.addItem(projectItem)
            }

            menu.addItem(NSMenuItem.separator())

            let stopItem = NSMenuItem(title: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "s")
            stopItem.keyEquivalentModifierMask = [.command, .shift]
            menu.addItem(stopItem)

            menu.addItem(NSMenuItem.separator())

            let openItem = NSMenuItem(title: "Open Project Folder", action: #selector(openProjectFolder), keyEquivalent: "o")
            menu.addItem(openItem)
        } else {
            let startItem = NSMenuItem(title: "Start Recording...", action: #selector(startRecording), keyEquivalent: "r")
            startItem.keyEquivalentModifierMask = [.command, .shift]
            menu.addItem(startItem)
        }

        menu.addItem(NSMenuItem.separator())

        let obsItem = NSMenuItem(title: "Open OBS", action: #selector(openOBS), keyEquivalent: "")
        menu.addItem(obsItem)

        let folderItem = NSMenuItem(title: "Open Recordings Folder", action: #selector(openRecordingsFolder), keyEquivalent: "")
        menu.addItem(folderItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func checkExistingSession() {
        let sessionFile = "/tmp/obs-tutorial-session.txt"
        let activeFile = "/tmp/obs-recording-active.txt"

        if FileManager.default.fileExists(atPath: activeFile),
           let projectPath = try? String(contentsOfFile: sessionFile, encoding: .utf8) {
            isRecording = true
            currentProject = (projectPath.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).lastPathComponent
            updateStatusIcon()
            setupMenu()
        }
    }

    @objc func startRecording() {
        // Show project name dialog
        let alert = NSAlert()
        alert.messageText = "New Tutorial Recording"
        alert.informativeText = "Enter a name for this project:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Start Recording")
        alert.addButton(withTitle: "Cancel")

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.stringValue = "Untitled Tutorial"
        alert.accessoryView = inputField

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let projectName = inputField.stringValue.isEmpty ? "Untitled Tutorial" : inputField.stringValue

            // Run start script in background
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.runStartScript(projectName: projectName)
            }

            // Update UI immediately
            currentProject = projectName
            isRecording = true
            updateStatusIcon()
            setupMenu()

            // Show notification
            showNotification(title: "Recording Started", body: "Project: \(projectName)")
        }
    }

    func runStartScript(projectName: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", """
            export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
            cd "\(scriptsPath)/.."

            # Create project folder
            RECORDINGS_BASE="$HOME/Desktop/Tutorial Recordings"
            DATE_PREFIX=$(date +%Y-%m-%d)
            SAFE_NAME=$(echo "\(projectName)" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g')
            PROJECT_DIR="${RECORDINGS_BASE}/${DATE_PREFIX}_${SAFE_NAME}"

            mkdir -p "$RECORDINGS_BASE"
            mkdir -p "$PROJECT_DIR/raw"
            mkdir -p "$PROJECT_DIR/exports"

            # Create metadata
            cat > "$PROJECT_DIR/metadata.json" << EOF
            {
              "projectName": "\(projectName)",
              "dateCreated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
              "recordings": []
            }
            EOF

            # Save session info
            echo "$PROJECT_DIR" > /tmp/obs-tutorial-session.txt
            date +%s > /tmp/obs-tutorial-start-time.txt
            touch /tmp/obs-recording-active.txt

            # Start OBS if needed
            if ! pgrep -x "OBS" > /dev/null 2>&1; then
                open -a "OBS"
                sleep 5
            fi

            # Wait for WebSocket
            for i in {1..30}; do
                if echo '{"op":1,"d":{"rpcVersion":1}}' | timeout 2 websocat "ws://localhost:4455" 2>/dev/null | grep -q "obsStudioVersion"; then
                    break
                fi
                sleep 1
            done

            # Set recording directory
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"SetRecordDirectory","requestId":"dir1","requestData":{"recordDirectory":"'"$PROJECT_DIR/raw"'"}}}'
                sleep 0.3
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null

            # Start recording
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"StartRecord","requestId":"rec1"}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null
            """]

        try? process.run()
        process.waitUntilExit()
    }

    @objc func stopRecording() {
        // Update UI immediately
        isRecording = false
        updateStatusIcon()
        setupMenu()

        // Run stop script in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runStopScript()

            DispatchQueue.main.async {
                self?.showNotification(title: "Recording Stopped", body: "Files collected and organized")
                self?.openProjectFolder()
            }
        }
    }

    func runStopScript() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", """
            export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

            # Stop recording via WebSocket
            {
                sleep 0.3
                echo '{"op":1,"d":{"rpcVersion":1}}'
                sleep 0.3
                echo '{"op":6,"d":{"requestType":"StopRecord","requestId":"stop1"}}'
                sleep 0.5
            } | timeout 5 websocat "ws://localhost:4455" 2>/dev/null

            sleep 3

            # Get session info
            SESSION_FILE="/tmp/obs-tutorial-session.txt"
            START_TIME_FILE="/tmp/obs-tutorial-start-time.txt"

            if [ -f "$SESSION_FILE" ]; then
                PROJECT_DIR=$(cat "$SESSION_FILE")
                RAW_DIR="$PROJECT_DIR/raw"
                START_TIME=$(cat "$START_TIME_FILE" 2>/dev/null || echo $(($(date +%s) - 1800)))

                mkdir -p "$RAW_DIR"

                # Collect files from Movies
                find "$HOME/Movies" -maxdepth 1 -type f \\( -name "*.mkv" -o -name "*.mov" -o -name "*.mp4" \\) 2>/dev/null | while read file; do
                    FILE_MTIME=$(stat -f%m "$file" 2>/dev/null || echo "0")
                    if [ "$FILE_MTIME" -ge "$START_TIME" ]; then
                        mv "$file" "$RAW_DIR/" 2>/dev/null
                    fi
                done
            fi

            # Cleanup
            rm -f /tmp/obs-tutorial-session.txt /tmp/obs-tutorial-start-time.txt /tmp/obs-recording-active.txt
            """]

        try? process.run()
        process.waitUntilExit()
    }

    @objc func openProjectFolder() {
        let sessionFile = "/tmp/obs-tutorial-session.txt"
        if let projectPath = try? String(contentsOfFile: sessionFile, encoding: .utf8) {
            let path = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } else {
            // Open most recent project
            let recordingsPath = NSHomeDirectory() + "/Desktop/Tutorial Recordings"
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: recordingsPath) {
                let projects = contents.filter { $0.hasPrefix("20") }.sorted().reversed()
                if let latest = projects.first {
                    NSWorkspace.shared.open(URL(fileURLWithPath: recordingsPath + "/" + latest))
                    return
                }
            }
            NSWorkspace.shared.open(URL(fileURLWithPath: recordingsPath))
        }
    }

    @objc func openOBS() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/OBS.app"))
    }

    @objc func openRecordingsFolder() {
        let path = NSHomeDirectory() + "/Desktop/Tutorial Recordings"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc func quit() {
        if isRecording {
            let alert = NSAlert()
            alert.messageText = "Recording in Progress"
            alert.informativeText = "Stop recording before quitting?"
            alert.addButton(withTitle: "Stop and Quit")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                stopRecording()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    NSApp.terminate(nil)
                }
            }
        } else {
            NSApp.terminate(nil)
        }
    }

    func showNotification(title: String, body: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "display notification \"\(body)\" with title \"\(title)\" sound name \"Glass\""]
        try? process.run()
    }
}

// Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // Makes it a menubar-only app
app.run()
