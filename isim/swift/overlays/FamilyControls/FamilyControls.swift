// isim FamilyControls (adapted): Screen Time authorization and the activity picker.
//
// AuthorizationCenter.requestAuthorization(for: .individual) shows iOS's Screen Time alert ("“App” Would Like to Access
// Screen Time"); ISIM_FAMILYCONTROLS_PERMISSION=allow|deny answers it in scripts. The answer is kept on the device
// (<isim data>/Library/isim/ScreenTime/authorization.json), where DeviceActivity and the home screen's shields read it.
// The app needs the com.apple.developer.family-controls entitlement (else `unavailable`). A child's authorization needs
// a Family Sharing parent, which isim's account is not: `.child` fails with `invalidAccountType`.
// FamilyActivityPicker lists the device's installed apps by Screen Time category; the selection holds opaque tokens
// (ManagedSettings' registry), so the app does not learn which apps were picked.
import Foundation
import SwiftUI
import Combine
@_exported import ManagedSettings

// MARK: - authorization

public enum AuthorizationStatus: Int, Codable, Sendable, CustomStringConvertible {
    case notDetermined = 0
    case denied = 1
    case approved = 2
    @available(iOS 26.4, *) case approvedWithDataAccess = 3
    public var description: String {
        switch rawValue { case 1: return "denied"; case 2: return "approved"; case 3: return "approvedWithDataAccess"; default: return "notDetermined" }
    }
}

@available(iOS 16.0, *)
@objc public enum FamilyControlsMember: Int, Codable, Sendable, CustomStringConvertible {
    case child = 0
    case individual = 1
    public var description: String { self == .child ? "child" : "individual" }
}

public enum FamilyControlsError: Int, Error, CustomNSError, LocalizedError, Sendable {
    case restricted = 0
    case unavailable = 1
    case invalidAccountType = 2
    case invalidArgument = 3
    case authorizationConflict = 4
    case authorizationCanceled = 5
    case networkError = 6
    @available(iOS 16.0, *) case authenticationMethodUnavailable = 7
    @available(iOS 26.4, *) case unauthorized = 8
    public static var errorDomain: String { "FamilyControls.FamilyControlsError" }
    public var errorCode: Int { rawValue }
    public var errorDescription: String? {
        switch rawValue {
        case 0: return "Screen Time is restricted on this device."
        case 1: return "Screen Time is not available to this app."
        case 2: return "The account on this device cannot be authorized for this kind of member."
        case 3: return "An argument was not valid."
        case 4: return "Another app already manages Screen Time for this member."
        case 5: return "The user canceled the authorization."
        case 6: return "The network is not available."
        case 7: return "The device has no passcode to confirm the authorization."
        default: return "The app is not authorized to use Screen Time."
        }
    }
}

public final class AuthorizationCenter: ObservableObject, @unchecked Sendable {
    public static let shared = AuthorizationCenter()
    @Published public private(set) var authorizationStatus: AuthorizationStatus

    init() { authorizationStatus = Self.stored }
    static var stored: AuthorizationStatus {
        switch _IsimScreenTime.authorization(_IsimScreenTime.appBundle) {
        case "approved": return .approved
        case "approvedWithDataAccess": if #available(iOS 26.4, *) { return .approvedWithDataAccess } else { return .approved }
        case "denied": return .denied
        default: return .notDetermined
        }
    }
    func set(_ s: AuthorizationStatus?) {
        _IsimScreenTime.setAuthorization(_IsimScreenTime.appBundle, s.map { $0.description })
        let v = Self.stored
        DispatchQueue.main.async { self.authorizationStatus = v }
    }
    static var entitled: Bool {
        let p = (Bundle.main.bundlePath as NSString).appendingPathComponent("archived-expanded-entitlements.xcent")
        return (NSDictionary(contentsOfFile: p)?["com.apple.developer.family-controls"] as? Bool) == true
    }

    /// asks the user to let the app use Screen Time for this device's user (.individual) or a child in their family
    @available(iOS 16.0, *)
    public func requestAuthorization(for member: FamilyControlsMember) async throws {
        guard Self.entitled else {
            NSLog("isim FamilyControls: the app has no com.apple.developer.family-controls entitlement")
            throw FamilyControlsError.unavailable
        }
        guard member == .individual else {
            NSLog("isim FamilyControls: a child's authorization needs a Family Sharing parent; this device's account is not a child")
            throw FamilyControlsError.invalidAccountType
        }
        if Self.stored == .approved { await MainActor.run { authorizationStatus = .approved }; return }
        let ok: Bool = await withCheckedContinuation { (k: CheckedContinuation<Bool, Never>) in
            if let s = _Privacy.scripted("FAMILYCONTROLS") { k.resume(returning: !(s == "deny" || s == "denied" || s == "no" || s == "0")); return }
            _Privacy.onMain {
                _Privacy.alert("“\(_Privacy.appName)” Would Like to Access Screen Time",
                               "Providing “\(_Privacy.appName)” access to Screen Time may allow it to see your activity data, restrict content, and limit the usage of apps and websites.",
                               [("Continue", .default), ("Don’t Allow", .cancel)]) { k.resume(returning: $0 == 0) }
            }
        }
        set(ok ? .approved : .denied)
        await MainActor.run { authorizationStatus = ok ? .approved : .denied }
        NSLog("isim FamilyControls: Screen Time %@ for %@", ok ? "approved" : "denied", _Privacy.appName)
        if !ok { throw FamilyControlsError.authorizationCanceled }
    }
    /// iOS 15: a child's authorization (a Family Sharing parent approves it; isim's account is not a child)
    @available(iOS, introduced: 15.0, deprecated: 16.0, message: "use requestAuthorization(for:)")
    public func requestAuthorization(completionHandler: @escaping (Result<Void, any Error>) -> Void) {
        Task {
            do { try await requestAuthorization(for: .child); completionHandler(.success(())) } catch { completionHandler(.failure(error)) }
        }
    }
    /// the app stops using Screen Time: its stores' settings and monitoring stop applying
    public func revokeAuthorization(completionHandler: @escaping (Result<Void, any Error>) -> Void) {
        set(nil)
        NSLog("isim FamilyControls: Screen Time authorization revoked for %@", _Privacy.appName)
        DispatchQueue.main.async { completionHandler(.success(())) }
    }
}

// MARK: - selections

public struct FamilyActivitySelection: Codable, Equatable, Sendable {
    public var applicationTokens: Set<ApplicationToken> = []
    public var categoryTokens: Set<ActivityCategoryToken> = []
    public var webDomainTokens: Set<WebDomainToken> = []
    /// whether a picked category includes its apps and web domains (iOS 15.2)
    @available(iOS 15.2, *)
    public var includeEntireCategory: Bool { _includeEntireCategory }
    let _includeEntireCategory: Bool
    public init() { _includeEntireCategory = false }
    public init(includeEntireCategory: Bool) { _includeEntireCategory = includeEntireCategory }
    public var applications: Set<Application> { Set(applicationTokens.map { Application(token: $0) }) }
    public var categories: Set<ActivityCategory> { Set(categoryTokens.map { ActivityCategory(token: $0) }) }
    public var webDomains: Set<WebDomain> { Set(webDomainTokens.map { WebDomain(token: $0) }) }
    enum CodingKeys: String, CodingKey { case applicationTokens, categoryTokens, webDomainTokens, _includeEntireCategory = "includeEntireCategory" }
}

// MARK: - the picker (system UI)

/// the system's picker of apps, categories and web domains; its rows are `family-category-ID` and `family-app-BUNDLE`
public struct FamilyActivityPicker: View {
    @Binding var selection: FamilyActivitySelection
    let headerText: String?, footerText: String?
    public init(selection: Binding<FamilyActivitySelection>) { _selection = selection; headerText = nil; footerText = nil }
    @available(iOS 16.0, *)
    public init(headerText: String? = nil, footerText: String? = nil, selection: Binding<FamilyActivitySelection>) {
        _selection = selection; self.headerText = headerText; self.footerText = footerText
    }
    public var body: some View { _FamilyPickerList(selection: $selection, headerText: headerText, footerText: footerText) }
}

struct _FamilyPickerList: View {
    @Binding var selection: FamilyActivitySelection
    let headerText: String?, footerText: String?
    @State var expanded: Set<String> = []
    var body: some View {
        let apps = _IsimScreenTime.installedApps()
        List {
            Section {
                ForEach(_IsimScreenTime.categories.map(\.id), id: \.self) { c in
                    let t = _IsimScreenTime.categoryToken(c)
                    let members = apps.filter { $0.category == c }
                    Button {
                        if selection.categoryTokens.contains(t) { selection.categoryTokens.remove(t) } else { selection.categoryTokens.insert(t) }
                        NSLog("isim FamilyControls: picker %@ %@", selection.categoryTokens.contains(t) ? "selects" : "deselects", c)
                    } label: {
                        HStack {
                            Image(systemName: selection.categoryTokens.contains(t) ? "checkmark.circle.fill" : "circle")
                            Text(_IsimScreenTime.categoryName(c))
                            Spacer()
                            if !members.isEmpty { Text("\(members.count)").foregroundColor(.secondary) }
                        }
                    }
                    .accessibilityIdentifier("family-category-\(c)")
                }
            } header: { Text(headerText ?? "Categories") }
            Section {
                ForEach(apps.map(\.bundle), id: \.self) { b in
                    let t = _IsimScreenTime.applicationToken(b)
                    Button {
                        if selection.applicationTokens.contains(t) { selection.applicationTokens.remove(t) } else { selection.applicationTokens.insert(t) }
                        NSLog("isim FamilyControls: picker %@ %@", selection.applicationTokens.contains(t) ? "selects" : "deselects", b)
                    } label: {
                        HStack {
                            Image(systemName: selection.applicationTokens.contains(t) ? "checkmark.circle.fill" : "circle")
                            Text(_IsimScreenTime.appName(b) ?? b)
                        }
                    }
                    .accessibilityIdentifier("family-app-\(b)")
                }
            } header: { Text("Apps") } footer: { Text(footerText ?? "") }
        }
    }
}

/// a picked app's, category's or web domain's name, drawn by the system (the app cannot read it)
public struct FamilyActivityTitleView: View {
    let text: String
    public init(_ token: ApplicationToken) { text = _IsimScreenTime.bundle(for: token).flatMap(_IsimScreenTime.appName) ?? "App" }
    public init(_ token: ActivityCategoryToken) { text = _IsimScreenTime.category(for: token).map(_IsimScreenTime.categoryName) ?? "Category" }
    public init(_ token: WebDomainToken) { text = _IsimScreenTime.domain(for: token) ?? "Website" }
    public var body: some View { Text(text) }
}
/// a picked app's, category's or web domain's icon, drawn by the system
public struct FamilyActivityIconView: View {
    let symbol: String
    public init(_ token: ApplicationToken) { symbol = "app" }
    public init(_ token: ActivityCategoryToken) { symbol = "square.grid.2x2" }
    public init(_ token: WebDomainToken) { symbol = "safari" }
    public var body: some View { Image(systemName: symbol) }
}
extension Label where Title == FamilyActivityTitleView, Icon == FamilyActivityIconView {
    public init(_ token: ApplicationToken) { self.init { FamilyActivityTitleView(token) } icon: { FamilyActivityIconView(token) } }
    public init(_ token: ActivityCategoryToken) { self.init { FamilyActivityTitleView(token) } icon: { FamilyActivityIconView(token) } }
    public init(_ token: WebDomainToken) { self.init { FamilyActivityTitleView(token) } icon: { FamilyActivityIconView(token) } }
}

extension View {
    /// presents the picker as a sheet with Cancel and Done (`family-cancel`, `family-done`)
    public func familyActivityPicker(isPresented: Binding<Bool>, selection: Binding<FamilyActivitySelection>) -> some View {
        sheet(isPresented: isPresented) { _FamilyPickerSheet(isPresented: isPresented, selection: selection) }
    }
    @available(iOS 16.0, *)
    public func familyActivityPicker(headerText: String? = nil, footerText: String? = nil, isPresented: Binding<Bool>,
                                     selection: Binding<FamilyActivitySelection>) -> some View {
        sheet(isPresented: isPresented) { _FamilyPickerSheet(isPresented: isPresented, selection: selection, headerText: headerText, footerText: footerText) }
    }
}
struct _FamilyPickerSheet: View {
    @Binding var isPresented: Bool
    @Binding var selection: FamilyActivitySelection
    var headerText: String? = nil, footerText: String? = nil
    @State var draft = FamilyActivitySelection()
    var body: some View {
        NavigationView {
            _FamilyPickerList(selection: $draft, headerText: headerText, footerText: footerText)
                .navigationTitle("Choose Activities")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false }.accessibilityIdentifier("family-cancel") }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { selection = draft; isPresented = false }.accessibilityIdentifier("family-done")
                    }
                }
        }
        .onAppear { draft = selection }
    }
}

// MARK: - iOS 26.4: the device's activity

@available(iOS 26.4, *)
public final class FamilyActivityData: @unchecked Sendable {
    public static let shared = FamilyActivityData()
    func authorized() throws {
        guard AuthorizationCenter.stored == .approved || AuthorizationCenter.stored.rawValue == 3 else { throw FamilyControlsError.unauthorized }
    }
    public var activityCategories: Set<ActivityCategory> {
        get async throws { try authorized(); return Set(_IsimScreenTime.categories.map { ActivityCategory(token: _IsimScreenTime.categoryToken($0.id)) }) }
    }
    public var installedApplications: [Application] {
        get async throws { try authorized(); return _IsimScreenTime.installedApps().map { Application(token: _IsimScreenTime.applicationToken($0.bundle)) } }
    }
    /// the web domains Safari visited (isim's Safari keeps no Screen Time history: none)
    public var visitedWebDomains: [WebDomain] { get async throws { try authorized(); return [] } }
}
