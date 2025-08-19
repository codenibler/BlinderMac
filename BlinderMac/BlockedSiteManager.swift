import Foundation

final class PACManager {
    private var previousPACURL: URL?

    func enablePAC(blockedHosts: Set<String>, proxyPort: Int) {
        let pacJS = generatePAC(blocked: blockedHosts, port: proxyPort)
        let pacURL = writeTempPAC(pacJS)
        // Apply PAC to Wi-Fi (you can enumerate all services if you like)
        shell("/usr/sbin/networksetup", "-setautoproxyurl", "Wi-Fi", pacURL.absoluteString)
        shell("/usr/sbin/networksetup", "-setautoproxystate", "Wi-Fi", "on")
    }

    func disablePAC() {
        shell("/usr/sbin/networksetup", "-setautoproxystate", "Wi-Fi", "off")
    }

    private func generatePAC(blocked: Set<String>, port: Int) -> String {
        // Simple suffix test in PAC
        let arr = blocked.sorted().map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        function FindProxyForURL(url, host) {
          var blocked = [\(arr)];
          host = host.toLowerCase();
          for (var i=0; i<blocked.length; i++) {
            var d = blocked[i];
            if (host === d || host.endsWith("." + d)) {
              return "PROXY 127.0.0.1:\(port)";
            }
          }
          return "DIRECT";
        }
        """
    }

    private func writeTempPAC(_ js: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("focus.pac")
        try? js.data(using: .utf8)?.write(to: url)
        return url
    }

    @discardableResult
    private func shell(_ cmd: String, _ args: String...) -> Int32 {
        let p = Process()
        p.launchPath = cmd
        p.arguments = args
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }
}
