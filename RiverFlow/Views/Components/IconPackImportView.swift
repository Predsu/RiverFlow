import SwiftUI
import UniformTypeIdentifiers

struct IconPackImportView: View {
    @ObservedObject var store: ImportedIconPackStore
    let onImported: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var prepared: PreparedIconPack?
    @State private var isReading = false
    @State private var errorMessage: String?
    @State private var readTask: Task<Void, Never>?
    @State private var showingChooser = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down").font(.title2).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Import an Icon Pack").font(.headline)
                    Text("Add icons from Material Icon Theme.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            if let prepared {
                preview(prepared)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    step("1", title: "Download the icons", detail: "Open the official download. Your browser saves a ZIP in Downloads; Safari may unzip it into a folder.") {
                        Link("Download Official ZIP", destination: IconPackImporter.downloadURL)
                    }
                    step("2", title: "Choose the download", detail: "Choose that ZIP or the extracted folder. Keep the whole folder together, including its LICENSE file.") {
                        Button("Choose ZIP or Folder…", action: chooseDownload).disabled(isReading)
                    }
                    step("3", title: "Preview, then import", detail: "Review the icons here, then click Import Pack. RiverFlow saves its own local copy, so you can move or delete the download afterward.") {
                        EmptyView()
                    }
                }
            }
            if isReading {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Reading icon pack…").font(.caption) }
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text("Imported artwork keeps its original licenses. No VS Code installation is needed.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack {
                if prepared != nil { Button("Choose Another…", action: chooseDownload).disabled(isReading) }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Import Pack", action: install).buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction).disabled(prepared == nil || isReading)
            }
        }
        .padding(20).frame(width: 440, height: 520)
        .fileImporter(isPresented: $showingChooser, allowedContentTypes: [.zip, .folder]) { result in
            switch result {
            case .success(let url): read(url)
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .onDisappear { readTask?.cancel(); prepared?.discard() }
    }

    private func step<Content: View>(_ number: String, title: String, detail: String, @ViewBuilder action: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number).font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24).background(Color.accentColor.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                action().font(.caption)
            }
        }
    }

    private func preview(_ prepared: PreparedIconPack) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(prepared.pack.name).font(.system(size: 14, weight: .semibold))
                    Text("\(prepared.pack.icons.count.formatted()) icons" + (prepared.pack.version.map { " · Version \($0)" } ?? ""))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                ForEach(Array(prepared.pack.icons.prefix(18))) { icon in
                    Group {
                        if let image = NSImage(contentsOf: prepared.directory.appendingPathComponent("pack/icons").appendingPathComponent(icon.filename)) {
                            Image(nsImage: image).resizable().scaledToFit().padding(8)
                        } else { Image(systemName: "questionmark.square.dashed").foregroundStyle(.secondary) }
                    }
                    .frame(height: 42).frame(maxWidth: .infinity)
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .help(icon.displayName)
                }
            }
            if prepared.skipped > 0 {
                Text("\(prepared.skipped) unsupported or unsafe files were skipped.").font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("License & Credits") {
                ScrollView { Text(prepared.pack.notices).font(.system(size: 10)).textSelection(.enabled) }
                    .frame(height: 70)
            }
            .font(.caption)
            if store.pack != nil {
                Text("This replaces your previously imported pack. Icons already applied to files stay in place.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func chooseDownload() {
        showingChooser = true
    }

    private func read(_ url: URL) {
        prepared?.discard(); prepared = nil
        isReading = true; errorMessage = nil
        readTask = Task {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let worker = Task.detached(priority: .userInitiated) { try IconPackImporter.prepare(url) }
            do {
                let result = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                guard !Task.isCancelled else { result.discard(); return }
                prepared = result
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isReading = false
        }
    }

    private func install() {
        guard let prepared else { return }
        do {
            try store.install(prepared)
            onImported()
            dismiss()
        } catch { errorMessage = "The pack could not be saved. \(error.localizedDescription)" }
    }
}
