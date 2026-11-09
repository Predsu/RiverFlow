import SwiftUI

struct PanePlacementOverlay: View {
    let folderName: String
    let onPlace: (Edge) -> Void

    @State private var hoveredEdge: Edge?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle().fill(.regularMaterial).opacity(0.85)
                if let edge = hoveredEdge {
                    highlight(edge, in: geometry.size)
                }
                VStack(spacing: 0) {
                    target(.top, title: "Above", symbol: "arrow.up")
                    HStack(spacing: 0) {
                        target(.leading, title: "Left", symbol: "arrow.left")
                        VStack(spacing: 3) {
                            Text("Place Pane").font(.headline)
                            Text(folderName).font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false)
                        target(.trailing, title: "Right", symbol: "arrow.right")
                    }
                    target(.bottom, title: "Below", symbol: "arrow.down")
                }
            }
            .overlay {
                Rectangle().strokeBorder(Color.accentColor.opacity(0.45))
                    .allowsHitTesting(false)
            }
        }
    }

    private func highlight(_ edge: Edge, in size: CGSize) -> some View {
        let vertical = edge == .top || edge == .bottom
        return Rectangle()
            .fill(Color.accentColor.opacity(0.22))
            .overlay { Rectangle().strokeBorder(Color.accentColor, lineWidth: 2) }
            .frame(width: vertical ? size.width : size.width / 2,
                   height: vertical ? size.height / 2 : size.height)
            .offset(x: vertical ? 0 : (edge == .leading ? -1 : 1) * size.width / 4,
                    y: vertical ? (edge == .top ? -1 : 1) * size.height / 4 : 0)
            .allowsHitTesting(false)
    }

    private func target(_ edge: Edge, title: String, symbol: String) -> some View {
        Button { onPlace(edge) } label: {
            Label(title, systemImage: symbol)
                .font(.callout.weight(.semibold))
                .padding(6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Place new pane \(title.lowercased()) of \(folderName)")
        .onHover { hovering in
            if hovering {
                hoveredEdge = edge
            } else if hoveredEdge == edge {
                hoveredEdge = nil
            }
        }
    }
}
