import SwiftUI
import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// AppKit-backed view wrapper that intercepts right-click mouse events.
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

/// SwiftUI view presenting element's data in separate window.
///
/// Handles automatic size calculation running in background and QuickLook thumbnails.
struct FileInfoView: View {
    let file: FileItem
    weak var window: NSWindow?
    
    @State private var displaySize: String = ""
    
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
                    Text(displaySize)
                        .fontWeight(.medium)
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
        .onAppear {
            if file.itemType == .DIRECTORY {
                displaySize = "Calculating..."
                Task(priority: .userInitiated) {
                    let size = await calculateFolderSize(at: file.url)
                    displaySize = formatBytes(size)
                }
            } else {
                displaySize = file.formattedSize
            }
        }
    }
    
    /// Calculates total folder contents size.
    ///
    /// Recursively searches through folder, skipping hidden files and insides of `.app` bundles.
    /// Supports task cancellation (`Task.isCancelled`).
    ///
    /// - Parameter url: URL path to target folder as `URL`.
    /// - Returns: Total size in bytes as `Int64`.
    private func calculateFolderSize(at url: URL) async -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { (url, error) -> Bool in
                print("Error at \(url.path): \(error.localizedDescription)")
                return true
            }
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            if Task.isCancelled { return totalSize }
            
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
            
            if let isDir = resourceValues.isDirectory, !isDir {
                if let size = resourceValues.fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        return totalSize
    }
    
    /// Formats raw bytes number into human-readable text.
    ///
    /// - Parameter bytes: Bytes number as `Int64`.
    /// - Returns: Automatically formatted bytes as `String` (e.g., "1.2 MB").
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

/// AppKit window manager responsible for displaying file info windows.
///
/// Maintains lifecycle of windows, handles duplication attempts and removing windows.
class FileWindowManager: NSObject, NSWindowDelegate {
    static let shared = FileWindowManager()
    private var openWindows: [String: NSWindow] = [:]
    
    /// Opens info window for given `FileItem`
    static func openInfoView(for file: FileItem) {
        shared.openInfoView(for: file)
    }
    
    /// Presents or brings to focus info window for specified `FileItem`.
    private func openInfoView(for file: FileItem) {
        let windowIdentifier = "fileinfowindow-\(file.id.uuidString)"
        
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
    
    /// Handles window closure to clean up tracking references.
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
            let id = window.identifier?.rawValue else { return }
        openWindows.removeValue(forKey: id)
    }
}

/// Manager responsible for generating and caching file thumbnails.
///
/// Uses Apple's QuickLook thumbnailing framework to asynchonously generate thumbnails which are stored in `NSCache`.
class ThumbnailManager {
    static let shared = ThumbnailManager()
    private let cache = NSCache<NSURL, NSImage>()
    
    init() {
        cache.countLimit = 35
        cache.evictsObjectsWithDiscardedContent = true
    }
    
    /// Asynchronously generates or retrieves a cached thumbnail image for a file at given URL.
    ///
    /// - Parameters:
    ///     - url: Target file URL as `URL`.
    ///     - size: Target width and height as `CGFloat`.
    ///     - completion: Closure invoked on main thread delivering the generated `NSImage` or `nil`.
    func getFileThumbnail(for url: URL, size: CGFloat, completion: @escaping (NSImage?) -> Void) {
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
    
    /// Clears all cached thumbnails.
    func clearCache() {
        cache.removeAllObjects()
    }
}

/// SwiftUI view that displays corresponding icon or thumbnail for `FileItem`.
///
/// Determines how an item should be visually represented based on its type and location. Supports:
/// - bundles icons
/// - image thumbnails
/// - special system and user directories
/// - generic directory icons
/// - generic documents icons with extension labels
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
    
//    private var isSpecialDirectory: Bool {
//        guard file.itemType == .DIRECTORY else { return false }
//        
//        let path = file.url.path
//        let homePath = NSHomeDirectory()
//        
//        let specialPaths = [
//            homePath,
//            "\(homePath)/Desktop",
//            "\(homePath)/Downloads",
//            "\(homePath)/Documents",
//            "\(homePath)/Movies",
//            "\(homePath)/Pictures",
//            "/Applications",
//            "/System/Applications"
//        ]
//        
//        return specialPaths.contains(path)
//    }
    
    private var specialFolderIconName: String? {
        guard file.itemType == .DIRECTORY else { return nil }
        let path = file.url.path
        let homePath = NSHomeDirectory()
        
        switch path {
        case homePath: return "house"
        case "\(homePath)/Desktop": return "menubar.dock.rectangle"
        case "\(homePath)/Downloads": return "arrow.down.circle"
        case "\(homePath)/Documents": return "doc.text"
        case "\(homePath)/Movies": return "film"
        case "\(homePath)/Music": return "music.note"
        case "\(homePath)/Pictures": return "photo.on.rectangle"
        case "/Applications", "/System/Applications", "\(homePath)/Applications": return "square.3.layers.3d"
        default: return nil
        }
    }
    
    private var appIcon: NSImage {
        return NSWorkspace.shared.icon(forFile: file.url.path)
    }
    
//    private var customIcon: NSImage {
//        return IconCache.shared.icon(for: file.url.path)
//    }

    final class IconCache {
        static let shared = IconCache()
        private var cache: [String: NSImage] = [:]
        
        /// Retrieves the cached icon for given path.
        /// - Parameter path: File path as `String`.
        /// - Returns: Icon as `NSImage`
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
            } else if let iconName = specialFolderIconName {
                Image(systemName: iconName)
                    .font(.system(size: baseSize))
                    .foregroundColor(.blue)
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
    
    /// Triggers asynchronous thumbnail generation for FileItem.
    private func loadThumbnailImage() {
        guard !hasAttemptedLoad else { return }
        hasAttemptedLoad = true
        
        ThumbnailManager.shared.getFileThumbnail(for: file.url, size: baseSize) { img in
            self.loadedThumbnail = img
        }
    }
}

/// SwiftUI context menu containing actions for `FileItem`.
///
/// Provides opening, copying, cutting, renaming, compressing, trashing.
struct FileContextMenu: View {
    let file: FileItem
    let viewModel: FolderViewModel
    let isSelected: Bool
    let onOpenAsDirectory: () -> Void
    let onCopy: () -> Void
    let onCut: () -> Void
    let onMoveToTrash: () -> Void

    var body: some View {
        Group {
            Button(action: {
                viewModel.openFileWith(file: file)
            }) {
                Text("Open File With")
                Image(systemName: "arrow.up.forward.app")
            }
            
            Button(action: {
                viewModel.revealInFinder(url: file.url)
            }) {
                Text("Reveal in Finder")
                Image(systemName: "magnifyingglass")
            }
            
            Divider()
            
            if file.url.pathExtension == "app" {
                Button(action: onOpenAsDirectory) {
                    Text("Show Package Contents")
                    Image(systemName: "folder.badge.gearshape")
                }
                
                Divider()
            }
            
            Button(action: {
                FileWindowManager.openInfoView(for: file)
            }) {
                Text("File Info")
                Image(systemName: "info.circle")
            }

            Divider()

            Button(action: onCopy) {
                Text("Copy File")
                Image(systemName: "doc.on.doc")
            }
            
            Button(action: onCut) {
                Text("Cut File")
                Image(systemName: "arrow.right.doc.on.clipboard")
            }
            
            Button(action: {
                viewModel.editingFileID = file.id
            }) {
                Text("Rename")
                Image(systemName: "character.cursor.ibeam")
            }
            
            Button(action: {
                if isSelected {
                    let selectedFiles = viewModel.files.filter { viewModel.selectedFileIds.contains($0.id) }
                    viewModel.compressToZip(files: selectedFiles)
                } else {
                    viewModel.compressToZip(files: [file])
                }
            }) {
                Text("Compress to ZIP")
                Image(systemName: "archivebox")
            }
            
            if viewModel.selectedFileIds.count > 1 && viewModel.selectedFileIds.contains(file.id) {
                Button(action: {
                    viewModel.createFolderFromSelection(files: viewModel.selectedFiles)
                    viewModel.selectedFileIds.removeAll()
                }) {
                    Text("Create Folder with Selected")
                    Image(systemName: "folder.badge.plus")
                }
            }
            
            Divider()
            
            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(file.url.path, forType: .string)
            }) {
                Text("Copy File Path")
                Image(systemName: "doc.on.doc")
            }
            
            Divider()
            
            Button(action: onMoveToTrash) {
                Text("Move to Trash")
                Image(systemName: "trash")
            }
        }
    }
}

/// SwiftUI view representing `FileItem` in grid layout.
///
/// Displays a file icon and editable name in grid cell. Supports:
/// - single click selection
/// - double click activation
/// - right-click context menu
/// - drag-and-drop targeting
/// - actions from `FileContextMenu`
struct FileGridItemView: View {
    let file: FileItem
    let isSelected: Bool
    var isTargeted: Bool = false
    let onTap: () -> Void
    let onRightClick: () -> Void
    let onDoubleTap: () -> Void
    let onCopy: () -> Void
    let onCut: () -> Void
    let onOpenAsDirectory: () -> Void
    let onRefreshRequired: () -> Void
    let onMoveToTrash: () -> Void
    var viewModel: FolderViewModel
    
    var isEditing: Bool {
        viewModel.editingFileID == file.id
    }
    
    var body: some View {
        VStack(spacing: 8) {
            FileIconView(file: file, baseSize: 64)
//            Text(file.name)
//                .font(.system(size: 12))
//                .lineLimit(2)
//                .multilineTextAlignment(.center)
//                .frame(height: 32, alignment: .top)
            EditableFileNameView(
                file: file,
                isEditing: isEditing,
                onCommit: { newName in
                    viewModel.renameFile(file: file, to: newName)
                    viewModel.editingFileID = nil
                },
                onCancel: {
                    viewModel.editingFileID = nil
                }
            )
        }
        .padding(10)
        .frame(width: 120, height: 110, alignment: .top)
        .background(
            ZStack {
                if isSelected {
                    Color(.selectedControlColor).opacity(0.15)
                }
                if isTargeted && file.itemType == .DIRECTORY {
                    Color.accentColor.opacity(0.2)
                }
            }
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isTargeted && file.itemType == .DIRECTORY ? Color.accentColor : Color(.selectedControlColor), lineWidth: (isSelected || (isTargeted && file.itemType == .DIRECTORY)) ? 2 : 0)
        )
        .contentShape(Rectangle())
        .overlay(RightClickCatcher(onRightClick: {
            onRightClick()
        }))
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
            FileContextMenu(
                file: file,
                viewModel: viewModel,
                isSelected: isSelected,
                onOpenAsDirectory: onOpenAsDirectory,
                onCopy: onCopy,
                onCut: onCut,
                onMoveToTrash: onMoveToTrash
            )
        }
    }
}

/// SwiftUI view representing `FileItem` in list layout.
///
/// Displays a compact horizontal representation. Supports:
/// - single click selection
/// - double click activation
/// - right-click context menu
/// - drag-and-drop targeting
/// - actions from `FileContextMenu`
struct FileListItemView: View {
    let file: FileItem
    let isSelected: Bool
    var isTargeted: Bool = false
    let onTap: () -> Void
    let onRightClick: () -> Void
    let onDoubleTap: () -> Void
    let onCopy: () -> Void
    let onCut: () -> Void
    let onOpenAsDirectory: () -> Void
    let onRefreshRequired: () -> Void
    let onMoveToTrash: () -> Void
    let viewModel: FolderViewModel

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
        .background(
            ZStack {
                if isSelected {
                    Color(.selectedControlColor).opacity(0.2)
                }
                if isTargeted && file.itemType == .DIRECTORY {
                    Color.accentColor.opacity(0.2)
                }
            }
        )
        .overlay(RightClickCatcher(onRightClick: {
            onRightClick()
        }))
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
            FileContextMenu(
                file: file,
                viewModel: viewModel,
                isSelected: isSelected,
                onOpenAsDirectory: onOpenAsDirectory,
                onCopy: onCopy,
                onCut: onCut,
                onMoveToTrash: onMoveToTrash
            )
        }
    }
}

/// SwiftUI view displaying folder name and full, copiable directory path on hover.
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
        .frame(minWidth: 140, maxWidth: 310, alignment: .leading)
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

/// Collection of utilities for playing app's sound effects.
struct SoundEffects {
    /// Warms audio engine by playing silent system sound.
    /// - Warning: It helps only for the first few minutes of app running. Issue fixing ongoing.
    static func warmUpAudioEngine() {
        if let silentSound = NSSound(named: "Tink") {
            silentSound.volume = 0.0
            silentSound.play()
        }
    }
    
    /// Plays custom sound effect.
    /// - Parameter name: Name of the sound asset (without file extension).
    /// - Note: Playback may be latenced or corrupted if audio engine not warmed up. See: `warmUpAudioEngine` method.
    static func playSoundEffect(name: String) {
        if let sound = NSSound(named: name) {
            sound.play()
        }
    }
}

/// SwiftUI displaying editable, inline `FileItem` name.
struct EditableFileNameView: View {
    let file: FileItem
    let isEditing: Bool
    let onCommit: (String) -> Void
    let onCancel: () -> Void
    
    @State private var editedName: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Group {
            if isEditing {
                TextField("", text: $editedName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 1.5)
                    )
                    .focused($isFocused)
                    .onSubmit {
                        commitChange()
                    }
                    .onExitCommand {
                        onCancel()
                    }
                    .onAppear {
                        editedName = file.url.lastPathComponent
                        isFocused = true
                    }
            } else {
                Text(file.url.lastPathComponent)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
    }
    
    /// Commits file name change if it differs from old name.
    private func commitChange() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != file.url.lastPathComponent {
            onCommit(trimmed)
        } else {
            onCancel()
        }
    }
}
