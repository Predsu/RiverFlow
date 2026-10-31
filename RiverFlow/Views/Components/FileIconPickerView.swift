import SwiftUI
import UniformTypeIdentifiers

struct FileIconPickerView: View {
    let file: FileItem
    let onChange: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var source = Source.symbols
    @State private var query = ""
    @State private var symbol = "star.fill"
    @State private var tint = Tint.blue
    @State private var image: NSImage?
    @State private var symbolImage: NSImage?
    @State private var errorMessage: String?
    @State private var hasCustomIcon = false

    private enum Source: String, CaseIterable, Identifiable {
        case symbols = "SF Symbols", image = "Image"
        var id: Self { self }
    }

    private enum Tint: String, CaseIterable, Identifiable {
        case blue, purple, pink, red, orange, yellow, green, graphite
        var id: Self { self }
        var color: NSColor {
            switch self {
            case .blue: return .systemBlue
            case .purple: return .systemPurple
            case .pink: return .systemPink
            case .red: return .systemRed
            case .orange: return .systemOrange
            case .yellow: return .systemYellow
            case .green: return .systemGreen
            case .graphite: return .gray
            }
        }
    }

    // Public SF Symbol names only. An exact name can also be entered for any installed symbol.
    private static let symbols = [
        "folder.fill", "folder.badge.gearshape", "folder.badge.person.crop", "doc.fill", "doc.text.fill",
        "doc.richtext", "doc.badge.gearshape", "books.vertical.fill", "book.closed.fill", "bookmark.fill",
        "archivebox.fill", "tray.fill", "externaldrive.fill", "internaldrive.fill", "opticaldisc.fill",
        "star.fill", "heart.fill", "flag.fill", "tag.fill", "pin.fill",
        "house.fill", "building.2.fill", "briefcase.fill", "backpack.fill", "graduationcap.fill",
        "hammer.fill", "wrench.and.screwdriver.fill", "gearshape.fill", "terminal.fill", "curlybraces",
        "chevron.left.forwardslash.chevron.right", "shippingbox.fill", "cube.fill", "puzzlepiece.fill", "app.fill",
        "photo.fill", "photo.on.rectangle.angled", "camera.fill", "paintpalette.fill", "paintbrush.fill",
        "pencil.and.outline", "scissors", "film.fill", "play.rectangle.fill", "music.note",
        "headphones", "waveform", "mic.fill", "speaker.wave.2.fill", "gamecontroller.fill",
        "globe", "network", "cloud.fill", "server.rack", "antenna.radiowaves.left.and.right",
        "lock.fill", "key.fill", "checkmark.shield.fill", "eye.fill", "checkmark.seal.fill",
        "bolt.fill", "flame.fill", "sparkles", "lightbulb.fill", "sun.max.fill",
        "moon.fill", "leaf.fill", "tree.fill", "pawprint.fill", "mountain.2.fill",
        "calendar", "clock.fill", "chart.bar.fill", "chart.pie.fill", "list.bullet.rectangle",
        "envelope.fill", "bubble.left.and.bubble.right.fill", "person.2.fill", "gift.fill", "airplane"
    ]

    private var filteredSymbols: [String] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var names = Self.symbols.filter { search.isEmpty || $0.contains(search) }
        if !search.isEmpty, !names.contains(search), NSImage(systemSymbolName: search, accessibilityDescription: nil) != nil {
            names.insert(search, at: 0)
        }
        return names.filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil }
    }

    private var proposedIcon: NSImage? {
        source == .symbols ? symbolImage : image
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                if let proposedIcon {
                    Image(nsImage: proposedIcon).resizable().scaledToFit().frame(width: 56, height: 56)
                } else {
                    Image(systemName: "photo").font(.system(size: 36)).foregroundStyle(.secondary)
                        .frame(width: 56, height: 56)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Change Icon").font(.headline)
                    Text(file.name).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
            }
            .padding(20)
            Picker("Icon source", selection: $source) {
                ForEach(Source.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().padding(.horizontal, 20).padding(.bottom, 16)
            Divider()

            Group {
                if source == .symbols { symbolBrowser } else { imageChooser }
            }
            .frame(height: 310)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20).padding(.bottom, 12)
            }
            Divider()
            HStack {
                Button("Restore Default") { save(nil) }.disabled(!hasCustomIcon)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Apply Icon") { if let proposedIcon { save(proposedIcon) } }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(proposedIcon == nil)
            }
            .controlSize(.small)
            .padding(16)
        }
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            hasCustomIcon = FileCustomIconService.hasCustomIcon(at: file.url)
            updateSymbolImage()
        }
        .onChange(of: symbol) { _, _ in updateSymbolImage() }
        .onChange(of: tint) { _, _ in updateSymbolImage() }
    }

    private var symbolBrowser: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search or enter an exact symbol name", text: $query).textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Clear search")
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            HStack(spacing: 10) {
                ForEach(Tint.allCases) { item in
                    Button { tint = item } label: {
                        Circle().fill(Color(nsColor: item.color)).frame(width: 19, height: 19)
                            .overlay { if tint == item { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white) } }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.rawValue.capitalized)
                    .accessibilityAddTraits(tint == item ? .isSelected : [])
                    .help(item.rawValue.capitalized)
                }
            }
            ScrollView {
                if filteredSymbols.isEmpty {
                    Text("No matching symbols. You can enter an exact SF Symbol name.")
                        .font(.caption).foregroundStyle(.secondary).padding(.vertical, 24)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(filteredSymbols, id: \.self) { name in
                        Button { symbol = name } label: {
                            Image(systemName: name)
                                .font(.system(size: 22))
                                .foregroundStyle(Color(nsColor: tint.color))
                                .frame(maxWidth: .infinity).frame(height: 43)
                                .background(symbol == name ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                                .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(symbol == name ? Color.accentColor : .clear, lineWidth: 1.5) }
                        }
                        .buttonStyle(.plain).help(name).accessibilityLabel(name)
                        .accessibilityAddTraits(symbol == name ? .isSelected : [])
                    }
                }
            }
            Text(symbol).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(16)
    }

    private var imageChooser: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 32)).foregroundStyle(.secondary)
            Text("Use your own image").font(.system(size: 13, weight: .semibold))
            Text("Choose an image or paste one from the clipboard.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack {
                Button("Choose Image…", action: chooseImage)
                Button("Paste Image") {
                    if let pasted = NSImage(pasteboard: .general), pasted.isValid {
                        image = pasted; errorMessage = nil
                    } else {
                        errorMessage = "The clipboard does not contain a usable image."
                    }
                }
            }
            if image != nil { Label("Image ready", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary) }
        }
        .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Image"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let selected = NSImage(contentsOf: url), selected.isValid {
                image = selected; errorMessage = nil
            } else {
                errorMessage = "This file could not be read as an image."
            }
        }
    }

    private func updateSymbolImage() {
        symbolImage = FileCustomIconService.symbolIcon(named: symbol, color: tint.color)
    }

    private func save(_ icon: NSImage?) {
        do {
            try FileCustomIconService.apply(icon, to: file.url)
            onChange()
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
