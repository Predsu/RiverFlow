import SwiftUI
import Quartz

/// A local-file inspector using the same materials and metadata style as the browser.
struct FilePreviewPanel: View {
    let files: [FileItem]
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Hide Preview")
                .accessibilityLabel("Hide Preview")
            }
            .padding(12)
            .background(Material.ultraThin)

            Divider()

            if files.count == 1, let file = files.first {
                preview(for: file)
                Divider()
                metadata(for: file)
            } else {
                placeholder(
                    symbol: files.isEmpty ? "doc.text.magnifyingglass" : "doc.on.doc",
                    title: files.isEmpty ? "Select a file to preview" : "\(files.count) items selected",
                    message: "Select a single file to see its preview and details."
                )
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .accessibilityIdentifier("filePreviewPanel")
    }

    @ViewBuilder
    private func preview(for file: FileItem) -> some View {
        if file.itemType == .DIRECTORY {
            placeholder(symbol: "folder", title: "Folder selected", message: "Open this folder to explore its contents.")
        } else if !FileManager.default.isReadableFile(atPath: file.url.path) {
            placeholder(symbol: "doc.badge.ellipsis", title: "Preview unavailable", message: "This file may have moved or cannot be read.")
        } else {
            QuickLookFilePreview(file: file)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Preview of \(file.name)")
        }
    }

    private func metadata(for file: FileItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(file.name)
                .font(.headline)
                .lineLimit(3)
                .textSelection(.enabled)
                .help(file.name)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                metadataRow("Kind", value: kindDescription(for: file))
                if file.itemType != .DIRECTORY {
                    metadataRow("Size", value: file.formattedSize)
                }
                metadataRow("Modified", value: file.formattedDate)
            }
            Text(file.url.path)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(file.url.path)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private func metadataRow(_ title: String, value: String) -> some View {
        GridRow(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }

    private func kindDescription(for file: FileItem) -> String {
        if file.itemType == .DIRECTORY { return "Folder" }
        return file.fileExtensionIconText.isEmpty ? "File" : "\(file.fileExtensionIconText) file"
    }

    private func placeholder(symbol: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Quick Look generates previews asynchronously and provides its native fallback
/// for unsupported formats. Close each view explicitly when the panel disappears.
private struct QuickLookFilePreview: NSViewRepresentable {
    let file: FileItem

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .compact)!
        view.shouldCloseWithWindow = false
        view.autostarts = false
        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        if context.coordinator.url != file.url {
            view.previewItem = file.url as NSURL
        } else if context.coordinator.modificationDate != file.modificationDate || context.coordinator.size != file.size {
            view.refreshPreviewItem()
        }
        context.coordinator.url = file.url
        context.coordinator.modificationDate = file.modificationDate
        context.coordinator.size = file.size
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleNSView(_ view: QLPreviewView, coordinator: Coordinator) {
        view.close()
    }

    final class Coordinator {
        var url: URL?
        var modificationDate: Date?
        var size: Int64?
    }
}
