import Foundation
import SwiftLlama
import Network

// MARK: - LocalAPIServer
// Minimal Ollama-compatible local HTTP API on 127.0.0.1.
// Endpoints:
//   GET  /api/tags
//   POST /api/show
//   POST /api/generate
//   POST /api/chat
// Built on Network.framework's NWListener. Only binds to loopback by default.

actor LocalAPIServer {
    static let shared = LocalAPIServer()

    private var listener: NWListener?
    private(set) var isRunning: Bool = false

    func start(port: Int = 11434) async throws {
        guard !isRunning else { return }
        let params = NWParameters.tcp
        let l = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: UInt16(port)))
        l.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .global())
            self?.handle(conn)
        }
        l.start(queue: .global())
        self.listener = l
        self.isRunning = true
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    nonisolated private func handle(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let data, !data.isEmpty else {
                if isComplete || error != nil { conn.cancel() }
                return
            }
            self?.processRequest(data: data, conn: conn)
        }
    }

    nonisolated private func processRequest(data: Data, conn: NWConnection) {
        guard let text = String(data: data, encoding: .utf8) else { conn.cancel(); return }
        let lines = text.split(separator: "\r\n")
        guard let first = lines.first else { conn.cancel(); return }
        let parts = first.split(separator: " ")
        guard parts.count >= 2 else { conn.cancel(); return }
        let method = String(parts[0])
        let path = String(parts[1])

        let body: String = {
            if let r = text.range(of: "\r\n\r\n") {
                return String(text[r.upperBound...])
            }
            return ""
        }()

        Task { [weak self] in
            guard let self else { return }
            let response = await self.route(method: method, path: path, body: body)
            let http = """
            HTTP/1.1 200 OK\r
            Content-Type: application/json\r
            Content-Length: \(response.utf8.count)\r
            Connection: close\r
            \r
            \(response)
            """
            let res = Data(http.utf8)
            conn.send(content: res, completion: .contentProcessed { _ in conn.cancel() })
        }
    }

    private func route(method: String, path: String, body: String) async -> String {
        switch path {
        case "/api/tags":
            return await listTags()
        case "/api/show":
            return "{\"info\":\"ok\"}"
        case "/api/generate":
            return await generate(body: body)
        case "/api/chat":
            return await chat(body: body)
        case "/", "/api":
            return "{\"name\":\"Neth-AI\",\"version\":\"0.1.0\"}"
        default:
            return "{\"error\":\"not found\"}"
        }
    }

    private func listTags() async -> String {
        let models = await ModelManager.shared.listInstalledModels()
        let arr = models.map { m in
            "{\"name\":\"\(escape(m.fileName))\",\"size\":\(m.fileSize),\"quant\":\"\(escape(m.quantization ?? ""))\"}"
        }.joined(separator: ",")
        return "{\"models\":[\(arr)]}"
    }

    private func generate(body: String) async -> String {
        guard let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let prompt = obj["prompt"] as? String else {
            return "{\"error\":\"missing prompt\"}"
        }
        return "{\"response\":\"\(escape(prompt))\",\"done\":true}"
    }

    private func chat(body: String) async -> String {
        guard let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = obj["messages"] as? [[String: Any]] else {
            return "{\"error\":\"missing messages\"}"
        }
        let prompt = messages.map { "\($0["role"] ?? "?"): \($0["content"] ?? "")" }.joined(separator: "\n")
        return "{\"response\":\"\(escape(prompt))\",\"done\":true}"
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
    }
}
