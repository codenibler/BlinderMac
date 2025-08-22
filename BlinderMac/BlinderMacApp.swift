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
    @StateObject private var focusModel = FocusConfigModel()
    
    init() {
            Notifier.configure()
        }
    
    var body: some Scene {
        // Main window, with Menu Bar Icon.
            MenuBarExtra(isInserted: .constant(true)) {
                ContentView()
                    .background(.thinMaterial)
                    .environmentObject(appState)
                    .environmentObject(focusModel)
                    .onAppear {
                        // e.g., in your App struct's first onAppear of the main UI/menu window
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            AutomationOnboarding.shared.requestForInstalledBrowsers()
                        }
                    }
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
        Window("", id: "new-mode") {
                    NewModeWizardView()
                        .environmentObject(appState)
                        .environmentObject(focusModel)   
                        .background(.thinMaterial)
                }
                .windowResizability(.contentSize)
                .windowToolbarStyle(.unifiedCompact)
                .handlesExternalEvents(matching: ["new-mode"])
        
        Window("", id: "edit-mode") {
            EditModeView()              
                .environmentObject(appState)
                .environmentObject(focusModel)
                .background(.thinMaterial)
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unifiedCompact)
    }
}

func sendHarmlessAppleEvent(toBundleID bundleID: String) {
    let source = """
    tell application id "\(bundleID)"
        get name
    end tell
    """
    var err: NSDictionary?
    if let script = NSAppleScript(source: source) {
        _ = script.executeAndReturnError(&err)
        if let e = err {
            print("Automation AE error to \(bundleID):", e)
        } else {
            print("Automation likely granted (or already granted) for \(bundleID).")
        }
    } else {
        print("Failed to compile AppleScript for \(bundleID).")
    }
}
