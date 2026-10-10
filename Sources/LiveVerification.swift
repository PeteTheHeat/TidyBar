import AppKit

// Opt-in integration harness. It changes only the bundled test fixtures' categories,
// restores the user's complete assignment map, and quits every fixture on completion.
final class LiveVerification {
    let model: AppModel
    var saved: [String: ItemCategory] = [:]
    var results: [String] = []
    var savedAutoHide = true
    var savedPaused = false
    var savedRevealed = false
    let fixtureBundles = ["com.peterargany.TidyBar.fixture.shown", "com.peterargany.TidyBar.fixture.hidden", "com.peterargany.TidyBar.fixture.never"]
    init(model: AppModel) { self.model = model }
    func record(_ name: String, _ success: Bool) { results.append("\(success ? "PASS" : "FAIL"): \(name)"); write() }
    func write() {
        let path = ProcessInfo.processInfo.environment["TIDYBAR_TEST_REPORT"] ?? "/tmp/tidybar-live-test.txt"
        try? results.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }
    func later(_ action: @escaping () -> Void) { DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: action) }
    func visible() -> Set<String> {
        let bounds = CGDisplayBounds(CGMainDisplayID())
        let items = MenuBarScanner.scan()
        results.append("DEBUG display=\(bounds) items=\(items.map { "\($0.id)=\($0.frame)" }.joined(separator: "; "))")
        return Set(items.filter { $0.frame.width > 0 && bounds.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }.map(\.bundleID))
    }
    func visibleSystemIDs() -> Set<Int> {
        let bounds = CGDisplayBounds(CGMainDisplayID())
        return Set(MenuBarScanner.scan().filter { bounds.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }.compactMap(\.systemID))
    }
    var testingSystemControls = false
    func run() {
        guard model.accessibility else { record("Accessibility is required for live verification", false); return }
        guard model.backendAvailable else { record("macOS 27 backend available", false); return }
        saved = model.assignments
        savedAutoHide = model.autoHide
        savedPaused = model.paused
        savedRevealed = model.revealed
        model.autoHide = false
        model.setPaused(true)
        for name in ["Shown", "Hidden", "Never"] {
            let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/\(name).app")
            LSRegisterURL(url as CFURL, true)
            NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, _ in }
        }
        later { self.baseline() }
    }
    func baseline() {
        let baseline = visible()
        record("Three real fixture icons are visible before hiding", fixtureBundles.allSatisfy(baseline.contains))
        guard fixtureBundles.allSatisfy(baseline.contains) else { cleanup(); return }
        testingSystemControls = visibleSystemIDs().isSuperset(of: [1, 6])
        model.assignments["app:" + fixtureBundles[0]] = .shown
        model.assignments["app:" + fixtureBundles[1]] = .hidden
        model.assignments["app:" + fixtureBundles[2]] = .alwaysHidden
        if testingSystemControls {
            model.assignments["system:6"] = .hidden
            model.assignments["system:1"] = .alwaysHidden
        }
        model.revealed = false
        model.setPaused(false)
        later { self.collapsed() }
    }
    func collapsed() {
        let bar = visible()
        record("Always Show remains visible", bar.contains(fixtureBundles[0]))
        record("Show on Demand disappears when collapsed", !bar.contains(fixtureBundles[1]))
        record("Always Hidden disappears when collapsed", !bar.contains(fixtureBundles[2]))
        record("Native assertion completed without error", !model.busy && !model.message.contains("failed"))
        if testingSystemControls {
            let system = visibleSystemIDs()
            record("Wi-Fi hides on demand; Bluetooth hides always", !system.contains(6) && !system.contains(1))
        }
        model.toggle()
        later { self.expanded() }
    }
    func expanded() {
        let bar = visible()
        record("Show on Demand returns on reveal", bar.contains(fixtureBundles[1]))
        record("Always Show stays visible on reveal", bar.contains(fixtureBundles[0]))
        record("Always Hidden remains hidden on reveal", !bar.contains(fixtureBundles[2]))
        if testingSystemControls {
            let system = visibleSystemIDs()
            record("Wi-Fi returns on reveal; Bluetooth remains hidden", system.contains(6) && !system.contains(1))
        }
        model.setPaused(true)
        later {
            let bar = self.visible()
            self.record("Pause restores all three real icons", self.fixtureBundles.allSatisfy(bar.contains))
            self.cleanup()
        }
    }
    func cleanup() {
        model.assignments = saved
        model.autoHide = savedAutoHide
        model.revealed = savedRevealed
        model.setPaused(savedPaused)
        model.scheduleRehide()
        for bundle in fixtureBundles { NSRunningApplication.runningApplications(withBundleIdentifier: bundle).forEach { $0.terminate() } }
        model.items.removeAll { fixtureBundles.contains($0.bundleID) }
        model.refresh()
        results.append("Verification finished; original categories restored.")
        write()
    }
}
