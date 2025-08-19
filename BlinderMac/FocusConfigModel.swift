import Foundation
import SwiftUI

// MARK: - Domain model
struct FocusMode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var blockedApps: Set<String>
    var blockedSites: Set<String>

    init(id: UUID = UUID(),
         name: String,
         blockedApps: Set<String> = [],
         blockedSites: Set<String> = []) {
        self.id = id
        self.name = name
        self.blockedApps = blockedApps
        self.blockedSites = blockedSites
    }
}

// Snapshot on disk
struct FocusSnapshot: Codable {
    var modes: [FocusMode]
    var selectedModeID: UUID?
}

// MARK: - JSON store
final class FocusStore {
    private let fm = FileManager.default
    private let filename = "FocusConfig.json"

    private var url: URL {
        let appSupport = try! fm.url(for: .applicationSupportDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil,
                                     create: true)
        let dir = appSupport.appendingPathComponent(Bundle.main.bundleIdentifier ?? "Blinder",
                                                    isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(filename)
    }

    func load() -> FocusSnapshot {
        guard let data = try? Data(contentsOf: url) else {
            return .init(modes: [FocusMode(name: "Test")], selectedModeID: nil)
        }
        return (try? JSONDecoder().decode(FocusSnapshot.self, from: data))
            ?? .init(modes: [FocusMode(name: "Test")], selectedModeID: nil)
    }

    func save(_ snapshot: FocusSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("FocusStore save error:", error)
        }
    }

    func deleteFile() {
        try? fm.removeItem(at: url)
    }
}

// MARK: - Main model
final class FocusConfigModel: ObservableObject {
    @Published var modes: [FocusMode]
    @Published var selectedModeID: UUID?
    @Published var editingModeID: UUID? = nil   // to track current edit target

    private let store = FocusStore()

    init() {
        let snap = store.load()
        modes = snap.modes
        selectedModeID = snap.selectedModeID
    }

    func addMode(named name: String,
                 blockedApps: Set<String>,
                 blockedSites: Set<String>) {
        let mode = FocusMode(name: name,
                             blockedApps: blockedApps,
                             blockedSites: blockedSites)
        modes.append(mode)
        selectedModeID = mode.id
        persist()
    }

    func renameMode(id: UUID, to newName: String) {
        guard let idx = modes.firstIndex(where: { $0.id == id }) else { return }
        modes[idx].name = newName
        persist()
    }

    func deleteMode(id: UUID) {
        modes.removeAll { $0.id == id }
        if selectedModeID == id {
            selectedModeID = modes.first?.id
        }
        if editingModeID == id {
            editingModeID = nil
        }
        persist()
    }

    func persist() {
        store.save(.init(modes: modes, selectedModeID: selectedModeID))
    }
}
