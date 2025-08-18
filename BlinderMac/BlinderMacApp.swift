import SwiftUI
import Combine
import AppKit

// App state (Idle or Running.) Only check whether Focus Mode is currently active.
final class AppState: ObservableObject {
    enum Status { case idle, running, error }
    @Published var status: Status = .idle
    @Published var progress: Double = 0
}

// Prevents entire app from shutting down when one tab is closed.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

// Main app.
@main
struct BlinderMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        // Main window, with Menu Bar Icon.
            MenuBarExtra(isInserted: .constant(true)) {
                ContentView()
                    .environmentObject(appState)
            } label: {
                switch appState.status {
                // Dynamic icon for focus running and focus missing.
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
                        .help("Error loading Blinder logo.")
                }
            }
            .menuBarExtraStyle(.window)
        
        // Separate window for creating a new mode.
        Window("New Focus Mode", id: "new-mode") {
                    NewModeWizardView()
                        .environmentObject(appState)
                        .background(.thinMaterial)
                }
                .windowResizability(.contentSize)
                .handlesExternalEvents(matching: ["new-mode"])
    }
}
