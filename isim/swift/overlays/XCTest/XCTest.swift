// isim XCTest Swift overlay (self-authored): the Swift assertion functions, XCTSkip, XCTUnwrap, async waiting.
// Failures go to the Objective-C XCTest framework's _XCTIsimRecordFailure with the caller's file and line.
@_exported import XCTest
@_exported import Foundation

@usableFromInline
func _xctRecord(_ assertion: String, _ detail: String, _ message: () -> String, file: StaticString, line: UInt) {
    let m = message()
    var text = assertion + " failed"
    if !detail.isEmpty { text += ": " + detail }
    if !m.isEmpty { text += " - " + m }
    _XCTIsimRecordFailure(text, "\(file)", Int(line), true)
}

@usableFromInline
func _xctThrew(_ assertion: String, _ error: Error, _ message: () -> String, file: StaticString, line: UInt) {
    let m = message()
    var text = assertion + " threw error \"\(error)\""
    if !m.isEmpty { text += " - " + m }
    _XCTIsimRecordFailure(text, "\(file)", Int(line), false)
}

@usableFromInline
func _xctDescribe<T>(_ v: T) -> String { String(describing: v) }

// MARK: Boolean

public func XCTAssert(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "",
                      file: StaticString = #filePath, line: UInt = #line) {
    do { if try !expression() { _xctRecord("XCTAssertTrue", "", message, file: file, line: line) } }
    catch { _xctThrew("XCTAssertTrue", error, message, file: file, line: line) }
}
public func XCTAssertTrue(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "",
                          file: StaticString = #filePath, line: UInt = #line) {
    do { if try !expression() { _xctRecord("XCTAssertTrue", "", message, file: file, line: line) } }
    catch { _xctThrew("XCTAssertTrue", error, message, file: file, line: line) }
}
public func XCTAssertFalse(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "",
                           file: StaticString = #filePath, line: UInt = #line) {
    do { if try expression() { _xctRecord("XCTAssertFalse", "", message, file: file, line: line) } }
    catch { _xctThrew("XCTAssertFalse", error, message, file: file, line: line) }
}
public func XCTFail(_ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    _XCTIsimRecordFailure(message.isEmpty ? "failed" : "failed - " + message, "\(file)", Int(line), true)
}

// MARK: nil

public func XCTAssertNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "",
                         file: StaticString = #filePath, line: UInt = #line) {
    do {
        if let v = try expression() { _xctRecord("XCTAssertNil", "\"\(_xctDescribe(v))\"", message, file: file, line: line) }
    } catch { _xctThrew("XCTAssertNil", error, message, file: file, line: line) }
}
public func XCTAssertNotNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "",
                            file: StaticString = #filePath, line: UInt = #line) {
    do {
        if try expression() == nil { _xctRecord("XCTAssertNotNil", "", message, file: file, line: line) }
    } catch { _xctThrew("XCTAssertNotNil", error, message, file: file, line: line) }
}

/// Fails (and throws) when the expression is nil; returns the unwrapped value.
public func XCTUnwrap<T>(_ expression: @autoclosure () throws -> T?, _ message: @autoclosure () -> String = "",
                         file: StaticString = #filePath, line: UInt = #line) throws -> T {
    let v: T?
    do { v = try expression() } catch {
        _xctThrew("XCTUnwrap", error, message, file: file, line: line)
        throw _XCTRecordedFailure()
    }
    guard let value = v else {
        _xctRecord("XCTUnwrap", "expected non-nil value of type \"\(T.self)\"", message, file: file, line: line)
        throw _XCTRecordedFailure()
    }
    return value
}

/// Thrown after a failure was already recorded (XCTUnwrap): the runner does not report it again.
public struct _XCTRecordedFailure: Error, CustomNSError {
    public static var errorDomain: String { "XCTIsimRecordedFailure" }
    public var errorCode: Int { 0 }
    public var errorUserInfo: [String: Any] { [:] }
}

// MARK: equality and ordering

public func XCTAssertEqual<T: Equatable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T,
                                         _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let a = try expression1(), b = try expression2()
        if a != b { _xctRecord("XCTAssertEqual", "(\"\(_xctDescribe(a))\") is not equal to (\"\(_xctDescribe(b))\")", message, file: file, line: line) }
    } catch { _xctThrew("XCTAssertEqual", error, message, file: file, line: line) }
}
public func XCTAssertNotEqual<T: Equatable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T,
                                            _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let a = try expression1(), b = try expression2()
        if a == b { _xctRecord("XCTAssertNotEqual", "(\"\(_xctDescribe(a))\") is equal to (\"\(_xctDescribe(b))\")", message, file: file, line: line) }
    } catch { _xctThrew("XCTAssertNotEqual", error, message, file: file, line: line) }
}
public func XCTAssertEqual<T: FloatingPoint>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T,
                                             accuracy: T, _ message: @autoclosure () -> String = "",
                                             file: StaticString = #filePath, line: UInt = #line) {
    do {
        let a = try expression1(), b = try expression2()
        if !(a == b || abs(a - b) <= abs(accuracy)) {
            _xctRecord("XCTAssertEqual", "(\"\(a)\") is not equal to (\"\(b)\") +/- (\"\(accuracy)\")", message, file: file, line: line)
        }
    } catch { _xctThrew("XCTAssertEqual", error, message, file: file, line: line) }
}
public func XCTAssertEqual<T: Numeric>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T,
                                       accuracy: T, _ message: @autoclosure () -> String = "",
                                       file: StaticString = #filePath, line: UInt = #line) where T: Comparable {
    do {
        let a = try expression1(), b = try expression2()
        let d = a > b ? a - b : b - a
        let acc = accuracy < 0 ? (0 - accuracy) : accuracy
        if d > acc { _xctRecord("XCTAssertEqual", "(\"\(a)\") is not equal to (\"\(b)\") +/- (\"\(accuracy)\")", message, file: file, line: line) }
    } catch { _xctThrew("XCTAssertEqual", error, message, file: file, line: line) }
}
public func XCTAssertNotEqual<T: FloatingPoint>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T,
                                                accuracy: T, _ message: @autoclosure () -> String = "",
                                                file: StaticString = #filePath, line: UInt = #line) {
    do {
        let a = try expression1(), b = try expression2()
        if a == b || abs(a - b) <= abs(accuracy) {
            _xctRecord("XCTAssertNotEqual", "(\"\(a)\") is equal to (\"\(b)\") +/- (\"\(accuracy)\")", message, file: file, line: line)
        }
    } catch { _xctThrew("XCTAssertNotEqual", error, message, file: file, line: line) }
}

@usableFromInline
func _xctCompare<T: Comparable>(_ name: String, _ op: (T, T) -> Bool, _ text: String,
                                _ e1: () throws -> T, _ e2: () throws -> T, _ message: () -> String, _ file: StaticString, _ line: UInt) {
    do {
        let a = try e1(), b = try e2()
        if !op(a, b) { _xctRecord(name, "(\"\(_xctDescribe(a))\") \(text) (\"\(_xctDescribe(b))\")", message, file: file, line: line) }
    } catch { _xctThrew(name, error, message, file: file, line: line) }
}
public func XCTAssertGreaterThan<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T,
                                                _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    _xctCompare("XCTAssertGreaterThan", (>), "is not greater than", expression1, expression2, message, file, line)
}
public func XCTAssertGreaterThanOrEqual<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T,
                                                       _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    _xctCompare("XCTAssertGreaterThanOrEqual", (>=), "is less than", expression1, expression2, message, file, line)
}
public func XCTAssertLessThan<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T,
                                             _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    _xctCompare("XCTAssertLessThan", (<), "is not less than", expression1, expression2, message, file, line)
}
public func XCTAssertLessThanOrEqual<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T,
                                                    _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    _xctCompare("XCTAssertLessThanOrEqual", (<=), "is greater than", expression1, expression2, message, file, line)
}
public func XCTAssertIdentical(_ expression1: @autoclosure () throws -> AnyObject?, _ expression2: @autoclosure () throws -> AnyObject?,
                               _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let a = try expression1(), b = try expression2()
        if a !== b { _xctRecord("XCTAssertIdentical", "(\"\(_xctDescribe(a as Any))\") is not identical to (\"\(_xctDescribe(b as Any))\")", message, file: file, line: line) }
    } catch { _xctThrew("XCTAssertIdentical", error, message, file: file, line: line) }
}
public func XCTAssertNotIdentical(_ expression1: @autoclosure () throws -> AnyObject?, _ expression2: @autoclosure () throws -> AnyObject?,
                                  _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let a = try expression1(), b = try expression2()
        if a === b { _xctRecord("XCTAssertNotIdentical", "(\"\(_xctDescribe(a as Any))\") is identical to (\"\(_xctDescribe(b as Any))\")", message, file: file, line: line) }
    } catch { _xctThrew("XCTAssertNotIdentical", error, message, file: file, line: line) }
}

// MARK: errors

public func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "",
                                    file: StaticString = #filePath, line: UInt = #line, _ errorHandler: (_ error: Error) -> Void = { _ in }) {
    do { _ = try expression(); _xctRecord("XCTAssertThrowsError", "", message, file: file, line: line) }
    catch { errorHandler(error) }
}
public func XCTAssertThrowsError<T>(_ expression: @autoclosure () async throws -> T, _ message: @autoclosure () -> String = "",
                                    file: StaticString = #filePath, line: UInt = #line, _ errorHandler: (_ error: Error) -> Void = { _ in }) async {
    do { _ = try await expression(); _xctRecord("XCTAssertThrowsError", "", message, file: file, line: line) }
    catch { errorHandler(error) }
}
public func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "",
                                file: StaticString = #filePath, line: UInt = #line) {
    do { _ = try expression() } catch { _xctThrew("XCTAssertNoThrow", error, message, file: file, line: line) }
}

// MARK: skipping

/// Thrown to skip a test; the runner reports the test as skipped with the message.
public struct XCTSkip: Error, CustomNSError, CustomStringConvertible {
    public let message: String?
    public let sourceLocation: (file: String, line: Int)?
    public init(_ message: @autoclosure () -> String? = nil, file: StaticString = #filePath, line: UInt = #line) {
        self.message = message()
        self.sourceLocation = ("\(file)", Int(line))
    }
    public static var errorDomain: String { "XCTSkip" }
    public var errorCode: Int { 0 }
    public var errorUserInfo: [String: Any] {
        var info: [String: Any] = ["message": message ?? ""]
        if let l = sourceLocation { info["file"] = l.file; info["line"] = l.line }
        return info
    }
    public var description: String { "Test skipped" + (message.map { " - " + $0 } ?? "") }
}
public func XCTSkipIf(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String? = nil,
                      file: StaticString = #filePath, line: UInt = #line) throws {
    if try expression() {
        let m = message()
        _XCTIsimRecordSkip("(\"\(true)\") is true" + (m.map { " - " + $0 } ?? ""), "\(file)", Int(line))
        throw XCTSkip(m, file: file, line: line)
    }
}
public func XCTSkipUnless(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String? = nil,
                          file: StaticString = #filePath, line: UInt = #line) throws {
    if try !expression() {
        let m = message()
        _XCTIsimRecordSkip("(\"\(false)\") is false" + (m.map { " - " + $0 } ?? ""), "\(file)", Int(line))
        throw XCTSkip(m, file: file, line: line)
    }
}

// MARK: async waiting and measuring

extension XCTestCase {
    /// Waits (suspending, not blocking) until the expectations are fulfilled or the timeout passes.
    public func fulfillment(of expectations: [XCTestExpectation], timeout seconds: TimeInterval = .infinity,
                            enforceOrder enforceOrderOfFulfillment: Bool = false) async {
        let limit = seconds.isFinite ? seconds : 86_400
        let deadline = Date().addingTimeInterval(limit)
        while Date() < deadline {
            let inverted = expectations.contains { $0.isInverted && $0._isimHasAnyFulfillment() }
            let all = expectations.allSatisfy { $0.isInverted || $0._isimIsFulfilled() }
            if inverted || (all && !expectations.contains { $0.isInverted }) { break }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        // the synchronous waiter reports timeouts / order / inverted fulfillment like XCTestCase.wait(for:)
        wait(for: expectations, timeout: 0, enforceOrder: enforceOrderOfFulfillment)
    }
}

