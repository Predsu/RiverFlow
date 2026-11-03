import Foundation
import Testing
import SwiftUI
@testable import RiverFlow

@Suite struct ThumbnailManagerTests {
    @Test("ThumbnailManager caching and clearing cache")
    func thumbnailManagerCachingAndClearingCache() throws {
        let manager = ThumbnailManager.shared
        manager.clearCache()
        
        let tempFileURL = URL(fileURLWithPath: "/tmp/thumbnail_test.png")
        manager.getFileThumbnail(for: tempFileURL, size: 48) { _ in }
        manager.clearCache()
    }
}