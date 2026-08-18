import SwiftUI
import QuickLookThumbnailing

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
