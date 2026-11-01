import SwiftUI

struct MaterialIconBrowserView: View {
    let onSelection: (NSImage?) -> Void
    @ObservedObject private var store = ImportedIconPackStore.shared
    @State private var query = ""
    @State private var category = "All"
    @State private var selectedID: String?
    @State private var showingImport = false
    @State private var showingCredits = false
    @State private var errorMessage: String?

    private var matches: [ImportedIconPack.Icon] {
        let terms = query.lowercased().split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
        return (store.pack?.icons ?? []).filter { icon in
            (category == "All" || icon.category == category) && terms.allSatisfy { icon.displayName.lowercased().contains($0) }
        }
    }

    var body: some View {
        Group {
            if let pack = store.pack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pack.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                            Text("\(pack.icons.count.formatted()) imported icons").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 2)
                        Menu {
                            Button("Import Another Pack…") { showingImport = true }
                            Button("Import Instructions…") { showingImport = true }
                            Divider()
                            Button("Remove Imported Pack", role: .destructive) {
                                do { try store.remove() } catch { errorMessage = error.localizedDescription }
                            }
                        } label: { Image(systemName: "ellipsis.circle") }
                        .menuStyle(.borderlessButton).fixedSize().help("Manage imported pack")
                        .accessibilityLabel("Manage imported pack")
                    }
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search Material icons", text: $query).textFieldStyle(.plain).font(.system(size: 12))
                        if !query.isEmpty {
                            Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                                .buttonStyle(.plain).accessibilityLabel("Clear imported search")
                        }
                    }
                    .padding(7).background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    Picker("Material icon category", selection: $category) {
                        ForEach(["All", "Files", "Folders"], id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.segmented).controlSize(.small)
                    ScrollView {
                        if matches.isEmpty { Text("No matching icons.").font(.caption).foregroundStyle(.secondary).padding() }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                            ForEach(matches) { icon in
                                Button {
                                    selectedID = icon.id
                                    onSelection(store.image(for: icon))
                                } label: {
                                    Group {
                                        if let image = store.image(for: icon) {
                                            Image(nsImage: image).resizable().scaledToFit().padding(7)
                                        } else { Image(systemName: "questionmark.square.dashed").foregroundStyle(.secondary) }
                                    }
                                    .frame(maxWidth: .infinity).frame(height: 43)
                                    .background(selectedID == icon.id ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                                    .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(selectedID == icon.id ? Color.accentColor : .clear, lineWidth: 1.5) }
                                }
                                .buttonStyle(.plain).help(icon.id).accessibilityLabel(icon.displayName)
                                .accessibilityAddTraits(selectedID == icon.id ? .isSelected : [])
                            }
                        }
                    }
                    HStack {
                        Text(selectedID ?? "Select an icon").font(.system(size: 10, design: .monospaced)).lineLimit(1)
                        Spacer(minLength: 4)
                        Button("License & Credits") { showingCredits = true }.buttonStyle(.link).font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                    if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down").font(.system(size: 30)).foregroundStyle(.secondary)
                    Text("Import Material icons").font(.system(size: 13, weight: .semibold))
                    Text("Material icons aren’t included with RiverFlow. Download the official pack, choose its ZIP or folder, then preview and import.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Import Icon Pack…") { showingImport = true }.buttonStyle(.borderedProminent)
                    Link("View Official Project", destination: IconPackImporter.projectURL).font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .sheet(isPresented: $showingImport) { IconPackImportView(store: store) { resetSelection() } }
        .sheet(isPresented: $showingCredits) {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.pack?.name ?? "Imported Icon Pack").font(.headline)
                if let source = store.pack?.source, let url = URL(string: source), url.scheme == "https" {
                    Link("Source Project", destination: url).font(.caption)
                }
                ScrollView { Text(store.pack?.notices ?? "").font(.system(size: 11)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                HStack { Spacer(); Button("Done") { showingCredits = false }.keyboardShortcut(.defaultAction) }
            }
            .padding(20).frame(width: 440, height: 480)
        }
        .onAppear { resetSelection() }
        .onChange(of: store.pack?.id) { _, _ in query = ""; category = "All"; resetSelection() }
    }

    private func resetSelection() {
        selectedID = nil
        onSelection(nil)
    }
}
