import AppKit
import SwiftUI

/// Renders the actual settings view with sample items, without scanning the Mac,
/// activating a hiding assertion, registering shortcuts, or changing saved rules.
enum ScreenshotExporter {
    @MainActor static func export(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = AppModel(preview: true)
        let samples: [(String, String, ItemCategory)] = [
            ("Wi-Fi", "wifi", .shown), ("Battery", "battery.100percent", .shown),
            ("Clock", "clock", .shown), ("Sound", "speaker.wave.2", .shown),
            ("Bluetooth", "wave.3.right", .hidden), ("Displays", "display", .hidden),
            ("Input Menu", "keyboard", .hidden), ("Sync", "arrow.triangle.2.circlepath", .alwaysHidden),
            ("Helper", "gearshape", .alwaysHidden)
        ]
        for (index, sample) in samples.enumerated() {
            let id = "demo:\(index)"
            model.items.append(BarItem(id: id, name: sample.0, bundleID: "example.demo", frame: .zero,
                                      icon: NSImage(systemSymbolName: sample.1, accessibilityDescription: sample.0)))
            model.assignments[id] = sample.2
        }
        for (name, scheme, selection) in [("settings-light", ColorScheme.light, 0), ("settings-dark", .dark, 0), ("permissions-light", .light, 1)] {
            NSApp.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            // ImageRenderer cannot rasterize AppKit text fields/scroll views.
            // Static containers preserve the view's layout and tile styling.
            let content = SettingsView(model: model, selection: selection, staticRendering: true)
                .frame(width: 1030, height: 850)
                .background(scheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.13) : Color.white)
                .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: content)
            renderer.proposedSize = ProposedViewSize(width: 1030, height: 850)
            renderer.scale = 2
            renderer.isOpaque = true
            guard let data = renderer.nsImage?.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data) else {
                throw NSError(domain: "TidyBar.Screenshots", code: 1)
            }
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "TidyBar.Screenshots", code: 2)
            }
            try png.write(to: directory.appendingPathComponent(name + ".png"))
            print("Rendered \(name).png")
        }
    }
}
