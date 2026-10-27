// iOS 26 typed notification messages for Foundation's own notifications (UndoManager, UserDefaults, NSMetadataQuery,
// Calendar, Date, TimeZone, Locale, Bundle, ProcessInfo, FileHandle, Port, FileManager, HTTPCookieStorage,
// NSExtensionContext) and their message identifiers, e.g.
//     NotificationCenter.default.addObserver(of: undoManager, for: .didCloseUndoGroup) { message in … }
// Each wraps the Foundation notification of the same name: makeMessage reads its object and userInfo, makeNotification
// builds it for the notification's observers. Adapted: the subject of the value types' messages (Calendar, Date,
// TimeZone, Locale) is their Objective-C class; the notifications are posted with no object.

@available(iOS 26.0, *)
extension UndoManager {
    public struct WillUndoChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UndoManager
        public static var name: Notification.Name { Notification.Name("NSUndoManagerWillUndoChangeNotification") }
        public init() {}
        @MainActor public static func makeMessage(_ n: Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension UndoManager {
    public struct DidUndoChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UndoManager
        public static var name: Notification.Name { Notification.Name("NSUndoManagerDidUndoChangeNotification") }
        public var groupIsDiscardable: Bool
        public init(groupIsDiscardable: Bool) { self.groupIsDiscardable = groupIsDiscardable }
        @MainActor public static func makeMessage(_ n: Notification) -> Self? { Self(groupIsDiscardable: (n.userInfo?["NSUndoManagerGroupIsDiscardableKey"] as? Bool) ?? false) }
        @MainActor public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil, userInfo: m.groupIsDiscardable ? ["NSUndoManagerGroupIsDiscardableKey": true] : nil) }
    }
}

@available(iOS 26.0, *)
extension UndoManager {
    public struct WillRedoChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UndoManager
        public static var name: Notification.Name { Notification.Name("NSUndoManagerWillRedoChangeNotification") }
        public init() {}
        @MainActor public static func makeMessage(_ n: Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension UndoManager {
    public struct DidRedoChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UndoManager
        public static var name: Notification.Name { Notification.Name("NSUndoManagerDidRedoChangeNotification") }
        public var groupIsDiscardable: Bool
        public init(groupIsDiscardable: Bool) { self.groupIsDiscardable = groupIsDiscardable }
        @MainActor public static func makeMessage(_ n: Notification) -> Self? { Self(groupIsDiscardable: (n.userInfo?["NSUndoManagerGroupIsDiscardableKey"] as? Bool) ?? false) }
        @MainActor public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil, userInfo: m.groupIsDiscardable ? ["NSUndoManagerGroupIsDiscardableKey": true] : nil) }
    }
}

@available(iOS 26.0, *)
extension UndoManager {
    public struct CheckpointMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UndoManager
        public static var name: Notification.Name { Notification.Name("NSUndoManagerCheckpointNotification") }
        public init() {}
        @MainActor public static func makeMessage(_ n: Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension UndoManager {
    public struct DidOpenUndoGroupMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UndoManager
        public static var name: Notification.Name { Notification.Name("NSUndoManagerDidOpenUndoGroupNotification") }
        public init() {}
        @MainActor public static func makeMessage(_ n: Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension UndoManager {
    public struct WillCloseUndoGroupMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UndoManager
        public static var name: Notification.Name { Notification.Name("NSUndoManagerWillCloseUndoGroupNotification") }
        public init() {}
        @MainActor public static func makeMessage(_ n: Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension UndoManager {
    public struct DidCloseUndoGroupMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UndoManager
        public static var name: Notification.Name { Notification.Name("NSUndoManagerDidCloseUndoGroupNotification") }
        public var groupIsDiscardable: Bool
        public init(groupIsDiscardable: Bool) { self.groupIsDiscardable = groupIsDiscardable }
        @MainActor public static func makeMessage(_ n: Notification) -> Self? { Self(groupIsDiscardable: (n.userInfo?["NSUndoManagerGroupIsDiscardableKey"] as? Bool) ?? false) }
        @MainActor public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil, userInfo: m.groupIsDiscardable ? ["NSUndoManagerGroupIsDiscardableKey": true] : nil) }
    }
}

@available(iOS 26.0, *)
extension UserDefaults {
    public struct DidChangeMessage: NotificationCenter.AsyncMessage {
        public typealias Subject = UserDefaults
        public static var name: Notification.Name { Notification.Name("NSUserDefaultsDidChangeNotification") }
        public init() {}
        public static func makeMessage(_ n: Notification) -> Self? { Self() }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension UserDefaults {
    public struct SizeLimitExceededMessage: NotificationCenter.AsyncMessage {
        public typealias Subject = UserDefaults
        public static var name: Notification.Name { Notification.Name("NSUserDefaultsSizeLimitExceededNotification") }
        public init() {}
        public static func makeMessage(_ n: Notification) -> Self? { Self() }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension NSMetadataQuery {
    public struct DidStartGatheringMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = NSMetadataQuery
        public static var name: Notification.Name { Notification.Name("NSMetadataQueryDidStartGatheringNotification") }
        public init() {}
        @MainActor public static func makeMessage(_ n: Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension NSMetadataQuery {
    public struct DidFinishGatheringMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = NSMetadataQuery
        public static var name: Notification.Name { Notification.Name("NSMetadataQueryDidFinishGatheringNotification") }
        public init() {}
        @MainActor public static func makeMessage(_ n: Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension Calendar {
    public struct CalendarDayChangedMessage: NotificationCenter.AsyncMessage {
        public typealias Subject = NSCalendar
        public static var name: Notification.Name { Notification.Name("NSCalendarDayChangedNotification") }
        public init() {}
        public static func makeMessage(_ n: Notification) -> Self? { Self() }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension Date {
    public struct SystemClockDidChangeMessage: NotificationCenter.AsyncMessage {
        public typealias Subject = NSDate
        public static var name: Notification.Name { Notification.Name("NSSystemClockDidChangeNotification") }
        public init() {}
        public static func makeMessage(_ n: Notification) -> Self? { Self() }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension TimeZone {
    public struct SystemTimeZoneDidChangeMessage: NotificationCenter.AsyncMessage {
        public typealias Subject = NSTimeZone
        public static var name: Notification.Name { Notification.Name("NSSystemTimeZoneDidChangeNotification") }
        public var previousTimeZone: TimeZone?
        public init(previousTimeZone: TimeZone?) { self.previousTimeZone = previousTimeZone }
        public static func makeMessage(_ n: Notification) -> Self? { Self(previousTimeZone: (n.object as? NSTimeZone).map { $0 as TimeZone }) }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: m.previousTimeZone.map { $0 as NSTimeZone }) }
    }
}

@available(iOS 26.0, *)
extension Locale {
    public struct CurrentLocaleDidChangeMessage: NotificationCenter.AsyncMessage {
        public typealias Subject = NSLocale
        public static var name: Notification.Name { Notification.Name("kCFLocaleCurrentLocaleDidChangeNotification") }
        public init() {}
        public static func makeMessage(_ n: Notification) -> Self? { Self() }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension Bundle {
    public struct DidLoadMessage: NotificationCenter.AsyncMessage {
        public typealias Subject = Bundle
        public static var name: Notification.Name { Notification.Name("NSBundleDidLoadNotification") }
        public init() {}
        public static func makeMessage(_ n: Notification) -> Self? { Self() }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension ProcessInfo {
    public struct PowerStateDidChangeMessage: NotificationCenter.AsyncMessage {
        public typealias Subject = ProcessInfo
        public static var name: Notification.Name { Notification.Name("NSProcessInfoPowerStateDidChangeNotification") }
        public init() {}
        public static func makeMessage(_ n: Notification) -> Self? { Self() }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension ProcessInfo {
    public struct ThermalStateDidChangeMessage: NotificationCenter.AsyncMessage {
        public typealias Subject = ProcessInfo
        public static var name: Notification.Name { Notification.Name("NSProcessInfoThermalStateDidChangeNotification") }
        public init() {}
        public static func makeMessage(_ n: Notification) -> Self? { Self() }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension FileHandle {
    public struct ConnectionAcceptedMessage: @unchecked Sendable, NotificationCenter.AsyncMessage {
        public typealias Subject = FileHandle
        public static var name: Notification.Name { Notification.Name("NSFileHandleConnectionAcceptedNotification") }
        public var fileHandleItem: Result<FileHandle, POSIXError>
        public init(fileHandleItem: Result<FileHandle, POSIXError>) { self.fileHandleItem = fileHandleItem }
        public static func makeMessage(_ n: Notification) -> Self? { Self(fileHandleItem: _fileHandleResult(n.userInfo, key: "NSFileHandleNotificationFileHandleItem", as: FileHandle.self)) }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil, userInfo: _fileHandleUserInfo(m.fileHandleItem, key: "NSFileHandleNotificationFileHandleItem")) }
    }
}

@available(iOS 26.0, *)
extension FileHandle {
    public struct DataAvailableMessage: NotificationCenter.AsyncMessage {
        public typealias Subject = FileHandle
        public static var name: Notification.Name { Notification.Name("NSFileHandleDataAvailableNotification") }
        public init() {}
        public static func makeMessage(_ n: Notification) -> Self? { Self() }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension FileHandle {
    public struct ReadToEndOfFileCompletionMessage: NotificationCenter.AsyncMessage {
        public typealias Subject = FileHandle
        public static var name: Notification.Name { Notification.Name("NSFileHandleReadToEndOfFileCompletionNotification") }
        public var dataItem: Result<Data, POSIXError>
        public init(dataItem: Result<Data, POSIXError>) { self.dataItem = dataItem }
        public static func makeMessage(_ n: Notification) -> Self? { Self(dataItem: _fileHandleResult(n.userInfo, key: "NSFileHandleNotificationDataItem", as: Data.self)) }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil, userInfo: _fileHandleUserInfo(m.dataItem, key: "NSFileHandleNotificationDataItem")) }
    }
}

@available(iOS 26.0, *)
extension FileHandle {
    public struct ReadCompletionMessage: NotificationCenter.AsyncMessage {
        public typealias Subject = FileHandle
        public static var name: Notification.Name { Notification.Name("NSFileHandleReadCompletionNotification") }
        public var dataItem: Result<Data, POSIXError>
        public init(dataItem: Result<Data, POSIXError>) { self.dataItem = dataItem }
        public static func makeMessage(_ n: Notification) -> Self? { Self(dataItem: _fileHandleResult(n.userInfo, key: "NSFileHandleNotificationDataItem", as: Data.self)) }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil, userInfo: _fileHandleUserInfo(m.dataItem, key: "NSFileHandleNotificationDataItem")) }
    }
}

@available(iOS 26.0, *)
extension Port {
    public struct DidBecomeInvalidMessage: NotificationCenter.AsyncMessage {
        public typealias Subject = Port
        public static var name: Notification.Name { Notification.Name("NSPortDidBecomeInvalidNotification") }
        public init() {}
        public static func makeMessage(_ n: Notification) -> Self? { Self() }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension FileManager {
    public struct UbiquityIdentityDidChangeMessage: NotificationCenter.AsyncMessage {
        public typealias Subject = FileManager
        public static var name: Notification.Name { Notification.Name("NSUbiquityIdentityDidChangeNotification") }
        public init() {}
        public static func makeMessage(_ n: Notification) -> Self? { Self() }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension HTTPCookieStorage {
    public struct CookiesChangedMessage: NotificationCenter.AsyncMessage {
        public typealias Subject = HTTPCookieStorage
        public static var name: Notification.Name { Notification.Name("NSHTTPCookieManagerCookiesChangedNotification") }
        public init() {}
        public static func makeMessage(_ n: Notification) -> Self? { Self() }
        public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension NSExtensionContext {
    public struct DidBecomeActiveMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = NSExtensionContext
        public static var name: Notification.Name { Notification.Name("NSExtensionHostDidBecomeActiveNotification") }
        public init() {}
        @MainActor public static func makeMessage(_ n: Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension NSExtensionContext {
    public struct WillResignActiveMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = NSExtensionContext
        public static var name: Notification.Name { Notification.Name("NSExtensionHostWillResignActiveNotification") }
        public init() {}
        @MainActor public static func makeMessage(_ n: Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension NSExtensionContext {
    public struct DidEnterBackgroundMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = NSExtensionContext
        public static var name: Notification.Name { Notification.Name("NSExtensionHostDidEnterBackgroundNotification") }
        public init() {}
        @MainActor public static func makeMessage(_ n: Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

@available(iOS 26.0, *)
extension NSExtensionContext {
    public struct WillEnterForegroundMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = NSExtensionContext
        public static var name: Notification.Name { Notification.Name("NSExtensionHostWillEnterForegroundNotification") }
        public init() {}
        @MainActor public static func makeMessage(_ n: Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Notification { Notification(name: name, object: nil) }
    }
}

/// a file handle notification's result: its item, or the errno in NSFileHandleError
func _fileHandleResult<T>(_ info: [AnyHashable: Any]?, key: String, as type: T.Type) -> Result<T, POSIXError> {
    if let v = info?[key] as? T { return .success(v) }
    let code = (info?["NSFileHandleError"] as? NSNumber)?.int32Value ?? EIO
    return .failure(POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO))
}
func _fileHandleUserInfo<T>(_ r: Result<T, POSIXError>, key: String) -> [AnyHashable: Any] {
    switch r {
    case .success(let v): return [key: v]
    case .failure(let e): return ["NSFileHandleError": NSNumber(value: e.code.rawValue)]
    }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UndoManager.WillUndoChangeMessage> {
    public static var willUndoChange: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UndoManager.DidUndoChangeMessage> {
    public static var didUndoChange: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UndoManager.WillRedoChangeMessage> {
    public static var willRedoChange: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UndoManager.DidRedoChangeMessage> {
    public static var didRedoChange: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UndoManager.CheckpointMessage> {
    public static var checkpoint: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UndoManager.DidOpenUndoGroupMessage> {
    public static var didOpenUndoGroup: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UndoManager.WillCloseUndoGroupMessage> {
    public static var willCloseUndoGroup: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UndoManager.DidCloseUndoGroupMessage> {
    public static var didCloseUndoGroup: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UserDefaults.DidChangeMessage> {
    public static var didChange: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UserDefaults.SizeLimitExceededMessage> {
    public static var sizeLimitExceeded: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<NSMetadataQuery.DidStartGatheringMessage> {
    public static var didStartGathering: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<NSMetadataQuery.DidFinishGatheringMessage> {
    public static var didFinishGathering: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<Calendar.CalendarDayChangedMessage> {
    public static var calendarDayChanged: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<Date.SystemClockDidChangeMessage> {
    public static var systemClockDidChange: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<TimeZone.SystemTimeZoneDidChangeMessage> {
    public static var systemTimeZoneDidChange: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<Locale.CurrentLocaleDidChangeMessage> {
    public static var currentLocaleDidChange: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<Bundle.DidLoadMessage> {
    public static var didLoad: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<ProcessInfo.PowerStateDidChangeMessage> {
    public static var powerStateDidChange: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<ProcessInfo.ThermalStateDidChangeMessage> {
    public static var thermalStateDidChange: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<FileHandle.ConnectionAcceptedMessage> {
    public static var connectionAccepted: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<FileHandle.DataAvailableMessage> {
    public static var dataAvailable: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<FileHandle.ReadToEndOfFileCompletionMessage> {
    public static var readToEndOfFileCompletion: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<FileHandle.ReadCompletionMessage> {
    public static var readCompletion: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<Port.DidBecomeInvalidMessage> {
    public static var didBecomeInvalid: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<FileManager.UbiquityIdentityDidChangeMessage> {
    public static var ubiquityIdentityDidChange: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<HTTPCookieStorage.CookiesChangedMessage> {
    public static var cookiesChanged: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<NSExtensionContext.DidBecomeActiveMessage> {
    public static var didBecomeActive: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<NSExtensionContext.WillResignActiveMessage> {
    public static var willResignActive: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<NSExtensionContext.DidEnterBackgroundMessage> {
    public static var didEnterBackground: Self { .init() }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<NSExtensionContext.WillEnterForegroundMessage> {
    public static var willEnterForeground: Self { .init() }
}
