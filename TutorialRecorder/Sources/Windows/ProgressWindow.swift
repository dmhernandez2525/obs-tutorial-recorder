import Cocoa

// MARK: - Progress Window Controller

class ProgressWindowController {
    private var window: NSWindow?
    private var label: NSTextField?
    private var spinner: NSProgressIndicator?

    func show(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.createWindowIfNeeded()
            self?.label?.stringValue = message
            self?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func update(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.label?.stringValue = message
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.window?.close()
            self?.window = nil
            self?.label = nil
            self?.spinner = nil
        }
    }

    private func createWindowIfNeeded() {
        guard window == nil else { return }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Tutorial Recorder"
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .statusBar  // Highest level - above all windows including OBS
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let contentView = NSView(frame: newWindow.contentView!.bounds)

        let newSpinner = NSProgressIndicator(frame: NSRect(x: 20, y: 25, width: 32, height: 32))
        newSpinner.style = .spinning
        newSpinner.startAnimation(nil)
        contentView.addSubview(newSpinner)

        let newLabel = NSTextField(frame: NSRect(x: 60, y: 30, width: 220, height: 20))
        newLabel.isEditable = false
        newLabel.isBordered = false
        newLabel.backgroundColor = .clear
        newLabel.stringValue = ""
        contentView.addSubview(newLabel)

        newWindow.contentView = contentView

        window = newWindow
        label = newLabel
        spinner = newSpinner
    }
}
