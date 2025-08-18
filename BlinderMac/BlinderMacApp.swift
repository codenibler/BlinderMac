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
    @State private var modeName: String = ""
    @StateObject private var catalog = AppCatalog()
    
    private var filteredApps: [AppInfo] {
            let q = catalog.search.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { return catalog.allApps }
            return catalog.allApps.filter {
                $0.name.localizedCaseInsensitiveContains(q) ||
                $0.bundleID.localizedCaseInsensitiveContains(q)
            }
        }

        // Validations
    private var canCreate: Bool {
            !modeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !catalog.selectedBundleIDs.isEmpty
        }
    
    
    var body: some View {
            VStack(spacing: 14) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create Focus Mode")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))

                    HStack(spacing: 8) {
                        TextField("Mode name", text: $modeName)
                            .textFieldStyle(.roundedBorder)
                            .frame(height: 36)

                        Button("Select All (filtered)") {
                            catalog.selectedBundleIDs = Set(filteredApps.map(\.bundleID))
                        }
                        .buttonStyle(.bordered)

                        Button("Clear") {
                            catalog.selectedBundleIDs.removeAll()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                VStack (alignment: .leading) {
                    Text("Select Blocked Apps")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                }
                
                // List
                List {
                    ForEach(filteredApps) { app in
                        AppRow(
                            app: app,
                            isSelected: catalog.selectedBundleIDs.contains(app.bundleID),
                            toggle: { toggleSelection(for: app.bundleID) }
                        )
                    }
                }
                .listStyle(.inset)
                .searchable(text: $catalog.search, placement: .toolbar, prompt: "Search apps or bundle IDs")
                .onAppear { catalog.loadIfNeeded() }

                // Footer
                HStack {
                    Text("\(catalog.selectedBundleIDs.count) selected")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Create") {
                        handleCreate()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCreate)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .frame(minWidth: 520, minHeight: 520)
        }

        // MARK: - Actions

        private func toggleSelection(for bundleID: String) {
            if catalog.selectedBundleIDs.contains(bundleID) {
                catalog.selectedBundleIDs.remove(bundleID)
            } else {
                catalog.selectedBundleIDs.insert(bundleID)
            }
        }

        private func handleCreate() {
            // TODO: persist the new mode
            // Example: send notification or update a shared model
            // NotificationCenter.default.post(name: .didCreateMode, object: nil,
            //                                 userInfo: ["name": modeName,
            //                                            "bundleIDs": Array(catalog.selectedBundleIDs)])

            // Close this window
            NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil)
        }
    }

    // MARK: - Row

    private struct AppRow: View {
        let app: AppInfo
        let isSelected: Bool
        let toggle: () -> Void

        var body: some View {
            Button(action: toggle) {
                HStack(spacing: 10) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Text(app.bundleID)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .imageScale(.medium)
                        .foregroundStyle(isSelected ? .secondary : .primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)
            .help(app.url.path)
        }
    }
