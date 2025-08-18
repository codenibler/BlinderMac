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
struct BlinderMacApp: App {
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
                    NewModeView()
                        .environmentObject(appState)
                }
                .defaultSize(width: 520, height: 360)
                .windowResizability(.contentSize)
                // Optional: route deep links to only this window if you ever use URL schemes:
                .handlesExternalEvents(matching: ["new-mode"])
    }
}

struct NewModeView: View {
    @EnvironmentObject var appState: AppState
    @State private var name: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create Focus Mode")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            
            TextField("Mode name", text: $name)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Spacer()
                Button("Create") {
                    // TODO: persist the new mode, then optionally close the window
                    // e.g., post a notification or update shared model
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(maxWidth: 380, minHeight: 500)
        
        Divider()
        
        
    }    
}

