// isim Foundation Models (iOS 27, issue #859): dynamic instructions and profiles, session properties, and the
// session's iOS 27 entry points. Instructions and profiles are declarative, like SwiftUI views: a `body` built from
// text, tools, conditionals and ForEach, read again before every request, so they follow the session's properties.
// A profile adds the model and its settings (temperature, sampling, token limit, reasoning, tool calling, the error
// policy, a history transform) and life-cycle hooks. Adapted: everything resolves to isim's session engine; a model
// other than the system one runs through its executor (LanguageModels.swift).
import Foundation

// MARK: - dynamic instructions

/// Instructions computed from the session's state.
@available(iOS 27.0, macOS 27.0, *)
public protocol DynamicInstructions {
    associatedtype Body: DynamicInstructions
    @DynamicInstructionsBuilder var body: Self.Body { get }
}
@available(iOS 27.0, macOS 27.0, *)
extension DynamicInstructions {
    public typealias ForEach = DynamicInstructionsForEach
    public typealias SessionProperty = LanguageModelSession.SessionProperty
}
@available(iOS 27.0, macOS 27.0, *)
extension Never: DynamicInstructions {
    public var body: Never { fatalError("Never has no body") }
}

/// what instructions resolve to: their text and tools
@available(iOS 27.0, macOS 27.0, *)
struct _ResolvedInstructions {
    var text: [String] = []
    var tools: [any Tool] = []
}
@available(iOS 27.0, macOS 27.0, *)
protocol _InstructionsPrimitive { func _resolve(into r: inout _ResolvedInstructions) }
@available(iOS 27.0, macOS 27.0, *)
func _isimResolve<D: DynamicInstructions>(_ d: D, into r: inout _ResolvedInstructions) {
    if let p = d as? _InstructionsPrimitive { p._resolve(into: &r) } else { _isimResolve(d.body, into: &r) }
}

@available(iOS 27.0, macOS 27.0, *)
extension Instructions: DynamicInstructions, _InstructionsPrimitive {
    public var body: Never { fatalError("Instructions has no body") }
    func _resolve(into r: inout _ResolvedInstructions) { if !_text.isEmpty { r.text.append(_text) } }
}
@available(iOS 27.0, macOS 27.0, *)
struct _ToolInstructions: DynamicInstructions, _InstructionsPrimitive {
    let tools: [any Tool]
    var body: Never { fatalError() }
    func _resolve(into r: inout _ResolvedInstructions) { r.tools += tools }
}
@available(iOS 27.0, macOS 27.0, *)
public struct EmptyDynamicInstructions: DynamicInstructions, _InstructionsPrimitive {
    public init() {}
    public var body: Never { fatalError() }
    func _resolve(into r: inout _ResolvedInstructions) {}
}
@available(iOS 27.0, macOS 27.0, *)
public struct AnyDynamicInstructions: DynamicInstructions, _InstructionsPrimitive {
    let _resolver: (inout _ResolvedInstructions) -> Void
    public init(_ dynamicInstructions: any DynamicInstructions) {
        func open<D: DynamicInstructions>(_ d: D) -> (inout _ResolvedInstructions) -> Void { { _isimResolve(d, into: &$0) } }
        _resolver = open(dynamicInstructions)
    }
    public init(erasing dynamicInstructions: some DynamicInstructions) { self.init(dynamicInstructions as any DynamicInstructions) }
    public var body: Never { fatalError() }
    func _resolve(into r: inout _ResolvedInstructions) { _resolver(&r) }
}
@available(iOS 27.0, macOS 27.0, *)
public struct ConditionalDynamicInstructions<TrueContent, FalseContent>: DynamicInstructions, _InstructionsPrimitive
    where TrueContent: DynamicInstructions, FalseContent: DynamicInstructions {
    public enum Branch { case trueContent(TrueContent), falseContent(FalseContent) }
    let _branch: Branch
    public init(_ branch: Branch) { _branch = branch }
    public var body: Never { fatalError() }
    func _resolve(into r: inout _ResolvedInstructions) {
        switch _branch { case .trueContent(let c): _isimResolve(c, into: &r); case .falseContent(let c): _isimResolve(c, into: &r) }
    }
}
@available(iOS 27.0, macOS 27.0, *)
public struct TupleDynamicInstructions<each Content>: DynamicInstructions, _InstructionsPrimitive where repeat each Content: DynamicInstructions {
    let _resolvers: [(inout _ResolvedInstructions) -> Void]
    public init(_ contents: repeat each Content) {
        var all: [(inout _ResolvedInstructions) -> Void] = []
        for c in repeat each contents { all.append({ _isimResolve(c, into: &$0) }) }
        _resolvers = all
    }
    public var body: Never { fatalError() }
    func _resolve(into r: inout _ResolvedInstructions) { for f in _resolvers { f(&r) } }
}
@available(iOS 27.0, macOS 27.0, *)
public struct DynamicInstructionsForEach<Data, ID, Content>: DynamicInstructions, _InstructionsPrimitive
    where Data: RandomAccessCollection, ID: Hashable, Content: DynamicInstructions {
    let _data: Data
    let _content: (Data.Element) -> Content
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @DynamicInstructionsBuilder content: @escaping (Data.Element) -> Content) {
        _data = data; _content = content
    }
    public var body: Never { fatalError() }
    func _resolve(into r: inout _ResolvedInstructions) { for e in _data { _isimResolve(_content(e), into: &r) } }
}
@available(iOS 27.0, macOS 27.0, *)
extension DynamicInstructionsForEach where ID == Data.Element.ID, Data.Element: Identifiable {
    public init(_ data: Data, @DynamicInstructionsBuilder content: @escaping (Data.Element) -> Content) {
        self.init(data, id: \.id, content: content)
    }
}

@available(iOS 27.0, macOS 27.0, *)
@resultBuilder public struct DynamicInstructionsBuilder {
    public static func buildBlock() -> EmptyDynamicInstructions { EmptyDynamicInstructions() }
    public static func buildBlock<T>(_ content: T) -> T where T: DynamicInstructions { content }
    public static func buildBlock<each Content>(_ content: repeat each Content) -> TupleDynamicInstructions<repeat each Content>
        where repeat each Content: DynamicInstructions { TupleDynamicInstructions(repeat each content) }
    public static func buildExpression<T: DynamicInstructions>(_ content: T) -> T { content }
    public static func buildExpression(_ text: String) -> Instructions { Instructions(text) }
    public static func buildExpression(_ tools: [any Tool]) -> some DynamicInstructions { _ToolInstructions(tools: tools) }
    public static func buildEither<TrueContent, FalseContent>(first content: TrueContent) -> ConditionalDynamicInstructions<TrueContent, FalseContent>
        where TrueContent: DynamicInstructions, FalseContent: DynamicInstructions { .init(.trueContent(content)) }
    public static func buildEither<TrueContent, FalseContent>(second content: FalseContent) -> ConditionalDynamicInstructions<TrueContent, FalseContent>
        where TrueContent: DynamicInstructions, FalseContent: DynamicInstructions { .init(.falseContent(content)) }
    public static func buildOptional<Content>(_ content: Content?) -> Content? where Content: DynamicInstructions { content }
    public static func buildLimitedAvailability(_ content: some DynamicInstructions) -> AnyDynamicInstructions { AnyDynamicInstructions(erasing: content) }
}
@available(iOS 27.0, macOS 27.0, *)
extension Optional: DynamicInstructions, _InstructionsPrimitive where Wrapped: DynamicInstructions {
    public var body: Never { fatalError() }
    func _resolve(into r: inout _ResolvedInstructions) { if let w = self { _isimResolve(w, into: &r) } }
}

// MARK: - session properties

/// A key for a session property (`@SessionPropertyEntry` declares one).
@available(iOS 27.0, macOS 27.0, *)
public protocol SessionPropertyKey: SendableMetatype {
    associatedtype Value
    static var defaultValue: Value { get }
}
/// The session's properties: the history and any keyed values instructions and profiles read.
@available(iOS 27.0, macOS 27.0, *)
public final class SessionPropertyValues: @unchecked Sendable {
    var _values: [ObjectIdentifier: Any] = [:]
    weak var _session: LanguageModelSession?
    var _detachedHistory = Transcript.HistoryView()
    let _lock = NSLock()
    init(session: LanguageModelSession?) { _session = session }
    /// the values read where no session is resolving (a property outside a session)
    static let _unbound = SessionPropertyValues(session: nil)
    @TaskLocal static var _current: SessionPropertyValues?
    public final var history: Transcript.HistoryView {
        get { _session?.transcript.history ?? _detachedHistory }
        set { if let s = _session { s._setHistory(newValue) } else { _detachedHistory = newValue } }
    }
    public final subscript<K>(key: K.Type) -> K.Value where K: SessionPropertyKey {
        get { _lock.lock(); defer { _lock.unlock() }; return _values[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { _lock.lock(); _values[ObjectIdentifier(key)] = newValue; _lock.unlock() }
    }
}
@available(iOS 27.0, macOS 27.0, *)
extension LanguageModelSession {
    /// Reads and writes one of the session's properties from instructions, profiles and tools.
    @propertyWrapper public struct SessionProperty<Value> {
        let _keyPath: ReferenceWritableKeyPath<SessionPropertyValues, Value>
        public init(_ keyPath: ReferenceWritableKeyPath<SessionPropertyValues, Value>) { _keyPath = keyPath }
        public var wrappedValue: Value {
            get { (SessionPropertyValues._current ?? ._unbound)[keyPath: _keyPath] }
            nonmutating set { (SessionPropertyValues._current ?? ._unbound)[keyPath: _keyPath] = newValue }
        }
    }
    /// the session's properties
    public final var properties: SessionPropertyValues {
        if let p = _properties as? SessionPropertyValues { return p }
        let p = SessionPropertyValues(session: self)
        _properties = p
        return p
    }
    func _setHistory(_ h: Transcript.HistoryView) { transcript.history = h }
}
@available(iOS 27.0, macOS 27.0, *)
extension Tool {
    public typealias SessionProperty = LanguageModelSession.SessionProperty
}

/// Declares a session property: `extension SessionPropertyValues { @SessionPropertyEntry var count: Int = 0 }`.
@available(iOS 27.0, macOS 27.0, *)
@attached(accessor) @attached(peer, names: prefixed(__Key_))
public macro SessionPropertyEntry() = #externalMacro(module: "FoundationModelsMacros", type: "SessionPropertyEntryMacro")

// MARK: - profiles

/// what a profile resolves to
@available(iOS 27.0, macOS 27.0, *)
struct _ResolvedProfile {
    var instructions = _ResolvedInstructions()
    var model: (any LanguageModel)?
    var temperature: Double??
    var sampling: GenerationOptions.SamplingMode??
    var maximumResponseTokens: Int??
    var reasoningLevel: ContextOptions.ReasoningLevel??
    var toolCallingMode: GenerationOptions.ToolCallingMode??
    var policy: TranscriptErrorHandlingPolicy??
    var historyTransform: (([Transcript.Entry]) -> [Transcript.Entry])?
    var hooks: [String: [() async throws -> Void]] = [:]
}
@available(iOS 27.0, macOS 27.0, *)
protocol _ProfilePrimitive { func _resolve(into r: inout _ResolvedProfile) }
@available(iOS 27.0, macOS 27.0, *)
func _isimResolveProfile<P: LanguageModelSession.DynamicProfile>(_ p: P, into r: inout _ResolvedProfile) {
    if let prim = p as? _ProfilePrimitive { prim._resolve(into: &r) } else { _isimResolveProfile(p.body, into: &r) }
}

@available(iOS 27.0, macOS 27.0, *)
extension LanguageModelSession {
    /// A session's model, settings and instructions, computed from its state.
    public protocol DynamicProfile {
        associatedtype Body: LanguageModelSession.DynamicProfile
        @LanguageModelSession.DynamicProfileBuilder var body: Self.Body { get }
    }
    /// Changes a profile (`profile.modifier(MyModifier())`).
    public protocol DynamicProfileModifier {
        associatedtype Body: LanguageModelSession.DynamicProfile
        typealias Content = LanguageModelSession.DynamicProfileModifierContent<Self>
        typealias DynamicProfile = LanguageModelSession.DynamicProfile
        typealias SessionProperty = LanguageModelSession.SessionProperty
        @LanguageModelSession.DynamicProfileBuilder func body(content: Self.Content) -> Self.Body
    }
    /// The instructions of a profile.
    public struct Profile: DynamicProfile, _ProfilePrimitive {
        let _resolver: (inout _ResolvedInstructions) -> Void
        public init(@DynamicInstructionsBuilder _ dynamicInstructions: () -> some DynamicInstructions) {
            let d = dynamicInstructions()
            _resolver = { _isimResolve(d, into: &$0) }
        }
        public var body: Never { fatalError() }
        func _resolve(into r: inout _ResolvedProfile) { _resolver(&r.instructions) }
    }
    public struct AnyDynamicProfile: DynamicProfile, _ProfilePrimitive {
        let _resolver: (inout _ResolvedProfile) -> Void
        public init(_ dynamicProfile: any LanguageModelSession.DynamicProfile) {
            func open<P: LanguageModelSession.DynamicProfile>(_ p: P) -> (inout _ResolvedProfile) -> Void { { _isimResolveProfile(p, into: &$0) } }
            _resolver = open(dynamicProfile)
        }
        public init(erasing dynamicProfile: some LanguageModelSession.DynamicProfile) { self.init(dynamicProfile as any LanguageModelSession.DynamicProfile) }
        public var body: Never { fatalError() }
        func _resolve(into r: inout _ResolvedProfile) { _resolver(&r) }
    }
    public struct ConditionalDynamicProfile<TrueContent, FalseContent>: DynamicProfile, _ProfilePrimitive
        where TrueContent: LanguageModelSession.DynamicProfile, FalseContent: LanguageModelSession.DynamicProfile {
        enum _Branch { case t(TrueContent), f(FalseContent) }
        let _branch: _Branch
        public var body: Never { fatalError() }
        func _resolve(into r: inout _ResolvedProfile) {
            switch _branch { case .t(let c): _isimResolveProfile(c, into: &r); case .f(let c): _isimResolveProfile(c, into: &r) }
        }
    }
    /// The profile a modifier changes.
    public struct DynamicProfileModifierContent<Modifier>: DynamicProfile, _ProfilePrimitive where Modifier: LanguageModelSession.DynamicProfileModifier {
        let _resolver: (inout _ResolvedProfile) -> Void
        public var body: Never { fatalError() }
        func _resolve(into r: inout _ResolvedProfile) { _resolver(&r) }
    }
    public struct ModifiedDynamicProfile<Content, Modifier>: DynamicProfile, _ProfilePrimitive
        where Content: LanguageModelSession.DynamicProfile, Modifier: LanguageModelSession.DynamicProfileModifier {
        let _content: Content
        let _modifier: Modifier
        public var body: Never { fatalError() }
        func _resolve(into r: inout _ResolvedProfile) {
            let c = _content
            _isimResolveProfile(_modifier.body(content: DynamicProfileModifierContent(_resolver: { _isimResolveProfile(c, into: &$0) })), into: &r)
        }
    }
    @resultBuilder public struct DynamicProfileBuilder {
        public static func buildBlock<T>(_ content: T) -> T where T: LanguageModelSession.DynamicProfile { content }
        public static func buildEither<TrueContent, FalseContent>(first content: TrueContent) -> ConditionalDynamicProfile<TrueContent, FalseContent>
            where TrueContent: LanguageModelSession.DynamicProfile, FalseContent: LanguageModelSession.DynamicProfile { .init(_branch: .t(content)) }
        public static func buildEither<TrueContent, FalseContent>(second content: FalseContent) -> ConditionalDynamicProfile<TrueContent, FalseContent>
            where TrueContent: LanguageModelSession.DynamicProfile, FalseContent: LanguageModelSession.DynamicProfile { .init(_branch: .f(content)) }
        public static func buildLimitedAvailability(_ component: some LanguageModelSession.DynamicProfile) -> AnyDynamicProfile { AnyDynamicProfile(erasing: component) }
    }
}
@available(iOS 27.0, macOS 27.0, *)
extension Never: LanguageModelSession.DynamicProfile {}

/// one setting a modifier method adds; the innermost setting wins (as in SwiftUI)
@available(iOS 27.0, macOS 27.0, *)
struct _ProfileSetting<Content: LanguageModelSession.DynamicProfile>: LanguageModelSession.DynamicProfile, _ProfilePrimitive {
    let content: Content
    let apply: (inout _ResolvedProfile) -> Void
    var body: Never { fatalError() }
    func _resolve(into r: inout _ResolvedProfile) { _isimResolveProfile(content, into: &r); apply(&r) }
}

@available(iOS 27.0, macOS 27.0, *)
extension LanguageModelSession.DynamicProfile {
    public typealias DynamicProfile = LanguageModelSession.DynamicProfile
    public typealias Profile = LanguageModelSession.Profile
    public typealias SessionProperty = LanguageModelSession.SessionProperty
    func _setting(_ apply: @escaping (inout _ResolvedProfile) -> Void) -> _ProfileSetting<Self> { _ProfileSetting(content: self, apply: apply) }
    public func model(_ model: any LanguageModel) -> some LanguageModelSession.DynamicProfile { _setting { if $0.model == nil { $0.model = model } } }
    public func temperature(_ temperature: Double?) -> some LanguageModelSession.DynamicProfile { _setting { if $0.temperature == nil { $0.temperature = temperature } } }
    public func samplingMode(_ samplingMode: GenerationOptions.SamplingMode?) -> some LanguageModelSession.DynamicProfile {
        _setting { if $0.sampling == nil { $0.sampling = samplingMode } }
    }
    public func maximumResponseTokens(_ maximumResponseTokens: Int?) -> some LanguageModelSession.DynamicProfile {
        _setting { if $0.maximumResponseTokens == nil { $0.maximumResponseTokens = maximumResponseTokens } }
    }
    public func reasoningLevel(_ reasoningLevel: ContextOptions.ReasoningLevel?) -> some LanguageModelSession.DynamicProfile {
        _setting { if $0.reasoningLevel == nil { $0.reasoningLevel = reasoningLevel } }
    }
    public func toolCallingMode(_ toolCallingMode: GenerationOptions.ToolCallingMode?) -> some LanguageModelSession.DynamicProfile {
        _setting { if $0.toolCallingMode == nil { $0.toolCallingMode = toolCallingMode } }
    }
    public func transcriptErrorHandlingPolicy(_ transcriptErrorHandlingPolicy: TranscriptErrorHandlingPolicy?) -> some LanguageModelSession.DynamicProfile {
        _setting { if $0.policy == nil { $0.policy = transcriptErrorHandlingPolicy } }
    }
    public func historyTransform(_ transform: @escaping ([Transcript.Entry]) -> [Transcript.Entry]) -> some LanguageModelSession.DynamicProfile {
        _setting { r in
            let inner = r.historyTransform
            r.historyTransform = inner.map { i in { transform(i($0)) } } ?? transform
        }
    }
    public func modifier<Modifier>(_ modifier: Modifier) -> some LanguageModelSession.DynamicProfile where Modifier: LanguageModelSession.DynamicProfileModifier {
        LanguageModelSession.ModifiedDynamicProfile(_content: self, _modifier: modifier)
    }
    func _hook(_ name: String, _ action: @escaping () async throws -> Void) -> _ProfileSetting<Self> { _setting { $0.hooks[name, default: []].append(action) } }
    public func onActivate(perform action: sending @escaping @isolated(any) () async -> Void) -> some LanguageModelSession.DynamicProfile { _hook("activate") { await action() } }
    public func onDeactivate(perform action: sending @escaping @isolated(any) () async -> Void) -> some LanguageModelSession.DynamicProfile { _hook("deactivate") { await action() } }
    public func onPrompt(perform action: sending @escaping () async throws -> Void) -> some LanguageModelSession.DynamicProfile { _hook("prompt", action) }
    public func onReasoning(perform action: sending @escaping () async throws -> Void) -> some LanguageModelSession.DynamicProfile { _hook("reasoning", action) }
    public func onResponse(perform action: sending @escaping () async throws -> Void) -> some LanguageModelSession.DynamicProfile { _hook("response", action) }
    public func onToolCall(perform action: sending @escaping () async throws -> Void) -> some LanguageModelSession.DynamicProfile { _hook("toolCall", action) }
    public func onToolOutput(perform action: sending @escaping () async throws -> Void) -> some LanguageModelSession.DynamicProfile { _hook("toolOutput", action) }
}

// MARK: - sessions from instructions and profiles

/// how a session re-reads its dynamic instructions or profile before each request
@available(iOS 27.0, macOS 27.0, *)
final class _DynamicSource: @unchecked Sendable {
    let resolve: () -> _ResolvedProfile
    init(_ resolve: @escaping () -> _ResolvedProfile) { self.resolve = resolve }
}

@available(iOS 27.0, macOS 27.0, *)
extension LanguageModelSession {
    /// A session whose instructions are computed (again before each request) from its properties.
    public convenience init(model: some LanguageModel = SystemLanguageModel.default, dynamicInstructions: sending some DynamicInstructions,
                            history: some Collection<Transcript.Entry> = []) {
        let d = dynamicInstructions
        self.init(_isimModel: model, source: _DynamicSource { var r = _ResolvedProfile(); _isimResolve(d, into: &r.instructions); return r }, history: Array(history))
    }
    /// A session whose model, settings and instructions come from a profile.
    public convenience init(profile: sending some LanguageModelSession.DynamicProfile, history: some Collection<Transcript.Entry> = []) {
        let p = profile
        self.init(_isimModel: nil, source: _DynamicSource { var r = _ResolvedProfile(); _isimResolveProfile(p, into: &r); return r }, history: Array(history))
    }
    convenience init(_isimModel model: (any LanguageModel)?, source: _DynamicSource, history: [Transcript.Entry]) {
        self.init(model: (model as? SystemLanguageModel) ?? .default, tools: [], transcript: Transcript(entries: history))
        if let model, !(model is SystemLanguageModel) { _custom = model }
        _source = source
        let r = SessionPropertyValues.$_current.withValue(properties) { source.resolve() }
        _apply(r, initial: true)
        if let hooks = r.hooks["activate"] { Task { for h in hooks { try? await h() } } }
    }
    /// re-reads the dynamic instructions or profile: the instructions entry, the tools, the model and its settings
    func _refreshDynamic() {
        guard let source = _source as? _DynamicSource else { return }
        let r = SessionPropertyValues.$_current.withValue(properties) { source.resolve() }
        _apply(r, initial: false)
    }
    func _apply(_ r: _ResolvedProfile, initial: Bool) {
        if let m = r.model { _custom = (m is SystemLanguageModel) ? nil : m }
        _tools = r.instructions.tools
        let entry = Transcript.Entry.instructions(Transcript.Instructions(segments: r.instructions.text.map { .text(.init(content: $0)) },
                                                                          toolDefinitions: _tools.map { Transcript.ToolDefinition(tool: $0) }))
        if let i = transcript._entries.firstIndex(where: { if case .instructions = $0 { return true }; return false }) {
            transcript._entries[i] = entry
        } else if !r.instructions.text.isEmpty || !_tools.isEmpty {
            transcript._entries.insert(entry, at: 0)
        }
        _profile = r
        if let p = r.policy { _policy = p }
        _hooks = r.hooks
    }
    /// the options of a request, with the profile's settings where the request leaves them unset
    func _effectiveOptions(_ o: GenerationOptions) -> GenerationOptions {
        guard let r = _profile as? _ResolvedProfile else { return o }
        var o = o
        if o.temperature == nil, let t = r.temperature { o.temperature = t }
        if o.sampling == nil, let s = r.sampling { o.sampling = s }
        if o.maximumResponseTokens == nil, let m = r.maximumResponseTokens { o.maximumResponseTokens = m }
        if o.toolCallingMode == nil, let t = r.toolCallingMode, let t { o = GenerationOptions(samplingMode: o.sampling, temperature: o.temperature,
                                                                                        maximumResponseTokens: o.maximumResponseTokens, toolCallingMode: t) }
        return o
    }

    /// what the session read and wrote so far
    public final var usage: Usage { _usage as? Usage ?? ._zero }
    /// what happens to the transcript when a request fails (nil: the prompt stays)
    public final var transcriptErrorHandlingPolicy: TranscriptErrorHandlingPolicy? {
        get { _policy as? TranscriptErrorHandlingPolicy }
        set { _policy = newValue }
    }
}

@available(iOS 27.0, macOS 27.0, *)
extension LanguageModelSession.Response {
    /// the tokens this request read and wrote
    public var usage: LanguageModelSession.Usage { _usage as? LanguageModelSession.Usage ?? ._zero }
}
@available(iOS 27.0, macOS 27.0, *)
extension LanguageModelSession.ResponseStream.Snapshot {
    public var transcriptEntries: ArraySlice<Transcript.Entry> { _entries }
    public var usage: LanguageModelSession.Usage { _usage as? LanguageModelSession.Usage ?? ._zero }
}
