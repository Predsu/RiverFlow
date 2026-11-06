import SwiftUI
import AppKit

/// Observes mouse-down before controls handle it, including right-clicks and text
/// fields. It never consumes events or competes with selection/drag gestures.
struct PaneActivationObserver: NSViewRepresentable {
    let onActivate: () -> Void

    func makeNSView(context: Context) -> ActivationView { ActivationView() }
    func updateNSView(_ nsView: ActivationView, context: Context) { nsView.onActivate = onActivate }

    final class ActivationView: NSView {
        var onActivate: (() -> Void)?
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self, event.window === self.window,
                      !self.isHiddenOrHasHiddenAncestor,
                      self.bounds.contains(self.convert(event.locationInWindow, from: nil)) else { return event }
                self.onActivate?()
                return event
            }
        }

        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}
