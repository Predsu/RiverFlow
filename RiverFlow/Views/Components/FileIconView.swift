import SwiftUI

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
