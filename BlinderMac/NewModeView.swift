import SwiftUI
import AppKit

// Three pieces of information we collect throughout the wizard.
final class NewModeDraft: ObservableObject {
    @Published var selectedAppBundleIDs: Set<String> = []
    @Published var blockedDomains: [String] = []
    @Published var modeName: String = ""    // finalized in step 3
}

// Three steps we must pass.
private enum Step: Int, CaseIterable {
    case apps, websites, confirm
    var title: String {
        switch self {
        case .apps: "Blocked Apps"
        case .websites: "Blocked Websites"
        case .confirm: "Confirm & Name"
        }
    }
}

// Wizard container, determines step of new mode creation.
struct NewModeWizardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var draft = NewModeDraft()
    @State private var step: Step = .apps
    // Allow storing new focus modes.
    @EnvironmentObject var focusModel: FocusConfigModel

    // Ability to open new windows.
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss


    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                if step.title != "Confirm & Name" {
                    Text(step.title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("Step \(step.rawValue + 1) of \(Step.allCases.count)")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }

            // Content
            Group {
                switch step {
                case .apps:
                    BlockedAppsStep(draft: draft)
                case .websites:
                    BlockedWebsitesStep(draft: draft)
                case .confirm:
                    ConfirmAndNameStep(draft: draft)
                }
            }

            Divider()

            // Footer controls
            HStack {
                Button("Back") { goBack() }
                    .disabled(step == .apps)

                Spacer()

                if step == .confirm {
                    Button("Create") {
                    focusModel.addMode(
                                named: draft.modeName.trimmingCharacters(in: .whitespacesAndNewlines),
                                blockedApps: draft.selectedAppBundleIDs,
                                blockedSites: Set(draft.blockedDomains)
                            )
                            dismiss()
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.modeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button("Next") { goNext() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canProceed(step))
                }
            }
        }
        .padding(16)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .toolbar(.visible, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbarBackground(.thinMaterial, for: .windowToolbar)
        .frame(minWidth: step.title == "Confirm & Name" ? 200 : 400, minHeight:  step.title == "Confirm & Name" ? 0 : 500)
        .background(
                WindowConfigurator { w in
                    w.isOpaque = false
                    w.backgroundColor = .clear
                    w.titlebarAppearsTransparent = true
                }
            )
    }

    // MARK: - Navigation rules

    private func canProceed(_ step: Step) -> Bool {
        switch step {
        case .apps:
            return !draft.selectedAppBundleIDs.isEmpty
        case .websites:
            return true
        case .confirm:
            return !draft.modeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func goNext() {
        switch step {
        case .apps: step = .websites
        case .websites: step = .confirm
        case .confirm: return
        }
    }

    private func goBack() {
        switch step {
        case .apps: break
        case .websites: step = .apps
        case .confirm: step = .websites
        }
    }
}


struct BlockedAppsStep: View {
    @ObservedObject var draft: NewModeDraft
    @StateObject private var catalog = AppCatalog()

    private var filteredApps: [AppInfo] {
        let q = catalog.search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return catalog.allApps }
        return catalog.allApps.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            $0.bundleID.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button("Select All (filtered)") {
                    draft.selectedAppBundleIDs = Set(filteredApps.map(\.bundleID))
                }
                .buttonStyle(.bordered)

                Button("Clear") {
                    draft.selectedAppBundleIDs.removeAll()
                }
                .buttonStyle(.bordered)

                Spacer()
                Text("\(draft.selectedAppBundleIDs.count) selected")
                    .foregroundStyle(.secondary)
            }

            List {
                ForEach(filteredApps) { app in
                    AppRow(
                        app: app,
                        isSelected: draft.selectedAppBundleIDs.contains(app.bundleID),
                        toggle: { toggle(app.bundleID) }
                    )
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(
                VisualEffectBackground(material: .sidebar) // or .popover
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            .searchable(text: $catalog.search, placement: .toolbar, prompt: "Search apps or bundle IDs")
            .onAppear { catalog.loadIfNeeded() }
        }
    }

    private func toggle(_ bundleID: String) {
        if draft.selectedAppBundleIDs.contains(bundleID) {
            draft.selectedAppBundleIDs.remove(bundleID)
        } else {
            draft.selectedAppBundleIDs.insert(bundleID)
        }
    }
}


struct BlockedWebsitesStep: View {
    @ObservedObject var draft: NewModeDraft
    @State private var newDomain: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("Add domain (e.g. twitter.com)", text: $newDomain)
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 32)
                    .onSubmit(addDomain)

                Button("Add") { addDomain() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValidDomain(newDomain))
            }

            List {
                ForEach(Array(draft.blockedDomains.enumerated()), id: \.offset) { idx, domain in
                    HStack {
                        Text(domain)
                            .font(.system(size: 13))
                        Spacer()
                        Button {
                            draft.blockedDomains.remove(at: idx)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove \(domain)")
                    }
                }
                .onMove { indices, newOffset in
                    draft.blockedDomains.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(
                VisualEffectBackground(material: .sidebar)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            
            Text("Domains are matched by suffix (Blocking youtube.com also blocks all of YouTube's subdomains).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func addDomain() {
        let d = normalizedDomain(newDomain)
        guard isValidDomain(d) else { return }
        if !draft.blockedDomains.contains(d) {
            draft.blockedDomains.append(d)
        }
        newDomain = ""
    }

    private func normalizedDomain(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
         .lowercased()
         .replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
         .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func isValidDomain(_ s: String) -> Bool {
        let d = normalizedDomain(s)
        // simple domain regex; adjust as needed
        let pattern = #"^([a-z0-9-]+\.)+[a-z]{2,}$"#
        return d.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Step 3: Confirm & Name

struct ConfirmAndNameStep: View {
    @ObservedObject var draft: NewModeDraft
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack() {
                Text("Confirm & Name")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Spacer()
                TextField("e.g. Maximum Hustle Mode", text: $draft.modeName)
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 36)
            }
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Summary")
                        .font(.headline)
                    Text("Apps blocked: \(draft.selectedAppBundleIDs.count)")
                    Text("Websites blocked: \(draft.blockedDomains.count)")
                }
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                VisualEffectBackground(material: .sidebar)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            )
        }
    }
}
// MARK: - Shared Row

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
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .help(app.url.path)
    }
}

// 2 helper functions to make the 3 windows translucent like the menu bar.
struct WindowConfigurator: NSViewRepresentable {
    let configure: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let win = nsView.window { configure(win) }
        }
    }
}
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blending: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = state
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}
