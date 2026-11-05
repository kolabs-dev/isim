// isim Foundation Models (iOS 27, issue #859): any language model, not only the system one. A `LanguageModel` names an
// `Executor` that answers a `LanguageModelExecutorGenerationRequest` (the transcript, the enabled tools, the schema
// and options) by sending events into a `LanguageModelExecutorGenerationChannel`: text, reasoning, tool calls, data
// and usage. A session with such a model turns the events into transcript entries and runs the tools the model asks
// for, as it does with the system model. SystemLanguageModel's executor drives isim's host backend (Backend.swift);
// Private Cloud Compute is not available on isim (no Apple servers), and says so.
import Foundation
import UniformTypeIdentifiers

@available(iOS 26.0, macOS 26.0, *)
func _isimGenerated(_ d: [String: any ConvertibleToGeneratedContent]) -> [String: GeneratedContent] { d.mapValues { $0.generatedContent } }

// MARK: - models and executors

/// A language model a session can use: what it can do, and the executor that runs it.
@available(iOS 27.0, macOS 27.0, *)
public protocol LanguageModel: Sendable {
    associatedtype Executor: LanguageModelExecutor where Self == Self.Executor.Model
    var capabilities: LanguageModelCapabilities { get }
    var executorConfiguration: Self.Executor.Configuration { get }
    func supportsDataAttachmentType(_ type: UTType) async throws -> Bool
    func supportsDataEntryType(_ type: UTType) async throws -> Bool
}
@available(iOS 27.0, macOS 27.0, *)
extension LanguageModel {
    public func supportsDataAttachmentType(_ type: UTType) async throws -> Bool { false }
    public func supportsDataEntryType(_ type: UTType) async throws -> Bool { false }
}

/// Runs a model: answers each request by sending events into the channel.
@available(iOS 27.0, macOS 27.0, *)
public protocol LanguageModelExecutor: Sendable {
    associatedtype Configuration: Hashable, Sendable
    associatedtype Model: LanguageModel
    init(configuration: Self.Configuration) throws
    func prewarm(model: Self.Model, transcript: Transcript)
    func respond(to request: LanguageModelExecutorGenerationRequest, model: Self.Model,
                 streamingInto channel: LanguageModelExecutorGenerationChannel) async throws
}
@available(iOS 27.0, macOS 27.0, *)
extension LanguageModelExecutor {
    public func prewarm(model: Self.Model, transcript: Transcript) {}
}

/// What a model can do.
@available(iOS 27.0, macOS 27.0, *)
public struct LanguageModelCapabilities: Sendable, Hashable {
    public struct Capability: Sendable, Hashable {
        let _name: String
        public static var guidedGeneration: Capability { Capability(_name: "guidedGeneration") }
        public static var reasoning: Capability { Capability(_name: "reasoning") }
        public static var toolCalling: Capability { Capability(_name: "toolCalling") }
        public static var vision: Capability { Capability(_name: "vision") }
    }
    let _set: Set<Capability>
    public init(_ capabilities: [Capability]) { _set = Set(capabilities) }
    public func contains(_ capability: Capability) -> Bool { _set.contains(capability) }
}

/// How the model should treat the context of a request.
@available(iOS 27.0, macOS 27.0, *)
public struct ContextOptions: Sendable, Equatable {
    public enum ReasoningLevel: Sendable, Hashable { case light, moderate, deep, custom(String) }
    public var includeSchemaInPrompt: Bool?
    public var reasoningLevel: ReasoningLevel?
    public init(includeSchemaInPrompt: Bool? = nil, reasoningLevel: ReasoningLevel? = nil) {
        self.includeSchemaInPrompt = includeSchemaInPrompt; self.reasoningLevel = reasoningLevel
    }
}

/// What happens to the transcript when a request fails.
@available(iOS 27.0, macOS 27.0, *)
public struct TranscriptErrorHandlingPolicy: Sendable, Hashable {
    let _revert: Bool
    /// the prompt (and the entries of the failed request) stay in the transcript
    public static let preserveTranscript = TranscriptErrorHandlingPolicy(_revert: false)
    /// the transcript is restored to what it was before the request
    public static let revertTranscript = TranscriptErrorHandlingPolicy(_revert: true)
}

/// One request to an executor.
@available(iOS 27.0, macOS 27.0, *)
public struct LanguageModelExecutorGenerationRequest: Sendable {
    public var id: UUID
    public var transcript: Transcript
    public var enabledToolDefinitions: [Transcript.ToolDefinition]
    public var schema: GenerationSchema?
    public var generationOptions: GenerationOptions
    public var contextOptions: ContextOptions
    public var metadata: [String: GeneratedContent]
    public init(id: UUID, transcript: Transcript, enabledTools: [Transcript.ToolDefinition], schema: GenerationSchema? = nil,
                generationOptions: GenerationOptions, contextOptions: ContextOptions, metadata: [String: any ConvertibleToGeneratedContent]) {
        self.id = id; self.transcript = transcript; enabledToolDefinitions = enabledTools; self.schema = schema
        self.generationOptions = generationOptions; self.contextOptions = contextOptions; self.metadata = _isimGenerated(metadata)
    }
}

// MARK: - the channel

/// Where an executor sends what the model produces; the session reads it.
@available(iOS 27.0, macOS 27.0, *)
public struct LanguageModelExecutorGenerationChannel: AsyncSequence, Sendable {
    public typealias Element = Event
    final class _Box: @unchecked Sendable {
        let stream: AsyncStream<Event>
        let continuation: AsyncStream<Event>.Continuation
        init() { (stream, continuation) = AsyncStream<Event>.makeStream(bufferingPolicy: .unbounded) }
    }
    let _box: _Box
    public init() { _box = _Box() }
    public func send(_ event: Event) async { _box.continuation.yield(event) }
    func _finish() { _box.continuation.finish() }
    public struct AsyncIterator: AsyncIteratorProtocol {
        var _it: AsyncStream<Event>.Iterator
        public mutating func next() async -> Event? { await _it.next() }
    }
    public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(_it: _box.stream.makeAsyncIterator()) }

    /// One thing the model produced, for one transcript entry (`entryID`).
    public struct Event: Sendable {
        enum _Kind: Sendable { case response(Response), reasoning(Reasoning), toolCalls(ToolCalls), data(DataEntry) }
        let _kind: _Kind
        public static func response(entryID: String? = nil, action: Response.Action) -> Event { Event(_kind: .response(Response(action: action, entryID: entryID))) }
        public static func reasoning(entryID: String? = nil, action: Reasoning.Action) -> Event { Event(_kind: .reasoning(Reasoning(action: action, entryID: entryID))) }
        public static func toolCalls(entryID: String? = nil, action: ToolCalls.Action) -> Event { Event(_kind: .toolCalls(ToolCalls(action: action, entryID: entryID))) }
        public static func data(entryID: String? = nil, action: DataEntry.Action) -> Event { Event(_kind: .data(DataEntry(action: action, entryID: entryID))) }
    }
    /// metadata the model attached to an entry
    public struct Metadata: Sendable { public var values: [String: GeneratedContent] }
    public struct TextFragment: Sendable { public var content: String; public var segmentID: String?; public var tokenCount: Int }
    public struct TextSegmentReplacement: Sendable { public var content: String; public var segmentID: String?; public var tokenCount: Int }
    public struct ReasoningSignature: Sendable { public var signature: Data; public var tokenCount: Int }
    /// tokens read and written
    public struct Usage: Sendable {
        public struct Input: Sendable {
            public var totalTokenCount: Int
            public var cachedTokenCount: Int
            public init(totalTokenCount: Int, cachedTokenCount: Int) { self.totalTokenCount = totalTokenCount; self.cachedTokenCount = cachedTokenCount }
        }
        public struct Output: Sendable {
            public var totalTokenCount: Int
            public var reasoningTokenCount: Int
            public init(totalTokenCount: Int, reasoningTokenCount: Int) { self.totalTokenCount = totalTokenCount; self.reasoningTokenCount = reasoningTokenCount }
        }
        public var input: Input
        public var output: Output
        public var metadata: [String: GeneratedContent]
        public init(input: Input, output: Output, metadata: [String: any ConvertibleToGeneratedContent] = [:]) {
            self.input = input; self.output = output; self.metadata = _isimGenerated(metadata)
        }
    }
    enum _TextAction: Sendable {
        case append(TextFragment), replace(TextSegmentReplacement), metadata(Metadata), usage(Usage)
    }
    /// the answer's text and attachments
    public struct Response: Sendable {
        public struct Action: Sendable {
            enum _Kind: Sendable { case text(_TextAction), addAttachment(Transcript.AttachmentSegment), removeAttachment(String) }
            let _kind: _Kind
            public static func appendText(_ text: String, segmentID: String? = nil, tokenCount: Int) -> Action {
                Action(_kind: .text(.append(TextFragment(content: text, segmentID: segmentID, tokenCount: tokenCount))))
            }
            public static func replaceTextSegment(_ text: String, segmentID: String? = nil, tokenCount: Int) -> Action {
                Action(_kind: .text(.replace(TextSegmentReplacement(content: text, segmentID: segmentID, tokenCount: tokenCount))))
            }
            public static func addAttachmentSegment(_ segment: Transcript.AttachmentSegment) -> Action { Action(_kind: .addAttachment(segment)) }
            public static func removeAttachmentSegment(id: String) -> Action { Action(_kind: .removeAttachment(id)) }
            public static func updateMetadata(_ values: [String: any ConvertibleToGeneratedContent]) -> Action {
                Action(_kind: .text(.metadata(Metadata(values: _isimGenerated(values)))))
            }
            public static func updateUsage(input: Usage.Input, output: Usage.Output, metadata: [String: any ConvertibleToGeneratedContent] = [:]) -> Action {
                Action(_kind: .text(.usage(Usage(input: input, output: output, metadata: metadata))))
            }
        }
        public var action: Action
        public var entryID: String?
    }
    /// the model's reasoning before it answers
    public struct Reasoning: Sendable {
        public struct Action: Sendable {
            enum _Kind: Sendable { case text(_TextAction), signature(ReasoningSignature) }
            let _kind: _Kind
            public static func appendText(_ text: String, segmentID: String? = nil, tokenCount: Int) -> Action {
                Action(_kind: .text(.append(TextFragment(content: text, segmentID: segmentID, tokenCount: tokenCount))))
            }
            public static func replaceTextSegment(_ text: String, segmentID: String? = nil, tokenCount: Int) -> Action {
                Action(_kind: .text(.replace(TextSegmentReplacement(content: text, segmentID: segmentID, tokenCount: tokenCount))))
            }
            public static func updateSignature(_ signature: Data, tokenCount: Int) -> Action {
                Action(_kind: .signature(ReasoningSignature(signature: signature, tokenCount: tokenCount)))
            }
            public static func updateMetadata(_ values: [String: any ConvertibleToGeneratedContent]) -> Action {
                Action(_kind: .text(.metadata(Metadata(values: _isimGenerated(values)))))
            }
            public static func updateUsage(input: Usage.Input, output: Usage.Output, metadata: [String: any ConvertibleToGeneratedContent] = [:]) -> Action {
                Action(_kind: .text(.usage(Usage(input: input, output: output, metadata: metadata))))
            }
        }
        public var action: Action
        public var entryID: String?
    }
    /// tools the model asks the session to call
    public struct ToolCalls: Sendable {
        public struct ToolCall: Sendable {
            public struct ArgumentsFragment: Sendable { public var content: String; public var tokenCount: Int }
            public struct Action: Sendable {
                enum _Kind: Sendable { case arguments(ArgumentsFragment), metadata(Metadata) }
                let _kind: _Kind
                public static func appendArguments(_ content: String, tokenCount: Int) -> Action {
                    Action(_kind: .arguments(ArgumentsFragment(content: content, tokenCount: tokenCount)))
                }
                public static func updateMetadata(_ values: [String: any ConvertibleToGeneratedContent]) -> Action {
                    Action(_kind: .metadata(Metadata(values: _isimGenerated(values))))
                }
            }
            public var id: String
            public var name: String
            public var action: Action
        }
        public struct Action: Sendable {
            enum _Kind: Sendable { case call(ToolCall), remove(String), metadata(Metadata), usage(Usage) }
            let _kind: _Kind
            public static func toolCall(id: String, name: String, action: ToolCall.Action) -> Action {
                Action(_kind: .call(ToolCall(id: id, name: name, action: action)))
            }
            public static func removeToolCall(id: String) -> Action { Action(_kind: .remove(id)) }
            public static func updateMetadata(_ values: [String: any ConvertibleToGeneratedContent]) -> Action {
                Action(_kind: .metadata(Metadata(values: _isimGenerated(values))))
            }
            public static func updateUsage(input: Usage.Input, output: Usage.Output, metadata: [String: any ConvertibleToGeneratedContent] = [:]) -> Action {
                Action(_kind: .usage(Usage(input: input, output: output, metadata: metadata)))
            }
        }
        public var action: Action
        public var entryID: String?
    }
    /// data (a file, an image) the model produces as an entry of its own
    public struct DataEntry: Sendable {
        public struct Update: Sendable { public var contentType: UTType; public var content: Data; public var metadata: GeneratedContent }
        public struct Action: Sendable {
            let _update: Update
            public static func update(contentType: UTType, content: Data, metadata: GeneratedContent = GeneratedContent(properties: [:])) -> Action {
                Action(_update: Update(contentType: contentType, content: content, metadata: metadata))
            }
        }
        public var action: Action
        public var entryID: String?
    }
}

// MARK: - usage

@available(iOS 27.0, macOS 27.0, *)
extension LanguageModelSession {
    /// Tokens a request (or the whole session) read and wrote.
    public struct Usage: Sendable {
        public struct Input: Sendable {
            public var totalTokenCount: Int
            public var cachedTokenCount: Int
            public init(totalTokenCount: Int, cachedTokenCount: Int) { self.totalTokenCount = totalTokenCount; self.cachedTokenCount = cachedTokenCount }
        }
        public struct Output: Sendable {
            public var totalTokenCount: Int
            public var reasoningTokenCount: Int
            public init(totalTokenCount: Int, reasoningTokenCount: Int) { self.totalTokenCount = totalTokenCount; self.reasoningTokenCount = reasoningTokenCount }
        }
        public var input: Input
        public var output: Output
        public var metadata: [String: GeneratedContent]
        public init(input: Input, output: Output, metadata: [String: any ConvertibleToGeneratedContent] = [:]) {
            self.input = input; self.output = output; self.metadata = _isimGenerated(metadata)
        }
        public var totalTokenCount: Int { input.totalTokenCount + output.totalTokenCount }
        static var _zero: Usage { Usage(input: Input(totalTokenCount: 0, cachedTokenCount: 0), output: Output(totalTokenCount: 0, reasoningTokenCount: 0)) }
        func _adding(_ o: Usage) -> Usage {
            var u = Usage(input: Input(totalTokenCount: input.totalTokenCount + o.input.totalTokenCount, cachedTokenCount: input.cachedTokenCount + o.input.cachedTokenCount),
                          output: Output(totalTokenCount: output.totalTokenCount + o.output.totalTokenCount,
                                         reasoningTokenCount: output.reasoningTokenCount + o.output.reasoningTokenCount))
            u.metadata = metadata.merging(o.metadata) { $1 }
            return u
        }
    }
    /// Misuse of a session.
    public enum Error: Swift.Error, LocalizedError, Sendable {
        case concurrentRequests
        case transcriptMutationWhileResponding
        public var errorDescription: String? {
            switch self {
            case .concurrentRequests: return "A session answers one request at a time."
            case .transcriptMutationWhileResponding: return "The transcript can't change while the session is responding."
            }
        }
    }
}

// MARK: - errors any model can report

@available(iOS 27.0, macOS 27.0, *)
public enum LanguageModelError: Error, LocalizedError, Sendable {
    public struct ContextSizeExceeded: Sendable {
        public var contextSize: Int
        public var tokenCount: Int
        public var debugDescription: String
        public var metadata: [String: any Sendable]
        public init(contextSize: Int, tokenCount: Int, debugDescription: String, metadata: [String: any Sendable] = [:]) {
            self.contextSize = contextSize; self.tokenCount = tokenCount; self.debugDescription = debugDescription; self.metadata = metadata
        }
    }
    public struct GuardrailViolation: Sendable {
        public var debugDescription: String
        public var metadata: [String: any Sendable]
        public init(debugDescription: String, metadata: [String: any Sendable] = [:]) { self.debugDescription = debugDescription; self.metadata = metadata }
    }
    public struct RateLimited: Sendable {
        public var resetDate: Date?
        public var debugDescription: String
        public var metadata: [String: any Sendable]
        public init(resetDate: Date?, debugDescription: String, metadata: [String: any Sendable] = [:]) {
            self.resetDate = resetDate; self.debugDescription = debugDescription; self.metadata = metadata
        }
    }
    public struct Refusal: Sendable {
        let _explanation: String
        public var debugDescription: String
        public var metadata: [String: any Sendable]
        public init(explanation: String, debugDescription: String, metadata: [String: any Sendable] = [:]) {
            _explanation = explanation; self.debugDescription = debugDescription; self.metadata = metadata
        }
        /// why the model refused
        public var explanation: LanguageModelSession.Response<String> {
            get async throws {
                LanguageModelSession.Response(content: _explanation, rawContent: GeneratedContent(_explanation), transcriptEntries: [])
            }
        }
        public var explanationStream: LanguageModelSession.ResponseStream<String> { .init(_text: _explanation) }
    }
    public struct Timeout: Sendable {
        public var debugDescription: String
        public var metadata: [String: any Sendable]
        public init(debugDescription: String, metadata: [String: any Sendable] = [:]) { self.debugDescription = debugDescription; self.metadata = metadata }
    }
    public struct UnsupportedCapability: Sendable {
        public var capability: LanguageModelCapabilities.Capability
        public var debugDescription: String
        public var metadata: [String: any Sendable]
        public init(capability: LanguageModelCapabilities.Capability, debugDescription: String, metadata: [String: any Sendable] = [:]) {
            self.capability = capability; self.debugDescription = debugDescription; self.metadata = metadata
        }
    }
    public struct UnsupportedGenerationGuide: Sendable {
        public var schemaName: String?
        public var debugDescription: String
        public var metadata: [String: any Sendable]
        public init(schemaName: String?, debugDescription: String, metadata: [String: any Sendable] = [:]) {
            self.schemaName = schemaName; self.debugDescription = debugDescription; self.metadata = metadata
        }
    }
    public struct UnsupportedLanguageOrLocale: Sendable {
        public var languageCode: Locale.LanguageCode
        public var debugDescription: String
        public var metadata: [String: any Sendable]
        public init(languageCode: Locale.LanguageCode, debugDescription: String, metadata: [String: any Sendable] = [:]) {
            self.languageCode = languageCode; self.debugDescription = debugDescription; self.metadata = metadata
        }
    }
    public struct UnsupportedTranscriptContent: Sendable {
        public var unsupportedContent: [Transcript.Entry]
        public var debugDescription: String
        public var metadata: [String: any Sendable]
        public init(unsupportedContent: [Transcript.Entry], debugDescription: String, metadata: [String: any Sendable] = [:]) {
            self.unsupportedContent = unsupportedContent; self.debugDescription = debugDescription; self.metadata = metadata
        }
    }
    case contextSizeExceeded(ContextSizeExceeded)
    case guardrailViolation(GuardrailViolation)
    case rateLimited(RateLimited)
    case refusal(Refusal)
    case timeout(Timeout)
    case unsupportedCapability(UnsupportedCapability)
    case unsupportedGenerationGuide(UnsupportedGenerationGuide)
    case unsupportedLanguageOrLocale(UnsupportedLanguageOrLocale)
    case unsupportedTranscriptContent(UnsupportedTranscriptContent)
    public var errorDescription: String? {
        switch self {
        case .contextSizeExceeded(let e): return e.debugDescription
        case .guardrailViolation(let e): return e.debugDescription
        case .rateLimited(let e): return e.debugDescription
        case .refusal(let e): return e.debugDescription
        case .timeout(let e): return e.debugDescription
        case .unsupportedCapability(let e): return e.debugDescription
        case .unsupportedGenerationGuide(let e): return e.debugDescription
        case .unsupportedLanguageOrLocale(let e): return e.debugDescription
        case .unsupportedTranscriptContent(let e): return e.debugDescription
        }
    }
}

// MARK: - the system model as a LanguageModel

@available(iOS 27.0, macOS 27.0, *)
extension SystemLanguageModel: LanguageModel {
    /// Which on-device model Apple's devices run (isim: the host model stands in for both).
    public struct Variant: Sendable, Hashable {
        public let displayName: String
        public static var core3: Variant { Variant(displayName: "Core 3") }
        public static var coreAdvanced3: Variant { Variant(displayName: "Core Advanced 3") }
    }
    public enum Error: Swift.Error, LocalizedError, Sendable {
        public struct AssetsUnavailable: Sendable {
            public var debugDescription: String
            public init(debugDescription: String) { self.debugDescription = debugDescription }
        }
        case assetsUnavailable(AssetsUnavailable)
        public var errorDescription: String? { switch self { case .assetsUnavailable(let e): return e.debugDescription } }
    }
    /// Runs the system model: isim's host backend (an OpenAI-compatible server, ISIM_LLM_URL / ISIM_LLM_MODEL).
    public struct Executor: LanguageModelExecutor {
        public struct Configuration: Hashable, Sendable { let _useCase: String }
        public typealias Model = SystemLanguageModel
        let _configuration: Configuration
        public init(configuration: Configuration) throws { _configuration = configuration }
        public func respond(to request: LanguageModelExecutorGenerationRequest, model: SystemLanguageModel,
                            streamingInto channel: LanguageModelExecutorGenerationChannel) async throws {
            guard model.isAvailable, let backend = _LanguageModelHost.backend else {
                throw Error.assetsUnavailable(.init(debugDescription: "the system language model is unavailable on this host"))
            }
            let messages = _isimMessages(request.transcript)
            var sent = ""
            for try await ev in backend.generate(messages: messages, tools: [], schema: request.schema, options: request.generationOptions) {
                switch ev {
                case .text(let t):
                    if t.hasPrefix(sent) { await channel.send(.response(action: .appendText(String(t.dropFirst(sent.count)), tokenCount: 0))) }
                    else { await channel.send(.response(action: .replaceTextSegment(t, tokenCount: 0))) }
                    sent = t
                case .toolCalls(let calls):
                    for c in calls { await channel.send(.toolCalls(action: .toolCall(id: c.id, name: c.name, action: .appendArguments(c.arguments, tokenCount: 0)))) }
                }
            }
        }
    }
    public var capabilities: LanguageModelCapabilities { LanguageModelCapabilities([.guidedGeneration, .toolCalling]) }
    public var executorConfiguration: Executor.Configuration { Executor.Configuration(_useCase: useCase._name) }
    public var variant: Variant { .core3 }
}

@available(iOS 26.0, macOS 26.0, *)
extension SystemLanguageModel {
    /// how many tokens a session's context holds (the host model's context; 4096 like Apple's on-device model)
    public var contextSize: Int { Int(ProcessInfo.processInfo.environment["ISIM_LLM_CONTEXT"] ?? "") ?? 4096 }
    /// the tokens instructions take (estimated: about four characters a token, as the host model's tokenizer is not known)
    public func tokenCount(for instructions: Instructions) async throws -> Int { _isimTokenEstimate(instructions._text) }
}
func _isimTokenEstimate(_ s: String) -> Int { s.isEmpty ? 0 : max(1, (s.utf8.count + 3) / 4) }

/// the transcript as chat messages (Backend.swift)
@available(iOS 26.0, macOS 26.0, *)
func _isimMessages(_ t: Transcript) -> [_ChatMessage] {
    var messages: [_ChatMessage] = []
    for e in t._entries {
        switch e {
        case .instructions(let i): messages.append(_ChatMessage(role: "system", content: i.segments.map(\._text).joined(separator: "\n")))
        case .prompt(let p): messages.append(_ChatMessage(role: "user", content: p.segments.map(\._text).joined(separator: "\n")))
        case .response(let r): messages.append(_ChatMessage(role: "assistant", content: r.segments.map(\._text).joined(separator: "\n")))
        case .toolCalls(let c): messages.append(_ChatMessage(role: "assistant", content: nil, toolCalls: c.map { (id: $0.id, name: $0.toolName, arguments: $0.arguments.jsonString) }))
        case .toolOutput(let o): messages.append(_ChatMessage(role: "tool", content: o.segments.map(\._text).joined(separator: "\n"), toolCallID: o.id))
        default: break   // reasoning and data entries are not sent to a chat-completions model
        }
    }
    return messages
}

// MARK: - Private Cloud Compute

/// Apple's server model. isim has no Private Cloud Compute: the model is never available and its executor fails.
@available(iOS 27.0, macOS 27.0, *)
public final class PrivateCloudComputeLanguageModel: LanguageModel, @unchecked Sendable {
    @frozen public enum Availability: Equatable, Sendable {
        public enum UnavailableReason: Equatable, Sendable { case deviceNotEligible, systemNotReady }
        case available
        case unavailable(UnavailableReason)
    }
    public enum Error: Swift.Error, LocalizedError, Sendable {
        public struct NetworkFailure: Sendable {
            public var debugDescription: String
            public init(debugDescription: String) { self.debugDescription = debugDescription }
        }
        public struct QuotaLimitReached: Sendable {
            public var limitIncreaseSuggestion: QuotaUsage.LimitIncreaseSuggestion?
            public var resetDate: Date?
            public var debugDescription: String
            public init(limitIncreaseSuggestion: QuotaUsage.LimitIncreaseSuggestion? = nil, resetDate: Date? = nil, debugDescription: String) {
                self.limitIncreaseSuggestion = limitIncreaseSuggestion; self.resetDate = resetDate; self.debugDescription = debugDescription
            }
        }
        public struct ServiceUnavailable: Sendable {
            public var debugDescription: String
            public init(debugDescription: String) { self.debugDescription = debugDescription }
        }
        case networkFailure(NetworkFailure)
        case quotaLimitReached(QuotaLimitReached)
        case serviceUnavailable(ServiceUnavailable)
        public var errorDescription: String? {
            switch self {
            case .networkFailure(let e): return e.debugDescription
            case .quotaLimitReached(let e): return e.debugDescription
            case .serviceUnavailable(let e): return e.debugDescription
            }
        }
    }
    /// How much of the app's Private Cloud Compute quota is used.
    public struct QuotaUsage: Sendable {
        public struct LimitIncreaseSuggestion: Sendable {
            /// shows the system's offer to raise the limit (isim: nothing to show)
            public func show() {}
        }
        public enum Status: Sendable {
            public struct BelowLimit: Sendable { public var isApproachingLimit: Bool }
            public struct LimitReached: Sendable {}
            case belowLimit(BelowLimit)
            case limitReached(LimitReached)
        }
        public var status: Status
        public var resetDate: Date?
        public var limitIncreaseSuggestion: LimitIncreaseSuggestion?
        public var isLimitReached: Bool { if case .limitReached = status { return true }; return false }
    }
    public struct Executor: LanguageModelExecutor {
        public struct Configuration: Hashable, Sendable {}
        public typealias Model = PrivateCloudComputeLanguageModel
        public init(configuration: Configuration) throws {}
        public func respond(to request: LanguageModelExecutorGenerationRequest, model: PrivateCloudComputeLanguageModel,
                            streamingInto channel: LanguageModelExecutorGenerationChannel) async throws {
            throw Error.serviceUnavailable(.init(debugDescription: "Private Cloud Compute is not available on isim"))
        }
    }
    public convenience init() { self.init(_isim: ()) }
    init(_isim: Void) {}
    public var availability: Availability { .unavailable(.deviceNotEligible) }
    public var isAvailable: Bool { false }
    public var capabilities: LanguageModelCapabilities { LanguageModelCapabilities([.guidedGeneration, .toolCalling, .reasoning, .vision]) }
    public var executorConfiguration: Executor.Configuration { Executor.Configuration() }
    public var quotaUsage: QuotaUsage { QuotaUsage(status: .belowLimit(.init(isApproachingLimit: false)), resetDate: nil, limitIncreaseSuggestion: nil) }
    public var contextSize: Int {
        get async throws { throw Error.serviceUnavailable(.init(debugDescription: "Private Cloud Compute is not available on isim")) }
    }
    public var supportedLanguages: Set<Locale.Language> {
        get async throws { [] }
    }
    public func supportsLocale(_ locale: Locale = Locale.current) async throws -> Bool { false }
}

// MARK: - feedback

/// Feedback on a response, for Apple's model team (isim: kept in the attachment it returns, sent nowhere).
@available(iOS 26.0, macOS 26.0, *)
public struct LanguageModelFeedback: Sendable {
    public enum Sentiment: String, Sendable, Hashable, CaseIterable { case positive, negative, neutral }
    public struct Issue: Sendable {
        public enum Category: String, Sendable, Hashable, CaseIterable {
            case unhelpful, tooVerbose, didNotFollowInstructions, incorrect, stereotypeOrBias, suggestiveOrSexual, vulgarOrOffensive
            case triggeredGuardrailUnexpectedly
        }
        public var category: Category
        public var explanation: String?
        public init(category: Category, explanation: String? = nil) { self.category = category; self.explanation = explanation }
    }
}
@available(iOS 26.0, macOS 26.0, *)
extension LanguageModelSession {
    /// The feedback and the session's transcript as JSON, to attach to a Feedback Assistant report.
    @discardableResult
    public final func logFeedbackAttachment(sentiment: LanguageModelFeedback.Sentiment?, issues: [LanguageModelFeedback.Issue] = [],
                                            desiredOutput: Transcript.Entry? = nil) -> Data {
        _isimFeedback(sentiment, issues, desired: desiredOutput?.description)
    }
    @discardableResult
    public final func logFeedbackAttachment(sentiment: LanguageModelFeedback.Sentiment?, issues: [LanguageModelFeedback.Issue] = [],
                                            desiredResponseContent: (any ConvertibleToGeneratedContent)?) -> Data {
        _isimFeedback(sentiment, issues, desired: desiredResponseContent?.generatedContent.jsonString)
    }
    @discardableResult
    public final func logFeedbackAttachment(sentiment: LanguageModelFeedback.Sentiment?, issues: [LanguageModelFeedback.Issue] = [],
                                            desiredResponseText: String?) -> Data {
        _isimFeedback(sentiment, issues, desired: desiredResponseText)
    }
    func _isimFeedback(_ sentiment: LanguageModelFeedback.Sentiment?, _ issues: [LanguageModelFeedback.Issue], desired: String?) -> Data {
        var d: [String: Any] = ["transcript": transcript.map(\.description),
                                "issues": issues.map { ["category": $0.category.rawValue, "explanation": $0.explanation ?? ""] }]
        if let sentiment { d["sentiment"] = sentiment.rawValue }
        if let desired { d["desiredOutput"] = desired }
        return (try? JSONSerialization.data(withJSONObject: d, options: [.sortedKeys])) ?? Data()
    }
}
