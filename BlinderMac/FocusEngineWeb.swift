import AppKit

extension FocusEngine {
    enum WebAction {
        case closeTab
        case navigateToBlank
    }

    func startWebBlockingAutomation(action: WebAction = .navigateToBlank,
                                    blockedDomains: Set<String>) {
        self.blockedSites = blockedDomains
        self.webAction = action
        startBrowserWatcher()
    }

    func stopWebBlockingAutomation() {
        webPollTask?.cancel(); webPollTask = nil
    }
}

// MARK: - Private impl
private extension FocusEngine {
    enum Browser: String {
        case safari = "com.apple.Safari"
        case chrome = "com.google.Chrome"
        case brave  = "com.brave.Browser"
        case edge   = "com.microsoft.edgemac"
    }

    var bundleToBrowser: [String: Browser] {
        [
            Browser.safari.rawValue: .safari,
            Browser.chrome.rawValue: .chrome,
            Browser.brave .rawValue: .brave,
            Browser.edge  .rawValue: .edge
        ]
    }

    static let tickNs: UInt64 = 400_000_000 // 0.4s
    var frontBrowser: Browser? {
        guard let bid = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        else { return nil }
        return bundleToBrowser[bid]
    }

    func startBrowserWatcher() {
        webPollTask?.cancel()
        webPollTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.tickNs)
                await MainActor.run { self.inspectFrontBrowser() }
            }
        }
    }

    @MainActor
    func inspectFrontBrowser() {
        guard let browser = frontBrowser else { return }
        guard let url = getFrontURL(browser: browser) else { return }
        if isBlockedURL(url) {
            switch webAction {
            case .closeTab:
                _ = closeFrontTab(browser: browser)
            case .navigateToBlank:
                _ = setFrontURL(browser: browser, to: "about:blank")
            }
        }
    }

    func isBlockedURL(_ urlString: String) -> Bool {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return false }
        return blockedSites.contains(where: { d in host == d || host.hasSuffix("." + d) })
    }

    // AppleScript helpers
    @discardableResult
    func getFrontURL(browser: Browser) -> String? {
        let script: String
        switch browser {
        case .safari:
            script = """
            tell application id "com.apple.Safari"
                if (count of windows) = 0 then return ""
                return URL of current tab of front window
            end tell
            """
        case .chrome, .brave, .edge:
            let bid: String = {
                switch browser {
                case .chrome: return "com.google.Chrome"
                case .brave:  return "com.brave.Browser"
                case .edge:   return "com.microsoft.edgemac"
                case .safari: return "com.apple.Safari" // not used in this branch
                }
            }()
            script = """
            tell application id "\(bid)"
                if (count of windows) = 0 then return ""
                return URL of active tab of front window
            end tell
            """
        }
        return runAppleScript(script)?.stringValue
    }

    @discardableResult
    func setFrontURL(browser: Browser, to newURL: String) -> Bool {
        let script: String
        switch browser {
        case .safari:
            script = """
            tell application id "com.apple.Safari"
                if (count of windows) = 0 then return false
                set URL of current tab of front window to "\(newURL)"
                return true
            end tell
            """
        case .chrome, .brave, .edge:
            let bid: String = {
                switch browser {
                case .chrome: return "com.google.Chrome"
                case .brave:  return "com.brave.Browser"
                case .edge:   return "com.microsoft.edgemac"
                case .safari: return "com.apple.Safari" // not used in this branch
                }
            }()
            script = """
            tell application id "\(bid)"
                if (count of windows) = 0 then return false
                set URL of active tab of front window to "\(newURL)"
                return true
            end tell
            """
        }
        return runAppleScript(script)?.booleanValue ?? false
    }

    @discardableResult
    func closeFrontTab(browser: Browser) -> Bool {
        let script: String
        switch browser {
        case .safari:
            script = """
            tell application id "com.apple.Safari"
                if (count of windows) = 0 then return false
                close current tab of front window
                return true
            end tell
            """
        case .chrome, .brave, .edge:
            let bid: String = {
                switch browser {
                case .chrome: return "com.google.Chrome"
                case .brave:  return "com.brave.Browser"
                case .edge:   return "com.microsoft.edgemac"
                case .safari: return "com.apple.Safari" // not used in this branch
                }
            }()
            script = """
            tell application id "\(bid)"
                if (count of windows) = 0 then return false
                close active tab of front window
                return true
            end tell
            """
        }
        return runAppleScript(script)?.booleanValue ?? false
    }


    func runAppleScript(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)
        if let error { print("AppleScript error:", error) }
        return result
    }
}
