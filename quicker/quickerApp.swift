//
//  quickerApp.swift
//  quicker
//
//  Created by Bryan Hu on 2026/2/3.
//

import SwiftUI
import SwiftData

@main
struct quickerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ClipboardEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
