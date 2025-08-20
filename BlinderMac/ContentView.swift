import SwiftUI
import AppKit

// - Main UI
struct ContentView: View {
    // List of Focus modes + Current Mode
    @State private var modes: [String] = ["Test"]
    @State private var selectedMode: String? = nil
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var focusModel: FocusConfigModel
    
    // Ability to open new windows.
    @Environment(\.openWindow) private var openWindow
    @StateObject private var engine = FocusEngine()
    
    // Create a new Focus mode sheet
    @State private var showingNewModeSheet = false
    @State private var newModeName: String = ""

    // Duration input. To display duration in 00:00 format, secs are needed.
    // Duration setup: Total seconds, remaining seconds, and timer task active/not.
    @State private var durationSeconds: Int = 50 * 60
    @State private var remainingSeconds: Int = 50 * 60
    @State private var timerTask: Task<Void, Never>? = nil
    
    // Turn number of seconds into 00:00 format.
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60, secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // Main Body
    var body: some View {
        
        VStack(spacing: 16) {
            // Top Row, App name and Focus Mode dropdown.
            HStack {
                // Fade in new text if state changes.
                ZStack(alignment: .leading) {
                    Text("Blinder Off")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .opacity(appState.status == .idle ? 1 : 0)
                    
                    Text("Blinder On")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .opacity(appState.status == .idle ? 0 : 1)
                }
                .animation(.easeInOut(duration: 0.5), value: appState.status)
                
                Spacer()
                
                Picker("", selection: $selectedMode) {
                    Text("Select Focus Mode")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .tag(nil as String?)

                    ForEach(focusModel.modes) { mode in
                        Text(mode.name)
                            .tag(Optional(mode.id.uuidString))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    Divider()
                    
                    Text("Create New…")
                    .frame(maxWidth: 5)
                    .tag(Optional("New-mode"))
                }
                .pickerStyle(.menu)
                .frame(minWidth: 70, maxWidth: 190)
                .allowsHitTesting(appState.status == .idle)
                .opacity(appState.status == .idle ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: appState.status)
                .onChange(of: selectedMode) { value in
                    guard let value else { return }
                    if value == "New-mode" {
                        openWindow(id: "new-mode")
                        selectedMode = nil
                    } else if let id = UUID(uuidString: value) {
                        focusModel.selectedModeID = id
                    }
                }
                .onAppear {
                    if let id = focusModel.selectedModeID {
                        selectedMode = id.uuidString
                    }
                }
                .onChange(of: focusModel.selectedModeID) { id in
                    selectedMode = id?.uuidString
                }
            }
            // Force HStack to left.
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Duration + Start button row
            HStack {
                // Duration block
                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.status == .idle ? "Focus Duration (mins)" : "Focus Time Remaining:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .animation(.easeInOut(duration: 0.3), value: appState.status)
                    if appState.status == .idle {
                        HStack(alignment: .center, spacing: 8) {
                            Text(formatTime(durationSeconds))
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .frame(width: 140, height: 50)
                                .background(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary))
                                .multilineTextAlignment(.center)
                            
                            VStack(spacing: 6) {
                                Button {
                                    durationSeconds += 5 * 60   // add 5 minutes
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                                .buttonStyle(.borderless)
                                
                                Button {
                                    durationSeconds = max(60, durationSeconds - 5 * 60) // subtract 5 mins, min 1 min
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        // Else is the appState is .running:
                    } else {
                        HStack(alignment: .center, spacing: 8) {
                            Text(formatTime(remainingSeconds))
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .frame(width: 140, height: 50)
                                .background(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary))
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                
                Spacer()
                HStack {
                // Start button
                    VStack (alignment: .trailing) {
                        if let id = focusModel.selectedModeID,
                           let _ = focusModel.modes.first(where: { $0.id == id }) {
                            Button {
                                focusModel.editingModeID = id
                                openWindow(id: "edit-mode")
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil")
                                    Text("Edit Focus")
                                }
                                .font(.system(size: 14, weight: .regular))
                            }
                            .keyboardShortcut(.defaultAction)
                            .frame(alignment: .trailing)
                            .font(.system(size: 14, weight: .regular))
                            .buttonStyle(.borderedProminent)
                            .opacity((appState.status == .running || selectedMode == nil) ? 0.0 : 1.0)
                            .tint(.gray)
                            .controlSize(.large)
                            .disabled(focusModel.selectedModeID == nil || appState.status == .running || selectedMode == "placeholder")}
                        
                        Button(action: {
                            if appState.status == .running {
                                stopFocus()   // stop
                            } else {
                                startFocus()  // start
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: appState.status == .running ? "stop.fill" : "play.fill")
                                Text(appState.status == .running ? "Stop Focus" : "Start Focus")
                            }
                            .font(.system(size: 14, weight: .regular))
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .frame(alignment: .trailing)
                        .tint(appState.status == .running ? .red : .accentColor)
                        .controlSize(.large)
                        .disabled(focusModel.selectedModeID == nil)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(width: 440, height: 160)
    }

    // MARK: - Actions
    private func startFocus() {
        if let id = focusModel.selectedModeID,
               let mode = focusModel.modes.first(where: { $0.id == id }) {
                engine.start(mode: mode)
            }
        // Set timer with seconds indicated by user.
        remainingSeconds = durationSeconds
        appState.status = .running
        
        // Cancel ongoing timers.
        timerTask?.cancel()
        
        // start a 1s ticking task
        timerTask = Task { [weak appState] in
            while !Task.isCancelled, remainingSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    remainingSeconds -= 1
                }
            }
            // If remaining seconds hits 0, shut down.
            await MainActor.run {
                if remainingSeconds <= 0 {
                    appState?.status = .idle
                }
            }
        }
    }
    
    private func stopFocus() {
        engine.stop()
        timerTask?.cancel()
        timerTask = nil
        appState.status = .idle
        remainingSeconds = durationSeconds   // reset display to preset
    }
}
