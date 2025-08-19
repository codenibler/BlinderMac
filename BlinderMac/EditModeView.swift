import SwiftUI

struct EditModeView: View {
    @EnvironmentObject var focusModel: FocusConfigModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirm = false

    var body: some View {
        if let id = focusModel.editingModeID,
           let idx = focusModel.modes.firstIndex(where: { $0.id == id }) {
            let binding = $focusModel.modes[idx]

            VStack(spacing: 16) {
                    LabeledContent("Name") {
                        TextField("Name", text: binding.name)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity) // <-- expand field column
                    }
                    Section {
                        BlockedAppsEditor(selectedAppBundleIDs: binding.blockedApps)
                            .frame(minHeight: 140)
                            .frame(maxWidth: .infinity) // <-- allow full width
                    }
                    Section {
                        BlockedSitesEditor(blockedDomains: binding.blockedSites)
                            .frame(minHeight: 140)
                            .frame(maxWidth: .infinity)
                    }
                

                HStack {
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Text("Delete Focus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Spacer()

                    Button("Save Changes") {
                        focusModel.persist()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.thinMaterial)
            .frame(minWidth: 580) // give the window/content some width to fill
            .alert("Are you sure you want to delete this focus?",
                   isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    focusModel.deleteMode(id: id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        } else {
            Text("No mode selected to edit").padding()
        }
    }
}
// Same as the Blocked Apps editor when creating a new mode, with small changes.
struct BlockedAppsEditor: View {
    @Binding var selectedAppBundleIDs: Set<String>
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
                    selectedAppBundleIDs = Set(filteredApps.map(\.bundleID))
                }
                .buttonStyle(.bordered)

                Button("Clear") {
                    selectedAppBundleIDs.removeAll()
                }
                .buttonStyle(.bordered)

                Spacer()
                Text("\(selectedAppBundleIDs.count) selected")
                    .foregroundStyle(.secondary)
            }

            List {
                ForEach(filteredApps) { app in
                    AppRow(
                        app: app,
                        isSelected: selectedAppBundleIDs.contains(app.bundleID),
                        toggle: { toggle(app.bundleID) }
                    )
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
            .onAppear { catalog.loadIfNeeded() }
        }
    }

    private func toggle(_ bundleID: String) {
        if selectedAppBundleIDs.contains(bundleID) {
            selectedAppBundleIDs.remove(bundleID)
        } else {
            selectedAppBundleIDs.insert(bundleID)
        }
    }
}

struct BlockedSitesEditor: View {
    @Binding var blockedDomains: Set<String>
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
                ForEach(Array(blockedDomains), id: \.self) { domain in
                    HStack {
                        Text(domain)
                            .font(.system(size: 13))
                        Spacer()
                        Button {
                            blockedDomains.remove(domain)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove \(domain)")
                    }
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
        blockedDomains.insert(d)
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
        let pattern = #"^([a-z0-9-]+\.)+[a-z]{2,}$"#
        return d.range(of: pattern, options: .regularExpression) != nil
    }
}


#Preview {
    // Dummy model for preview
    let model = FocusConfigModel()
    model.addMode(named: "Preview Mode", blockedApps: ["com.apple.Safari"], blockedSites: ["twitter.com"])
    model.editingModeID = model.modes.first?.id

    return EditModeView()
        .environmentObject(model)
}



