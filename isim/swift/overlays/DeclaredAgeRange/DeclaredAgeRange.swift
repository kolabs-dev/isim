// isim DeclaredAgeRange (issue #397): the age range an app may ask for. isim has no Apple Account, so the age comes
// from the device's simulated account: `isim agerange set <age>` (ISIM_DATA/Library/isim/AgeRange.json, also its
// declaration, parental controls and the regulated region). requestAgeRange shows isim's rendition of iOS's "Share
// Age Range" sheet; sharing answers with the range between the app's age gates the age falls in, as iOS does.
// Adapted: no account, no family, no Screen Time; the sheet's wording is isim's.
import UIKit
import SwiftUI

public struct AgeRangeService: Sendable {
    public static let shared = AgeRangeService()

    public enum AgeRangeDeclaration: Hashable, Sendable {
        case selfDeclared, guardianDeclared, confirmed, paymentChecked, governmentIDChecked, checkedByOtherMethod
        case guardianPaymentChecked, guardianGovernmentIDChecked, guardianCheckedByOtherMethod
    }

    public struct ParentalControls: OptionSet, Hashable, Sendable, CustomStringConvertible {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let communicationLimits = ParentalControls(rawValue: 1 << 0)
        public static let significantAppChangeApprovalRequired = ParentalControls(rawValue: 1 << 1)
        public var description: String {
            var names: [String] = []
            if contains(.communicationLimits) { names.append("communicationLimits") }
            if contains(.significantAppChangeApprovalRequired) { names.append("significantAppChangeApprovalRequired") }
            return "[" + names.joined(separator: ", ") + "]"
        }
    }

    public struct AgeRange: Hashable, Sendable {
        public var lowerBound: Int?
        public var upperBound: Int?
        public var ageRangeDeclaration: AgeRangeDeclaration?
        public var activeParentalControls: ParentalControls
    }

    public enum Response: Hashable, Sendable {
        case declinedSharing
        case sharing(range: AgeRange)
    }

    public enum RegulatoryFeature: Hashable, Sendable {
        case declaredAgeRangeRequired
        case significantAppChangeRequiresAdultNotification
        case significantAppChangeRequiresParentalConsent
    }

    public enum Error: Swift.Error, Hashable, Sendable {
        case notAvailable, invalidRequest, declinedOnboarding, invalidAccount, network
    }

    /// whether the account is in a region whose law gives it age features (`isim agerange set … --regulated`)
    public var isEligibleForAgeFeatures: Bool {
        get async throws { try _AgeRangeAccount.load().regulated }
    }

    public var requiredRegulatoryFeatures: Set<RegulatoryFeature> {
        get async throws {
            let a = try _AgeRangeAccount.load()
            guard a.regulated else { return [] }
            var f: Set<RegulatoryFeature> = [.declaredAgeRangeRequired]
            if let age = a.age, age < 18 { f.insert(.significantAppChangeRequiresParentalConsent) } else { f.insert(.significantAppChangeRequiresAdultNotification) }
            return f
        }
    }

    /// iOS's "Share Age Range" sheet; the gates (1 to 3, increasing, 2 years apart or more) split the ages into ranges
    @MainActor public func requestAgeRange(ageGates threshold1: Int, _ threshold2: Int? = nil, _ threshold3: Int? = nil,
                                           in viewController: UIViewController) async throws -> Response {
        let gates = [threshold1] + [threshold2, threshold3].compactMap { $0 }
        guard gates.allSatisfy({ $0 > 0 }), zip(gates, gates.dropFirst()).allSatisfy({ $1 - $0 >= 2 }) else { throw Error.invalidRequest }
        let account = try _AgeRangeAccount.load()
        guard let age = account.age else { throw Error.notAvailable }
        // the range: from the highest gate at or below the age up to the next gate (open ends stay nil)
        let lower = gates.last { $0 <= age }
        let upper = gates.first { $0 > age }.map { $0 - 1 }
        let range = AgeRange(lowerBound: lower, upperBound: upper, ageRangeDeclaration: account.declaration, activeParentalControls: account.controls)
        let text = _AgeRangeAccount.describe(lower, upper)
        NSLog("isim DeclaredAgeRange: share sheet (gates %@, the account's range %@)", gates.map(String.init).joined(separator: ","), text)
        if let a = ProcessInfo.processInfo.environment["ISIM_AGERANGE_ANSWER"]?.lowercased(), a == "share" || a == "decline" {
            NSLog("isim DeclaredAgeRange: answered %@ (ISIM_AGERANGE_ANSWER)", a)
            return a == "share" ? .sharing(range: range) : .declinedSharing
        }
        let share = await _AgeRangeSheets.ask(from: viewController) { done in
            AnyView(_AgeRangeShareView(range: text, share: { done(true) }, decline: { done(false) }))
        }
        NSLog("isim DeclaredAgeRange: %@", share ? "shared \(text)" : "declined")
        return share ? .sharing(range: range) : .declinedSharing
    }

    /// tells the person about a significant update to the app (where the law asks for it), as iOS's sheet does
    @MainActor public func showSignificantUpdateAcknowledgment(in windowScene: UIWindowScene, updateDescription: String) async throws {
        guard let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? windowScene.windows.first?.rootViewController else {
            throw Error.invalidRequest
        }
        var top = root
        while let p = top.presentedViewController { top = p }
        NSLog("isim DeclaredAgeRange: significant update acknowledgment: %@", updateDescription)
        _ = await _AgeRangeSheets.ask(from: top) { done in
            AnyView(_SignificantUpdateView(description: updateDescription, done: { done(true) }))
        }
    }
}

/// `@Environment(\.requestAgeRange)`: requestAgeRange from the view's window
public struct DeclaredAgeRangeAction: Sendable {
    @MainActor public func callAsFunction(ageGates threshold1: Int, _ threshold2: Int? = nil, _ threshold3: Int? = nil) async throws -> AgeRangeService.Response {
        guard let vc = _AgeRangeSheets.topController() else { throw AgeRangeService.Error.invalidRequest }
        return try await AgeRangeService.shared.requestAgeRange(ageGates: threshold1, threshold2, threshold3, in: vc)
    }
}

/// `@Environment(\.showSignificantUpdateAcknowledgment)`
public struct SignificantUpdateAction: Sendable {
    @MainActor public func callAsFunction(updateDescription: String) async throws {
        guard let scene = _AgeRangeSheets.topController()?.view.window?.windowScene else { throw AgeRangeService.Error.invalidRequest }
        try await AgeRangeService.shared.showSignificantUpdateAcknowledgment(in: scene, updateDescription: updateDescription)
    }
}

private struct _RequestAgeRangeKey: EnvironmentKey { static let defaultValue = DeclaredAgeRangeAction() }
private struct _SignificantUpdateKey: EnvironmentKey { static let defaultValue = SignificantUpdateAction() }
extension EnvironmentValues {
    public var requestAgeRange: DeclaredAgeRangeAction { self[_RequestAgeRangeKey.self] }
    public var showSignificantUpdateAcknowledgment: SignificantUpdateAction { self[_SignificantUpdateKey.self] }
}

// MARK: - the simulated account

struct _AgeRangeAccount {
    var age: Int?
    var declaration: AgeRangeService.AgeRangeDeclaration?
    var controls: AgeRangeService.ParentalControls = []
    var regulated = false

    static var file: String {
        let env = ProcessInfo.processInfo.environment
        let data = env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? ((env["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
        return (data as NSString).appendingPathComponent("Library/isim/AgeRange.json")
    }
    /// what `isim agerange set` wrote; no file: no age (requestAgeRange throws notAvailable)
    static func load() throws -> _AgeRangeAccount {
        var a = _AgeRangeAccount()
        guard let data = FileManager.default.contents(atPath: file) else { return a }
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AgeRangeService.Error.invalidAccount }
        a.age = o["age"] as? Int
        a.declaration = (o["declaration"] as? String).flatMap(declaration)
        for c in o["controls"] as? [String] ?? [] {
            if c == "communicationLimits" { a.controls.insert(.communicationLimits) }
            if c == "significantAppChangeApprovalRequired" { a.controls.insert(.significantAppChangeApprovalRequired) }
        }
        a.regulated = o["regulated"] as? Bool ?? false
        return a
    }
    static func declaration(_ s: String) -> AgeRangeService.AgeRangeDeclaration? {
        let all: [(String, AgeRangeService.AgeRangeDeclaration)] = [
            ("selfDeclared", .selfDeclared), ("guardianDeclared", .guardianDeclared), ("confirmed", .confirmed),
            ("paymentChecked", .paymentChecked), ("governmentIDChecked", .governmentIDChecked), ("checkedByOtherMethod", .checkedByOtherMethod),
            ("guardianPaymentChecked", .guardianPaymentChecked), ("guardianGovernmentIDChecked", .guardianGovernmentIDChecked),
            ("guardianCheckedByOtherMethod", .guardianCheckedByOtherMethod)]
        return all.first { $0.0 == s }?.1
    }
    static func describe(_ lower: Int?, _ upper: Int?) -> String {
        switch (lower, upper) {
        case let (l?, u?): return "\(l)–\(u)"
        case let (l?, nil): return "\(l)+"
        case let (nil, u?): return "under \(u + 1)"
        default: return "any age"
        }
    }
}

// MARK: - sheets

@MainActor enum _AgeRangeSheets {
    static func topController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = scenes.flatMap(\.windows).first { $0.isKeyWindow }?.rootViewController ?? scenes.first?.windows.first?.rootViewController
        while let p = top?.presentedViewController { top = p }
        return top
    }
    /// presents the content as a sheet over `from` and returns the answer its buttons give (false when swiped away)
    static func ask(from: UIViewController, _ build: (_ done: @escaping (Bool) -> Void) -> AnyView) async -> Bool {
        await withCheckedContinuation { (k: CheckedContinuation<Bool, Never>) in
            final class Box { var finished = false }
            let box = Box()
            var host: UIViewController?
            let done: (Bool) -> Void = { answer in
                guard !box.finished else { return }
                box.finished = true
                host?.dismiss(animated: true, completion: nil)
                k.resume(returning: answer)
            }
            let h = _AgeRangeHost(rootView: build(done))
            h.onGone = { if !box.finished { box.finished = true; k.resume(returning: false) } }
            h.sheetPresentationController?.detents = [.medium()]
            host = h
            from.present(h, animated: true, completion: nil)
        }
    }
}

final class _AgeRangeHost: UIHostingController<AnyView> {
    var onGone: (() -> Void)?
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if presentingViewController == nil { let f = onGone; onGone = nil; f?() }
    }
}

var _ageRangeAppName: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "This app"
}

struct _AgeRangeShareView: View {
    let range: String
    let share: () -> Void
    let decline: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle").font(.system(size: 44)).foregroundStyle(.tint).padding(.top, 28)
            Text(verbatim: "Share Age Range?").font(.system(size: 22, weight: .bold))
            Text(verbatim: "“\(_ageRangeAppName)” would like to know your age range to provide an appropriate experience. Your birthday will not be shared.")
                .font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text(verbatim: "Age range: \(range)").font(.system(size: 15, weight: .semibold)).accessibilityIdentifier("agerange-range")
            Spacer()
            Button { share() } label: { Text(verbatim: "Share Age Range").font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 6) }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("agerange-share")
            Button { decline() } label: { Text(verbatim: "Don’t Share").font(.system(size: 17)).frame(maxWidth: .infinity) }
                .accessibilityIdentifier("agerange-decline").padding(.bottom, 16)
        }
        .padding(.horizontal, 28)
    }
}

struct _SignificantUpdateView: View {
    let description: String
    let done: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "info.circle").font(.system(size: 44)).foregroundStyle(.tint).padding(.top, 28)
            Text(verbatim: "“\(_ageRangeAppName)” Has Changed").font(.system(size: 22, weight: .bold)).multilineTextAlignment(.center)
            Text(verbatim: description).font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .accessibilityIdentifier("agerange-update-text")
            Spacer()
            Button { done() } label: { Text(verbatim: "OK").font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 6) }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("agerange-update-ok").padding(.bottom, 16)
        }
        .padding(.horizontal, 28)
    }
}
