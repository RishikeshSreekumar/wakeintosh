import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let defaults = UserDefaults.standard

    private var caffeinate: Process?
    private var endDate: Date?          // nil while active = indefinitely
    private var activeMinutes: Int?     // which duration item to check
    private var ticker: Timer?

    // App icon in the menu bar: full colour when awake, grayscale and dimmed when off.
    private lazy var onIcon = menuBarIcon(grayscale: false)
    private lazy var offIcon = menuBarIcon(grayscale: true)

    private func menuBarIcon(grayscale: Bool) -> NSImage {
        let source = NSApp.applicationIconImage!
        var cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
        if grayscale, let cg = cgImage {
            let ci = CIImage(cgImage: cg).applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            cgImage = CIContext().createCGImage(ci, from: ci.extent)
        }
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            guard let cg = cgImage, let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setAlpha(grayscale ? 0.55 : 1)
            ctx.interpolationQuality = .high
            ctx.draw(cg, in: rect)
            return true
        }
        image.accessibilityDescription = grayscale ? "Wakeintosh off" : "Wakeintosh awake"
        return image
    }

    private let presets: [(String, Int?)] = [
        ("Indefinitely", nil),
        ("15 Minutes", 15),
        ("30 Minutes", 30),
        ("1 Hour", 60),
        ("2 Hours", 120),
        ("4 Hours", 240),
        ("8 Hours", 480),
    ]

    private var isAwake: Bool { caffeinate?.isRunning ?? false }

    private var allowDisplaySleep: Bool {
        get { defaults.bool(forKey: "allowDisplaySleep") }
        set { defaults.set(newValue, forKey: "allowDisplaySleep") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        menu.delegate = self
        statusItem.menu = menu

        // Register as a login item on first launch; user can turn it off from the menu.
        if !defaults.bool(forKey: "didSetUpLoginItem") {
            try? SMAppService.mainApp.register()
            defaults.set(true, forKey: "didSetUpLoginItem")
        }
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stop()
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let status = NSMenuItem(title: statusText(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if isAwake {
            menu.addItem(item("Turn Off", #selector(turnOff)))
        }
        menu.addItem(.separator())

        let header = NSMenuItem(title: "Keep Awake For", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for (title, minutes) in presets {
            let mi = item(title, #selector(startPreset(_:)))
            mi.representedObject = minutes
            mi.indentationLevel = 1
            mi.state = isAwake && activeMinutes == minutes && !isCustom ? .on : .off
            menu.addItem(mi)
        }
        let custom = item("Custom…", #selector(startCustom))
        custom.indentationLevel = 1
        custom.state = isAwake && isCustom ? .on : .off
        menu.addItem(custom)

        menu.addItem(.separator())
        let display = item("Allow Display to Sleep", #selector(toggleDisplaySleep))
        display.state = allowDisplaySleep ? .on : .off
        menu.addItem(display)
        let login = item("Open at Login", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Wakeintosh", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: "")
        mi.target = self
        return mi
    }

    private var isCustom: Bool {
        guard let m = activeMinutes else { return false }
        return !presets.contains { $0.1 == m }
    }

    // MARK: - Actions

    @objc private func startPreset(_ sender: NSMenuItem) {
        start(minutes: sender.representedObject as? Int)
    }

    @objc private func startCustom() {
        let alert = NSAlert()
        alert.messageText = "Keep Mac awake for how long?"
        alert.informativeText = "Enter minutes."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = String(defaults.integer(forKey: "customMinutes").nonZero ?? 90)
        alert.accessoryView = field
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn,
              let minutes = Int(field.stringValue.trimmingCharacters(in: .whitespaces)), minutes > 0
        else { return }
        defaults.set(minutes, forKey: "customMinutes")
        start(minutes: minutes)
    }

    @objc private func turnOff() {
        stop()
        refresh()
    }

    @objc private func toggleDisplaySleep() {
        allowDisplaySleep.toggle()
        // Restart with the same remaining time so the new flags apply.
        if isAwake {
            let remaining = endDate.map { max(1, Int($0.timeIntervalSinceNow)) }
            let minutes = activeMinutes
            launch(seconds: remaining)
            activeMinutes = minutes
        }
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        if service.status == .enabled {
            try? service.unregister()
        } else {
            try? service.register()
        }
    }

    // MARK: - caffeinate

    private func start(minutes: Int?) {
        launch(seconds: minutes.map { $0 * 60 })
        activeMinutes = minutes
    }

    private func launch(seconds: Int?) {
        stop()
        var args = [allowDisplaySleep ? "-imsu" : "-dimsu"]
        // -w ties caffeinate to this app, so it exits even if the app crashes.
        args += ["-w", String(ProcessInfo.processInfo.processIdentifier)]
        if let seconds { args += ["-t", String(seconds)] }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        p.arguments = args
        p.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                guard let self, self.caffeinate === proc else { return }
                self.stop()
                self.refresh()
            }
        }
        do { try p.run() } catch { return }
        caffeinate = p
        endDate = seconds.map { Date().addingTimeInterval(TimeInterval($0)) }
        if endDate != nil {
            ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
            RunLoop.main.add(ticker!, forMode: .common)
        }
        refresh()
    }

    private func stop() {
        ticker?.invalidate()
        ticker = nil
        let p = caffeinate
        caffeinate = nil
        p?.terminate()
        endDate = nil
        activeMinutes = nil
    }

    // MARK: - UI

    private func refresh() {
        let awake = isAwake
        statusItem.button?.image = awake ? onIcon : offIcon
        statusItem.button?.title = awake ? (remainingText().map { " " + $0 } ?? "") : ""
        statusItem.button?.toolTip = "Wakeintosh: " + statusText()
    }

    private func remainingText() -> String? {
        guard let endDate else { return nil }
        let s = max(0, Int(endDate.timeIntervalSinceNow.rounded()))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    private func statusText() -> String {
        guard isAwake else { return "Off — Mac can sleep normally" }
        if let endDate, let left = remainingText() {
            let f = DateFormatter()
            f.timeStyle = .short
            return "Awake — \(left) left (until \(f.string(from: endDate)))"
        }
        return "Awake — indefinitely"
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
