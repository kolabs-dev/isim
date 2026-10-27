// isim Foundation Models: SystemLanguageModel (honest availability), LanguageModelSession, prompts and instructions,
// tools, generation options and the transcript. With no model configured on the host, the model is unavailable and a
// session's requests fail with GenerationError.assetsUnavailable (the prompt is still recorded in the transcript).
import Foundation
import Observation

// MARK: - prompts and instructions

@available(iOS 26.0, macOS 26.0, *)
public protocol PromptRepresentable { var promptRepresentation: Prompt { get } }
@available(iOS 26.0, macOS 26.0, *)
public protocol InstructionsRepresentable { var instructionsRepresentation: Instructions { get } }

@available(iOS 26.0, macOS 26.0, *)
public struct Prompt: Sendable, PromptRepresentable {
    let _text: String
    init(_ text: String) { _text = text }
    public init(_ content: some PromptRepresentable) { _text = content.promptRepresentation._text }
    public init(@PromptBuilder _ content: () throws -> Prompt) rethrows { self = try content() }
    public var promptRepresentation: Prompt { self }
}
@available(iOS 26.0, macOS 26.0, *)
public struct Instructions: Sendable, InstructionsRepresentable {
    let _text: String
    init(_ text: String) { _text = text }
    public init(_ content: some InstructionsRepresentable) { _text = content.instructionsRepresentation._text }
    public init(@InstructionsBuilder _ content: () throws -> Instructions) rethrows { self = try content() }
    public var instructionsRepresentation: Instructions { self }
}
/// Builds a prompt from its parts, one per line.
@available(iOS 26.0, macOS 26.0, *)
@resultBuilder public struct PromptBuilder {
    public static func buildBlock(_ components: any PromptRepresentable...) -> Prompt {
        Prompt(components.map(\.promptRepresentation._text).filter { !$0.isEmpty }.joined(separator: "\n"))
    }
    public static func buildArray(_ prompts: [some PromptRepresentable]) -> Prompt {
        Prompt(prompts.map(\.promptRepresentation._text).filter { !$0.isEmpty }.joined(separator: "\n"))
    }
    public static func buildEither(first component: some PromptRepresentable) -> Prompt { component.promptRepresentation }
    public static func buildEither(second component: some PromptRepresentable) -> Prompt { component.promptRepresentation }
    public static func buildOptional(_ component: Prompt?) -> Prompt { component ?? Prompt("") }
    public static func buildLimitedAvailability(_ prompt: some PromptRepresentable) -> Prompt { prompt.promptRepresentation }
    public static func buildExpression<P: PromptRepresentable>(_ expression: P) -> P { expression }
    public static func buildExpression(_ expression: Prompt) -> Prompt { expression }
}
/// Builds instructions from their parts, one per line.
@available(iOS 26.0, macOS 26.0, *)
@resultBuilder public struct InstructionsBuilder {
    public static func buildBlock(_ components: any InstructionsRepresentable...) -> Instructions {
        Instructions(components.map(\.instructionsRepresentation._text).filter { !$0.isEmpty }.joined(separator: "\n"))
    }
    public static func buildArray(_ instructions: [some InstructionsRepresentable]) -> Instructions {
        Instructions(instructions.map(\.instructionsRepresentation._text).filter { !$0.isEmpty }.joined(separator: "\n"))
    }
    public static func buildEither(first component: some InstructionsRepresentable) -> Instructions { component.instructionsRepresentation }
    public static func buildEither(second component: some InstructionsRepresentable) -> Instructions { component.instructionsRepresentation }
    public static func buildOptional(_ instructions: Instructions?) -> Instructions { instructions ?? Instructions("") }
    public static func buildLimitedAvailability(_ instructions: some InstructionsRepresentable) -> Instructions { instructions.instructionsRepresentation }
    public static func buildExpression<I: InstructionsRepresentable>(_ expression: I) -> I { expression }
    public static func buildExpression(_ expression: Instructions) -> Instructions { expression }
}

// MARK: - options

@available(iOS 26.0, macOS 26.0, *)
public struct GenerationOptions: Sendable, Equatable {
    public struct SamplingMode: Sendable, Equatable {
        /// the strategies for choosing the next token
        @available(iOS 27.0, macOS 27.0, *)
        public enum Kind: Sendable, Equatable { case greedy, randomTopK(Int, seed: UInt64?), randomProbabilityThreshold(Double, seed: UInt64?) }
        enum _Kind: Sendable, Equatable { case greedy, top(Int, UInt64?), probability(Double, UInt64?) }
        let _kind: _Kind
        public static var greedy: SamplingMode { SamplingMode(_kind: .greedy) }
        public static func random(top k: Int, seed: UInt64? = nil) -> SamplingMode { SamplingMode(_kind: .top(k, seed)) }
        public static func random(probabilityThreshold: Double, seed: UInt64? = nil) -> SamplingMode {
            SamplingMode(_kind: .probability(probabilityThreshold, seed))
        }
        @available(iOS 27.0, macOS 27.0, *)
        public var kind: Kind {
            switch _kind {
            case .greedy: return .greedy
            case .top(let k, let seed): return .randomTopK(k, seed: seed)
            case .probability(let p, let seed): return .randomProbabilityThreshold(p, seed: seed)
            }
        }
    }
    /// how the model uses the session's tools in a request: `allowed` (the model decides), `disallowed` (it answers
    /// without them) or `required` (it calls one or more tools in every round, until a tool throws)
    @available(iOS 27.0, macOS 27.0, *)
    public struct ToolCallingMode: Sendable, Equatable {
        public enum Kind: Sendable, Equatable { case allowed, disallowed, required }
        public let kind: Kind
        public static let allowed = ToolCallingMode(kind: .allowed)
        public static let disallowed = ToolCallingMode(kind: .disallowed)
        public static let required = ToolCallingMode(kind: .required)
    }
    public var sampling: SamplingMode?
    public var temperature: Double?
    public var maximumResponseTokens: Int?
    var _toolCallingMode: String?                        // ToolCallingMode.Kind's name (the struct is iOS 27)
    @available(iOS 27.0, macOS 27.0, *)
    public var toolCallingMode: ToolCallingMode? {
        get { _toolCallingMode.map { ToolCallingMode(kind: $0 == "required" ? .required : $0 == "disallowed" ? .disallowed : .allowed) } }
        set { _toolCallingMode = newValue.map { "\($0.kind)" } }
    }
    public init(sampling: SamplingMode? = nil, temperature: Double? = nil, maximumResponseTokens: Int? = nil) {
        self.sampling = sampling; self.temperature = temperature; self.maximumResponseTokens = maximumResponseTokens
    }
    @available(iOS 27.0, macOS 27.0, *)
    public init(samplingMode: SamplingMode? = nil, temperature: Double? = nil, maximumResponseTokens: Int? = nil, toolCallingMode: ToolCallingMode?) {
        self.init(sampling: samplingMode, temperature: temperature, maximumResponseTokens: maximumResponseTokens)
        self.toolCallingMode = toolCallingMode
    }
}

// MARK: - tools

/// A tool the model may call while it responds.
@available(iOS 26.0, macOS 26.0, *)
public protocol Tool<Arguments, Output>: Sendable {
    associatedtype Output: PromptRepresentable
    associatedtype Arguments: ConvertibleFromGeneratedContent
    var name: String { get }
    var description: String { get }
    var parameters: GenerationSchema { get }
    var includesSchemaInInstructions: Bool { get }
    func call(arguments: Arguments) async throws -> Output
}
@available(iOS 26.0, macOS 26.0, *)
extension Tool {
    public var name: String { String(describing: Self.self) }
    public var includesSchemaInInstructions: Bool { true }
}
@available(iOS 26.0, macOS 26.0, *)
extension Tool where Arguments: Generable {
    public var parameters: GenerationSchema { Arguments.generationSchema }
}

// MARK: - the model

@available(iOS 26.0, macOS 26.0, *)
public final class SystemLanguageModel: Sendable, Observable {
    public struct UseCase: Sendable, Equatable {
        let _name: String
        public static let general = UseCase(_name: "general")
        public static let contentTagging = UseCase(_name: "contentTagging")
    }
    public struct Guardrails: Sendable {
        let _name: String
        public static let `default` = Guardrails(_name: "default")
        public static let permissiveContentTransformations = Guardrails(_name: "permissiveContentTransformations")
    }
    @frozen public enum Availability: Equatable, Sendable {
        public enum UnavailableReason: Equatable, Sendable { case deviceNotEligible, appleIntelligenceNotEnabled, modelNotReady }
        case available
        case unavailable(UnavailableReason)
    }
    public let useCase: UseCase
    let _guardrails: Guardrails
    public static let `default` = SystemLanguageModel()
    public init(useCase: UseCase = .general, guardrails: Guardrails = .default) { self.useCase = useCase; _guardrails = guardrails }

    /// Apple Intelligence runs on the iPhone 15 Pro and later and on iPads with an M chip; on those, isim's model is
    /// the one configured on the host (ISIM_LLM_URL or ISIM_LLM_MODEL, Backend.swift; none: Apple Intelligence counts
    /// as not enabled)
    public var availability: Availability {
        guard _LanguageModelHost.deviceIsEligible else { return .unavailable(.deviceNotEligible) }
        return _LanguageModelHost.isConfigured ? .available : .unavailable(.appleIntelligenceNotEnabled)
    }
    public var isAvailable: Bool { availability == .available }
    public var supportedLanguages: Set<Locale.Language> {
        Set(["en", "fr", "de", "es", "it", "pt", "ja", "ko", "zh"].map { Locale.Language(identifier: $0) })
    }
    public func supportsLocale(_ locale: Locale = Locale.current) -> Bool {
        supportedLanguages.contains { $0.languageCode == locale.language.languageCode }
    }
}

// MARK: - the session

@available(iOS 26.0, macOS 26.0, *)
public final class LanguageModelSession: @unchecked Sendable, Observable {
    public private(set) var transcript: Transcript
    public private(set) var isResponding = false
    let _model: SystemLanguageModel
    let _tools: [any Tool]
    private let lock = NSLock()

    public init(model: SystemLanguageModel = .default, tools: [any Tool] = [], instructions: Instructions? = nil) {
        _model = model; _tools = tools
        var entries: [Transcript.Entry] = []
        if instructions != nil || !tools.isEmpty {
            entries.append(.instructions(Transcript.Instructions(segments: instructions.map { [.text(.init(content: $0._text))] } ?? [],
                                                                  toolDefinitions: tools.map { Transcript.ToolDefinition(tool: $0) })))
        }
        transcript = Transcript(entries: entries)
    }
    public convenience init(model: SystemLanguageModel = .default, tools: [any Tool] = [], instructions: String? = nil) {
        self.init(model: model, tools: tools, instructions: instructions.map(Instructions.init(_:)))
    }
    public convenience init(model: SystemLanguageModel = .default, tools: [any Tool] = [],
                            @InstructionsBuilder instructions: () throws -> Instructions) rethrows {
        self.init(model: model, tools: tools, instructions: try instructions())
    }
    /// continues a conversation from its transcript
    public init(model: SystemLanguageModel = .default, tools: [any Tool] = [], transcript: Transcript) {
        _model = model; _tools = tools; self.transcript = transcript
    }

    /// loads the model ahead of a request (isim: nothing to load)
    public func prewarm(promptPrefix: Prompt? = nil) {}

    public struct Response<Content>: @unchecked Sendable {
        public let content: Content
        public let rawContent: GeneratedContent
        public let transcriptEntries: ArraySlice<Transcript.Entry>
    }

    public enum GenerationError: Error, LocalizedError {
        public struct Context: Sendable {
            public let debugDescription: String
            public init(debugDescription: String) { self.debugDescription = debugDescription }
        }
        public struct Refusal: Sendable {
            let _explanation: String
            public init(transcriptEntries: [Transcript.Entry]) {
                var text = ""
                for e in transcriptEntries { if case .response(let r) = e { text += r.segments.map(\._text).joined() } }
                _explanation = text
            }
            public var explanation: Response<String> {
                get async throws { Response(content: _explanation, rawContent: GeneratedContent(_explanation), transcriptEntries: []) }
            }
        }
        case exceededContextWindowSize(Context)
        case assetsUnavailable(Context)
        case guardrailViolation(Context)
        case unsupportedGuide(Context)
        case unsupportedLanguageOrLocale(Context)
        case decodingFailure(Context)
        case rateLimited(Context)
        case concurrentRequests(Context)
        case refusal(Refusal, Context)
        var _context: Context {
            switch self {
            case .exceededContextWindowSize(let c), .assetsUnavailable(let c), .guardrailViolation(let c), .unsupportedGuide(let c),
                 .unsupportedLanguageOrLocale(let c), .decodingFailure(let c), .rateLimited(let c), .concurrentRequests(let c), .refusal(_, let c):
                return c
            }
        }
        public var errorDescription: String? { _context.debugDescription }
        public var failureReason: String? { _context.debugDescription }
        public var recoverySuggestion: String? { nil }
    }
    public struct ToolCallError: Error, LocalizedError {
        public var tool: any Tool
        public var underlyingError: any Error
        public init(tool: any Tool, underlyingError: any Error) { self.tool = tool; self.underlyingError = underlyingError }
        public var errorDescription: String? { "\(tool.name) failed: \(underlyingError.localizedDescription)" }
    }

    // MARK: responding

    @discardableResult
    public func respond(to prompt: Prompt, options: GenerationOptions = GenerationOptions()) async throws -> Response<String> {
        let (text, entries) = try await _respond(prompt._text, schema: nil, includeSchema: false, options: options)
        return Response(content: text, rawContent: GeneratedContent(text), transcriptEntries: entries)
    }
    @discardableResult
    public func respond(to prompt: String, options: GenerationOptions = GenerationOptions()) async throws -> Response<String> {
        try await respond(to: Prompt(prompt), options: options)
    }
    @discardableResult
    public func respond(options: GenerationOptions = GenerationOptions(), @PromptBuilder prompt: () throws -> Prompt) async throws -> Response<String> {
        try await respond(to: try prompt(), options: options)
    }
    @discardableResult
    public func respond(to prompt: Prompt, schema: GenerationSchema, includeSchemaInPrompt: Bool = true,
                        options: GenerationOptions = GenerationOptions()) async throws -> Response<GeneratedContent> {
        let (text, entries) = try await _respond(prompt._text, schema: schema, includeSchema: includeSchemaInPrompt, options: options)
        let content = try GeneratedContent(json: text)
        return Response(content: content, rawContent: content, transcriptEntries: entries)
    }
    @discardableResult
    public func respond(to prompt: String, schema: GenerationSchema, includeSchemaInPrompt: Bool = true,
                        options: GenerationOptions = GenerationOptions()) async throws -> Response<GeneratedContent> {
        try await respond(to: Prompt(prompt), schema: schema, includeSchemaInPrompt: includeSchemaInPrompt, options: options)
    }
    @discardableResult
    public func respond<Content: Generable>(to prompt: Prompt, generating type: Content.Type = Content.self, includeSchemaInPrompt: Bool = true,
                                            options: GenerationOptions = GenerationOptions()) async throws -> Response<Content> {
        let r = try await respond(to: prompt, schema: Content.generationSchema, includeSchemaInPrompt: includeSchemaInPrompt, options: options)
        return Response(content: try Content(r.rawContent), rawContent: r.rawContent, transcriptEntries: r.transcriptEntries)
    }
    @discardableResult
    public func respond<Content: Generable>(to prompt: String, generating type: Content.Type = Content.self, includeSchemaInPrompt: Bool = true,
                                            options: GenerationOptions = GenerationOptions()) async throws -> Response<Content> {
        try await respond(to: Prompt(prompt), generating: type, includeSchemaInPrompt: includeSchemaInPrompt, options: options)
    }
    @discardableResult
    public func respond<Content: Generable>(generating type: Content.Type = Content.self, includeSchemaInPrompt: Bool = true,
                                            options: GenerationOptions = GenerationOptions(),
                                            @PromptBuilder prompt: () throws -> Prompt) async throws -> Response<Content> {
        try await respond(to: try prompt(), generating: type, includeSchemaInPrompt: includeSchemaInPrompt, options: options)
    }

    // MARK: streaming

    public struct ResponseStream<Content: Generable>: AsyncSequence, @unchecked Sendable {
        public struct Snapshot: @unchecked Sendable {
            public var content: Content.PartiallyGenerated
            public var rawContent: GeneratedContent
        }
        public typealias Element = Snapshot
        let _make: () -> AsyncThrowingStream<Snapshot, Error>
        let _final: () async throws -> Response<Content>
        public struct AsyncIterator: AsyncIteratorProtocol {
            var _it: AsyncThrowingStream<Snapshot, Error>.AsyncIterator
            public mutating func next() async throws -> Snapshot? { try await _it.next() }
        }
        public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(_it: _make().makeAsyncIterator()) }
        /// waits for the whole response
        public func collect() async throws -> Response<Content> { try await _final() }
    }
    public func streamResponse(to prompt: Prompt, options: GenerationOptions = GenerationOptions()) -> ResponseStream<String> {
        _stream(prompt._text, schema: nil, includeSchema: false, options: options) { text, _ in GeneratedContent(text) }
    }
    public func streamResponse(to prompt: String, options: GenerationOptions = GenerationOptions()) -> ResponseStream<String> {
        streamResponse(to: Prompt(prompt), options: options)
    }
    public func streamResponse(options: GenerationOptions = GenerationOptions(), @PromptBuilder prompt: () throws -> Prompt) rethrows -> ResponseStream<String> {
        streamResponse(to: try prompt(), options: options)
    }
    public func streamResponse<Content: Generable>(to prompt: Prompt, generating type: Content.Type = Content.self, includeSchemaInPrompt: Bool = true,
                                                   options: GenerationOptions = GenerationOptions()) -> ResponseStream<Content> {
        _stream(prompt._text, schema: Content.generationSchema, includeSchema: includeSchemaInPrompt, options: options) { _, json in json }
    }
    public func streamResponse<Content: Generable>(to prompt: String, generating type: Content.Type = Content.self, includeSchemaInPrompt: Bool = true,
                                                   options: GenerationOptions = GenerationOptions()) -> ResponseStream<Content> {
        streamResponse(to: Prompt(prompt), generating: type, includeSchemaInPrompt: includeSchemaInPrompt, options: options)
    }
    public func streamResponse<Content: Generable>(generating type: Content.Type = Content.self, includeSchemaInPrompt: Bool = true,
                                                   options: GenerationOptions = GenerationOptions(),
                                                   @PromptBuilder prompt: () throws -> Prompt) rethrows -> ResponseStream<Content> {
        streamResponse(to: try prompt(), generating: type, includeSchemaInPrompt: includeSchemaInPrompt, options: options)
    }
    public func streamResponse(to prompt: Prompt, schema: GenerationSchema, includeSchemaInPrompt: Bool = true,
                               options: GenerationOptions = GenerationOptions()) -> ResponseStream<GeneratedContent> {
        _stream(prompt._text, schema: schema, includeSchema: includeSchemaInPrompt, options: options) { _, json in json }
    }

    // MARK: the request

    func _append(_ e: Transcript.Entry) { lock.lock(); transcript._entries.append(e); lock.unlock() }

    /// records the prompt and returns what to send: the conversation so far and the backend
    func _begin(_ prompt: String, schema: GenerationSchema?, includeSchema: Bool, options: GenerationOptions) throws -> ([_ChatMessage], any _LanguageModelBackend, Int) {
        lock.lock()
        defer { lock.unlock() }
        if isResponding {
            throw GenerationError.concurrentRequests(.init(debugDescription: "a session answers one request at a time; this one is still responding"))
        }
        /* the conversation before this prompt */
        var messages: [_ChatMessage] = []
        for e in transcript._entries {
            switch e {
            case .instructions(let i): messages.append(_ChatMessage(role: "system", content: i.segments.map(\._text).joined(separator: "\n")))
            case .prompt(let p): messages.append(_ChatMessage(role: "user", content: p.segments.map(\._text).joined(separator: "\n")))
            case .response(let r): messages.append(_ChatMessage(role: "assistant", content: r.segments.map(\._text).joined(separator: "\n")))
            case .toolCalls(let c): messages.append(_ChatMessage(role: "assistant", content: nil, toolCalls: c.map { (id: $0.id, name: $0.toolName, arguments: $0.arguments.jsonString) }))
            case .toolOutput(let o): messages.append(_ChatMessage(role: "tool", content: o.segments.map(\._text).joined(separator: "\n"), toolCallID: o.id))
            }
        }
        let start = transcript._entries.count
        transcript._entries.append(.prompt(Transcript.Prompt(segments: [.text(.init(content: prompt))], options: options,
                                                             responseFormat: schema.map { Transcript.ResponseFormat(schema: $0) })))
        guard _model.isAvailable, let backend = _LanguageModelHost.backend else {
            let why: String
            switch _model.availability {
            case .unavailable(.deviceNotEligible): why = "this device does not support Apple Intelligence"
            case .available: why = "the configured model (ISIM_LLM_MODEL) could not be started"
            default: why = "no language model is configured on this host (Apple Intelligence is not enabled; set ISIM_LLM_URL or ISIM_LLM_MODEL)"
            }
            throw GenerationError.assetsUnavailable(.init(debugDescription: "the system language model is unavailable: \(why)"))
        }
        isResponding = true
        let text = includeSchema ? schema.map { "\(prompt)\n\nRespond with JSON that matches this schema: \($0._jsonString)" } ?? prompt : prompt
        messages.append(_ChatMessage(role: "user", content: text))
        return (messages, backend, start)
    }
    /// asks the backend, calling the session's tools when the model asks for them (recorded in the transcript), until it
    /// answers; `onText` gets the answer so far
    func _generate(_ messages: [_ChatMessage], _ backend: any _LanguageModelBackend, schema: GenerationSchema?, options: GenerationOptions,
                   onText: (String) throws -> Void) async throws -> String {
        var msgs = messages
        let rounds = options._toolCallingMode == "required" ? 64 : 8   // `required` stops when a tool throws
        for _ in 0..<rounds {
            var last = ""
            var calls: [(id: String, name: String, arguments: String)] = []
            for try await ev in backend.generate(messages: msgs, tools: _tools, schema: schema, options: options) {
                switch ev {
                case .text(let t): last = t; try onText(t)
                case .toolCalls(let c): calls = c
                }
            }
            if calls.isEmpty { return last }
            let recorded = calls.map {
                Transcript.ToolCall(id: $0.id, toolName: $0.name,
                                    arguments: (try? GeneratedContent(json: $0.arguments)) ?? GeneratedContent(kind: .structure(properties: [:], orderedKeys: [])))
            }
            _append(.toolCalls(Transcript.ToolCalls(recorded)))
            msgs.append(_ChatMessage(role: "assistant", content: nil, toolCalls: calls))
            for call in recorded {
                guard let tool = _tools.first(where: { $0.name == call.toolName }) else {
                    throw GenerationError.decodingFailure(.init(debugDescription: "the model called \(call.toolName), which the session does not have"))
                }
                let output: String
                do { output = try await _callTool(tool, call.arguments) } catch { throw ToolCallError(tool: tool, underlyingError: error) }
                _append(.toolOutput(Transcript.ToolOutput(id: call.id, toolName: call.toolName, segments: [.text(.init(content: output))])))
                msgs.append(_ChatMessage(role: "tool", content: output, toolCallID: call.id))
            }
        }
        throw GenerationError.decodingFailure(.init(debugDescription: "the model kept calling tools without answering"))
    }
    func _callTool<T: Tool>(_ tool: T, _ arguments: GeneratedContent) async throws -> String {
        try await tool.call(arguments: try T.Arguments(arguments)).promptRepresentation._text
    }
    /// records the response (nil: the request failed) and returns this request's transcript entries
    @discardableResult
    func _end(_ result: (text: String, structured: Bool, start: Int)?) -> ArraySlice<Transcript.Entry> {
        lock.lock()
        defer { lock.unlock() }
        isResponding = false
        guard let result else { return [] }
        let segment: Transcript.Segment = result.structured
            ? .structure(.init(source: "", content: (try? GeneratedContent(json: result.text)) ?? GeneratedContent(result.text)))
            : .text(.init(content: result.text))
        transcript._entries.append(.response(Transcript.Response(assetIDs: [], segments: [segment])))
        return transcript._entries[result.start...]
    }
    func _respond(_ prompt: String, schema: GenerationSchema?, includeSchema: Bool, options: GenerationOptions) async throws -> (String, ArraySlice<Transcript.Entry>) {
        let (messages, backend, start) = try _begin(prompt, schema: schema, includeSchema: includeSchema, options: options)
        let text: String
        do { text = try await _generate(messages, backend, schema: schema, options: options) { _ in } } catch { _end(nil); throw error }
        return (text, _end((text, schema != nil, start)))
    }
    func _stream<Content: Generable>(_ prompt: String, schema: GenerationSchema?, includeSchema: Bool, options: GenerationOptions,
                                     _ content: @escaping @Sendable (String, GeneratedContent) -> GeneratedContent) -> ResponseStream<Content> {
        let run = _StreamRun<Content>(), lock = NSLock()
        do { run.started = try _begin(prompt, schema: schema, includeSchema: includeSchema, options: options) } catch { run.error = error }
        let structured = schema != nil
        let stream = AsyncThrowingStream<ResponseStream<Content>.Snapshot, Error> { cont in
            Task {
                do {
                    if let e = run.error { throw e }
                    guard let (messages, backend, start) = run.started else { throw GenerationError.assetsUnavailable(.init(debugDescription: "no response")) }
                    let last = try await self._generate(messages, backend, schema: schema, options: options) { text in
                        let raw = structured ? try GeneratedContent(json: text) : GeneratedContent(text)
                        cont.yield(.init(content: try Content.PartiallyGenerated(content(text, raw)), rawContent: raw))
                    }
                    let entries = self._end((last, structured, start))
                    let raw = structured ? try GeneratedContent(json: last) : GeneratedContent(last)
                    lock.lock(); run.final = Response(content: try Content(content(last, raw)), rawContent: raw, transcriptEntries: entries); lock.unlock()
                    cont.finish()
                } catch {
                    if run.started != nil && run.final == nil { self._end(nil) }
                    lock.lock(); run.error = error; lock.unlock()
                    cont.finish(throwing: error)
                }
                lock.lock(); run.done = true; let w = run.waiters; run.waiters = []; lock.unlock()
                for c in w { c.resume() }
            }
        }
        return ResponseStream(_make: { stream }, _final: {
            for try await _ in stream {}
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                lock.lock()
                if run.done { lock.unlock(); c.resume() } else { run.waiters.append(c); lock.unlock() }
            }
            lock.lock(); defer { lock.unlock() }
            if let f = run.final { return f }
            throw run.error ?? GenerationError.assetsUnavailable(.init(debugDescription: "no response"))
        })
    }
}

/// a streamed request's state, shared by the stream and collect()
@available(iOS 26.0, macOS 26.0, *)
final class _StreamRun<Content: Generable>: @unchecked Sendable {
    var started: ([_ChatMessage], any _LanguageModelBackend, Int)?, error: Error?, final: LanguageModelSession.Response<Content>?
    var waiters: [CheckedContinuation<Void, Never>] = []
    var done = false
    init() {}
}

// MARK: - the transcript

@available(iOS 26.0, macOS 26.0, *)
public struct Transcript: Sendable, Equatable, RandomAccessCollection {
    var _entries: [Entry]
    public init(entries: some Sequence<Entry> = []) { _entries = Array(entries) }
    public var startIndex: Int { _entries.startIndex }
    public var endIndex: Int { _entries.endIndex }
    public subscript(index: Int) -> Entry { _entries[index] }
    public static func == (a: Transcript, b: Transcript) -> Bool { a._entries.map(\.id) == b._entries.map(\.id) }

    public enum Entry: Sendable, Identifiable, CustomStringConvertible, Equatable {
        case instructions(Instructions)
        case prompt(Prompt)
        case toolCalls(ToolCalls)
        case toolOutput(ToolOutput)
        case response(Response)
        public var id: String {
            switch self {
            case .instructions(let x): return x.id
            case .prompt(let x): return x.id
            case .toolCalls(let x): return x.id
            case .toolOutput(let x): return x.id
            case .response(let x): return x.id
            }
        }
        public var description: String {
            switch self {
            case .instructions(let x): return "(Instructions) " + x.segments.map(\._text).joined()
            case .prompt(let x): return "(Prompt) " + x.segments.map(\._text).joined()
            case .toolCalls(let x): return "(Tool calls) " + x.map { "\($0.toolName)(\($0.arguments.jsonString))" }.joined(separator: ", ")
            case .toolOutput(let x): return "(Tool output: \(x.toolName)) " + x.segments.map(\._text).joined()
            case .response(let x): return "(Response) " + x.segments.map(\._text).joined()
            }
        }
        public static func == (a: Entry, b: Entry) -> Bool { a.id == b.id }
    }
    public enum Segment: Sendable, Identifiable, CustomStringConvertible, Equatable {
        case text(TextSegment)
        case structure(StructuredSegment)
        public var id: String { switch self { case .text(let t): return t.id; case .structure(let s): return s.id } }
        var _text: String { switch self { case .text(let t): return t.content; case .structure(let s): return s.content.jsonString } }
        public var description: String { _text }
        public static func == (a: Segment, b: Segment) -> Bool { a.id == b.id }
    }
    public struct TextSegment: Sendable, Identifiable, Equatable {
        public var id: String
        public var content: String
        public init(id: String = UUID().uuidString, content: String) { self.id = id; self.content = content }
    }
    public struct StructuredSegment: Sendable, Identifiable, Equatable {
        public var id: String
        public var source: String
        public var content: GeneratedContent
        public init(id: String = UUID().uuidString, source: String, content: GeneratedContent) { self.id = id; self.source = source; self.content = content }
    }
    public struct Instructions: Sendable, Identifiable, Equatable {
        public var id: String
        public var segments: [Segment]
        public var toolDefinitions: [ToolDefinition]
        public init(id: String = UUID().uuidString, segments: [Segment], toolDefinitions: [ToolDefinition]) {
            self.id = id; self.segments = segments; self.toolDefinitions = toolDefinitions
        }
        public static func == (a: Instructions, b: Instructions) -> Bool { a.id == b.id }
    }
    public struct ToolDefinition: Sendable, Equatable {
        public var name: String
        public var description: String
        let _parameters: GenerationSchema
        public init(name: String, description: String, parameters: GenerationSchema) { self.name = name; self.description = description; _parameters = parameters }
        public init(tool: some Tool) { self.init(name: tool.name, description: tool.description, parameters: tool.parameters) }
        public static func == (a: ToolDefinition, b: ToolDefinition) -> Bool { a.name == b.name && a.description == b.description }
    }
    public struct Prompt: Sendable, Identifiable, Equatable {
        public var id: String
        public var segments: [Segment]
        public var options: GenerationOptions
        public var responseFormat: ResponseFormat?
        public init(id: String = UUID().uuidString, segments: [Segment], options: GenerationOptions = GenerationOptions(), responseFormat: ResponseFormat? = nil) {
            self.id = id; self.segments = segments; self.options = options; self.responseFormat = responseFormat
        }
        public static func == (a: Prompt, b: Prompt) -> Bool { a.id == b.id }
    }
    public struct ResponseFormat: Sendable, Equatable {
        public var name: String
        let _schema: GenerationSchema
        public init(type: any Generable.Type) { name = String(describing: type); _schema = type.generationSchema }
        public init(schema: GenerationSchema) {
            switch schema._node {
            case .object(let n, _), .anyOf(let n, _), .named(let n, _): name = n
            default: name = "Response"
            }
            _schema = schema
        }
        public static func == (a: ResponseFormat, b: ResponseFormat) -> Bool { a.name == b.name }
    }
    public struct ToolCalls: Sendable, Identifiable, Equatable, RandomAccessCollection {
        public var id: String
        let _calls: [ToolCall]
        public init(id: String = UUID().uuidString, _ calls: some Collection<ToolCall>) { self.id = id; _calls = Array(calls) }
        public var startIndex: Int { _calls.startIndex }
        public var endIndex: Int { _calls.endIndex }
        public subscript(position: Int) -> ToolCall { _calls[position] }
        public static func == (a: ToolCalls, b: ToolCalls) -> Bool { a.id == b.id }
    }
    public struct ToolCall: Sendable, Identifiable, Equatable {
        public var id: String
        public var toolName: String
        public var arguments: GeneratedContent
        public init(id: String, toolName: String, arguments: GeneratedContent) { self.id = id; self.toolName = toolName; self.arguments = arguments }
    }
    public struct ToolOutput: Sendable, Identifiable, Equatable {
        public var id: String
        public var toolName: String
        public var segments: [Segment]
        public init(id: String, toolName: String, segments: [Segment]) { self.id = id; self.toolName = toolName; self.segments = segments }
        public static func == (a: ToolOutput, b: ToolOutput) -> Bool { a.id == b.id }
    }
    public struct Response: Sendable, Identifiable, Equatable {
        public var id: String
        public var assetIDs: [String]
        public var segments: [Segment]
        public init(id: String = UUID().uuidString, assetIDs: [String], segments: [Segment]) { self.id = id; self.assetIDs = assetIDs; self.segments = segments }
        public static func == (a: Response, b: Response) -> Bool { a.id == b.id }
    }
}

// MARK: - macros

/// Makes a struct or an enum Generable: its schema (with `@Guide` descriptions and guides), made from and turned
/// into generated content, and a PartiallyGenerated form for responses in progress.
@available(iOS 26.0, macOS 26.0, *)
@attached(extension, conformances: Generable, names: named(init(_:)), named(generatedContent))
@attached(member, names: named(generationSchema), named(PartiallyGenerated))
public macro Generable(description: String? = nil) = #externalMacro(module: "FoundationModelsMacros", type: "GenerableMacro")

/// Describes a Generable type's property for the model (read by `@Generable`).
@available(iOS 26.0, macOS 26.0, *)
@attached(peer)
public macro Guide(description: String) = #externalMacro(module: "FoundationModelsMacros", type: "GuideMacro")
@available(iOS 26.0, macOS 26.0, *)
@attached(peer)
public macro Guide<T: Generable>(description: String? = nil, _ guides: GenerationGuide<T>...) = #externalMacro(module: "FoundationModelsMacros", type: "GuideMacro")
@available(iOS 26.0, macOS 26.0, *)
@attached(peer)
public macro Guide<RegexOutput>(description: String? = nil, _ guides: Regex<RegexOutput>) = #externalMacro(module: "FoundationModelsMacros", type: "GuideMacro")
