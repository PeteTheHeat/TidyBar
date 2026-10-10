import AppKit
import SwiftUI

if CommandLine.arguments.contains("--self-test") {
    let failures = policyTests()
    print(failures.isEmpty ? "PASS: collapsed/revealed categories, always-hidden isolation, new apps, own control, persistence" : failures.joined(separator: "\n"))
    exit(failures.isEmpty ? 0 : 1)
}
if CommandLine.arguments.contains("--probe") {
    print(pelmet_describeAssessmentClasses())
    exit(pelmet_assessmentModeAvailable() ? 0 : 1)
}
if let index = CommandLine.arguments.firstIndex(of: "--export-screenshots") {
    guard CommandLine.arguments.indices.contains(index + 1) else {
        fputs("Usage: TidyBar --export-screenshots DIRECTORY\n", stderr)
        exit(1)
    }
    _ = NSApplication.shared
    do {
        try MainActor.assumeIsolated {
            try ScreenshotExporter.export(to: URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true))
        }
        exit(0)
    } catch {
        fputs("Screenshot export failed: \(error)\n", stderr)
        exit(1)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel!
    var status: NSStatusItem!
    var window: NSWindow!
    var hotkey: Hotkey!
    var verification: LiveVerification?

    func applicationDidFinishLaunching(_ notification: Notification) {
        LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
        model = AppModel()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.autosaveName = "TidyBar.Control"
        status.button?.image = NSImage(systemSymbolName: "line.3.horizontal.decrease", accessibilityDescription: "TidyBar")
        status.button?.toolTip = "TidyBar — click to show hidden items; right-click for settings"
        status.button?.target = self
        status.button?.action = #selector(statusClicked)
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        model.onToggle = { [weak self] in self?.updateIcon() }
        hotkey = Hotkey { [weak self] in self?.model.toggle() }
        model.hotkeyAvailable = hotkey.registered
        if !hotkey.registered { model.message = "⌥⌘B is in use by another app. Click the TidyBar icon to reveal items." }
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "TidyBar")
        applicationMenu.addItem(withTitle: "TidyBar Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "Quit TidyBar", action: #selector(quit), keyEquivalent: "q").target = self
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        for (title, selector, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: NSSelectorFromString(selector), keyEquivalent: key)
        }
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1030, height: 850), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "TidyBar Settings"
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        window.setFrameAutosaveName("TidyBar.Settings")
        window.contentMinSize = NSSize(width: 920, height: 850)
        if window.contentLayoutRect.height < 850 {
            window.setContentSize(NSSize(width: max(920, window.contentLayoutRect.width), height: 850))
        }
        if CommandLine.arguments.contains("--reset-window") { window.setContentSize(NSSize(width: 1030, height: 850)) }
        window.center()
        showSettings()
        if CommandLine.arguments.contains("--verify-live") {
            verification = LiveVerification(model: model)
            verification?.run()
        }
    }
    func updateIcon() {
        status.button?.image = NSImage(systemSymbolName: model.revealed ? "chevron.right" : "line.3.horizontal.decrease", accessibilityDescription: "TidyBar")
    }
    @objc func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "TidyBar Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
            menu.addItem(withTitle: model.revealed ? "Hide On-Demand Items" : "Show On-Demand Items", action: #selector(toggle), keyEquivalent: "").target = self
            menu.addItem(withTitle: model.paused ? "Resume Hiding" : "Pause Hiding (Show All)", action: #selector(pause), keyEquivalent: "").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit TidyBar", action: #selector(quit), keyEquivalent: "q").target = self
            status.menu = menu
            status.button?.performClick(nil)
            status.menu = nil
        } else if !model.accessibility || !model.backendAvailable { showSettings() }
        else { model.toggle(); updateIcon() }
    }
    @objc func toggle() { model.toggle(); updateIcon() }
    @objc func pause() { model.setPaused(!model.paused) }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationWillTerminate(_ notification: Notification) { model.restore() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
