import SwiftUI
import Combine
import AppKit

// App state (Idle or Running.) Only check whether Focus Mode is currently active.
final class AppState: ObservableObject {
    enum Status { case idle, running, error }
    @Published var status: Status = .idle
    @Published var progress: Double = 0
}

// Main app.
@main
struct MenuBarApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra(isInserted: .constant(true)) {
            ContentView()
                .environmentObject(appState)
        } label: {
            switch appState.status {
            case .idle:
                Image("blindericon")          // <- asset name
                    .renderingMode(.template) // system tints it
                    .opacity(appState.status == .idle ? 1 : 0)
            case .running:
                Image("blinderonicon")        // <- asset name
                    .renderingMode(.template)
                    .opacity(appState.status == .idle ? 0 : 1)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
