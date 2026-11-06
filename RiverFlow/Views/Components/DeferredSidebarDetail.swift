import AppKit
import SwiftUI

/// Freeze the file browser during a manual divider drag. The browser follows
/// the native column size during Show/Hide and window resizing.
struct DeferredSidebarDetail<Content: View>: View {
    let content: Content
    @State private var sizing = SidebarDetailSizing()

    var body: some View {
        content
            .frame(width: sizing.frozenWidth)
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipped()
            .background(alignment: .topLeading) { SidebarWindowProbe(sizing: sizing) }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                sizing.propose(width)
            }
    }
}

@MainActor
@Observable
private final class SidebarDetailSizing {
    private(set) var frozenWidth: CGFloat?
    @ObservationIgnored weak var window: NSWindow?
    @ObservationIgnored private var latestWidth: CGFloat?
    @ObservationIgnored private var releaseTask: Task<Void, Never>?

    func propose(_ width: CGFloat) {
        guard width > 0 else { return }
        let previousWidth = latestWidth
        latestWidth = width

        guard let previousWidth, window?.inLiveResize != true, Self.isMouseDown else {
            resumeLayout()
            return
        }

        // A stationary divider is still being dragged until the mouse comes up.
        guard releaseTask == nil else { return }
        frozenWidth = previousWidth
        releaseTask = Task { [weak self] in
            while Self.isMouseDown, self != nil {
                do { try await Task.sleep(for: .milliseconds(16)) }
                catch { return }
            }
            self?.resumeLayout()
        }
    }

    private static var isMouseDown: Bool {
        NSEvent.pressedMouseButtons & 1 != 0
    }

    private func resumeLayout() {
        guard let releaseTask else { return }
        releaseTask.cancel()
        self.releaseTask = nil
        frozenWidth = nil
    }
}

private struct SidebarWindowProbe: NSViewRepresentable {
    let sizing: SidebarDetailSizing

    func makeNSView(context: Context) -> WindowView {
        let view = WindowView()
        view.sizing = sizing
        return view
    }

    func updateNSView(_ view: WindowView, context: Context) {}

    final class WindowView: NSView {
        weak var sizing: SidebarDetailSizing?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            sizing?.window = window
        }
    }
}
