// isim AppIntents: SiriTipView and ShortcutsLink (adapted: isim's drawing of Apple's views).
import Foundation
import SwiftUI
import UIKit

public enum SiriTipViewStyle: Sendable { case automatic, light, dark }
public enum ShortcutsLinkStyle: Sendable { case automatic, light, dark, lightOutline, darkOutline }
private struct _SiriTipStyleKey: EnvironmentKey { static let defaultValue: SiriTipViewStyle = .automatic }
private struct _ShortcutsLinkStyleKey: EnvironmentKey { static let defaultValue: ShortcutsLinkStyle = .automatic }
extension EnvironmentValues {
    var _isimSiriTipStyle: SiriTipViewStyle { get { self[_SiriTipStyleKey.self] } set { self[_SiriTipStyleKey.self] = newValue } }
    var _isimShortcutsLinkStyle: ShortcutsLinkStyle { get { self[_ShortcutsLinkStyleKey.self] } set { self[_ShortcutsLinkStyleKey.self] = newValue } }
}
extension View {
    public func siriTipViewStyle(_ style: SiriTipViewStyle) -> some View { environment(\._isimSiriTipStyle, style) }
    public func shortcutsLinkStyle(_ style: ShortcutsLinkStyle) -> some View { environment(\._isimShortcutsLinkStyle, style) }
}

/// Siri's multicolored orb (the glyph tips use)
struct _IsimSiriGlyph: View {
    var body: some View {
        Circle()
            .fill(AngularGradient(colors: [Color(red: 1, green: 0.25, blue: 0.55), Color(red: 0.55, green: 0.3, blue: 1), Color(red: 0.2, green: 0.65, blue: 1),
                                           Color(red: 0.25, green: 0.9, blue: 0.8), Color(red: 1, green: 0.6, blue: 0.2), Color(red: 1, green: 0.25, blue: 0.55)],
                                  center: .center))
            .overlay(Circle().fill(RadialGradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0)], center: .center, startRadius: 0, endRadius: 9)))
            .frame(width: 30, height: 30)
    }
}

/// A tip that tells people the phrase of one of the app's App Shortcuts.
public struct SiriTipView: View {
    let phrase: String
    @Binding var isVisible: Bool
    @Environment(\._isimSiriTipStyle) var style
    @Environment(\.colorScheme) var scheme
    public init<I: AppIntent>(intent: I, isVisible: Binding<Bool> = .constant(true)) {
        _isVisible = isVisible
        phrase = MainActor.assumeIsolated { _isimPhrase(for: I.self) } ?? I.title.description
    }
    public var body: some View {
        if isVisible {
            let dark = style == .dark || (style == .automatic && scheme == .dark)
            HStack(alignment: .center, spacing: 12) {
                _IsimSiriGlyph()
                Text("Try saying “\(phrase)”")
                    .font(.subheadline)
                    .foregroundColor(dark ? .white : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { isVisible = false } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                }
                .accessibilityIdentifier("siri-tip-close")
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(dark ? Color(white: 0.17) : Color(UIColor.secondarySystemBackground)))
            .accessibilityIdentifier("siri-tip")
        }
    }
}

/// A button that opens the Shortcuts app on the app's App Shortcuts.
public struct ShortcutsLink: View {
    let action: (() -> Void)?
    @Environment(\._isimShortcutsLinkStyle) var style
    @Environment(\.colorScheme) var scheme
    @Environment(\.openURL) var openURL
    public init(action: (() -> Void)? = nil) { self.action = action }
    public var body: some View {
        let dark = style == .dark || style == .darkOutline || (style == .automatic && scheme == .dark)
        let outline = style == .lightOutline || style == .darkOutline
        Button {
            if let action { action(); return }
            let id = Bundle.main.bundleIdentifier ?? ""
            NSLog("isim AppIntents: ShortcutsLink opens Shortcuts for %@", id)
            if let u = URL(string: "shortcuts://app-shortcuts?bundle=\(id)") { openURL(u) }
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [Color(red: 0.3, green: 0.4, blue: 1), Color(red: 0.9, green: 0.3, blue: 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 14, height: 14).offset(x: -3, y: -3)
                    RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [Color(red: 0.2, green: 0.8, blue: 1), Color(red: 0.4, green: 0.4, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 14, height: 14).offset(x: 3, y: 3)
                }
                .frame(width: 22, height: 22)
                Text("Shortcuts").font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(dark ? .white : .black)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(Capsule().fill(dark ? Color.black : Color.white))
            .overlay(Capsule().stroke(dark ? Color.white : Color.black, lineWidth: outline ? 1 : 0))
        }
        .accessibilityIdentifier("shortcuts-link")
    }
}
