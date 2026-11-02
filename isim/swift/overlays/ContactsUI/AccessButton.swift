// isim ContactsUI (issue #420): ContactAccessButton and contactAccessPicker (iOS 18), for apps with limited Contacts
// access. The button shows the device contact that best matches a search the app has not been given yet, with its phone
// number or email, and shares it with the app when tapped (an app that has not asked for access gets limited access to
// it, as on iOS). The picker adds contacts to the app's limited selection. Both run outside the app's permission, like
// iOS's: the app only learns the identifiers it was given.
@_spi(isim) import Contacts
import SwiftUI

@available(iOS 18.0, *)
public struct ContactAccessButton: View {
    public enum Caption: Sendable, Hashable { case defaultText, email, phone }

    public struct Style: Sendable {
        var imageTrailingEdgePadding: CGFloat?
        var imageWidth: CGFloat?
        var imageColor: Color?
        public init(imageTrailingEdgePadding: CGFloat? = nil, imageWidth: CGFloat? = nil, imageColor: Color? = nil) {
            self.imageTrailingEdgePadding = imageTrailingEdgePadding; self.imageWidth = imageWidth; self.imageColor = imageColor
        }
        public static let automatic = Style()
    }

    let queryString: String
    let ignoredEmails: Set<String>?
    let ignoredPhoneNumbers: Set<String>?
    let approvalCallback: (([String]) -> Void)?
    @Environment(\._contactAccessCaption) private var caption
    @Environment(\._contactAccessStyle) private var style
    @State private var added: String?
    @State private var revision = 0

    public init(queryString: String, ignoredEmails: Set<String>? = nil, ignoredPhoneNumbers: Set<String>? = nil,
                approvalCallback: (([String]) -> Void)? = nil) {
        self.queryString = queryString; self.ignoredEmails = ignoredEmails; self.ignoredPhoneNumbers = ignoredPhoneNumbers
        self.approvalCallback = approvalCallback
    }

    /// the best match the app cannot read yet: names first, then phone numbers and emails
    var match: CNContact? {
        _ = revision
        let q = queryString.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty, let shared = CNContactStore._isimLimitedIDs ?? (CNContactStore.authorizationStatus(for: .contacts) == .notDetermined ? [] : nil)
        else { return nil }
        let digits = q.filter(\.isNumber)
        let ignoredE = Set((ignoredEmails ?? []).map { $0.lowercased() })
        let ignoredP = Set((ignoredPhoneNumbers ?? []).map { $0.filter(\.isNumber) })
        let candidates = CNContactStore._isimAllContacts().filter { c in
            !shared.contains(c.identifier)
                && !c.emailAddresses.contains { ignoredE.contains(($0.value as String).lowercased()) }
                && !c.phoneNumbers.contains { ignoredP.contains($0.value.stringValue.filter(\.isNumber)) }
        }
        return candidates.first { CNContactStore._isimFullName($0).lowercased().contains(q) }
            ?? candidates.first { c in digits.count >= 3 && c.phoneNumbers.contains { $0.value.stringValue.filter(\.isNumber).contains(digits) } }
            ?? candidates.first { c in c.emailAddresses.contains { ($0.value as String).lowercased().contains(q) } }
    }

    func detail(_ c: CNContact) -> String? {
        let phone = c.phoneNumbers.first?.value.stringValue, email = c.emailAddresses.first.map { $0.value as String }
        switch caption {
        case .phone: return phone
        case .email: return email
        case .defaultText:
            let digits = queryString.filter(\.isNumber)
            if digits.count >= 3, let p = c.phoneNumbers.first(where: { $0.value.stringValue.filter(\.isNumber).contains(digits) }) {
                return p.value.stringValue
            }
            return email ?? phone
        }
    }

    public var body: some View {
        if let name = added {
            row(name, "Added", symbol: "checkmark.circle.fill")
        } else if let c = match {
            Button {
                guard CNContactStore._isimShare([c.identifier]) else { revision += 1; return }
                added = CNContactStore._isimFullName(c)
                approvalCallback?([c.identifier])
            } label: {
                row(CNContactStore._isimFullName(c), detail(c), symbol: "plus.circle.fill")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("contact-access-button")
            .accessibilityLabel("Share \(CNContactStore._isimFullName(c))")
        }
    }

    func row(_ title: String, _ subtitle: String?, symbol: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body).foregroundStyle(.primary)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            Image(systemName: symbol)
                .resizable().scaledToFit()
                .frame(width: style.imageWidth ?? 24, height: style.imageWidth ?? 24)
                .foregroundStyle(style.imageColor ?? .accentColor)
                .padding(.trailing, style.imageTrailingEdgePadding ?? 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

@available(iOS 18.0, *)
struct _ContactAccessCaptionKey: EnvironmentKey { static let defaultValue: ContactAccessButton.Caption = .defaultText }
@available(iOS 18.0, *)
struct _ContactAccessStyleKey: EnvironmentKey { static let defaultValue: ContactAccessButton.Style = .automatic }
@available(iOS 18.0, *)
extension EnvironmentValues {
    var _contactAccessCaption: ContactAccessButton.Caption {
        get { self[_ContactAccessCaptionKey.self] } set { self[_ContactAccessCaptionKey.self] = newValue }
    }
    var _contactAccessStyle: ContactAccessButton.Style {
        get { self[_ContactAccessStyleKey.self] } set { self[_ContactAccessStyleKey.self] = newValue }
    }
}

@available(iOS 18.0, *)
struct _ContactAccessPicker: ViewModifier {
    @Binding var isPresented: Bool
    let completionHandler: ([String]) -> Void
    func body(content: Content) -> some View {
        content.onChange(of: isPresented) { _, shown in
            guard shown else { return }
            CNContactStore._isimPresentLimitedSelection { ids in
                isPresented = false
                completionHandler(ids)
            }
        }
    }
}

@available(iOS 18.0, *)
extension View {
    public func contactAccessButtonCaption(_ caption: ContactAccessButton.Caption) -> some View {
        environment(\._contactAccessCaption, caption)
    }
    public func contactAccessButtonStyle(_ style: ContactAccessButton.Style) -> some View {
        environment(\._contactAccessStyle, style)
    }
    /// presents the limited-access picker, for adding contacts to what the app may read; the handler gets the added ones
    public func contactAccessPicker(isPresented: Binding<Bool>, completionHandler: @escaping ([String]) -> Void) -> some View {
        modifier(_ContactAccessPicker(isPresented: isPresented, completionHandler: completionHandler))
    }
}
