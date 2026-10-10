import AppKit
import ScreenCaptureKit

enum MenuBarPreviews {
    static func capture(items: [BarItem], completion: @escaping ([String: NSImage]) -> Void) {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) else { return }
                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                let config = SCStreamConfiguration()
                config.sourceRect = CGRect(x: 0, y: 0, width: display.width, height: 38)
                config.width = display.width * 2
                config.height = 76
                config.showsCursor = false
                let capture = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                let scale = CGFloat(capture.width) / CGFloat(display.width)
                var images: [String: NSImage] = [:]
                for item in items where item.frame.minY >= 0 && item.frame.maxY <= 38 && item.frame.minX >= 0 && item.frame.maxX <= CGFloat(display.width) && item.frame.width > 0 {
                    let rect = CGRect(x: item.frame.minX * scale, y: item.frame.minY * scale, width: item.frame.width * scale, height: item.frame.height * scale)
                    if let image = capture.cropping(to: rect) { images[item.id] = NSImage(cgImage: image, size: item.frame.size) }
                }
                DispatchQueue.main.async { completion(images) }
            } catch {
                // Optional previews must never interrupt visibility controls.
            }
        }
    }
}
