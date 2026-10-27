// isim Translation (self-authored, Apple's API names): TranslationSession, LanguageAvailability, TranslationError.
// Apple translates on the device with downloaded language models. isim passes translations through to a
// LibreTranslate-compatible server on the host (ISIM_TRANSLATE_URL; LibreTranslate runs Argos Translate's offline
// models): its /languages are the installed pairs, /translate translates, /detect identifies a text's language.
// Without a server no pair is supported: LanguageAvailability says .unsupported and sessions throw
// TranslationError.unsupportedLanguagePairing. Downloads are not simulated: a pair is installed when the server has it.
import Foundation

// MARK: - the host engine

/// the kinds of TranslationError (internal: the engine and the iOS 17.4 sheet use them without the iOS 18 type)
enum _TranslationCode: String, Sendable { case nothingToTranslate, unableToIdentifyLanguage, internalError, alreadyCancelled, notInstalled,
                                          unsupportedSourceLanguage, unsupportedTargetLanguage, unsupportedLanguagePairing }
struct _TranslationFailure: Error { let code: _TranslationCode; let reason: String? }

/// a LibreTranslate-compatible server (POST /translate, GET /languages, POST /detect)
struct _TranslationHost: @unchecked Sendable {
    let base: URL
    let key: String?

    static let shared: _TranslationHost? = {
        let env = ProcessInfo.processInfo.environment
        guard let u = env["ISIM_TRANSLATE_URL"], !u.isEmpty, let url = URL(string: u) else { return nil }
        return _TranslationHost(base: url, key: env["ISIM_TRANSLATE_API_KEY"].flatMap { $0.isEmpty ? nil : $0 })
    }()

    /// isim's language codes for the server: the language, `zt` for Traditional Chinese (LibreTranslate's code)
    static func code(_ l: Locale.Language) -> String {
        let id = l.minimalIdentifier
        let lang = l.languageCode?.identifier.lowercased() ?? id
        if lang == "zh" && (id.contains("Hant") || id.hasSuffix("-TW") || id.hasSuffix("-HK")) { return "zt" }
        return lang
    }
    static func language(_ code: String) -> Locale.Language { Locale.Language(identifier: code == "zt" ? "zh-Hant" : code) }

    /// the server's pairs, fetched once (a synchronous request: `isReady` and `supportedLanguages` are properties)
    static let pairs: [String: Set<String>] = {
        guard let host = shared else { return [:] }
        var req = URLRequest(url: host.base.appendingPathComponent("languages"))
        req.timeoutInterval = 10
        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var result: [String: Set<String>] = [:]
        URLSession.shared.dataTask(with: req) { data, _, _ in
            defer { done.signal() }
            guard let data, let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
            for l in list {
                guard let c = l["code"] as? String else { continue }
                result[c] = Set((l["targets"] as? [String] ?? []).filter { $0 != c })
            }
        }.resume()
        _ = done.wait(timeout: .now() + 15)
        return result
    }()

    func post(_ path: String, _ body: [String: Any]) async throws -> Any {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var b = body
        if let key { b["api_key"] = key }
        req.httpBody = try JSONSerialization.data(withJSONObject: b)
        req.timeoutInterval = 120
        let data: Data, response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: req) } catch {
            throw _TranslationFailure(code: .internalError, reason: "the translation server at \(base.absoluteString) is not reachable: \(error.localizedDescription)")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        let json = try? JSONSerialization.jsonObject(with: data)
        guard status == 200, let json else {
            let why = (json as? [String: Any])?["error"] as? String ?? String(decoding: data.prefix(500), as: UTF8.self)
            throw _TranslationFailure(code: .internalError, reason: "the translation server answered \(status): \(why)")
        }
        return json
    }
    func translate(_ texts: [String], from source: String, to target: String) async throws -> [String] {
        let o = try await post("translate", ["q": texts, "source": source, "target": target, "format": "text"]) as? [String: Any]
        if let list = o?["translatedText"] as? [String], list.count == texts.count { return list }
        if texts.count == 1, let one = o?["translatedText"] as? String { return [one] }
        throw _TranslationFailure(code: .internalError, reason: "the translation server's answer has no translatedText")
    }
    static let noEngine = "no translation engine is configured on this host (set ISIM_TRANSLATE_URL to a LibreTranslate-compatible server)"
    /// the user's language: a session or a check without a target translates into it
    static var preferred: Locale.Language { Locale.Language(identifier: Locale.preferredLanguages.first ?? "en") }
    /// whether the server translates `source` into `target`
    static func has(_ source: String, _ target: String) -> Bool { source != target && pairs[source]?.contains(target) == true }
    /// translates texts from `source` (nil: the texts' detected language) into `target`: the codes used and the translations
    static func run(_ texts: [String], source: String?, target: String) async throws -> (source: String, target: String, texts: [String]) {
        guard let host = shared else { throw _TranslationFailure(code: .unsupportedLanguagePairing, reason: noEngine) }
        guard !texts.isEmpty, texts.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw _TranslationFailure(code: .nothingToTranslate, reason: nil)
        }
        let from: String
        if let source { from = source } else {
            guard let d = try await host.detect(texts.joined(separator: "\n")) else { throw _TranslationFailure(code: .unableToIdentifyLanguage, reason: nil) }
            from = d
        }
        try check(from, target)
        return (from, target, try await host.translate(texts, from: from, to: target))
    }
    /// throws unless the server has the pair
    static func check(_ source: String, _ target: String) throws {
        guard let targets = pairs[source] else {
            throw _TranslationFailure(code: pairs.values.contains { $0.contains(target) } ? .unsupportedSourceLanguage : .unsupportedLanguagePairing,
                                      reason: "the translation server has no \(source) models")
        }
        guard source != target, targets.contains(target) else {
            throw _TranslationFailure(code: .unsupportedLanguagePairing, reason: "the translation server does not translate \(source) into \(target)")
        }
    }
    /// the language of a text: its code, or nil when the server cannot tell
    func detect(_ text: String) async throws -> String? {
        let list = try await post("detect", ["q": text]) as? [[String: Any]]
        guard let best = list?.first, let lang = best["language"] as? String,
              (best["confidence"] as? Double ?? 100) > 0 else { return nil }
        return lang
    }
}

// MARK: - errors

/// The errors a translation fails with.
@available(iOS 18.0, macOS 15.0, *)
public struct TranslationError: Error, LocalizedError, CustomStringConvertible, Sendable, Equatable {
    typealias Code = _TranslationCode
    let _code: Code
    let _reason: String?
    init(_ code: Code, _ reason: String? = nil) { _code = code; _reason = reason }
    init(_ f: _TranslationFailure) { self.init(f.code, f.reason) }

    public static let nothingToTranslate = TranslationError(.nothingToTranslate)
    public static let unableToIdentifyLanguage = TranslationError(.unableToIdentifyLanguage)
    public static let internalError = TranslationError(.internalError)
    @available(iOS 26.0, macOS 26.0, *)
    public static let alreadyCancelled = TranslationError(.alreadyCancelled)
    @available(iOS 26.0, macOS 26.0, *)
    public static let notInstalled = TranslationError(.notInstalled)
    public static let unsupportedSourceLanguage = TranslationError(.unsupportedSourceLanguage)
    public static let unsupportedTargetLanguage = TranslationError(.unsupportedTargetLanguage)
    public static let unsupportedLanguagePairing = TranslationError(.unsupportedLanguagePairing)

    public var errorDescription: String? {
        switch _code {
        case .nothingToTranslate: return "There is nothing to translate."
        case .unableToIdentifyLanguage: return "The language of the text could not be identified."
        case .internalError: return "The translation failed."
        case .alreadyCancelled: return "The translation session was cancelled."
        case .notInstalled: return "The languages are not installed."
        case .unsupportedSourceLanguage: return "The source language is not supported."
        case .unsupportedTargetLanguage: return "The target language is not supported."
        case .unsupportedLanguagePairing: return "Translation between these languages is not supported."
        }
    }
    public var failureReason: String? { _reason }
    public var description: String { "TranslationError.\(_code.rawValue)" + (_reason.map { ": \($0)" } ?? "") }
    public static func == (a: TranslationError, b: TranslationError) -> Bool { a._code == b._code }
    /// matches an error of the same kind (`catch TranslationError.notInstalled`)
    public static func ~= (match: TranslationError, error: any Error) -> Bool { (error as? TranslationError)?._code == match._code }
}

// MARK: - availability

/// Which languages the device can translate between.
@available(iOS 18.0, macOS 15.0, *)
public final class LanguageAvailability: Sendable {
    public enum Status: Sendable, Hashable { case installed, supported, unsupported }
    let _strategy: String
    public init() { _strategy = "highFidelity" }
    @available(iOS 26.4, macOS 26.4, *)
    public init(preferredStrategy: TranslationSession.Strategy) { _strategy = preferredStrategy._name }
    @available(iOS 26.4, macOS 26.4, *)
    public var preferredStrategy: TranslationSession.Strategy { TranslationSession.Strategy(_name: _strategy) }

    /// the languages the host's engine translates from or to (none without a server)
    public var supportedLanguages: [Locale.Language] {
        let pairs = _TranslationHost.pairs
        let codes = Set(pairs.keys).union(pairs.values.flatMap { $0 })
        return codes.sorted().map(_TranslationHost.language)
    }
    public func status(from source: Locale.Language, to target: Locale.Language?) async -> Status {
        LanguageAvailability._status(from: _TranslationHost.code(source), to: _TranslationHost.code(target ?? _TranslationHost.preferred))
    }
    /// identifies the text's language, then gives the pair's status; throws `unableToIdentifyLanguage`
    public func status(for text: String, to target: Locale.Language?) async throws -> Status {
        guard let host = _TranslationHost.shared else { return .unsupported }
        let found: String?
        do { found = try await host.detect(text) } catch let f as _TranslationFailure { throw TranslationError(f) }
        guard let lang = found else { throw TranslationError.unableToIdentifyLanguage }
        return LanguageAvailability._status(from: lang, to: _TranslationHost.code(target ?? _TranslationHost.preferred))
    }
    static func _status(from s: String, to t: String) -> Status { _TranslationHost.has(s, t) ? .installed : .unsupported }
}

// MARK: - sessions

/// Translates text between a pair of languages.
@available(iOS 18.0, macOS 15.0, *)
public final class TranslationSession: @unchecked Sendable {
    /// The model a session prefers (iOS 26.4): isim's engine has one, so both translate the same.
    @available(iOS 26.4, macOS 26.4, *)
    public struct Strategy: Sendable, Hashable {
        let _name: String
        public static let highFidelity = Strategy(_name: "highFidelity")
        public static let lowLatency = Strategy(_name: "lowLatency")
    }
    /// What a view's translation task translates between; `invalidate()` runs the task again.
    public struct Configuration: Sendable, Equatable {
        public var source: Locale.Language?
        public var target: Locale.Language?
        public private(set) var version: Int = 0
        var _strategy = "highFidelity"
        public init(source: Locale.Language? = nil, target: Locale.Language? = nil) { self.source = source; self.target = target }
        @available(iOS 26.4, macOS 26.4, *)
        public init(source: Locale.Language? = nil, target: Locale.Language? = nil, preferredStrategy: TranslationSession.Strategy) {
            self.init(source: source, target: target); _strategy = preferredStrategy._name
        }
        @available(iOS 26.4, macOS 26.4, *)
        public var preferredStrategy: TranslationSession.Strategy {
            get { Strategy(_name: _strategy) }
            set { _strategy = newValue._name }
        }
        public mutating func invalidate() { version += 1 }
    }
    /// A text to translate in a batch; the client identifier comes back in its response.
    public struct Request: Sendable {
        public var sourceText: String
        public var attributedSourceText: AttributedString?
        public var clientIdentifier: String?
        public init(sourceText: String, clientIdentifier: String? = nil) { self.sourceText = sourceText; self.clientIdentifier = clientIdentifier }
        public init(sourceText: AttributedString, clientIdentifier: String? = nil) {
            self.sourceText = String(sourceText.characters); attributedSourceText = sourceText; self.clientIdentifier = clientIdentifier
        }
    }
    /// A translation.
    public struct Response: Sendable {
        public let sourceLanguage: Locale.Language
        public let targetLanguage: Locale.Language
        public let sourceText: String
        public let targetText: String
        public let attributedSourceText: AttributedString?
        public let attributedTargetText: AttributedString?
        public let clientIdentifier: String?
        public init(sourceLanguage: Locale.Language, targetLanguage: Locale.Language, sourceText: String, targetText: String, clientIdentifier: String?) {
            self.sourceLanguage = sourceLanguage; self.targetLanguage = targetLanguage; self.sourceText = sourceText; self.targetText = targetText
            attributedSourceText = nil; attributedTargetText = nil; self.clientIdentifier = clientIdentifier
        }
        public init(sourceLanguage: Locale.Language, targetLanguage: Locale.Language, sourceAttributedText: AttributedString,
                    targetAttributedText: AttributedString, clientIdentifier: String?) {
            self.sourceLanguage = sourceLanguage; self.targetLanguage = targetLanguage
            sourceText = String(sourceAttributedText.characters); targetText = String(targetAttributedText.characters)
            attributedSourceText = sourceAttributedText; attributedTargetText = targetAttributedText; self.clientIdentifier = clientIdentifier
        }
    }
    /// The responses of `translate(batch:)`, as each is ready.
    public struct BatchResponse: AsyncSequence, Sendable {
        public typealias Element = Response
        let _stream: AsyncThrowingStream<Response, Error>
        public struct AsyncIterator: AsyncIteratorProtocol {
            var _it: AsyncThrowingStream<Response, Error>.AsyncIterator
            public mutating func next() async throws -> Response? { try await _it.next() }
        }
        public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(_it: _stream.makeAsyncIterator()) }
    }

    public let sourceLanguage: Locale.Language?
    public let targetLanguage: Locale.Language?
    let _canRequestDownloads: Bool
    let _strategy: String
    let lock = NSLock()
    var _cancelled = false

    init(source: Locale.Language?, target: Locale.Language?, canRequestDownloads: Bool, strategy: String) {
        sourceLanguage = source; targetLanguage = target; _canRequestDownloads = canRequestDownloads; _strategy = strategy
    }
    /// a session for languages already installed (it cannot ask to download them)
    @available(iOS 26.0, macOS 26.0, *)
    public convenience init(installedSource: Locale.Language, target: Locale.Language? = nil) {
        self.init(source: installedSource, target: target, canRequestDownloads: false, strategy: "highFidelity")
    }
    @available(iOS 26.4, macOS 26.4, *)
    public convenience init(installedSource: Locale.Language, target: Locale.Language? = nil, preferredStrategy: Strategy) {
        self.init(source: installedSource, target: target, canRequestDownloads: false, strategy: preferredStrategy._name)
    }

    /// true for the sessions a view's translation task gets (there the system may ask to download languages)
    @available(iOS 26.0, macOS 26.0, *)
    public var canRequestDownloads: Bool { _canRequestDownloads }
    /// whether the host's engine has the session's pair (a session without a source language: its target)
    @available(iOS 26.0, macOS 26.0, *)
    public var isReady: Bool {
        if let s = sourceLanguage { return _TranslationHost.has(_TranslationHost.code(s), _target) }
        return _TranslationHost.pairs.values.contains { $0.contains(_target) }
    }
    @available(iOS 26.4, macOS 26.4, *)
    public var preferredStrategy: Strategy { Strategy(_name: _strategy) }
    /// stops the session: its requests from now on throw `alreadyCancelled`
    @available(iOS 26.0, macOS 26.0, *)
    public func cancel() { lock.lock(); _cancelled = true; lock.unlock() }

    /// checks that the pair can be translated (isim downloads nothing: the server has the pair or it is unsupported)
    public func prepareTranslation() async throws {
        try _checkCancelled()
        do {
            guard _TranslationHost.shared != nil else { throw _TranslationFailure(code: .unsupportedLanguagePairing, reason: _TranslationHost.noEngine) }
            if let s = sourceLanguage { try _TranslationHost.check(_TranslationHost.code(s), _target) }
        } catch let f as _TranslationFailure { throw TranslationError(f) }
    }
    public func translate(_ string: String) async throws -> Response {
        try await _translate([Request(sourceText: string)]).first!
    }
    /// translates the text; isim's engine translates plain text, so the translation carries no attributes
    public func translate(_ attributedString: AttributedString) async throws -> Response {
        try await _translate([Request(sourceText: attributedString)]).first!
    }
    public func translations(from batch: [Request]) async throws -> [Response] { try await _translate(batch) }
    public func translate(batch: [Request]) -> BatchResponse {
        let stream = AsyncThrowingStream<Response, Error> { cont in
            let task = Task {
                do {
                    for r in batch { cont.yield(try await self._translate([r]).first!) }
                    cont.finish()
                } catch { cont.finish(throwing: error) }
            }
            cont.onTermination = { _ in task.cancel() }
        }
        return BatchResponse(_stream: stream)
    }

    var _target: String { _TranslationHost.code(targetLanguage ?? _TranslationHost.preferred) }
    func _checkCancelled() throws {
        lock.lock(); defer { lock.unlock() }
        if _cancelled { throw TranslationError(.alreadyCancelled) }
    }
    func _translate(_ requests: [Request]) async throws -> [Response] {
        try _checkCancelled()
        let run: (source: String, target: String, texts: [String])
        do { run = try await _TranslationHost.run(requests.map(\.sourceText), source: sourceLanguage.map(_TranslationHost.code), target: _target) }
        catch let f as _TranslationFailure { throw TranslationError(f) }
        try _checkCancelled()
        let source = _TranslationHost.language(run.source), target = _TranslationHost.language(run.target)
        return zip(requests, run.texts).map { r, text in
            if let a = r.attributedSourceText {
                return Response(sourceLanguage: source, targetLanguage: target, sourceAttributedText: a,
                                targetAttributedText: AttributedString(text), clientIdentifier: r.clientIdentifier)
            }
            return Response(sourceLanguage: source, targetLanguage: target, sourceText: r.sourceText, targetText: text,
                            clientIdentifier: r.clientIdentifier)
        }
    }
}
