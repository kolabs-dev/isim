// isim ManagedSettings: the settings groups of a store (each setting nil: not set by this store) and their metadata.
// Generated shape: every group is Codable, kept in the store's file (Store.swift).
import Foundation

/// a group of settings in a ManagedSettingsStore
public protocol ManagedSettingsGroup {}

/// what a setting is when no store sets it
public struct SettingMetadata<Value> {
    public let defaultValue: Value
    init(defaultValue: Value) { self.defaultValue = defaultValue }
}
extension SettingMetadata: Sendable where Value: Sendable {}
/// a setting with a range of values
public struct BoundedSettingMetadata<Value> where Value: Comparable {
    public let defaultValue: Value
    public let bounds: ClosedRange<Value>
    init(defaultValue: Value, bounds: ClosedRange<Value>) { self.defaultValue = defaultValue; self.bounds = bounds }
}
extension BoundedSettingMetadata: Sendable where Value: Sendable {}

/// settings for the user's accounts
public struct AccountSettings: ManagedSettingsGroup, Codable, Equatable, Sendable {
    public var lockAccounts: Bool?
    init() {}
    public static let lockAccounts = SettingMetadata<Bool>(defaultValue: false)
}

/// settings for apps
public struct ApplicationSettings: ManagedSettingsGroup, Codable, Equatable, Sendable {
    public var blockedApplications: Set<Application>?
    public var denyAppInstallation: Bool?
    public var denyAppRemoval: Bool?
    init() {}
    public static let blockedApplications = SettingMetadata<Set<Application>>(defaultValue: [])
    public static let denyAppInstallation = SettingMetadata<Bool>(defaultValue: false)
    public static let denyAppRemoval = SettingMetadata<Bool>(defaultValue: false)
}

/// settings for the App Store
public struct AppStoreSettings: ManagedSettingsGroup, Codable, Equatable, Sendable {
    public var denyInAppPurchases: Bool?
    public var maximumRating: Int?
    public var requirePasswordForPurchases: Bool?
    init() {}
    public static let denyInAppPurchases = SettingMetadata<Bool>(defaultValue: false)
    public static let maximumRating = BoundedSettingMetadata<Int>(defaultValue: 1000, bounds: 0...1000)
    public static let requirePasswordForPurchases = SettingMetadata<Bool>(defaultValue: false)
}

/// settings for cellular data
public struct CellularSettings: ManagedSettingsGroup, Codable, Equatable, Sendable {
    public var lockAppCellularData: Bool?
    public var lockCellularPlan: Bool?
    public var lockESIM: Bool?
    init() {}
    public static let lockAppCellularData = SettingMetadata<Bool>(defaultValue: false)
    public static let lockCellularPlan = SettingMetadata<Bool>(defaultValue: false)
    public static let lockESIM = SettingMetadata<Bool>(defaultValue: false)
}

/// settings for the date and time
public struct DateAndTimeSettings: ManagedSettingsGroup, Codable, Equatable, Sendable {
    public var requireAutomaticDateAndTime: Bool?
    init() {}
    public static let requireAutomaticDateAndTime = SettingMetadata<Bool>(defaultValue: false)
}

/// settings for Game Center
public struct GameCenterSettings: ManagedSettingsGroup, Codable, Equatable, Sendable {
    public var denyAddingFriends: Bool?
    public var denyMultiplayerGaming: Bool?
    init() {}
    public static let denyAddingFriends = SettingMetadata<Bool>(defaultValue: false)
    public static let denyMultiplayerGaming = SettingMetadata<Bool>(defaultValue: false)
}

/// settings for media content
public struct MediaSettings: ManagedSettingsGroup, Codable, Equatable, Sendable {
    public var denyBookstoreErotica: Bool?
    public var denyExplicitContent: Bool?
    public var denyMusicService: Bool?
    public var maximumMovieRating: Int?
    public var maximumTVShowRating: Int?
    init() {}
    public static let denyBookstoreErotica = SettingMetadata<Bool>(defaultValue: false)
    public static let denyExplicitContent = SettingMetadata<Bool>(defaultValue: false)
    public static let denyMusicService = SettingMetadata<Bool>(defaultValue: false)
    public static let maximumMovieRating = BoundedSettingMetadata<Int>(defaultValue: 1000, bounds: 0...1000)
    public static let maximumTVShowRating = BoundedSettingMetadata<Int>(defaultValue: 1000, bounds: 0...1000)
}

/// settings for the passcode
public struct PasscodeSettings: ManagedSettingsGroup, Codable, Equatable, Sendable {
    public var lockPasscode: Bool?
    init() {}
    public static let lockPasscode = SettingMetadata<Bool>(defaultValue: false)
}

/// settings for Safari
public struct SafariSettings: ManagedSettingsGroup, Codable, Equatable, Sendable {
    public var cookiePolicy: SafariSettings.CookiePolicy?
    public var denyAutoFill: Bool?
    init() {}
    public static let cookiePolicy = SettingMetadata<SafariSettings.CookiePolicy>(defaultValue: .always)
    public static let denyAutoFill = SettingMetadata<Bool>(defaultValue: false)
}

/// settings for which apps, categories and web domains are shielded
public struct ShieldSettings: ManagedSettingsGroup, Codable, Equatable, Sendable {
    public var applicationCategories: ShieldSettings.ActivityCategoryPolicy<Application>?
    public var applications: Set<ApplicationToken>?
    public var webDomainCategories: ShieldSettings.ActivityCategoryPolicy<WebDomain>?
    public var webDomains: Set<WebDomainToken>?
    init() {}
    public static let applicationCategories = SettingMetadata<ShieldSettings.ActivityCategoryPolicy<Application>>(defaultValue: .none)
    public static let applications = SettingMetadata<Set<ApplicationToken>>(defaultValue: [])
    public static let webDomainCategories = SettingMetadata<ShieldSettings.ActivityCategoryPolicy<WebDomain>>(defaultValue: .none)
    public static let webDomains = SettingMetadata<Set<WebDomainToken>>(defaultValue: [])
}

/// settings for Siri
public struct SiriSettings: ManagedSettingsGroup, Codable, Equatable, Sendable {
    public var denySiri: Bool?
    init() {}
    public static let denySiri = SettingMetadata<Bool>(defaultValue: false)
}

/// settings for web content
public struct WebContentSettings: ManagedSettingsGroup, Codable, Equatable, Sendable {
    public var blockedByFilter: WebContentSettings.FilterPolicy?
    init() {}
    public static let blockedByFilter = SettingMetadata<WebContentSettings.FilterPolicy>(defaultValue: .none)
}

extension SafariSettings {
    public enum CookiePolicy: Int, Codable, Comparable, Sendable {
        case never = 0, currentWebsite = 1, visitedWebsites = 2, always = 3
        public static func < (lhs: SafariSettings.CookiePolicy, rhs: SafariSettings.CookiePolicy) -> Bool { lhs.rawValue < rhs.rawValue }
    }
}

extension ShieldSettings {
    /// which activity categories (and so which of their apps or web domains) are shielded
    public enum ActivityCategoryPolicy<Activity>: Codable, Equatable, Sendable {
        case none
        case all(except: Set<Token<Activity>> = [])
        case specific(Set<ActivityCategoryToken>, except: Set<Token<Activity>> = [])
        public static func == (lhs: ShieldSettings.ActivityCategoryPolicy<Activity>, rhs: ShieldSettings.ActivityCategoryPolicy<Activity>) -> Bool {
            switch (lhs, rhs) {
            case (.none, .none): return true
            case let (.all(a), .all(b)): return a == b
            case let (.specific(c, a), .specific(d, b)): return c == d && a == b
            default: return false
            }
        }
    }
}

extension WebContentSettings {
    /// which web content is filtered
    public enum FilterPolicy: Codable, Equatable, Sendable {
        case none
        case all(except: Set<WebDomain> = [])
        case auto(Set<WebDomain> = [], except: Set<WebDomain> = [])
        case specific(Set<WebDomain>)
        public static func == (lhs: WebContentSettings.FilterPolicy, rhs: WebContentSettings.FilterPolicy) -> Bool {
            switch (lhs, rhs) {
            case (.none, .none): return true
            case let (.all(a), .all(b)): return a == b
            case let (.auto(a, x), .auto(b, y)): return a == b && x == y
            case let (.specific(a), .specific(b)): return a == b
            default: return false
            }
        }
    }
}
