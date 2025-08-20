import AppKit

@MainActor
final class FocusEngine: ObservableObject {
    private var appLaunchObserver: Any?
    private var appActivateObserver: Any?
    private var pollTask: Task<Void, Never>?

    private var blockedApps = Set<String>()
    private var modeName = ""

    // Optional safety allowlist so you don't nuke yourself/Finder/etc.
    private let allowlist: Set<String> = [
        Bundle.main.bundleIdentifier ?? "",
        "com.apple.finder",
        "com.apple.Terminal"
    ]

    func start(mode: FocusMode) {
        blockedApps = mode.blockedApps.subtracting(allowlist) // never block allowlisted
        modeName = mode.name
        startAppBlocking()
    }

    func stop() {
        stopAppBlocking()
    }

    // MARK: - Apps
    private func startAppBlocking() {
        let nc = NSWorkspace.shared.notificationCenter
        appLaunchObserver = nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                                           object: nil, queue: .main) { [weak self] n in
            self?.handleAppEvent(n)
        }
        appActivateObserver = nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                             object: nil, queue: .main) { [weak self] n in
            self?.handleAppEvent(n)
        }

        // Kick off an immediate sweep so already-running background apps get killed now.
        sweepAllRunning()

        // Keep sweeping periodically (background + frontmost safety belt)
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 700_000_000) // ~0.7s
                await self?.sweepAllRunning()
            }
        }
    }

    private func stopAppBlocking() {
        let nc = NSWorkspace.shared.notificationCenter
        if let o = appLaunchObserver { nc.removeObserver(o) }
        if let o = appActivateObserver { nc.removeObserver(o) }
        appLaunchObserver = nil
        appActivateObserver = nil
        pollTask?.cancel()
        pollTask = nil
    }

    private func handleAppEvent(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bid = app.bundleIdentifier else { return }
        if shouldBlock(bid) { kill(app) }
    }

    /// Sweep EVERYTHING, not just the frontmost app.
    @MainActor
    private func sweepAllRunning() {
        for app in NSWorkspace.shared.runningApplications {
            guard let bid = app.bundleIdentifier else { continue }
            if shouldBlock(bid) {
                kill(app)
            }
        }
    }

    private func shouldBlock(_ bundleID: String) -> Bool {
        guard !allowlist.contains(bundleID) else { return false }
        return blockedApps.contains(bundleID)
    }

    private func kill(_ app: NSRunningApplication) {
        // Try a graceful terminate; follow-up with forceTerminate shortly after.
        app.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak app, modeName] in
            guard let app, !app.isTerminated else { return }
            app.forceTerminate()
            Notifier.remindFocusOn(modeName: modeName)
        }
    }
}
