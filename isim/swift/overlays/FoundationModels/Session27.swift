// isim Foundation Models (iOS 27, issue #859): how a session runs a model other than the system one, and the
// session's iOS 27 overloads (context options and metadata). A custom model runs through its executor: the session
// sends it the transcript (the prompt is already in it), reads the events it streams into the channel, records
// reasoning, data entries and attachments in the transcript and counts the usage; tool calls go back to the session's
// tool loop (Session.swift), which calls the tools and asks the model again.
import Foundation

@available(iOS 26.0, macOS 26.0, *)
extension LanguageModelSession {
    /// before each request: the dynamic instructions or profile again, and this request's usage from zero
    func _isimPreRequest() {
        _lastUsage = nil
        if #available(iOS 27.0, macOS 27.0, *) { _refreshDynamic() }
    }
    /// the backend of a session whose model is not the system one
    func _isimCustomBackend() -> (any _LanguageModelBackend)? {
        if #available(iOS 27.0, macOS 27.0, *), let m = _custom as? any LanguageModel { return _ExecutorBackend(model: m, session: self) }
        return nil
    }
    func _isimEffective(_ o: GenerationOptions) -> GenerationOptions {
        if #available(iOS 27.0, macOS 27.0, *) { return _effectiveOptions(o) }
        return o
    }
    /// the entries the model sees (the profile's history transform, if any)
    func _isimHistoryForModel(_ entries: [Transcript.Entry]) -> [Transcript.Entry] {
        if #available(iOS 27.0, macOS 27.0, *), let r = _profile as? _ResolvedProfile, let t = r.historyTransform { return t(entries) }
        return entries
    }
    var _isimRevertsOnError: Bool {
        if #available(iOS 27.0, macOS 27.0, *) { return (_policy as? TranscriptErrorHandlingPolicy) == .revertTranscript }
        return false
    }
    func _isimRunHooks(_ name: String) async {
        for h in _hooks[name] ?? [] { try? await h() }
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension LanguageModelSession.ResponseStream where Content == String {
    /// a stream of a text known in advance (a refusal's explanation)
    init(_text text: String) {
        let snapshot = Snapshot(content: text, rawContent: GeneratedContent(text))
        self.init(_make: { AsyncThrowingStream { $0.yield(snapshot); $0.finish() } },
                  _final: { LanguageModelSession.Response(content: text, rawContent: GeneratedContent(text), transcriptEntries: []) })
    }
}
@available(iOS 26.0, macOS 26.0, *)
extension LanguageModelSession.GenerationError.Refusal {
    public var explanationStream: LanguageModelSession.ResponseStream<String> { .init(_text: _explanation) }
}

// MARK: - a custom model's executor as the session's backend

@available(iOS 27.0, macOS 27.0, *)
struct _ExecutorBackend: _LanguageModelBackend, @unchecked Sendable {
    let model: any LanguageModel
    unowned let session: LanguageModelSession
    var name: String { String(describing: type(of: model)) }

    func generate(messages: [_ChatMessage], tools: [any Tool], schema: GenerationSchema?, options: GenerationOptions) -> AsyncThrowingStream<_BackendEvent, Swift.Error> {
        let session = self.session, model = self.model
        return AsyncThrowingStream { cont in
            let task = Task {
                do { try await _ExecutorBackend.run(model, session: session, tools: tools, schema: schema, options: options) { cont.yield($0) }; cont.finish() }
                catch { cont.finish(throwing: error) }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }

    static func run<M: LanguageModel>(_ model: M, session: LanguageModelSession, tools: [any Tool], schema: GenerationSchema?, options: GenerationOptions,
                                      yield: @escaping (_BackendEvent) -> Void) async throws {
        let executor = try M.Executor(configuration: model.executorConfiguration)
        let transcript = Transcript(entries: session._isimHistoryForModel(session.transcript._entries))
        let request = LanguageModelExecutorGenerationRequest(
            id: UUID(), transcript: transcript, enabledTools: tools.map { Transcript.ToolDefinition(tool: $0) }, schema: schema,
            generationOptions: options, contextOptions: session._context as? ContextOptions ?? ContextOptions(), metadata: session._metadata)
        let channel = LanguageModelExecutorGenerationChannel()
        let work = Task {
            defer { channel._finish() }
            try await executor.respond(to: request, model: model, streamingInto: channel)
        }
        var text = _Segments(), reasoning = _Segments()
        var signature: Data?
        var calls: [(id: String, name: String, arguments: String)] = []
        var usage = LanguageModelSession.Usage._zero
        var responseMetadata: [String: GeneratedContent] = [:], reasoningMetadata: [String: GeneratedContent] = [:]
        func addUsage(_ u: LanguageModelExecutorGenerationChannel.Usage) {
            usage = usage._adding(LanguageModelSession.Usage(input: .init(totalTokenCount: u.input.totalTokenCount, cachedTokenCount: u.input.cachedTokenCount),
                                                             output: .init(totalTokenCount: u.output.totalTokenCount, reasoningTokenCount: u.output.reasoningTokenCount),
                                                             metadata: u.metadata))
        }
        for await event in channel {
            switch event._kind {
            case .response(let r):
                switch r.action._kind {
                case .text(.append(let f)): text.append(f.content, f.segmentID); yield(.text(text.joined))
                case .text(.replace(let f)): text.replace(f.content, f.segmentID); yield(.text(text.joined))
                case .text(.metadata(let m)): responseMetadata.merge(m.values) { $1 }
                case .text(.usage(let u)): addUsage(u)
                case .addAttachment(let a): session._attachments.append(.attachment(a))
                case .removeAttachment(let id): session._attachments.removeAll { $0.id == id }
                }
            case .reasoning(let r):
                switch r.action._kind {
                case .text(.append(let f)): reasoning.append(f.content, f.segmentID)
                case .text(.replace(let f)): reasoning.replace(f.content, f.segmentID)
                case .text(.metadata(let m)): reasoningMetadata.merge(m.values) { $1 }
                case .text(.usage(let u)): addUsage(u)
                case .signature(let s): signature = s.signature
                }
            case .toolCalls(let t):
                switch t.action._kind {
                case .call(let c):
                    if case .arguments(let a) = c.action._kind {
                        if let i = calls.firstIndex(where: { $0.id == c.id }) { calls[i].arguments += a.content } else { calls.append((c.id, c.name, a.content)) }
                    }
                case .remove(let id): calls.removeAll { $0.id == id }
                case .metadata: break
                case .usage(let u): addUsage(u)
                }
            case .data(let d):
                let u = d.action._update
                session._append(.data(Transcript.DataEntry(id: d.entryID ?? UUID().uuidString, contentType: u.contentType, content: u.content, metadata: u.metadata)))
            }
        }
        try await work.value
        if !reasoning.isEmpty {
            var entry = Transcript.Reasoning(segments: reasoning.segments.map { .text(.init(content: $0.text)) }, signature: signature)
            entry.metadata = reasoningMetadata
            session._append(.reasoning(entry))
            await session._isimRunHooks("reasoning")
        }
        session._lastUsage = (session._lastUsage as? LanguageModelSession.Usage ?? ._zero)._adding(usage)
        session._usage = (session._usage as? LanguageModelSession.Usage ?? ._zero)._adding(usage)
        if !calls.isEmpty { yield(.toolCalls(calls)) }
    }
}

/// text segments by ID, as an executor appends and replaces them
@available(iOS 27.0, macOS 27.0, *)
struct _Segments {
    var segments: [(id: String?, text: String)] = []
    var isEmpty: Bool { segments.allSatisfy { $0.text.isEmpty } }
    var joined: String { segments.map(\.text).joined() }
    mutating func append(_ s: String, _ id: String?) {
        if let i = segments.lastIndex(where: { $0.id == id }), i == segments.count - 1 || id != nil { segments[i].text += s } else { segments.append((id, s)) }
    }
    mutating func replace(_ s: String, _ id: String?) {
        if let i = segments.lastIndex(where: { $0.id == id }) { segments[i].text = s } else { segments.append((id, s)) }
    }
}

// MARK: - the iOS 27 overloads: context options and metadata

@available(iOS 27.0, macOS 27.0, *)
extension LanguageModelSession {
    func _with(_ contextOptions: ContextOptions, _ metadata: [String: any ConvertibleToGeneratedContent]) {
        _context = contextOptions
        _metadata = _isimGenerated(metadata)
    }
    @_disfavoredOverload @discardableResult
    public final func respond(to prompt: Prompt, options: GenerationOptions = GenerationOptions(), contextOptions: ContextOptions = ContextOptions(),
                              metadata: [String: any ConvertibleToGeneratedContent] = [:]) async throws -> Response<String> {
        _with(contextOptions, metadata)
        return try await respond(to: prompt, options: options)
    }
    @_disfavoredOverload @discardableResult
    public final func respond(options: GenerationOptions = GenerationOptions(), contextOptions: ContextOptions = ContextOptions(),
                              metadata: [String: any ConvertibleToGeneratedContent] = [:], @PromptBuilder prompt: () throws -> Prompt) async throws -> Response<String> {
        try await respond(to: try prompt(), options: options, contextOptions: contextOptions, metadata: metadata)
    }
    @_disfavoredOverload @discardableResult
    public final func respond(to prompt: Prompt, schema: GenerationSchema, options: GenerationOptions = GenerationOptions(),
                              contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
                              metadata: [String: any ConvertibleToGeneratedContent] = [:]) async throws -> Response<GeneratedContent> {
        _with(contextOptions, metadata)
        return try await respond(to: prompt, schema: schema, includeSchemaInPrompt: contextOptions.includeSchemaInPrompt ?? true, options: options)
    }
    @_disfavoredOverload @discardableResult
    public final func respond(schema: GenerationSchema, options: GenerationOptions = GenerationOptions(),
                              contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
                              metadata: [String: any ConvertibleToGeneratedContent] = [:], @PromptBuilder prompt: () throws -> Prompt) async throws -> Response<GeneratedContent> {
        try await respond(to: try prompt(), schema: schema, options: options, contextOptions: contextOptions, metadata: metadata)
    }
    @_disfavoredOverload @discardableResult
    public final func respond<Content: Generable>(to prompt: Prompt, generating type: Content.Type = Content.self, options: GenerationOptions = GenerationOptions(),
                                                  contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
                                                  metadata: [String: any ConvertibleToGeneratedContent] = [:]) async throws -> Response<Content> {
        _with(contextOptions, metadata)
        return try await respond(to: prompt, generating: type, includeSchemaInPrompt: contextOptions.includeSchemaInPrompt ?? true, options: options)
    }
    @_disfavoredOverload @discardableResult
    public final func respond<Content: Generable>(generating type: Content.Type = Content.self, options: GenerationOptions = GenerationOptions(),
                                                  contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
                                                  metadata: [String: any ConvertibleToGeneratedContent] = [:],
                                                  @PromptBuilder prompt: () throws -> Prompt) async throws -> Response<Content> {
        try await respond(to: try prompt(), generating: type, options: options, contextOptions: contextOptions, metadata: metadata)
    }
    @_disfavoredOverload
    public final func streamResponse(to prompt: Prompt, options: GenerationOptions = GenerationOptions(), contextOptions: ContextOptions = ContextOptions(),
                                     metadata: [String: any ConvertibleToGeneratedContent] = [:]) -> ResponseStream<String> {
        _with(contextOptions, metadata)
        return streamResponse(to: prompt, options: options)
    }
    @_disfavoredOverload
    public final func streamResponse(options: GenerationOptions = GenerationOptions(), contextOptions: ContextOptions = ContextOptions(),
                                     metadata: [String: any ConvertibleToGeneratedContent] = [:], @PromptBuilder prompt: () throws -> Prompt) rethrows -> ResponseStream<String> {
        streamResponse(to: try prompt(), options: options, contextOptions: contextOptions, metadata: metadata)
    }
    @_disfavoredOverload
    public final func streamResponse(to prompt: Prompt, schema: GenerationSchema, options: GenerationOptions = GenerationOptions(),
                                     contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
                                     metadata: [String: any ConvertibleToGeneratedContent] = [:]) -> ResponseStream<GeneratedContent> {
        _with(contextOptions, metadata)
        return streamResponse(to: prompt, schema: schema, includeSchemaInPrompt: contextOptions.includeSchemaInPrompt ?? true, options: options)
    }
    @_disfavoredOverload
    public final func streamResponse(schema: GenerationSchema, options: GenerationOptions = GenerationOptions(),
                                     contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
                                     metadata: [String: any ConvertibleToGeneratedContent] = [:], @PromptBuilder prompt: () throws -> Prompt) rethrows -> ResponseStream<GeneratedContent> {
        streamResponse(to: try prompt(), schema: schema, options: options, contextOptions: contextOptions, metadata: metadata)
    }
    @_disfavoredOverload
    public final func streamResponse<Content: Generable>(to prompt: Prompt, generating type: Content.Type = Content.self, options: GenerationOptions = GenerationOptions(),
                                                         contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
                                                         metadata: [String: any ConvertibleToGeneratedContent] = [:]) -> ResponseStream<Content> {
        _with(contextOptions, metadata)
        return streamResponse(to: prompt, generating: type, includeSchemaInPrompt: contextOptions.includeSchemaInPrompt ?? true, options: options)
    }
    @_disfavoredOverload
    public final func streamResponse<Content: Generable>(generating type: Content.Type = Content.self, options: GenerationOptions = GenerationOptions(),
                                                         contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
                                                         metadata: [String: any ConvertibleToGeneratedContent] = [:],
                                                         @PromptBuilder prompt: () throws -> Prompt) rethrows -> ResponseStream<Content> {
        streamResponse(to: try prompt(), generating: type, options: options, contextOptions: contextOptions, metadata: metadata)
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension LanguageModelSession {
    /// the iOS 26 `respond(schema:includeSchemaInPrompt:options:prompt:)` with a prompt builder
    @discardableResult
    public final func respond(schema: GenerationSchema, includeSchemaInPrompt: Bool = true, options: GenerationOptions = GenerationOptions(),
                              @PromptBuilder prompt: () throws -> Prompt) async throws -> Response<GeneratedContent> {
        try await respond(to: try prompt(), schema: schema, includeSchemaInPrompt: includeSchemaInPrompt, options: options)
    }
    public final func streamResponse(schema: GenerationSchema, includeSchemaInPrompt: Bool = true, options: GenerationOptions = GenerationOptions(),
                                     @PromptBuilder prompt: () throws -> Prompt) rethrows -> ResponseStream<GeneratedContent> {
        streamResponse(to: try prompt(), schema: schema, includeSchemaInPrompt: includeSchemaInPrompt, options: options)
    }
}
