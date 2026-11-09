//
//  RiverFlowApp.swift
//  RiverFlow
//
//  Created by ToriYukari on 05/07/2026.
//

import AppKit
import SwiftUI

@main
struct RiverFlowApp: App {
    @State private var tabTransfers = BrowserTabTransfers()

    var body: some Scene {
        WindowGroup(id: "mainWindow", for: UUID.self) { $transferID in
            ContentView(tabTransfers: tabTransfers, transferID: transferID)
        }
        .commands {
            RiverFlowCommands()
        }
    }
}

/// A scene value carries only the request ID. The live tab stays in memory
/// until the new window has appeared and can take ownership.
@MainActor
final class BrowserTabTransfers {
    struct Transfer {
        let tab: BrowserTab
        let dropPoint: CGPoint
        let complete: () -> Void
    }

    private var pending: [UUID: Transfer] = [:]

    func prepare(_ tab: BrowserTab, dropPoint: CGPoint, complete: @escaping () -> Void) -> UUID {
        let id = UUID()
        pending[id] = Transfer(tab: tab, dropPoint: dropPoint, complete: complete)
        return id
    }

    func tab(for id: UUID) -> BrowserTab? { pending[id]?.tab }

    func finish(_ id: UUID, in window: NSWindow) {
        guard let transfer = pending.removeValue(forKey: id) else { return }
        let point = transfer.dropPoint
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? window.screen ?? NSScreen.main
        if let area = screen?.visibleFrame {
            let size = window.frame.size
            let left = min(max(point.x - size.width / 2, area.minX), max(area.minX, area.maxX - size.width))
            let top = min(max(point.y + 20, area.minY + size.height), area.maxY)
            window.setFrameTopLeftPoint(CGPoint(x: left, y: top))
        }
        transfer.complete()
    }
}

/// Wait until SwiftUI has attached the destination window before positioning it.
struct DetachedTabWindowAttachment: NSViewRepresentable {
    let onAttach: (NSWindow) -> Void

    func makeNSView(context: Context) -> AttachmentView {
        let view = AttachmentView()
        view.onAttach = onAttach
        return view
    }

    func updateNSView(_ view: AttachmentView, context: Context) {}

    final class AttachmentView: NSView {
        var onAttach: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window, self.window === window else { return }
                self.onAttach?(window)
            }
        }
    }
}
