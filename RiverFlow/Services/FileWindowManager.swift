import AppKit
import SwiftUI

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
