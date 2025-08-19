import Network

final class BlockProxy {
    private let port: NWEndpoint.Port
    private let listener: NWListener
    private let isBlockedHost: (String) -> Bool
    private let onBlockedHit: () -> Void

    init?(port: Int,
          isBlockedHost: @escaping (String) -> Bool,
          onBlockedHit: @escaping () -> Void) {
        guard let p = NWEndpoint.Port(rawValue: UInt16(port)),
              let l = try? NWListener(using: .tcp, on: p) else { return nil }
        self.port = p
        self.listener = l
        self.isBlockedHost = isBlockedHost
        self.onBlockedHit = onBlockedHit
    }

    func start() {
        listener.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }
        listener.start(queue: .global(qos: .userInitiated))
    }

    func stop() {
        listener.cancel()
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: .global(qos: .userInitiated))
        // Read the first line (HTTP request line or CONNECT) + headers (small buffer)
        readLine(conn) { [weak self] requestLine in
            guard let self = self, let line = requestLine else { conn.cancel(); return }
            if line.hasPrefix("CONNECT ") {
                // HTTPS tunnel: CONNECT host:443 HTTP/1.1
                let host = line.split(separator: " ")[1].split(separator: ":").first.map(String.init) ?? ""
                if self.isBlockedHost(host) {
                    self.onBlockedHit()
                    // Reject: close without establishing tunnel
                    conn.cancel()
                    return
                }
            } else {
                // HTTP: GET /... ; we need Host header
                self.readHeaders(conn) { headers in
                    let host = headers["host"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                    if self.isBlockedHost(host) {
                        self.onBlockedHit()
                        // respond with minimal 403 plain text and close
                        let resp = "HTTP/1.1 403 Forbidden\r\nConnection: close\r\nContent-Length: 0\r\n\r\n"
                        conn.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in
                            conn.cancel()
                        })
                    } else {
                        // Not handling pass-through (MVP blocks only); close.
                        conn.cancel()
                    }
                }
            }
        }
    }

    private func readLine(_ conn: NWConnection, completion: @escaping (String?) -> Void) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 2048) { data, _, isComplete, _ in
            guard let data = data, !data.isEmpty,
                  let s = String(data: data, encoding: .utf8),
                  let line = s.components(separatedBy: "\r\n").first
            else { completion(nil); return }
            completion(line)
        }
    }

    private func readHeaders(_ conn: NWConnection, completion: @escaping ([String:String]) -> Void) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
            var result: [String:String] = [:]
            if let data = data, let s = String(data: data, encoding: .utf8) {
                for row in s.components(separatedBy: "\r\n") {
                    if row.isEmpty { break }
                    if let sep = row.firstIndex(of: ":") {
                        let key = row[..<sep].lowercased()
                        let val = row[row.index(after: sep)...]
                        result[String(key)] = String(val)
                    }
                }
            }
            completion(result)
        }
    }
}
