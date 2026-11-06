import SwiftUI

enum TabDropZone: Hashable {
    case center, left, right, top, bottom

    init(point: CGPoint, size: CGSize, headerHeight: CGFloat) {
        if point.y < headerHeight {
            self = .center
            return
        }
        let x = point.x / max(1, size.width)
        let y = (point.y - headerHeight) / max(1, size.height - headerHeight)
        let edges: [(zone: Self, distance: CGFloat)] = [
            (.left, x), (.right, 1 - x), (.top, y), (.bottom, 1 - y)
        ]
        if let nearest = edges.min(by: { $0.distance < $1.distance }), nearest.distance <= 0.30 {
            self = nearest.zone
        } else {
            self = .center
        }
    }

    var label: String {
        switch self {
        case .center: return "Move Tab"
        case .left: return "Split Left"
        case .right: return "Split Right"
        case .top: return "Split Above"
        case .bottom: return "Split Below"
        }
    }

    var split: TabSplit? {
        switch self {
        case .center: return nil
        case .left: return TabSplit(vertical: false, before: true)
        case .right: return TabSplit(vertical: false, before: false)
        case .top: return TabSplit(vertical: true, before: true)
        case .bottom: return TabSplit(vertical: true, before: false)
        }
    }

    var alignment: Alignment {
        switch self {
        case .center: return .center
        case .left: return .leading
        case .right: return .trailing
        case .top: return .top
        case .bottom: return .bottom
        }
    }
}

struct BrowserTabDropPreview: View {
    let zone: TabDropZone

    var body: some View {
        GeometryReader { geometry in
            let split = zone.split
            Rectangle()
                .fill(Color.accentColor.opacity(0.22))
                .overlay { Rectangle().strokeBorder(Color.accentColor, lineWidth: 2) }
                .frame(width: split?.vertical == false ? geometry.size.width / 2 : geometry.size.width,
                       height: split?.vertical == true ? geometry.size.height / 2 : geometry.size.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: zone.alignment)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Keeps horizontal scrolling and button tracking from taking over a tab drag.
struct BrowserTabPointerTarget: NSViewRepresentable {
    let origin: CGPoint
    let onClick: () -> Void
    let onDrag: (CGPoint, Bool) -> Void

    func makeNSView(context: Context) -> PointerView { PointerView() }

    func updateNSView(_ view: PointerView, context: Context) {
        view.origin = origin
        view.onClick = onClick
        view.onDrag = onDrag
    }

    final class PointerView: NSView {
        var origin = CGPoint.zero
        var onClick: (() -> Void)?
        var onDrag: ((CGPoint, Bool) -> Void)?
        private var start: CGPoint?
        private var dragging = false

        override var isFlipped: Bool { true }

        override func mouseDown(with event: NSEvent) {
            start = event.locationInWindow
            dragging = false
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start else { return }
            let location = event.locationInWindow
            guard dragging || hypot(location.x - start.x, location.y - start.y) >= 4 else { return }
            dragging = true
            onDrag?(workspacePoint(for: event), false)
        }

        override func mouseUp(with event: NSEvent) {
            defer {
                start = nil
                dragging = false
            }
            if dragging {
                onDrag?(workspacePoint(for: event), true)
            } else if start != nil, bounds.contains(convert(event.locationInWindow, from: nil)) {
                onClick?()
            }
        }

        private func workspacePoint(for event: NSEvent) -> CGPoint {
            let local = convert(event.locationInWindow, from: nil)
            return CGPoint(x: origin.x + local.x, y: origin.y + local.y)
        }
    }
}

/// Only the overlay observes pointer updates. Browser content and pane layout
/// stay out of the drag's per-event update path.
@Observable
final class BrowserTabDragState {
    struct Preview: Equatable {
        let frame: CGRect
        let zone: TabDropZone
    }

    struct Guide: Identifiable {
        let id: UUID
        let frame: CGRect
        let headerHeight: CGFloat
        let zones: [TabDropZone]
    }

    var guides: [Guide] = []
    var title: String?
    var position: CGPoint = .zero
    var preview: Preview?
}

struct BrowserTabDragOverlay: View {
    let drag: BrowserTabDragState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            // Measurements come from the workspace. The overlay can have a
            // different origin when the native window applies its safe area.
            let origin = geometry.frame(in: .named("browserWorkspaceTabs")).origin
            ZStack(alignment: .topLeading) {
                if let preview = drag.preview {
                    BrowserTabDropPreview(zone: preview.zone)
                        .frame(width: preview.frame.width, height: preview.frame.height)
                        .position(x: preview.frame.midX - origin.x, y: preview.frame.midY - origin.y)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: preview.zone)
                }
                ForEach(drag.guides) { guide in
                    ZStack {
                        ForEach(guide.zones, id: \.self) { zone in
                            Text(zone.label)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(.regularMaterial, in: Capsule())
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: zone.alignment)
                        }
                    }
                    .padding(8)
                    .padding(.top, guide.headerHeight)
                    .frame(width: guide.frame.width, height: guide.frame.height)
                    .position(x: guide.frame.midX - origin.x, y: guide.frame.midY - origin.y)
                }
                BrowserDraggedTab(drag: drag, origin: origin)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct BrowserDraggedTab: View {
    let drag: BrowserTabDragState
    let origin: CGPoint

    var body: some View {
        if let title = drag.title {
            Label(title, systemImage: "folder")
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 170)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.separator) }
                .shadow(color: .black.opacity(0.20), radius: 5, y: 2)
                .fixedSize()
                .position(x: drag.position.x - origin.x, y: drag.position.y - origin.y)
        }
    }
}
