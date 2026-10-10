import AppKit
import ApplicationServices

struct BarItem: Identifiable {
    let id: String
    var name: String
    var bundleID: String
    var systemID: Int?
    var frame: CGRect
    var available = true
    var manageable = true
    var icon: NSImage?
}

enum MenuBarScanner {
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        AXUIElementCopyAttributeValue(element, name as CFString, &result)
        return result
    }
    static func children(_ element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let value = attribute(element, "AXFrame"), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        return AXValueGetValue(value as! AXValue, .cgRect, &rect) ? rect : nil
    }
    static let systemNames = ["Battery", "Bluetooth", "Clock", "Displays", "Input Menu", "Sound", "Wi-Fi", "Screen Mirroring", "Control Center"]
    static let systemSymbols = ["battery.100percent", "wave.3.right", "clock", "display", "keyboard", "speaker.wave.2", "wifi", "rectangle.on.rectangle", "switch.2"]
    static func systemID(_ identifier: String) -> Int? {
        let suffix = identifier.components(separatedBy: ".").last ?? ""
        return ["battery": 0, "bluetooth": 1, "clock": 2, "display": 3, "displays": 3, "textinput": 4, "keyboard": 4, "sound": 5, "wifi": 6, "screen-mirroring": 7, "controlcenter": 8][suffix]
    }
    static func scan() -> [BarItem] {
        guard AXIsProcessTrusted(), let agent = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first else { return [] }
        let root = AXUIElementCreateApplication(agent.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.3)
        var items: [String: BarItem] = [:]
        for window in children(root) where attribute(window, kAXRoleAttribute) as? String == "AXWindow" {
            for group in children(window) {
                guard let rect = frame(group) else { continue }
                let nodes = children(group)
                var candidate: BarItem?
                for node in nodes {
                    let role = attribute(node, kAXRoleAttribute) as? String ?? ""
                    if role == "AXGroup" {
                        for leaf in children(node) {
                            guard let identifier = attribute(leaf, kAXIdentifierAttribute) as? String else { continue }
                            if let sid = systemID(identifier) {
                                candidate = BarItem(id: "system:\(sid)", name: systemNames[sid], bundleID: "com.apple.MenuBarAgent", systemID: sid, frame: rect, icon: NSImage(systemSymbolName: systemSymbols[sid], accessibilityDescription: systemNames[sid]))
                            } else {
                                candidate = BarItem(id: identifier, name: (attribute(leaf, kAXDescriptionAttribute) as? String) ?? identifier, bundleID: "com.apple.MenuBarAgent", frame: rect, manageable: false)
                            }
                        }
                    } else {
                        var pid: pid_t = 0
                        AXUIElementGetPid(node, &pid)
                        guard pid != agent.processIdentifier, let app = NSRunningApplication(processIdentifier: pid), let bundle = app.bundleIdentifier else { continue }
                        if bundle == Bundle.main.bundleIdentifier { continue }
                        if bundle == "com.apple.TextInputMenuAgent" {
                            candidate = BarItem(id: "system:4", name: "Input Menu", bundleID: bundle, systemID: 4, frame: rect, icon: NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil))
                        } else {
                            let manageable = bundle != "com.apple.screencaptureui" && bundle != "com.apple.controlcenter"
                            candidate = BarItem(id: "app:" + bundle, name: app.localizedName ?? bundle, bundleID: bundle, frame: rect, manageable: manageable, icon: app.icon)
                        }
                    }
                }
                if let item = candidate {
                    let bounds = CGDisplayBounds(CGMainDisplayID())
                    if items[item.id] == nil || bounds.contains(CGPoint(x: rect.midX, y: rect.midY)) { items[item.id] = item }
                }
            }
        }
        return items.values.sorted { $0.frame.minX < $1.frame.minX }
    }
}
