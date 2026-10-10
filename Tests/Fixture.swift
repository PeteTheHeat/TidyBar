import AppKit

final class FixtureDelegate: NSObject, NSApplicationDelegate {
    var item: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Fixture"
        item.button?.title = ["Shown": "①", "Hidden": "②", "Never": "③"][name] ?? "T"
        item.button?.setAccessibilityLabel("TidyBar Test \(name)")
        let menu = NSMenu()
        menu.addItem(withTitle: "TidyBar Test \(name)", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
    }
}
let app = NSApplication.shared
let delegate = FixtureDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
