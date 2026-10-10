import AppKit
import SwiftUI
import ApplicationServices
import Carbon

final class AppModel: ObservableObject {
    @Published var items: [BarItem] = []
    @Published var assignments: [String: ItemCategory] = [:]
    @Published var revealed = false
    @Published var paused = false
    @Published var accessibility = AXIsProcessTrusted()
    @Published var screenRecording = CGPreflightScreenCaptureAccess()
    @Published var backendAvailable = pelmet_assessmentModeAvailable()
    @Published var message = "Ready"
    @Published var busy = false
    @Published var hotkeyAvailable = false
    @Published var autoHide = UserDefaults.standard.object(forKey: "autoHide") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoHide, forKey: "autoHide"); scheduleRehide() }
    }
    private var assertion: Any?
    private var assertionGeneration = 0
    private var timer: Timer?
    private var rehide: Timer?
    private var scanning = false
    private var applyAgain = false
    private var lastBundles: Set<String> = []
    private var lastPreview = Date.distantPast
    private var previews: [String: NSImage] = [:]
    private let previewMode: Bool
    var onToggle: (() -> Void)?
    let ownBundle = Bundle.main.bundleIdentifier ?? "com.peterargany.TidyBar"

    init(preview: Bool = false) {
        previewMode = preview
        if preview {
            accessibility = true
            screenRecording = false
            backendAvailable = true
            hotkeyAvailable = true
            message = "Your menu bar is tidy"
            return
        }
        if let data = UserDefaults.standard.data(forKey: "assignments.v1"), let decoded = try? JSONDecoder().decode([String: ItemCategory].self, from: data) { assignments = decoded }
        if let names = UserDefaults.standard.dictionary(forKey: "itemNames.v1") as? [String: String] {
            items = names.filter {
                ($0.key.hasPrefix("app:") || $0.key.hasPrefix("system:")) && !$0.key.hasPrefix("app:com.peterargany.TidyBar.fixture.")
            }.map { key, name in
                let sid = key.hasPrefix("system:") ? Int(key.dropFirst(7)) : nil
                let bundle = key.hasPrefix("app:") ? String(key.dropFirst(4)) : "com.apple.MenuBarAgent"
                let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first
                let icon = sid.flatMap { NSImage(systemSymbolName: MenuBarScanner.systemSymbols[$0], accessibilityDescription: name) } ?? running?.icon
                return BarItem(id: key, name: name, bundleID: bundle, systemID: sid, frame: .zero, available: running != nil, icon: icon)
            }.sorted { $0.name < $1.name }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
        refresh()
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.refresh(); self?.apply() }
    }

    func category(_ item: BarItem) -> ItemCategory { assignments[item.id] ?? .shown }
    func assign(_ item: BarItem, to category: ItemCategory) {
        guard item.manageable else { return }
        assignments[item.id] = category
        guard !previewMode else { return }
        if let data = try? JSONEncoder().encode(assignments) { UserDefaults.standard.set(data, forKey: "assignments.v1") }
        apply()
    }
    func refresh() {
        guard !previewMode else { return }
        let trusted = AXIsProcessTrusted()
        let justGranted = trusted && !accessibility
        if !trusted && accessibility {
            restore()
            revealed = false
            message = "Accessibility was revoked — menu bar restored"
        }
        accessibility = trusted
        screenRecording = CGPreflightScreenCaptureAccess()
        backendAvailable = pelmet_assessmentModeAvailable()
        let bundles = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let changed = bundles != lastBundles
        let addedBundles = bundles.subtracting(lastBundles)
        let newlyLaunched = !lastBundles.isEmpty && NSWorkspace.shared.runningApplications.contains {
            $0.activationPolicy != .prohibited && $0.bundleIdentifier.map(addedBundles.contains) == true
        }
        lastBundles = bundles
        if newlyLaunched && assertion != nil {
            // macOS 27 can park fresh registrations while ANY assertion is held.
            // Give the new app an adoption window, then reapply the saved rules.
            restore()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.apply() }
        } else if changed || justGranted { apply() }
        guard trusted, !scanning else { return }
        scanning = true
        DispatchQueue.global(qos: .utility).async {
            let found = MenuBarScanner.scan()
            DispatchQueue.main.async {
                self.scanning = false
                var byID = Dictionary(uniqueKeysWithValues: self.items.map { ($0.id, $0) })
                for key in byID.keys {
                    if var item = byID[key] {
                        item.available = item.systemID != nil || bundles.contains(item.bundleID)
                        byID[key] = item
                    }
                }
                for var item in found {
                    if let preview = self.previews[item.id] { item.icon = preview }
                    byID[item.id] = item
                }
                let previousOrder = self.items.map(\.id)
                let newIDs = found.map(\.id).filter { !previousOrder.contains($0) }
                self.items = (previousOrder + newIDs).compactMap { byID[$0] }
                UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: self.items.filter(\.manageable).map { ($0.id, $0.name) }), forKey: "itemNames.v1")
                if self.screenRecording && Date().timeIntervalSince(self.lastPreview) > 15 {
                    self.lastPreview = Date()
                    MenuBarPreviews.capture(items: found) { images in
                        self.previews.merge(images) { _, new in new }
                        self.items = self.items.map { item in
                            var result = item
                            if let image = self.previews[item.id] { result.icon = image }
                            return result
                        }
                    }
                }
            }
        }
    }
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacy("Privacy_Accessibility")
    }
    func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        openPrivacy("Privacy_ScreenCapture")
    }
    func openPrivacy(_ section: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(section)") { NSWorkspace.shared.open(url) }
    }
    func toggle() {
        guard accessibility, backendAvailable, !paused else { return }
        revealed.toggle()
        scheduleRehide()
        apply()
        onToggle?()
    }
    func scheduleRehide() {
        rehide?.invalidate()
        if revealed && autoHide {
            rehide = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.revealed = false; self.apply(); self.onToggle?()
            }
        }
    }
    func setPaused(_ value: Bool) {
        paused = value
        if value { restore(); message = "Hiding paused — all items are visible" }
        else { apply() }
    }
    func restore() {
        assertionGeneration += 1
        pelmet_invalidateAssertion(assertion)
        assertion = nil
    }
    func apply() {
        guard !previewMode else { return }
        if busy { applyAgain = true; return }
        guard accessibility else { message = "Grant Accessibility to manage your menu bar"; return }
        guard backendAvailable else { restore(); message = "Menu bar control is unavailable on this macOS build"; return }
        guard !paused else { return }
        let observedBundles = items.filter { $0.systemID == nil }.map(\.bundleID)
        let policy = VisibilityPolicy.make(assignments: assignments, runningBundles: NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier) + observedBundles, ownBundle: ownBundle, revealed: revealed)
        if CommandLine.arguments.contains("--verify-live") {
            try? "own=\(ownBundle)\nallowed=\(policy.bundles.joined(separator: ","))\n".write(toFile: "/tmp/tidybar-policy.txt", atomically: true, encoding: .utf8)
        }
        let needsHiding = assignments.values.contains(.alwaysHidden) || (!revealed && assignments.values.contains(.hidden))
        if !needsHiding { restore(); message = revealed ? "On-demand items are showing" : "All configured items are showing"; return }
        guard let config = pelmet_makeConfiguration(policy.systemItems.map { NSNumber(value: $0) }, policy.bundles) else {
            restore(); message = "macOS could not create a menu bar configuration"; return
        }
        busy = true
        let generation = assertionGeneration
        var newAssertion: Any?
        newAssertion = pelmet_activateAssertion(config) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                if generation != self.assertionGeneration {
                    pelmet_invalidateAssertion(newAssertion)
                    if self.applyAgain { self.applyAgain = false; self.apply() }
                    return
                }
                if let error {
                    pelmet_invalidateAssertion(newAssertion)
                    self.restore()
                    self.message = "Menu bar access failed: \(error.localizedDescription)"
                } else if self.paused {
                    pelmet_invalidateAssertion(newAssertion)
                } else {
                    self.restore()
                    self.assertion = newAssertion
                    self.message = self.revealed ? "On-demand items are showing · always-hidden items stay hidden" : "Your menu bar is tidy"
                }
                if self.applyAgain { self.applyAgain = false; self.apply() }
            }
        }
        if newAssertion == nil { busy = false; message = "macOS did not activate menu bar control" }
        else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self, self.busy, generation == self.assertionGeneration else { return }
                pelmet_invalidateAssertion(newAssertion)
                self.busy = false
                self.restore()
                self.message = "Menu bar control timed out — all items restored. Try again."
            }
        }
    }
}

final class Hotkey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: () -> Void
    var registered = false
    private var localMonitor: Any?
    private var globalMonitor: Any?
    init(action: @escaping () -> Void) {
        self.action = action
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, context -> OSStatus in
            guard let context else { return noErr }
            let hotkey = Unmanaged<Hotkey>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { hotkey.action() }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let id = EventHotKeyID(signature: 0x54494459, id: 1)
        let registration = RegisterEventHotKey(UInt32(kVK_ANSI_B), UInt32(optionKey | cmdKey), id, GetApplicationEventTarget(), 0, &ref)
        registered = installed == noErr && registration == noErr
        if CommandLine.arguments.contains("--verify-live") {
            try? "handler=\(installed) registration=\(registration)\n".write(toFile: "/tmp/tidybar-hotkey.txt", atomically: true, encoding: .utf8)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if Self.matches(event) { self?.action(); return nil }
            return event
        }
        // Carbon normally consumes the shortcut before it becomes an NSEvent.
        // This fallback also handles events delivered directly to another app.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if Self.matches(event) { self?.action() }
        }
    }
    private static func matches(_ event: NSEvent) -> Bool {
        event.keyCode == UInt16(kVK_ANSI_B) && event.modifierFlags.intersection([.command, .option, .control, .shift]) == [.command, .option]
    }
    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
    }
}
