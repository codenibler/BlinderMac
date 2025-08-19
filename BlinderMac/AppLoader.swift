// Loads all of the apps to be picked from for blocking.
import SwiftUI
import AppKit

// Struct holding information on an app.
struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleID: String
    let url: URL
    let icon: NSImage?
}

@MainActor
final class AppCatalog: ObservableObject {
    @Published var allApps: [AppInfo] = []
    @Published var search: String = ""
    @Published var selectedBundleIDs: Set<String> = []
    
    private var isLoaded = false
    
    // Little guard before calling main lgoic to find all downloaded apps
    func loadIfNeeded() {
        guard !isLoaded else { return }
        // Once called, set isLoaded = 1 to avoid calling again.
        isLoaded = true
        Task { @MainActor in
            self.allApps = await Self.discoverInstalledApps()
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
    
    // Main logic searching for downloaded aps.
    // Looks in common directories.
    static func discoverInstalledApps() async -> [AppInfo] {
        // FileManager can access local directories.
        let fm = FileManager.default
        let mainBundleID = Bundle.main.bundleIdentifier
        let searchDirs: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Applications"),
        ]
        
        // Loop through directories, inside of each loop through results and
        var found: [String: AppInfo] = [:] // key: bundleID
        for dir in searchDirs {
            guard let e = fm.enumerator(at: dir, // .enumerator at:dir returns every file within dir.
                                        includingPropertiesForKeys: [.isDirectoryKey],
                                        // else {continue}: If we can't access dir, skip.
                                        options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            
            // While there are more objects available, loop.
            while let obj = e.nextObject() as? URL {
                // However if object is not an app, skip.
                guard obj.pathExtension == "app" else { continue }
                if let bundle = Bundle(url: obj),
                   // Grab bundleID
                   let bid = bundle.bundleIdentifier,
                   bid != mainBundleID,
                !bid.hasPrefix("com.apple.") {
                    // Grab app name
                    let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? obj.deletingPathExtension().lastPathComponent
                    // Grab app Icon
                    let icon = NSWorkspace.shared.icon(forFile: obj.path)
                    icon.size = NSSize(width: 24, height: 24)
                    // Fill AppInfo struct with information found, loop again.
                    found[bid] = AppInfo(name: name, bundleID: bid, url: obj, icon: icon)
                }
            }
        }
        return Array(found.values)
    }
}

