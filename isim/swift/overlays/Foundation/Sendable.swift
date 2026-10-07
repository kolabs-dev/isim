// Sendable conformances that Apple's Foundation declares for its thread-safe classes. Swift 6 code relies on them,
// e.g. the `static let module: Bundle` accessor that Swift packages with resources generate.
extension Bundle: @unchecked Sendable {}
extension ProcessInfo: @unchecked Sendable {}
extension NotificationCenter: @unchecked Sendable {}
extension UserDefaults: @unchecked Sendable {}
extension FileManager: @unchecked Sendable {}
