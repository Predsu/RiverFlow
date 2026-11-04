import SwiftUI

/// Copy stays on the title; a separate, always-visible menu handles navigation.
struct InteractivePathTitleView: View {
    let fullPath: String
    let folderName: String
    var onNavigate: ((URL) -> Void)? = nil
    var onGoToFolder: (() -> Void)? = nil
    var onActivate: () -> Void = {}

    @State private var isHoveringPath = false
    @State private var showCopyFeedback = false
    @State private var feedbackTask: Task<Void, Never>?

    static func ancestorURLs(for path: String) -> [URL] {
        var url = URL(fileURLWithPath: path).standardizedFileURL
        var ancestors = [url]
        while url.path != "/" {
            url.deleteLastPathComponent()
            ancestors.append(url)
        }
        return ancestors
    }

    var body: some View {
        HStack(spacing: 2) {
            Button(action: copyPath) {
                HStack(spacing: 6) {
                    Text(isHoveringPath ? fullPath : folderName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if isHoveringPath || showCopyFeedback {
                        Image(systemName: showCopyFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(showCopyFeedback ? Color.green : Color.secondary)
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
                .background(isHoveringPath ? Color(NSColor.quaternaryLabelColor) : .clear, in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .onHover { isHoveringPath = $0 }
            .help("Copy Path: \(fullPath)")
            .accessibilityLabel("Copy folder path")
            .accessibilityValue(fullPath)
            .accessibilityIdentifier("copyFolderPath")

            if let onNavigate {
                Menu {
                    if let onGoToFolder {
                        Button("Go to Folder…", systemImage: "arrow.right.circle", action: onGoToFolder)
                        Divider()
                    }
                    ForEach(Self.ancestorURLs(for: fullPath), id: \.self) { url in
                        Button {
                            onNavigate(url)
                        } label: {
                            Label(url.path == "/" ? "This Mac (/)" : url.lastPathComponent,
                                  systemImage: url.path == fullPath ? "folder.fill" : "folder")
                        }
                        .help(url.path)
                    }
                    Divider()
                    Button("Copy Path", systemImage: "doc.on.doc", action: copyPath)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .padding(.vertical, 5)
                        .padding(.horizontal, 4)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Navigate to a Folder")
                .accessibilityLabel("Navigate to a Folder")
                .accessibilityIdentifier("pathNavigationMenu")
            }
        }
        .onChange(of: fullPath) { _, _ in
            feedbackTask?.cancel()
            showCopyFeedback = false
        }
        .onDisappear { feedbackTask?.cancel() }
    }

    private func copyPath() {
        onActivate()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullPath, forType: .string)
        showCopyFeedback = true
        feedbackTask?.cancel()
        feedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            showCopyFeedback = false
        }
    }
}

/// SwiftUI view displaying folder name and full, copiable directory path on hover.
struct WindowPathTitleView: View {
    let fullPath: String
    let folderName: String
    
    @State private var isHoveringPath = false
    @State private var showCopyFeedback = false
    
    @Binding var width: CGFloat
    
    var body: some View {
        HStack(spacing: 6) {
            if isHoveringPath {
                Text(fullPath)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .transition(.asymmetric(insertion: .opacity.animation(.easeInOut(duration: 0.2)),
                                            removal: .identity))
            } else {
                Text(folderName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .transition(.identity)
            }
            
            if isHoveringPath {
                Image(systemName: showCopyFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(showCopyFeedback ? .green : .secondary)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(isHoveringPath ? Color(NSColor.quaternaryLabelColor) : Color.clear)
        .cornerRadius(4)
        .frame(minWidth: 140, maxWidth: max(140, width * 0.35), alignment: .leading)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHoveringPath)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isHoveringPath = hovering
            }
        }
        .onTapGesture {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(fullPath, forType: .string)
            
            withAnimation(.easeInOut(duration: 0.15)) {
                showCopyFeedback = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showCopyFeedback = false
                }
            }
        }
    }
}
