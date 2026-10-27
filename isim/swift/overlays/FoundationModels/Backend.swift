// isim Foundation Models: the model behind SystemLanguageModel (passthrough, issue #277). isim has no Apple model; it
// talks to a local OpenAI-compatible server instead:
//   - ISIM_LLM_URL=http://127.0.0.1:8080/v1: a running server (llama.cpp's llama-server, Ollama's /v1, LM Studio,
//     vLLM), with ISIM_LLM_MODEL naming its model if it needs one;
//   - ISIM_LLM_MODEL=/path/model.gguf without ISIM_LLM_URL: isim starts llama.cpp's llama-server with that model on the
//     host (runtime/host_llm.c) and talks to it.
// Requests use /chat/completions with streaming (server-sent events): the instructions as the system message, the
// transcript's turns, JSON Schema `response_format` for Generable responses and `tools` for the session's tools.
import Foundation
import isim_host

@available(iOS 26.0, macOS 26.0, *)
struct _ChatMessage {
    var role: String
    var content: String?
    var toolCalls: [(id: String, name: String, arguments: String)] = []
    var toolCallID: String? = nil
    var json: [String: Any] {
        var d: [String: Any] = ["role": role]
        d["content"] = content ?? NSNull()
        if !toolCalls.isEmpty {
            d["tool_calls"] = toolCalls.map { ["id": $0.id, "type": "function", "function": ["name": $0.name, "arguments": $0.arguments]] }
        }
        if let toolCallID { d["tool_call_id"] = toolCallID }
        return d
    }
}
/// what a request produces: the text so far, or the tool calls the model asks for
@available(iOS 26.0, macOS 26.0, *)
enum _BackendEvent: Sendable {
    case text(String)
    case toolCalls([(id: String, name: String, arguments: String)])
}
@available(iOS 26.0, macOS 26.0, *)
protocol _LanguageModelBackend: Sendable {
    var name: String { get }
    func generate(messages: [_ChatMessage], tools: [any Tool], schema: GenerationSchema?, options: GenerationOptions) -> AsyncThrowingStream<_BackendEvent, Error>
}

@available(iOS 26.0, macOS 26.0, *)
struct _OpenAICompatibleBackend: _LanguageModelBackend, @unchecked Sendable {
    let base: URL
    let model: String
    var name: String { base.absoluteString }

    func body(_ messages: [_ChatMessage], _ tools: [any Tool], _ schema: GenerationSchema?, _ o: GenerationOptions) -> [String: Any] {
        var b: [String: Any] = ["model": model, "messages": messages.map(\.json), "stream": true]
        if let t = o.temperature { b["temperature"] = t }
        if let n = o.maximumResponseTokens { b["max_tokens"] = n }
        switch o.sampling?._kind {
        case .greedy?: b["temperature"] = 0; b["top_k"] = 1
        case .top(let k, let seed)?: b["top_k"] = k; if let seed { b["seed"] = seed }
        case .probability(let p, let seed)?: b["top_p"] = p; if let seed { b["seed"] = seed }
        case nil: break
        }
        if let schema {
            b["response_format"] = ["type": "json_schema",
                                    "json_schema": ["name": Transcript.ResponseFormat(schema: schema).name, "strict": true, "schema": schema._jsonObject]]
        }
        if !tools.isEmpty {
            b["tools"] = tools.map { ["type": "function", "function": ["name": $0.name, "description": $0.description, "parameters": $0.parameters._jsonObject]] }
            switch o._toolCallingMode {                       // GenerationOptions.ToolCallingMode (iOS 27)
            case "disallowed"?: b["tool_choice"] = "none"
            case "required"?: b["tool_choice"] = "required"
            case "allowed"?: b["tool_choice"] = "auto"
            default: break
            }
        }
        return b
    }

    func generate(messages: [_ChatMessage], tools: [any Tool], schema: GenerationSchema?, options: GenerationOptions) -> AsyncThrowingStream<_BackendEvent, Error> {
        let payload = body(messages, tools, schema, options)
        let url = base.appendingPathComponent("chat/completions")
        return AsyncThrowingStream { cont in
            let task = Task {
                do {
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    if let key = ProcessInfo.processInfo.environment["ISIM_LLM_API_KEY"], !key.isEmpty {
                        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    }
                    req.httpBody = try JSONSerialization.data(withJSONObject: payload)
                    req.timeoutInterval = 600
                    let (bytes, response): (URLSession.AsyncBytes, URLResponse)
                    do { (bytes, response) = try await URLSession.shared.bytes(for: req) } catch {
                        throw LanguageModelSession.GenerationError.assetsUnavailable(.init(debugDescription: "the language model server at \(base.absoluteString) is not reachable: \(error.localizedDescription)"))
                    }
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 200
                    if status != 200 {
                        var text = ""
                        for try await line in bytes.lines { text += line; if text.count > 2000 { break } }
                        let ctx = LanguageModelSession.GenerationError.Context(debugDescription: "the language model server answered \(status): \(text)")
                        switch status {
                        case 429: throw LanguageModelSession.GenerationError.rateLimited(ctx)
                        case 400 where text.lowercased().contains("context"): throw LanguageModelSession.GenerationError.exceededContextWindowSize(ctx)
                        default: throw LanguageModelSession.GenerationError.assetsUnavailable(ctx)
                        }
                    }
                    var text = ""
                    var calls: [Int: (id: String, name: String, arguments: String)] = [:]
                    var plain = ""                                    // a server that does not stream: one JSON body
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { plain += line; continue }
                        let data = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if data == "[DONE]" { break }
                        guard let o = try? JSONSerialization.jsonObject(with: Data(data.utf8)) as? [String: Any],
                              let choice = (o["choices"] as? [[String: Any]])?.first else { continue }
                        let delta = choice["delta"] as? [String: Any] ?? choice["message"] as? [String: Any] ?? [:]
                        if let piece = delta["content"] as? String, !piece.isEmpty { text += piece; cont.yield(.text(text)) }
                        for c in delta["tool_calls"] as? [[String: Any]] ?? [] {
                            let i = c["index"] as? Int ?? calls.count
                            var call = calls[i] ?? (id: "", name: "", arguments: "")
                            if let id = c["id"] as? String { call.id = id }
                            if let f = c["function"] as? [String: Any] {
                                if let n = f["name"] as? String { call.name += n }
                                if let a = f["arguments"] as? String { call.arguments += a }
                            }
                            calls[i] = call
                        }
                    }
                    if text.isEmpty, calls.isEmpty, let o = try? JSONSerialization.jsonObject(with: Data(plain.utf8)) as? [String: Any],
                       let m = (o["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any] {
                        if let c = m["content"] as? String { text = c; cont.yield(.text(text)) }
                        for (i, c) in (m["tool_calls"] as? [[String: Any]] ?? []).enumerated() {
                            let f = c["function"] as? [String: Any] ?? [:]
                            calls[i] = (id: c["id"] as? String ?? "call\(i)", name: f["name"] as? String ?? "", arguments: f["arguments"] as? String ?? "{}")
                        }
                    }
                    if !calls.isEmpty {
                        cont.yield(.toolCalls(calls.keys.sorted().map { k in
                            let c = calls[k]!
                            return (id: c.id.isEmpty ? "call\(k)" : c.id, name: c.name, arguments: c.arguments.isEmpty ? "{}" : c.arguments)
                        }))
                    } else if text.isEmpty {
                        cont.yield(.text(""))
                    }
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
struct _LanguageModelHost {
    static var deviceIsEligible: Bool {
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "iPhone17,1"
        /* iPhone 15 Pro / Pro Max (iPhone16,1 / 16,2), every iPhone 16 and 17 (iPhone17,x, iPhone18,x); iPads with an M
           chip (iPad13,4 and later Pros, iPad14,8+ Airs, iPad16,x) or the A17 Pro (iPad mini, iPad16,1) */
        func ver(_ p: String) -> (Int, Int)? {
            guard model.hasPrefix(p) else { return nil }
            let parts = model.dropFirst(p.count).split(separator: ",").compactMap { Int($0) }
            return parts.count == 2 ? (parts[0], parts[1]) : nil
        }
        if let (a, b) = ver("iPhone") { return a > 16 || (a == 16 && b >= 1) }
        if let (a, b) = ver("iPad") { return a >= 16 || (a == 14 && b >= 8) || (a == 13 && b >= 4) }
        return false
    }
    /// whether a model is configured (ISIM_LLM_URL, or a GGUF in ISIM_LLM_MODEL), without starting it
    static var isConfigured: Bool {
        let env = ProcessInfo.processInfo.environment
        if let u = env["ISIM_LLM_URL"], !u.isEmpty { return true }
        if let m = env["ISIM_LLM_MODEL"], m.hasSuffix(".gguf") { return FileManager.default.fileExists(atPath: m) }
        return false
    }
    /// the backend: the configured server, or llama-server started on the host for a GGUF (once per app)
    static let backend: (any _LanguageModelBackend)? = {
        let env = ProcessInfo.processInfo.environment
        let model = env["ISIM_LLM_MODEL"] ?? ""
        if let u = env["ISIM_LLM_URL"], !u.isEmpty, let url = URL(string: u) {
            return _OpenAICompatibleBackend(base: url, model: model.isEmpty ? "default" : model)
        }
        guard model.hasSuffix(".gguf") else { return nil }
        var buf = [CChar](repeating: 0, count: 256)
        guard isim_llm_server(model, &buf, Int32(buf.count)) != 0, let url = URL(string: String(cString: buf)) else {
            NSLog("isim Foundation Models: llama-server could not be started for %@ (install llama.cpp's llama-server)", model)
            return nil
        }
        return _OpenAICompatibleBackend(base: url, model: (model as NSString).lastPathComponent)
    }()
}
