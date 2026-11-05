import SwiftUI

enum TabDropZone: Equatable {
    case center, left, right, top, bottom

    init(point: CGPoint, size: CGSize, headerHeight: CGFloat) {
        if point.y < headerHeight {
            self = .center
            return
        }
        let horizontalInset = min(48, size.width * 0.23)
        let verticalInset = min(48, (size.height - headerHeight) * 0.23)
        if point.y - headerHeight < verticalInset {
            self = .top
        } else if size.height - point.y < verticalInset {
            self = .bottom
        } else if point.x < horizontalInset {
            self = .left
        } else if size.width - point.x < horizontalInset {
            self = .right
        } else {
            self = .center
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
                .overlay {
                    Label(split == nil ? "Move Tab" : "New Split", systemImage: "rectangle.on.rectangle")
                        .font(.callout.weight(.semibold))
                        .padding(6)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
                }
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
            guard dragging || hypot(location.x - start.x, location.y - start.y) >= 6 else { return }
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

    var title: String?
    var position: CGPoint = .zero
    var preview: Preview?
}

struct BrowserTabDragOverlay: View {
    let drag: BrowserTabDragState

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let preview = drag.preview {
                BrowserTabDropPreview(zone: preview.zone)
                    .frame(width: preview.frame.width, height: preview.frame.height)
                    .offset(x: preview.frame.minX, y: preview.frame.minY)
            }
            BrowserDraggedTab(drag: drag)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct BrowserDraggedTab: View {
    let drag: BrowserTabDragState

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
                .offset(x: drag.position.x + 12, y: drag.position.y + 12)
        }
    }
}
