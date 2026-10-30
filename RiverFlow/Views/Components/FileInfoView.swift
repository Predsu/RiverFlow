import SwiftUI

struct FileInfoView: View {
    let file: FileItem
    weak var window: NSWindow?

    private enum Tab: String, CaseIterable, Identifiable {
        case general = "General", details = "Details", permissions = "Permissions"
        var id: Self { self }
    }

    @State private var selection: Tab = .general
    @State private var metadata: FileInfoMetadata?
    @State private var folderSummary: FileInfoFolderSummary?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Information section", selection: $selection) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                            .padding(12)
                    } else if let metadata {
                        ForEach(sections(for: metadata)) { section in
                            sectionView(section)
                        }
                    } else {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Reading metadata…").foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 32)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(selection)
            .background(Color(NSColor.textBackgroundColor).opacity(0.35))

            Divider()
            HStack(spacing: 5) {
                Image(systemName: "clock")
                Text("State for: " + Date().formatted(date: .complete, time: .complete))
                Spacer()
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(minWidth: 360, idealWidth: 400, minHeight: 420, idealHeight: 640)
        .task(id: file.url) { await loadMetadata() }
        .onKeyPress(.escape) {
            window?.performClose(nil)
            return .handled
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            FileIconView(file: file, baseSize: 48)
            VStack(alignment: .leading, spacing: 5) {
                Text(file.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .help(file.name)
                Text(metadata?.kind ?? (file.itemType == .DIRECTORY ? "Folder" : "File"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sections(for metadata: FileInfoMetadata) -> [FileInfoSection] {
        switch selection {
        case .general:
            return metadata.general.map { section in
                guard section.title == "Storage", file.itemType == .DIRECTORY,
                      metadata.kind != "Symbolic link" else { return section }
                guard let summary = folderSummary else {
                    return .init(title: "Storage", symbol: "internaldrive", fields: [
                        .init(label: "Contents", value: "Calculating…")
                    ], note: "Includes hidden items and package contents. Symbolic links are not followed.")
                }
                return .init(title: "Storage", symbol: "internaldrive", fields: [
                    .init(label: "Contents size", value: FileInfoMetadata.formatBytes(summary.bytes)),
                    .init(label: "Exact size", value: "\(summary.bytes.formatted()) bytes"),
                    .init(label: "Allocated", value: FileInfoMetadata.formatBytes(summary.allocatedBytes)),
                    .init(label: "Files & links", value: summary.files.formatted()),
                    .init(label: "Folders", value: summary.folders.formatted())
                ], note: summary.unreadableItems > 0
                    ? "Partial totals: \(summary.unreadableItems.formatted()) items could not be read."
                    : "Includes hidden items and package contents. Links are not followed. Allocation is summed per entry; hard links and shared blocks may be counted more than once.")
            }
        case .details: return metadata.details
        case .permissions: return metadata.permissions
        }
    }

    private func sectionView(_ section: FileInfoSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(section.title, systemImage: section.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                ForEach(Array(section.fields.enumerated()), id: \.element.id) { index, field in
                    if index > 0 { Divider().padding(.leading, 12) }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(field.label)
                            .foregroundStyle(.secondary)
                            .frame(width: 92, alignment: .leading)
                        Text(field.value)
                            .font(.system(size: 12, design: field.monospaced ? .monospaced : .default))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            }

            if let note = section.note {
                Text(note)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
    }

    @MainActor
    private func loadMetadata() async {
        let url = file.url
        let read = Task.detached(priority: .userInitiated) { try FileInfoMetadata.read(at: url) }
        do {
            let snapshot = try await withTaskCancellationHandler {
                try await read.value
            } onCancel: { read.cancel() }
            guard !Task.isCancelled else { return }
            metadata = snapshot
            if file.itemType == .DIRECTORY, snapshot.kind != "Symbolic link" {
                let scan = Task.detached(priority: .utility) { FileInfoFolderSummary.read(at: url) }
                let summary = await withTaskCancellationHandler {
                    await scan.value
                } onCancel: { scan.cancel() }
                guard !Task.isCancelled else { return }
                folderSummary = summary
            }
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Metadata could not be read. \(error.localizedDescription)"
        }
    }
}
