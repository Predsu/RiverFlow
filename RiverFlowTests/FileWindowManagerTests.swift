import Foundation
import Testing
import SwiftUI
@testable import RiverFlow

@Suite struct FileWindowManagerTests {
    @Test("FileWindowManager opens and tracks info windows")
    @MainActor
    func fileWindowManagerOpensAndTracksInfoWindows() throws {
        let file = FileItem(
            url: URL(fileURLWithPath: "/tmp/infofile.txt"),
            name: "infofile.txt",
            itemType: .FILE,
            size: 100,
            modificationDate: Date(),
            isHidden: false
        )
        
        FileWindowManager.openInfoView(for: file)
        FileWindowManager.openInfoView(for: file)
        
        let windowIdentifier = "fileinfowindow-\(file.id.uuidString)"
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == windowIdentifier }) {
            NotificationCenter.default.post(
                name: NSWindow.willCloseNotification,
                object: window
            )
        }
    }
}