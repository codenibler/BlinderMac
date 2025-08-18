//
//  BlinderMacApp.swift
//  BlinderMac
//
//  Created by Angel Barrio on 18/08/2025.
//

import SwiftUI

@main
struct BlinderMacApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
