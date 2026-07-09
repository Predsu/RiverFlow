import SwiftUI
import AppKit
import QuickLookThumbnailing

struct RightClickCatcher: NSViewRepresentable {
    let onRightClick: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = CatcherView()
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? CatcherView)?.onRightClick = onRightClick
    }

    private class CatcherView: NSView {
        var onRightClick: (() -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            if let event = NSApp.currentEvent,
               event.type == .rightMouseDown || event.type == .rightMouseUp {
                return self
            }
            return nil
        }

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?()
            super.rightMouseDown(with: event)
        }
    }
}

struct FileInfoView: View {
    let file: FileItem
    weak var window: NSWindow?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                FileIconView(file: file, baseSize: 64)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(file.name)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(file.itemType == .DIRECTORY ? "Directory" : "File")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Size:")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(file.formattedSize)
                        .textSelection(.enabled)
                }
                
                HStack {
                    Text("Modified:")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(file.formattedDate)
                        .textSelection(.enabled)
                }
                
                HStack(alignment: .top) {
                    Text("Path:")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(file.url.path)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .frame(minHeight: 32, maxHeight: 64)
                        .textSelection(.enabled)
                        .truncationMode(.head)
                        .help(file.url.path)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Close") {
                    window?.performClose(nil)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380, height: 260)
    }
}

class FileWindowManager: NSObject, NSWindowDelegate {
    static let shared = FileWindowManager()
    private var openWindows: [String: NSWindow] = [:]
    
    static func openInfoView(for file: FileItem) {
        shared.openInfoView(for: file)
    }
    
    private func openInfoView(for file: FileItem) {
        let windowIdentifier = "elementinfowindow-\(file.id.uuidString)"
        
        if let existingWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == windowIdentifier }) {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 380,
                height: 260),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.identifier = NSUserInterfaceItemIdentifier(windowIdentifier)
        window.title = file.name
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: FileInfoView(file: file, window: window))
        window.makeKeyAndOrderFront(nil)
        
        openWindows[windowIdentifier] = window
    }
    
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
            let id = window.identifier?.rawValue else { return }
        openWindows.removeValue(forKey: id)
    }
}

class ThumbnailManager {
    static let shared = ThumbnailManager()
    private let cache = NSCache<NSURL, NSImage>()
    
    init() {
        cache.countLimit = 35
        cache.evictsObjectsWithDiscardedContent = true
    }
    
    func getElementThumbnail(for url: URL, size: CGFloat, completion: @escaping (NSImage?) -> Void) {
        let nsURL = url as NSURL
        
        if let cachedImage = cache.object(forKey: nsURL) {
            completion(cachedImage)
            return
        }
        
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(
                width: size,
                height: size
            ),
            scale: scale,
            representationTypes: .thumbnail
        )
        
        QLThumbnailGenerator.shared.generateRepresentations(for: request) { representation, type, error in
            if let thumbnail = representation {
                let nsImage = thumbnail.nsImage
                self.cache.setObject(nsImage, forKey: nsURL)
                DispatchQueue.main.async {
                    completion(nsImage)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

struct FileIconView: View {
    let file: FileItem
    var baseSize: CGFloat = 64
    
    @State private var loadedThumbnail: NSImage? = nil
    @State private var hasAttemptedLoad: Bool = false
    
    private var isAppBundle: Bool {
        return file.url.pathExtension.lowercased() == "app"
    }
    
    private var isImageFile: Bool {
        let imageExtensions = ["jpg", "png", "jpeg", "gif", "bmp", "tiff", "heic", "webp"]
        return imageExtensions.contains(file.url.pathExtension.lowercased())
    }
    
    private var appIcon: NSImage {
        return NSWorkspace.shared.icon(forFile: file.url.path)
    }
    
    final class IconCache {
        static let shared = IconCache()
        private var cache: [String: NSImage] = [:]
        
        func icon(for path: String) -> NSImage {
            if let cached = cache[path] { return cached }
            let icon = NSWorkspace.shared.icon(forFile: path)
            cache[path] = icon
            return icon
        }
    }
    
    var body: some View {
        Group {
            if isAppBundle {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: baseSize, height: baseSize)
                    .opacity(file.isHidden ? 0.5 : 1.0)
            } else if isImageFile {
                if let img = loadedThumbnail {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(4)
                        .opacity(file.isHidden ? 0.5 : 1.0)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: baseSize))
                        .foregroundColor(.secondary)
                        .opacity(file.isHidden ? 0.5 : 1.0)
                        .onAppear {
                            loadThumbnailImage()
                        }
                }
            } else if file.itemType == .DIRECTORY {
                Image(systemName: "folder")
                    .font(.system(size: baseSize))
                    .foregroundColor(.blue)
                    .opacity(file.isHidden ? 0.5 : 1.0)
            } else {
                ZStack(alignment: .bottom) {
                    Image(systemName: "doc")
                        .font(.system(size: baseSize))
                        .foregroundColor(.secondary)
                        .opacity(file.isHidden ? 0.5 : 1.0)
                    
                    if !file.fileExtensionIconText.isEmpty {
                        Text(file.fileExtensionIconText)
                            .font(.system(size: baseSize * 0.18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 2)
                            .padding(.bottom, baseSize * 0.22)
                            .lineLimit(1)
                            .allowsHitTesting(false)
                            .frame(width: baseSize * 0.75)
                    }
                }
            }
        }
        .frame(width: baseSize, height: baseSize)
        .onChange(of: file.url) { _, _ in
            loadedThumbnail = nil
            hasAttemptedLoad = false
            if isImageFile {
                loadThumbnailImage()
            }
        }
    }
    
    private func loadThumbnailImage() {
        guard !hasAttemptedLoad else { return }
        hasAttemptedLoad = true
        
        ThumbnailManager.shared.getElementThumbnail(for: file.url, size: baseSize) { img in
            self.loadedThumbnail = img
        }
    }
}

struct FileGridItemView: View {
    let file: FileItem
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onCopy: () -> Void
    let onCut: () -> Void
    let onOpenAsDirectory: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            FileIconView(file: file, baseSize: 64)
            Text(file.name)
                .font(.system(size: 12))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 32, alignment: .top)
        }
        .padding(10)
        .frame(width: 120, height: 110, alignment: .top)
        .background(isSelected ? Color(.selectedControlColor).opacity(0.15) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.selectedControlColor), lineWidth: isSelected ? 2 : 0)
        )
        .contentShape(Rectangle())
        .overlay(RightClickCatcher(onRightClick: onTap))
        .gesture(
            TapGesture(count: 1)
                .onEnded {
                    onTap()
                }
                .simultaneously(
                    with: TapGesture(count: 2)
                        .onEnded {
                            onDoubleTap()
                        }
                )
        )
        .contextMenu {
            if file.url.pathExtension == "app" {
                Button(action: onOpenAsDirectory) {
                    Text("Show Package Contents")
                    Image(systemName: "folder.badge.gearshape")
                }
            }
            
            Divider()
            
            Button(action: {
                FileWindowManager.openInfoView(for: file)
            }) {
                Text("Element Info")
                Image(systemName: "info.circle")
            }

            Divider()

            Button(action: onCopy) {
                Text("Copy Element")
                Image(systemName: "doc.on.doc")
            }
            
            Button(action: onCut) {
                Text("Cut Element")
                Image(systemName: "arrow.right.doc.on.clipboard")
            }
            
            Divider()
            
            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(file.url.path, forType: .string)
            }) {
                Text("Copy Element Path")
                Image(systemName: "doc.on.doc")
            }
            
            Divider()
            
            Button(action: {
                do {
                    try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                } catch {
                    print("Error while moving element to trash \(error.localizedDescription)")
                }
            }) {
                Text("Move to Trash")
                Image(systemName: "trash")
            }
            
            Divider()
        }
    }
}

struct FileListItemView: View {
    let file: FileItem
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onCopy: () -> Void
    let onCut: () -> Void
    let onOpenAsDirectory: () -> Void

    var body: some View {
        HStack {
            FileIconView(file: file, baseSize: 18)
            Text(file.name)
                .lineLimit(1)

            Spacer()

            Text(file.formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)

            Text(file.formattedSize)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isSelected ? Color(.selectedControlColor).opacity(0.2) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(.selectedControlColor), lineWidth: isSelected ? 1.5 : 0)
        )
        .contentShape(Rectangle())
        .gesture(
            TapGesture(count: 1)
                .onEnded {
                    onTap()
                }
                .simultaneously(
                    with: TapGesture(count: 2)
                        .onEnded {
                            onDoubleTap()
                        }
                )
        )
        .contextMenu {
            if file.url.pathExtension == "app" {
                Button(action: onOpenAsDirectory) {
                    Text("Show Package Contents")
                    Image(systemName: "folder.badge.gearshape")
                }
            }

            Divider()

            Button(action: onCopy) {
                Text("Copy Element")
                Image(systemName: "doc.on.doc")
            }

            Button(action: onCut) {
                Text("Cut Element")
                Image(systemName: "arrow.right.doc.on.clipboard")
            }

            Divider()

            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(file.url.path, forType: .string)
            }) {
                Text("Copy Full Path")
                Image(systemName: "doc.on.doc")
            }

            Divider()

            Button(action: {
                do {
                    try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                } catch {
                    print("Error while moving item to trash \(error.localizedDescription)")
                }
            }) {
                Text("Move to Trash")
                Image(systemName: "trash")
            }

            Divider()
        }
    }
}

struct InteractivePathTitleView: View {
    let fullPath: String
    let folderName: String
    
    @State private var isHoveringPath = false
    @State private var showCopyFeedback = false
    
    var body: some View {
        HStack(spacing: 6) {
            if isHoveringPath {
                Text(fullPath)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
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
        .frame(minWidth: 140, maxWidth: 320, alignment: .leading)
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
