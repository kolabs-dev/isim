// isim XCTest Swift overlay: XCTIssue (the value type, bridged to the Objective-C XCTIssueReference), expected
// failures (XCTExpectFailure), activities (XCTContext.runActivity) and the source location conveniences.

/// Something wrong in a test, recorded with XCTestCase.record(_:): an assertion failure, a thrown error, an uncaught
/// exception. Overrides of record(_:) can change it before calling super.
public struct XCTIssue: CustomStringConvertible {
    public typealias IssueType = XCTIssueReference.IssueType
    public var type: IssueType
    public var compactDescription: String
    public var detailedDescription: String?
    public var sourceCodeContext: XCTSourceCodeContext
    public var associatedError: Error?
    public var attachments: [XCTAttachment]

    public init(type: IssueType, compactDescription: String, detailedDescription: String? = nil,
                sourceCodeContext: XCTSourceCodeContext = XCTSourceCodeContext(), associatedError: Error? = nil,
                attachments: [XCTAttachment] = []) {
        self.type = type
        self.compactDescription = compactDescription
        self.detailedDescription = detailedDescription
        self.sourceCodeContext = sourceCodeContext
        self.associatedError = associatedError
        self.attachments = attachments
    }
    public mutating func add(_ attachment: XCTAttachment) { attachments.append(attachment) }
    public var description: String { _bridgeToObjectiveC().description }
}

extension XCTIssue: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> XCTIssueReference {
        XCTIssueReference(type: type, compactDescription: compactDescription, detailedDescription: detailedDescription,
                          sourceCodeContext: sourceCodeContext, associatedError: associatedError, attachments: attachments)
    }
    public static func _forceBridgeFromObjectiveC(_ source: XCTIssueReference, result: inout XCTIssue?) {
        result = XCTIssue(type: source.type, compactDescription: source.compactDescription, detailedDescription: source.detailedDescription,
                          sourceCodeContext: source.sourceCodeContext, associatedError: source.associatedError, attachments: source.attachments)
    }
    public static func _conditionallyBridgeFromObjectiveC(_ source: XCTIssueReference, result: inout XCTIssue?) -> Bool {
        _forceBridgeFromObjectiveC(source, result: &result)
        return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ source: XCTIssueReference?) -> XCTIssue {
        var result: XCTIssue?
        _forceBridgeFromObjectiveC(source!, result: &result)
        return result!
    }
}

extension XCTSourceCodeLocation {
    public convenience init(filePath: StaticString, lineNumber: Int) { self.init(filePath: "\(filePath)", lineNumber: lineNumber) }
    public convenience init(filePath: StaticString, lineNumber: UInt) { self.init(filePath: "\(filePath)", lineNumber: Int(lineNumber)) }
}

// MARK: expected failures

/// Issues recorded from here to the end of the test are expected failures: they do not fail it.
@_disfavoredOverload
public func XCTExpectFailure(_ failureReason: String? = nil, options: XCTExpectedFailure.Options = .init()) {
    __XCTExpectFailureWithOptions(failureReason, options)
}

/// Issues recorded in the block are expected failures; a strict scope fails the test when the block records none.
@_disfavoredOverload
public func XCTExpectFailure<R>(_ failureReason: String? = nil, options: XCTExpectedFailure.Options = .init(),
                                failingBlock: () throws -> R) rethrows -> R {
    let scope = _XCTIsimPushExpectedFailure(failureReason, options)
    defer { _XCTIsimPopExpectedFailure(scope) }
    return try failingBlock()
}

public func XCTExpectFailure(_ failureReason: String? = nil, enabled: Bool? = nil, strict: Bool? = nil,
                             issueMatcher: ((XCTIssue) -> Bool)? = nil) {
    XCTExpectFailure(failureReason, options: _xctOptions(enabled, strict, issueMatcher))
}

public func XCTExpectFailure<R>(_ failureReason: String? = nil, enabled: Bool? = nil, strict: Bool? = nil,
                                failingBlock: () throws -> R, issueMatcher: ((XCTIssue) -> Bool)? = nil) rethrows -> R {
    try XCTExpectFailure(failureReason, options: _xctOptions(enabled, strict, issueMatcher), failingBlock: failingBlock)
}

func _xctOptions(_ enabled: Bool?, _ strict: Bool?, _ matcher: ((XCTIssue) -> Bool)?) -> XCTExpectedFailure.Options {
    let o = XCTExpectedFailure.Options()
    if let enabled { o.isEnabled = enabled }
    if let strict { o.isStrict = strict }
    if let matcher { o.issueMatcher = matcher }
    return o
}

// MARK: activities

extension XCTContext {
    /// Runs the block as a named step of the test (printed by `isim test`); attachments added to the activity are
    /// kept with the test.
    public static func runActivity<Result>(named name: String, block: (any XCTActivity) throws -> Result) rethrows -> Result {
        let activity = _XCTIsimBeginActivity(name)
        defer { _XCTIsimEndActivity(activity) }
        return try block(activity)
    }
}
