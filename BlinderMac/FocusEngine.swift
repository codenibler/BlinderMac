import AppKit

final class FocusEngine: ObservableObject {
    private var appLaunchObserver: Any?
    private var appActivateObserver: Any?
    private var pollTask: Task<Void, Never>?

    private var blockedApps = Set<String>()
    private var blockedSites = Set<String>()
    private var modeName = ""

    func start(mode: FocusMode) {
        blockedApps = mode.blockedApps
        blockedSites = mode.blockedSites
        modeName = mode.name
        startAppBlocking()
        startWebBlocking()   // defined in section 3
    }

    func stop() {
        stopAppBlocking()
        stopWebBlocking()
    }

    // MARK: Apps
    private func startAppBlocking() {
        let nc = NSWorkspace.shared.notificationCenter
        appLaunchObserver = nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] n in
            self?.handleAppEvent(n)
        }
        appActivateObserver = nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            self?.handleAppEvent(n)
        }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await self?.checkFrontmost()
            }
        }
    }

    private func stopAppBlocking() {
        let nc = NSWorkspace.shared.notificationCenter
        if let o = appLaunchObserver { nc.removeObserver(o) }
        if let o = appActivateObserver { nc.removeObserver(o) }
        appLaunchObserver = nil; appActivateObserver = nil
        pollTask?.cancel(); pollTask = nil
    }

    private func handleAppEvent(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bid = app.bundleIdentifier
        else { return }

        if blockedApps.contains(bid) {
            app.terminate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { app.forceTerminate() }
            Notifier.remindFocusOn(modeName: modeName)
        }
    }

    @MainActor private func checkFrontmost() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bid = app.bundleIdentifier else { return }
        if blockedApps.contains(bid) {
            app.terminate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { app.forceTerminate() }
            Notifier.remindFocusOn(modeName: modeName)
        }
    }

    // MARK: Web (PAC + local proxy)
    private var pacManager = PACManager()
    private var proxy: BlockProxy?

    private func startWebBlocking() {
        // Start a tiny local proxy and point PAC to it
        let port = 9876
        proxy = BlockProxy(port: port, isBlockedHost: { [weak self] host in
            guard let self = self else { return false }
            return self.matchesBlocked(host)
        }, onBlockedHit: { [weak self] in
            guard let self = self else { return }
            Notifier.remindFocusOn(modeName: self.modeName)
        })
        proxy?.start()
        pacManager.enablePAC(blockedHosts: blockedSites, proxyPort: port)
    }

    private func stopWebBlocking() {
        proxy?.stop(); proxy = nil
        pacManager.disablePAC()
    }

    private func matchesBlocked(_ host: String) -> Bool {
        // suffix match: example.com blocks foo.example.com too
        let h = host.lowercased()
        return blockedSites.contains(where: { d in h == d || h.hasSuffix("." + d) })
    }
}
