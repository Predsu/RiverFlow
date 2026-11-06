//
//  RiverFlowApp.swift
//  RiverFlow
//
//  Created by ToriYukari on 05/07/2026.
//

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
        let complete: () -> Void
    }

    private var pending: [UUID: Transfer] = [:]

    func prepare(_ tab: BrowserTab, complete: @escaping () -> Void) -> UUID {
        let id = UUID()
        pending[id] = Transfer(tab: tab, complete: complete)
        return id
    }

    func tab(for id: UUID) -> BrowserTab? { pending[id]?.tab }

    func finish(_ id: UUID) {
        pending.removeValue(forKey: id)?.complete()
    }
}
