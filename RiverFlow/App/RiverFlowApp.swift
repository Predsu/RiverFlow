//
//  RiverFlowApp.swift
//  RiverFlow
//
//  Created by ToriYukari on 05/07/2026.
//

import SwiftUI

@main
struct RiverFlowApp: App {
    var body: some Scene {
        WindowGroup(id: "mainWindow") {
            ContentView()
        }
        .commands {
            RiverFlowCommands()
        }
    }
}
