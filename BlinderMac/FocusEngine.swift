// Engine that watches over active apps and terminates them if active.
import AppKit

@MainActor
final class FocusEngine: ObservableObject {
    private var appLaunchObserver: Any?
    private var appActivateObserver: Any?
    private var pollTask: Task<Void, Never>?

    private var blockedApps = Set<String>()
    private var modeName = ""

    // Just in case we plan to explode ourselves....
    private let allowlist: Set<String> = [
        Bundle.main.bundleIdentifier ?? "",
        "com.apple.finder",
        "com.apple.Terminal"
    ]

    // Called when Start Focus is called, with mode name passed in,.
    func start(mode: FocusMode) {
        blockedApps = mode.blockedApps.subtracting(allowlist) // In case. Don't block allowed apps.
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

        // Immediatelyn scan all active apps and delete those on block list.
        sweepAllRunning()

        // Keep sweeping front and background every second to terminate.
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1000_000_000)
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

    // Not only Frontmost app, but delete ALL blocked apps running.
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
