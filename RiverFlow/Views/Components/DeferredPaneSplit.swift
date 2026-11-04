import SwiftUI

extension PaneArrangement {
    var minimumSize: CGSize {
        switch self {
        case .pane:
            return CGSize(width: 230, height: 155)
        case .split(let vertical, let first, let second):
            let a = first.minimumSize
            let b = second.minimumSize
            return vertical
                ? CGSize(width: max(a.width, b.width), height: a.height + b.height + 1)
                : CGSize(width: a.width + b.width + 1, height: max(a.height, b.height))
        }
    }
}

/// The divider owns the transient drag state. Pane sizes change only on commit.
struct DeferredPaneSplit: View {
    let vertical: Bool
    let firstMinimum: CGFloat
    let secondMinimum: CGFloat
    let first: AnyView
    let second: AnyView

    @State private var fraction: CGFloat = 0.5

    var body: some View {
        GeometryReader { geometry in
            let length = max(0, (vertical ? geometry.size.height : geometry.size.width) - 1)
            let minimum = min(firstMinimum, length)
            let maximum = max(minimum, length - secondMinimum)
            let position = min(max(length * fraction, minimum), maximum)
            let layout = vertical ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))

            layout {
                first.frame(width: vertical ? geometry.size.width : position,
                            height: vertical ? position : geometry.size.height)
                    .clipped()
                Rectangle().fill(.separator)
                    .frame(width: vertical ? geometry.size.width : 1,
                           height: vertical ? 1 : geometry.size.height)
                second.frame(width: vertical ? geometry.size.width : length - position,
                             height: vertical ? length - position : geometry.size.height)
                    .clipped()
            }
            .overlay(alignment: .topLeading) {
                PaneDividerGuide(vertical: vertical, position: position, limits: minimum...maximum) { newPosition in
                    if length > 0 { fraction = newPosition / length }
                }
                .frame(width: vertical ? geometry.size.width : 9,
                       height: vertical ? 9 : geometry.size.height)
                .offset(x: vertical ? 0 : position - 4, y: vertical ? position - 4 : 0)
            }
        }
    }
}

private struct PaneDividerGuide: View {
    let vertical: Bool
    let position: CGFloat
    let limits: ClosedRange<CGFloat>
    let onCommit: (CGFloat) -> Void

    @GestureState private var translation: CGFloat? = nil
    @State private var isHovering = false

    private func clampedPosition(_ delta: CGFloat) -> CGFloat {
        min(max(position + delta, limits.lowerBound), limits.upperBound)
    }

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .overlay {
                if isHovering || translation != nil {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: vertical ? nil : 2, height: vertical ? 2 : nil)
                        .offset(x: vertical ? 0 : clampedPosition(translation ?? 0) - position,
                                y: vertical ? clampedPosition(translation ?? 0) - position : 0)
                        .allowsHitTesting(false)
                }
            }
            .onHover { isHovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($translation) { value, state, _ in
                        state = vertical ? value.translation.height : value.translation.width
                    }
                    .onEnded { value in
                        onCommit(clampedPosition(vertical ? value.translation.height : value.translation.width))
                    }
            )
            .accessibilityLabel(vertical ? "Resize stacked panes" : "Resize side-by-side panes")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onCommit(clampedPosition(24))
                case .decrement: onCommit(clampedPosition(-24))
                @unknown default: break
                }
            }
    }
}
