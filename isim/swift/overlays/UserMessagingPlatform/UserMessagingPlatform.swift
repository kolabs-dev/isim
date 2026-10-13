// isim stand-in for Google's User Messaging Platform SDK (a closed-source binary isim does not fetch or run), API of
// UMP 3.
//
// Adapted: the consent message is isim's own form in the style of Google's GDPR message, shown where it would be.
// Geography: DebugSettings.geography (isim is always a test device, like the Simulator), else ISIM_UMP_GEOGRAPHY
// (eea | regulated-us-state | other), else the device's region (Settings › Language & Region; EEA, UK and
// Switzerland need consent). In the EEA requestConsentInfoUpdate makes consent required until the user answers;
// loadAndPresentIfRequired shows the form (Consent / Do not consent / Manage options with the TCF purposes) and the
// answer is written like Google's CMP writes it: the IAB TCF v2.2 keys in the app's standard UserDefaults
// (IABTCF_gdprApplies, IABTCF_TCString encoded per the TCF core string spec, IABTCF_PurposeConsents, vendor
// consents with Google's vendor 755, ...). presentPrivacyOptionsForm shows it again. In a regulated US state the
// privacy options form offers the opt-out of sale/sharing (no GPP string is written). canRequestAds follows the
// SDK: true once consent is obtained or not required. Nothing is sent over the network.
import UIKit

public enum ConsentStatus: Int, Sendable { case unknown = 0, required = 1, notRequired = 2, obtained = 3 }
public enum PrivacyOptionsRequirementStatus: Int, Sendable { case unknown = 0, required = 1, notRequired = 2 }
public enum FormStatus: Int, Sendable { case unknown = 0, available = 1, unavailable = 2 }
public enum DebugGeography: Int, Sendable { case disabled = 0, EEA = 1, notEEA = 2, regulatedUSState = 3, other = 4 }

public let UMPErrorDomain = "com.google.ump"
public enum RequestErrorCode: Int, Sendable { case `internal` = 1, invalidAppID = 2, network = 3, misconfiguration = 4 }
public enum FormErrorCode: Int, Sendable { case `internal` = 5, alreadyUsed = 6, unavailable = 7, timeout = 8, invalidViewController = 9 }
func _umpError(_ code: Int, _ message: String) -> NSError { NSError(domain: UMPErrorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: message]) }

public final class DebugSettings: NSObject, @unchecked Sendable {
    public var testDeviceIdentifiers: [String] = []
    public var geography = DebugGeography.disabled
    // isim ABI: until 0.20 geography was an Int; keep its getter and setter for apps built then
    @usableFromInline @_silgen_name("$s21UserMessagingPlatform13DebugSettingsC9geographySivg")
    final func _abi_geographyInt() -> Int { geography.rawValue }
    @usableFromInline @_silgen_name("$s21UserMessagingPlatform13DebugSettingsC9geographySivs")
    final func _abi_setGeographyInt(_ v: Int) { geography = DebugGeography(rawValue: v) ?? .disabled }
}
public final class RequestParameters: NSObject, @unchecked Sendable {
    public var isTaggedForUnderAgeOfConsent = false
    public var debugSettings: DebugSettings?
    public override init() {}
}

// MARK: - the user's answer, as Google's CMP stores it

enum _UMPRegion { case eea, usState, other }

enum _TCF {
    static let purposes = ["Store and/or access information on a device", "Use limited data to select advertising",
                           "Create profiles for personalised advertising", "Use profiles to select personalised advertising",
                           "Create profiles to personalise content", "Use profiles to select personalised content",
                           "Measure advertising performance", "Measure content performance",
                           "Understand audiences through statistics or combinations of data from different sources",
                           "Develop and improve services", "Use limited data to select content"]
    static let legitimateInterestPurposes: Set<Int> = [2, 7, 8, 9, 10, 11]
    static let googleVendor = 755

    /// the TCF v2.2 core segment (TC string spec: fixed-width bit fields, base64url without padding)
    static func coreString(consents: Set<Int>, vendorConsent: Bool, language: String, publisherCC: String, now: Date) -> String {
        var bits: [Bool] = []
        func put(_ v: Int, _ n: Int) { for i in stride(from: n - 1, through: 0, by: -1) { bits.append((v >> i) & 1 == 1) } }
        func letters(_ s: String) { let u = Array(s.uppercased().utf8) + [65, 65]; put(Int(u[0]) - 65, 6); put(Int(u[1]) - 65, 6) }
        let ds = Int(now.timeIntervalSince1970 * 10)
        put(2, 6); put(ds, 36); put(ds, 36)                    // version, created, last updated (deciseconds)
        put(300, 12); put(2, 12); put(1, 6)                    // CMP id (Google), CMP version, consent screen
        letters(language); put(100, 12); put(4, 6)             // consent language, vendor list version, TCF policy version
        put(1, 1); put(0, 1); put(0, 12)                       // service specific, standard texts, special features
        for p in 1...24 { bits.append(consents.contains(p)) }
        for p in 1...24 { bits.append(legitimateInterestPurposes.contains(p)) }
        put(0, 1); letters(publisherCC)                        // purpose one treatment, publisher country
        for vendorBit in [vendorConsent, true] {               // vendor consents, then vendor legitimate interests
            put(googleVendor, 16); put(0, 1)
            for v in 1...googleVendor { bits.append(v == googleVendor && vendorBit) }
        }
        put(0, 12)                                             // no publisher restrictions
        while bits.count % 6 != 0 { bits.append(false) }
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        var out = ""
        for i in stride(from: 0, to: bits.count, by: 6) {
            var v = 0
            for b in bits[i..<i + 6] { v = v << 1 | (b ? 1 : 0) }
            out.append(alphabet[v])
        }
        return out
    }

    static func store(consents: Set<Int>) {
        let d = UserDefaults.standard
        let lang = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "EN"
        let cc = Locale.current.regionCode ?? "AA"
        let vendor = consents.contains(1)
        d.set(300, forKey: "IABTCF_CmpSdkID"); d.set(2, forKey: "IABTCF_CmpSdkVersion"); d.set(4, forKey: "IABTCF_PolicyVersion")
        d.set(1, forKey: "IABTCF_gdprApplies"); d.set(cc.count == 2 ? cc : "AA", forKey: "IABTCF_PublisherCC")
        d.set(0, forKey: "IABTCF_PurposeOneTreatment"); d.set(0, forKey: "IABTCF_UseNonStandardTexts")
        d.set(coreString(consents: consents, vendorConsent: vendor, language: lang, publisherCC: cc.count == 2 ? cc : "AA", now: Date()), forKey: "IABTCF_TCString")
        d.set(String((1...11).map { consents.contains($0) ? "1" : "0" }), forKey: "IABTCF_PurposeConsents")
        d.set(String((1...11).map { legitimateInterestPurposes.contains($0) ? "1" : "0" }), forKey: "IABTCF_PurposeLegitimateInterests")
        d.set(String((1...googleVendor).map { $0 == googleVendor && vendor ? "1" : "0" }), forKey: "IABTCF_VendorConsents")
        d.set(String((1...googleVendor).map { $0 == googleVendor ? "1" : "0" }), forKey: "IABTCF_VendorLegitimateInterests")
        d.set("00000000000", forKey: "IABTCF_SpecialFeaturesOptIns")
        d.set("2~~dv.", forKey: "IABTCF_AddtlConsent")
    }
    static let keys = ["IABTCF_CmpSdkID", "IABTCF_CmpSdkVersion", "IABTCF_PolicyVersion", "IABTCF_gdprApplies", "IABTCF_PublisherCC",
                       "IABTCF_PurposeOneTreatment", "IABTCF_UseNonStandardTexts", "IABTCF_TCString", "IABTCF_PurposeConsents",
                       "IABTCF_PurposeLegitimateInterests", "IABTCF_VendorConsents", "IABTCF_VendorLegitimateInterests",
                       "IABTCF_SpecialFeaturesOptIns", "IABTCF_AddtlConsent", "isim.UMP.answered", "isim.UMP.usOptOut"]
}

// MARK: - consent information

public final class ConsentInformation: NSObject, @unchecked Sendable {
    public static let shared = ConsentInformation()
    var region: _UMPRegion?
    var answered: Bool { UserDefaults.standard.bool(forKey: "isim.UMP.answered") }
    public var consentStatus: ConsentStatus {
        switch region {
        case nil: return answered ? .obtained : .unknown
        case .eea?: return answered ? .obtained : .required
        case .usState?, .other?: return .notRequired
        }
    }
    public var formStatus: FormStatus {
        switch region { case nil: return .unknown; case .eea?, .usState?: return .available; case .other?: return .unavailable }
    }
    public var canRequestAds: Bool { consentStatus == .obtained || consentStatus == .notRequired }
    public var privacyOptionsRequirementStatus: PrivacyOptionsRequirementStatus {
        switch region { case nil: return .unknown; case .eea?, .usState?: return .required; case .other?: return .notRequired }
    }
    public var isConsentFormAvailable: Bool { formStatus == .available }

    static func region(for parameters: RequestParameters?) -> _UMPRegion {
        switch parameters?.debugSettings?.geography ?? .disabled {
        case .EEA: return .eea
        case .regulatedUSState: return .usState
        case .notEEA, .other: return .other
        case .disabled: break
        }
        switch ProcessInfo.processInfo.environment["ISIM_UMP_GEOGRAPHY"]?.lowercased() {
        case "eea"?: return .eea
        case "regulated-us-state"?, "us-state"?, "usstate"?: return .usState
        case "other"?, "not-eea"?: return .other
        default: break
        }
        let eea: Set<String> = ["AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU",
                                "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE", "IS", "LI", "NO", "GB", "CH"]
        return eea.contains(Locale.current.regionCode ?? "") ? .eea : .other
    }

    public func requestConsentInfoUpdate(with parameters: RequestParameters?, completionHandler: @escaping (Error?) -> Void) {
        guard ((Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String) ?? "").isEmpty == false else {
            print("isim: User Messaging Platform: no GADApplicationIdentifier in Info.plist")
            DispatchQueue.main.async {
                completionHandler(_umpError(RequestErrorCode.misconfiguration.rawValue,
                                            "Publisher misconfiguration: Failed to read publisher's account configuration; please check your configured app ID. Received app ID: `(null)`."))
            }
            return
        }
        let r = Self.region(for: parameters)
        if parameters?.isTaggedForUnderAgeOfConsent == true, r == .eea {
            print("isim: User Messaging Platform: tagged for under age of consent: no form, consent not required")
            region = .other
        } else {
            region = r
        }
        if region != .eea { UserDefaults.standard.set(0, forKey: "IABTCF_gdprApplies") }   /* GDPR does not apply here */
        print("isim: User Messaging Platform: consent info updated: \(region.map { "\($0)" } ?? "-") status=\(consentStatus) canRequestAds=\(canRequestAds)")
        DispatchQueue.main.async { completionHandler(nil) }
    }
    public func requestConsentInfoUpdate(with parameters: RequestParameters?) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            requestConsentInfoUpdate(with: parameters) { e in e.map { k.resume(throwing: $0) } ?? k.resume() }
        }
    }
    public func reset() {
        for k in _TCF.keys { UserDefaults.standard.removeObject(forKey: k) }
        region = nil
        print("isim: User Messaging Platform: consent reset")
    }
}

// MARK: - forms

public final class ConsentForm: NSObject, @unchecked Sendable {
    var used = false
    public class func load(with completionHandler: @escaping (ConsentForm?, Error?) -> Void) {
        let info = ConsentInformation.shared
        DispatchQueue.main.async {
            info.formStatus == .available ? completionHandler(ConsentForm(), nil)
                : completionHandler(nil, _umpError(FormErrorCode.unavailable.rawValue, "No available form can be built."))
        }
    }
    public class func load(completionHandler: @escaping (ConsentForm?, Error?) -> Void) { load(with: completionHandler) }
    public class func load() async throws -> ConsentForm {
        try await withCheckedThrowingContinuation { k in load(with: { f, e in f.map { k.resume(returning: $0) } ?? k.resume(throwing: e!) }) }
    }
    public class func loadAndPresentIfRequired(from viewController: UIViewController?, completionHandler: ((Error?) -> Void)? = nil) {
        let info = ConsentInformation.shared
        guard info.consentStatus == .required else { DispatchQueue.main.async { completionHandler?(nil) }; return }
        ConsentForm().present(from: viewController, completionHandler: completionHandler)
    }
    public class func loadAndPresentIfRequired(from viewController: UIViewController?) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            loadAndPresentIfRequired(from: viewController) { e in e.map { k.resume(throwing: $0) } ?? k.resume() }
        }
    }
    public class func presentPrivacyOptionsForm(from viewController: UIViewController?, completionHandler: ((Error?) -> Void)? = nil) {
        guard ConsentInformation.shared.privacyOptionsRequirementStatus == .required else {
            DispatchQueue.main.async { completionHandler?(_umpError(FormErrorCode.unavailable.rawValue, "Privacy options form is not required.")) }
            return
        }
        ConsentForm().present(from: viewController, completionHandler: completionHandler)
    }
    public class func presentPrivacyOptionsForm(from viewController: UIViewController?) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            presentPrivacyOptionsForm(from: viewController) { e in e.map { k.resume(throwing: $0) } ?? k.resume() }
        }
    }
    public func present(from viewController: UIViewController?, completionHandler: ((Error?) -> Void)? = nil) {
        guard !used else { DispatchQueue.main.async { completionHandler?(_umpError(FormErrorCode.alreadyUsed.rawValue, "Form was already used.")) }; return }
        var top = viewController ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let p = top?.presentedViewController { top = p }
        guard let top else { DispatchQueue.main.async { completionHandler?(_umpError(FormErrorCode.invalidViewController.rawValue, "No view controller to present from.")) }; return }
        used = true
        let us = ConsentInformation.shared.region == .usState
        let form = _UMPFormController(usState: us) { completionHandler?(nil) }
        print("isim: User Messaging Platform: \(us ? "US state privacy" : "GDPR consent") form shown")
        top.present(form, animated: true)
    }
}

/// the message: a card over the app in the style of Google's consent message
final class _UMPFormController: UIViewController {
    let usState: Bool, done: () -> Void
    let card = UIView(), stack = UIStackView()
    var managing = false
    var switches: [Int: UISwitch] = [:]
    init(usState: Bool, done: @escaping () -> Void) {
        self.usState = usState; self.done = done
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    var appName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "This app"
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0, alpha: 0.4)
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16), card.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -16), card.topAnchor.constraint(greaterThanOrEqualTo: g.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 22), stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
        usState ? buildUS() : buildConsent()
    }
    func label(_ text: String, _ font: UIFont, _ color: UIColor = UIColor(white: 0.13, alpha: 1)) -> UILabel {
        let l = UILabel(); l.text = text; l.font = font; l.textColor = color; l.numberOfLines = 0; return l
    }
    func button(_ title: String, id: String, filled: Bool, _ action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        b.accessibilityIdentifier = id
        b.layer.cornerRadius = 20
        let blue = UIColor(red: 0.1, green: 0.45, blue: 0.91, alpha: 1)
        if filled { b.backgroundColor = blue; b.setTitleColor(.white, for: .normal) } else {
            b.layer.borderWidth = 1; b.layer.borderColor = UIColor(white: 0.75, alpha: 1).cgColor; b.setTitleColor(blue, for: .normal)
        }
        b.heightAnchor.constraint(equalToConstant: 40).isActive = true
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }
    /// a purpose (or choice) row: the text fills the width, the switch keeps its size at the trailing edge
    func row(_ text: String, _ font: UIFont, _ s: UISwitch) -> UIStackView {
        let r = UIStackView()
        r.spacing = 8
        r.alignment = .center
        let l = label(text, font)
        l.setContentHuggingPriority(.defaultLow, for: .horizontal)
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        s.setContentHuggingPriority(.required, for: .horizontal)
        s.setContentCompressionResistancePriority(.required, for: .horizontal)
        r.addArrangedSubview(l)
        r.addArrangedSubview(s)
        return r
    }
    func clear() { stack.arrangedSubviews.forEach { $0.removeFromSuperview() }; switches = [:] }

    func buildConsent() {
        clear()
        stack.addArrangedSubview(label(appName, .boldSystemFont(ofSize: 20)))
        stack.addArrangedSubview(label("\(appName) asks for your consent to use your personal data to:", .systemFont(ofSize: 16, weight: .semibold)))
        stack.addArrangedSubview(label("•  Personalised advertising and content, advertising and content measurement, audience research and services development",
                                       .systemFont(ofSize: 14)))
        stack.addArrangedSubview(label("•  Store and/or access information on a device", .systemFont(ofSize: 14)))
        stack.addArrangedSubview(label("Your personal data will be processed and information from your device (cookies, unique identifiers, and other "
                                       + "device data) may be stored by, accessed by and shared with third-party vendors, or used specifically by this "
                                       + "app. You can change your choices at any time in the app's privacy settings.", .systemFont(ofSize: 12), .darkGray))
        stack.addArrangedSubview(button("Consent", id: "ump-consent", filled: true, #selector(consentAll)))
        stack.addArrangedSubview(button("Do not consent", id: "ump-do-not-consent", filled: false, #selector(consentNone)))
        stack.addArrangedSubview(button("Manage options", id: "ump-manage", filled: false, #selector(manage)))
    }
    @objc func manage() {
        clear()
        managing = true
        stack.addArrangedSubview(label("Manage your data", .boldSystemFont(ofSize: 20)))
        stack.addArrangedSubview(label("Choose how your personal data is used.", .systemFont(ofSize: 14), .darkGray))
        let current = UserDefaults.standard.string(forKey: "IABTCF_PurposeConsents").map(Array.init) ?? []
        for (i, name) in _TCF.purposes.enumerated() {
            let s = UISwitch()
            s.isOn = i < current.count && current[i] == "1"
            s.accessibilityIdentifier = "ump-purpose-\(i + 1)"
            switches[i + 1] = s
            stack.addArrangedSubview(row(name, .systemFont(ofSize: 14), s))
        }
        stack.addArrangedSubview(button("Confirm choices", id: "ump-confirm", filled: true, #selector(confirm)))
        stack.addArrangedSubview(button("Accept all", id: "ump-accept-all", filled: false, #selector(consentAll)))
    }
    func buildUS() {
        clear()
        stack.addArrangedSubview(label("Your privacy choices", .boldSystemFont(ofSize: 20)))
        stack.addArrangedSubview(label("\(appName) and its partners may sell or share your personal information for advertising. "
                                       + "You can opt out of the sale or sharing of your personal information.", .systemFont(ofSize: 14)))
        let s = UISwitch()
        s.isOn = UserDefaults.standard.bool(forKey: "isim.UMP.usOptOut")
        s.accessibilityIdentifier = "ump-opt-out"
        switches[0] = s
        stack.addArrangedSubview(row("Do Not Sell or Share My Personal Information", .systemFont(ofSize: 14, weight: .semibold), s))
        stack.addArrangedSubview(button("Confirm", id: "ump-confirm", filled: true, #selector(confirmUS)))
    }

    @objc func consentAll() { finish(Set(1...11), "consent") }
    @objc func consentNone() { finish([], "do not consent") }
    @objc func confirm() { finish(Set(switches.filter { $0.value.isOn }.map(\.key)), "custom choices") }
    @objc func confirmUS() {
        let out = switches[0]?.isOn ?? false
        UserDefaults.standard.set(out, forKey: "isim.UMP.usOptOut")
        print("isim: User Messaging Platform: US state privacy choice saved: opt out of sale/sharing \(out)")
        close()
    }
    func finish(_ consents: Set<Int>, _ how: String) {
        _TCF.store(consents: consents)
        UserDefaults.standard.set(true, forKey: "isim.UMP.answered")
        print("isim: User Messaging Platform: \(how): purposes \(String((1...11).map { consents.contains($0) ? "1" : "0" })) "
              + "TCString \(UserDefaults.standard.string(forKey: "IABTCF_TCString")?.prefix(24) ?? "")…")
        close()
    }
    func close() { dismiss(animated: true) { [done] in done() } }
}
