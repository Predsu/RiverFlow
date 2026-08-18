import SwiftUI

/// AppKit-backed view wrapper that intercepts right-click mouse events.
///
/// This `NSViewRepresentable` bridges SwiftUI and AppKit to detect right-click events on views that would otherwise not respond to them. When a right-click occurs within the view's bounds, the `onRightClick` closure is invoked.
///
/// Use this as an overlay on views where you need to capture right-click context menu triggers.
///
/// Example:
/// ```swift
/// VStack {
///     Text("Right-click me")
/// }
/// .overlay(RightClickCatcher(onRightClick: {
///     print("Right-clicked!")
///     showContextMenu = true
/// }))
/// ```
struct RightClickCatcher: NSViewRepresentable {
    let onRightClick: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = CatcherView()
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? CatcherView)?.onRightClick = onRightClick
    }

    private class CatcherView: NSView {
        var onRightClick: (() -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            if let event = NSApp.currentEvent,
               event.type == .rightMouseDown || event.type == .rightMouseUp {
                return self
            }
            return nil
        }

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?()
            super.rightMouseDown(with: event)
        }
    }
}
