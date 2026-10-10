import AppKit
import SwiftUI

func recordDrag(_ entry: String) {
    guard CommandLine.arguments.contains("--verify-drag"), let data = (entry + "\n").data(using: .utf8) else { return }
    let url = URL(fileURLWithPath: "/tmp/tidybar-drag.txt")
    if let file = try? FileHandle(forWritingTo: url) {
        _ = try? file.seekToEnd()
        try? file.write(contentsOf: data)
        try? file.close()
    } else { try? data.write(to: url) }
}

// AppKit owns the mouse sequence so clicking and dragging never compete with
// SwiftUI's popover gesture recognizer on macOS.
struct NativeDragHandle: NSViewRepresentable {
    var identifier: String
    var icon: NSImage?
    var onClick: () -> Void
    func makeNSView(context: Context) -> DragHandleView { DragHandleView() }
    func updateNSView(_ view: DragHandleView, context: Context) {
        view.itemIdentifier = identifier
        view.icon = icon
        view.onClick = onClick
    }
}

final class DragHandleView: NSView, NSDraggingSource {
    var itemIdentifier = ""
    var icon: NSImage?
    var onClick: (() -> Void)?
    private var downPoint = NSPoint.zero
    private var dragged = false
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        recordDrag("down \(itemIdentifier)")
        downPoint = event.locationInWindow
        dragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        recordDrag("drag \(itemIdentifier)")
        guard !dragged, hypot(event.locationInWindow.x - downPoint.x, event.locationInWindow.y - downPoint.y) > 3 else { return }
        dragged = true
        let item = NSDraggingItem(pasteboardWriter: itemIdentifier as NSString)
        let image = icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!
        let point = convert(event.locationInWindow, from: nil)
        item.setDraggingFrame(NSRect(x: point.x - 16, y: point.y - 16, width: 32, height: 32), contents: image)
        let session = beginDraggingSession(with: [item], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }
    override func mouseUp(with event: NSEvent) {
        if !dragged { onClick?() }
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { [.copy, .move] }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        recordDrag("ended \(screenPoint) operation=\(operation.rawValue)")
    }
}
