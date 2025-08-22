//
//  BrowserPermissions.swift
//  BlinderMac
//
//  Created by Angel Barrio on 22/08/2025.
//

import AppKit

// 1) Candidate browsers you want to support (add more if needed)
private let candidateBrowsers: [String: String] = [
    "Safari": "com.apple.Safari",
    "Safari Technology Preview": "com.apple.SafariTechnologyPreview",
    "Brave": "com.brave.Browser",
    "Brave Beta": "com.brave.Browser.beta",
    "Google Chrome": "com.google.Chrome",
    "Google Chrome Beta": "com.google.Chrome.beta",
    "Google Chrome Canary": "com.google.Chrome.canary",
    "Microsoft Edge": "com.microsoft.edgemac",
    "Arc": "company.thebrowser.Browser"
]

// 2) Find which of those are actually installed
func installedBrowsers() -> [(name: String, bundleID: String, url: URL)] {
    candidateBrowsers.compactMap { name, bid in
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            return (name, bid, url)
        }
        return nil
    }
}

// 3) Onboarding gate: ask once on first run; store per-browser result
final class AutomationOnboarding {
    static let shared = AutomationOnboarding()
    private let askedKey = "AutomationAskedBundleIDs" // [String] of bundle IDs

    func notYetAsked(_ bundleID: String) -> Bool {
        let asked = (UserDefaults.standard.array(forKey: askedKey) as? [String]) ?? []
        return !asked.contains(bundleID)
    }
    private func markAsked(_ bundleID: String) {
        var asked = (UserDefaults.standard.array(forKey: askedKey) as? [String]) ?? []
        if !asked.contains(bundleID) { asked.append(bundleID) }
        UserDefaults.standard.set(asked, forKey: askedKey)
    }

    // Present your own UI to let user pick which browsers to pre-authorize.
    // For demo purposes, we request for all installed browsers not yet asked.
    func requestForInstalledBrowsers() {
        let targets = installedBrowsers().filter { notYetAsked($0.bundleID) }
        guard !targets.isEmpty else { return }

        // Show a sheet/panel explaining what will happen, then on "Continue":
        // (1) Launch hidden (optional), (2) Send harmless AE to trigger prompt, (3) Mark asked
        for (idx, t) in targets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(350 * idx)) {
                self.triggerAutomationPrompt(bundleID: t.bundleID, appURL: t.url)
                self.markAsked(t.bundleID)
            }
        }
    }

    private func triggerAutomationPrompt(bundleID: String, appURL: URL) {
        // Optional: Launch hidden to avoid window focus stealing
        var conf = NSWorkspace.OpenConfiguration()
        conf.activates = false
        conf.hides = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: conf) { app, error in
            // Even if launch fails or app is already running, attempt the AE.
            sendHarmlessAppleEvent(toBundleID: bundleID)
        }
    }
}
