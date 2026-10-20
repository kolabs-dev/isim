// isim XCTest Swift overlay: accessibility audits (XCUIApplication.performAccessibilityAudit), over the Objective-C
// method; an error the issue handler throws ends the audit and is rethrown.

@available(iOS 17.0, *)
extension XCUIApplication {
    /// Audits the app's current screen; issues the handler does not handle (returns false, or no handler) fail the test.
    public func performAccessibilityAudit(for auditTypes: XCUIAccessibilityAuditType = .all,
                                          _ issueHandler: ((XCUIAccessibilityAuditIssue) throws -> Bool)? = nil) throws {
        var thrown: Error?
        if let issueHandler {
            try __performAccessibilityAudit(with: auditTypes) { issue in
                if thrown != nil { return true }
                do { return try issueHandler(issue) } catch { thrown = error; return true }
            }
        } else {
            try __performAccessibilityAudit(with: auditTypes, issueHandler: nil)
        }
        if let thrown { throw thrown }
    }
}
