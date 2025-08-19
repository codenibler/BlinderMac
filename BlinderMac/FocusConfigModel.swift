import Foundation
import SwiftUI

// MARK: - Domain model
struct FocusMode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var blockedApps: Set<String>         // bundle IDs, e.g. "com.apple.Safari"
    var blockedSites: Set<String>        // domains/URL patterns
    // add more: schedules, timers, notes, etc.

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

// MARK: - JSON store (same idea as before, now saving full modes)
final class FocusStore {
    private let fm = FileManager.default
    private let filename = "FocusConfig.json"

    private var url: URL {
        let appSupport = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = appSupport.appendingPathComponent(Bundle.main.bundleIdentifier ?? "Blinder", isDirectory: true)
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
}


final class FocusConfigModel: ObservableObject {
    @Published var modes: [FocusMode]
    @Published var selectedModeID: UUID?

    private let store = FocusStore()

    init() {
        // FOR NOW, DO NOT INITIALIZE WITH JSON FILES FROM MEMORY. TEST
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
        // FOR NOW, we do not wish to persist.
        //persist()
    }

    func persist() {
        store.save(.init(modes: modes, selectedModeID: selectedModeID))
    }
}
