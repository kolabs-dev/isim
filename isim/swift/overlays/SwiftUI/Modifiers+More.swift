// isim SwiftUI: more of SwiftUI's own View modifiers (issue #868): the accessibility modifiers' isEnabled: forms and
// the iOS 13 accessibility(…) forms, the speech attributes, Alert / ActionSheet values, the gesture and task variants,
// background / overlay variants and the iOS 13 navigation-bar modifiers. They build on the modifiers isim already has.
import UIKit

// MARK: - accessibility

/// The kind of text content, for VoiceOver's reading (iOS 15).
public struct AccessibilityTextContentType: Sendable {
    let raw: String
    public static let plain = AccessibilityTextContentType(raw: "UIAccessibilityTextualContextPlain")
    public static let console = AccessibilityTextContentType(raw: "UIAccessibilityTextualContextConsole")
    public static let fileSystem = AccessibilityTextContentType(raw: "UIAccessibilityTextualContextFileSystem")
    public static let messaging = AccessibilityTextContentType(raw: "UIAccessibilityTextualContextMessaging")
    public static let narrative = AccessibilityTextContentType(raw: "UIAccessibilityTextualContextNarrative")
    public static let sourceCode = AccessibilityTextContentType(raw: "UIAccessibilityTextualContextSourceCode")
    public static let spreadsheet = AccessibilityTextContentType(raw: "UIAccessibilityTextualContextSpreadsheet")
    public static let wordProcessing = AccessibilityTextContentType(raw: "UIAccessibilityTextualContextWordProcessing")
}

extension View {
    // the isEnabled: forms: when false the modifier does nothing
    public func accessibilityHidden(_ hidden: Bool, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        _axApply { v in guard isEnabled else { return }; v.accessibilityElementsHidden = hidden; if hidden { v.isAccessibilityElement = false } }
    }
    public func accessibilityIdentifier(_ identifier: String, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        _axApply { v in if isEnabled { v.accessibilityIdentifier = identifier } }
    }
    public func accessibilityLabel(_ label: Text, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        let s = label.string; return _axApply { v in if isEnabled { v.accessibilityLabel = s } }
    }
    public func accessibilityLabel(_ key: LocalizedStringKey, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityLabel(Text(key), isEnabled: isEnabled) }
    @_disfavoredOverload public func accessibilityLabel<S: StringProtocol>(_ label: S, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityLabel(Text(label), isEnabled: isEnabled) }
    public func accessibilityHint(_ hint: Text, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        let s = hint.string; return _axApply { v in if isEnabled { v.accessibilityHint = s } }
    }
    public func accessibilityHint(_ key: LocalizedStringKey, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityHint(Text(key), isEnabled: isEnabled) }
    @_disfavoredOverload public func accessibilityHint<S: StringProtocol>(_ hint: S, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityHint(Text(hint), isEnabled: isEnabled) }
    public func accessibilityValue(_ value: Text, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        let s = value.string; return _axApply { v in if isEnabled { v.accessibilityValue = s } }
    }
    public func accessibilityValue(_ key: LocalizedStringKey, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityValue(Text(key), isEnabled: isEnabled) }
    @_disfavoredOverload public func accessibilityValue<S: StringProtocol>(_ value: S, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityValue(Text(value), isEnabled: isEnabled) }
    public func accessibilityInputLabels(_ labels: [Text], isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        let l = labels.map(\.string); return _axApply { v in if isEnabled { v.accessibilityUserInputLabels = l } }
    }
    public func accessibilityInputLabels(_ keys: [LocalizedStringKey], isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityInputLabels(keys.map { Text($0) }, isEnabled: isEnabled) }
    @_disfavoredOverload public func accessibilityInputLabels<S: StringProtocol>(_ labels: [S], isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityInputLabels(labels.map { Text($0) }, isEnabled: isEnabled) }
    public func accessibilityRespondsToUserInteraction(_ respondsToUserInteraction: Bool, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        _axApply { v in if isEnabled { v.accessibilityRespondsToUserInteraction = respondsToUserInteraction } }
    }
    /// where VoiceOver activates the element: a point in its bounds
    public func accessibilityActivationPoint(_ point: CGPoint) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityActivationPoint(point, isEnabled: true) }
    public func accessibilityActivationPoint(_ point: CGPoint, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        _axApply { v in if isEnabled { v.accessibilityActivationPoint = v.convert(point, to: nil) } }
    }
    public func accessibilityActivationPoint(_ point: UnitPoint) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityActivationPoint(point, isEnabled: true) }
    public func accessibilityActivationPoint(_ point: UnitPoint, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        _axApply { v in
            guard isEnabled else { return }
            v.accessibilityActivationPoint = v.convert(CGPoint(x: v.bounds.width * point.x, y: v.bounds.height * point.y), to: nil)
        }
    }
    public func accessibilityTextContentType(_ value: AccessibilityTextContentType) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        let ctx = UIAccessibilityTextualContext(rawValue: value.raw)
        return _axApply { v in v.accessibilityTextualContext = ctx }
    }
    /// keeps the view's colours when Smart Invert is on
    public func accessibilityIgnoresInvertColors(_ active: Bool = true) -> some View { _accessibility { $0.accessibilityIgnoresInvertColors = active } }

    // iOS 13 accessibility(…) forms (deprecated): the same as the modifiers that replaced them
    public func accessibility(label: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityLabel(label, isEnabled: true) }
    public func accessibility(hint: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityHint(hint, isEnabled: true) }
    public func accessibility(value: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityValue(value, isEnabled: true) }
    public func accessibility(hidden: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityHidden(hidden, isEnabled: true) }
    public func accessibility(identifier: String) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityIdentifier(identifier, isEnabled: true) }
    public func accessibility(inputLabels: [Text]) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityInputLabels(inputLabels, isEnabled: true) }
    public func accessibility(addTraits traits: AccessibilityTraits) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        _axApply { v in v.accessibilityTraits = v.accessibilityTraits.union(traits.uikit) }
    }
    public func accessibility(removeTraits traits: AccessibilityTraits) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        _axApply { v in v.accessibilityTraits = v.accessibilityTraits.subtracting(traits.uikit) }
    }
    public func accessibility(sortPriority: Double) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        _axApply { v in v.perform(NSSelectorFromString("_isim_setAccessibilitySortPriority:"), with: NSNumber(value: sortPriority)) }
    }
    public func accessibility(activationPoint: CGPoint) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityActivationPoint(activationPoint) }
    public func accessibility(activationPoint: UnitPoint) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { accessibilityActivationPoint(activationPoint) }
    public func accessibility(selectionIdentifier: AnyHashable) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _axApply { _ in } }

    // speech: how VoiceOver speaks the element's label (UIKit's speech attributes on its attributed label)
    func _speech(_ key: String, _ value: Any) -> some View {
        _accessibility { v in
            let base = v.accessibilityAttributedLabel ?? NSAttributedString(string: v.accessibilityLabel ?? "")
            let m = NSMutableAttributedString(attributedString: base)
            if m.length > 0 { m.addAttribute(NSAttributedString.Key(key), value: value, range: NSRange(location: 0, length: m.length)) }
            v.accessibilityAttributedLabel = m
        }
    }
    public func speechAdjustedPitch(_ value: Double) -> some View { _speech("UIAccessibilitySpeechAttributePitch", NSNumber(value: value + 1)) }
    public func speechAlwaysIncludesPunctuation(_ value: Bool = true) -> some View { _speech("UIAccessibilitySpeechAttributePunctuation", NSNumber(value: value)) }
    public func speechAnnouncementsQueued(_ value: Bool = true) -> some View { _speech("UIAccessibilitySpeechAttributeQueueAnnouncement", NSNumber(value: value)) }
    public func speechSpellsOutCharacters(_ value: Bool = true) -> some View { _speech("UIAccessibilitySpeechAttributeSpellOut", NSNumber(value: value)) }
}

// MARK: - Alert and ActionSheet values (iOS 13)

/// An alert built as a value (iOS 13, deprecated): presented through .alert(isPresented:content:).
public struct Alert {
    public struct Button {
        let label: Text, role: ButtonRole?, action: (() -> Void)?
        public static func `default`(_ label: Text, action: (() -> Void)? = {}) -> Button { Button(label: label, role: nil, action: action) }
        public static func cancel(_ label: Text, action: (() -> Void)? = {}) -> Button { Button(label: label, role: .cancel, action: action) }
        public static func cancel(_ action: (() -> Void)? = {}) -> Button { Button(label: Text("Cancel"), role: .cancel, action: action) }
        public static func destructive(_ label: Text, action: (() -> Void)? = {}) -> Button { Button(label: label, role: .destructive, action: action) }
    }
    let title: Text, message: Text?, buttons: [Button]
    public init(title: Text, message: Text? = nil, dismissButton: Button? = nil) {
        self.title = title; self.message = message; buttons = [dismissButton ?? .default(Text("OK"))]
    }
    public init(title: Text, message: Text? = nil, primaryButton: Button, secondaryButton: Button) {
        self.title = title; self.message = message; buttons = [primaryButton, secondaryButton]
    }
}
/// An action sheet built as a value (iOS 13, deprecated): a confirmation dialog.
public struct ActionSheet {
    public typealias Button = Alert.Button
    let title: Text, message: Text?, buttons: [Button]
    public init(title: Text, message: Text? = nil, buttons: [Button] = [.cancel()]) { self.title = title; self.message = message; self.buttons = buttons }
}
struct _AlertButtons: View {
    let buttons: [Alert.Button]
    var body: some View {
        ForEach(0..<buttons.count, id: \.self) { i in
            let b = buttons[i]
            SwiftUI.Button(role: b.role, action: { b.action?() }) { b.label }
        }
    }
}
extension View {
    public func alert(isPresented: Binding<Bool>, content: () -> Alert) -> some View {
        let a = content()
        return alert(a.title, isPresented: isPresented) { _AlertButtons(buttons: a.buttons) } message: { a.message ?? Text("") }
    }
    public func alert<Item: Identifiable>(item: Binding<Item?>, content: (Item) -> Alert) -> some View {
        let shown = Binding<Bool>(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
        let a = item.wrappedValue.map(content)
        return alert(a?.title ?? Text(""), isPresented: shown) { _AlertButtons(buttons: a?.buttons ?? []) } message: { a?.message ?? Text("") }
    }
    public func actionSheet(isPresented: Binding<Bool>, content: () -> ActionSheet) -> some View {
        let s = content()
        return confirmationDialog(s.title.string, isPresented: isPresented, titleVisibility: .visible) { _AlertButtons(buttons: s.buttons) } message: { s.message ?? Text("") }
    }
    public func actionSheet<T: Identifiable>(item: Binding<T?>, content: (T) -> ActionSheet) -> some View {
        let shown = Binding<Bool>(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
        let s = item.wrappedValue.map(content)
        return confirmationDialog(s?.title.string ?? "", isPresented: shown, titleVisibility: .visible) { _AlertButtons(buttons: s?.buttons ?? []) } message: { s?.message ?? Text("") }
    }
    /// an alert for an error: its description as the title, its failure reason and recovery suggestion as the message
    public func alert<E: LocalizedError, A: View>(isPresented: Binding<Bool>, error: E?, @ViewBuilder actions: () -> A) -> some View {
        alert(Text(error?.errorDescription ?? ""), isPresented: isPresented, actions: actions) {
            Text([error?.failureReason, error?.recoverySuggestion].compactMap { $0 }.joined(separator: "\n"))
        }
    }
    public func alert<E: LocalizedError, A: View, M: View>(isPresented: Binding<Bool>, error: E?, @ViewBuilder actions: (E) -> A,
                                                         @ViewBuilder message: (E) -> M) -> some View {
        alert(error?.errorDescription ?? "", isPresented: isPresented, presenting: error, actions: actions, message: message)
    }
}

// MARK: - gestures, tasks, tags

extension View {
    public func gesture<G: Gesture>(_ gesture: G, name: String, isEnabled: Bool = true) -> some View { self.gesture(gesture, including: isEnabled ? .all : .subviews) }
    public func highPriorityGesture<G: Gesture>(_ gesture: G, isEnabled: Bool) -> some View { highPriorityGesture(gesture, including: isEnabled ? .all : .subviews) }
    public func highPriorityGesture<G: Gesture>(_ gesture: G, name: String, isEnabled: Bool = true) -> some View { highPriorityGesture(gesture, including: isEnabled ? .all : .subviews) }
    public func simultaneousGesture<G: Gesture>(_ gesture: G, isEnabled: Bool) -> some View { simultaneousGesture(gesture, including: isEnabled ? .all : .subviews) }
    public func simultaneousGesture<G: Gesture>(_ gesture: G, name: String, isEnabled: Bool = true) -> some View { simultaneousGesture(gesture, including: isEnabled ? .all : .subviews) }
    /// iOS 13 (deprecated): `pressing` before `perform`
    public func onLongPressGesture(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10, pressing: ((Bool) -> Void)? = nil, perform action: @escaping () -> Void) -> some View {
        onLongPressGesture(minimumDuration: minimumDuration, maximumDistance: maximumDistance, perform: action, onPressingChanged: pressing)
    }
    /// iOS 26: a task with a name (shown in debuggers); the name is not used
    @_disfavoredOverload
    public func task(name: String?, priority: TaskPriority = .userInitiated, file: String = #fileID, line: Int = #line,
                     @_inheritActorContext _ action: @escaping @Sendable () async -> Void) -> some View { task(priority: priority, action) }
    @_disfavoredOverload
    public func task<T: Equatable>(id value: T, name: String?, priority: TaskPriority = .userInitiated, file: String = #fileID, line: Int = #line,
                                   @_inheritActorContext _ action: @escaping @Sendable () async -> Void) -> some View { task(id: value, priority: priority, action) }
    /// iOS 17: a tag that also matches an optional selection
    public func tag<V: Hashable>(_ tag: V, includeOptional: Bool) -> some View { self.tag(tag) }
}

// MARK: - backgrounds and overlays

extension View {
    /// the system background behind the view
    public func background(ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View { background(Color(UIColor.systemBackground)) }
    public func background<S: ShapeStyle>(_ style: S, ignoresSafeAreaEdges edges: Edge.Set) -> some View { background(style) }
    public func background<S: Shape>(in shape: S, fillStyle: FillStyle = FillStyle()) -> some View { background(Color(UIColor.systemBackground), in: shape, fillStyle: fillStyle) }
    public func overlay<S: ShapeStyle, T: Shape>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View {
        overlay { shape.fill(style, style: fillStyle) }
    }
    @_disfavoredOverload
    public func backgroundPreferenceValue<K: PreferenceKey, T: View>(_ key: K.Type = K.self, @ViewBuilder _ transform: @escaping (K.Value) -> T) -> some View {
        backgroundPreferenceValue(key, alignment: .center, transform)
    }
    @_disfavoredOverload
    public func overlayPreferenceValue<K: PreferenceKey, T: View>(_ key: K.Type = K.self, @ViewBuilder _ transform: @escaping (K.Value) -> T) -> some View {
        overlayPreferenceValue(key, alignment: .center, transform)
    }
    /// iOS 13 (deprecated): `antialiased` is always on in isim's drawing
    public func cornerRadius(_ radius: CGFloat, antialiased: Bool) -> some View { cornerRadius(radius) }
    /// iOS 13 (deprecated): no frame change
    public func frame() -> some View { self }
}

// MARK: - iOS 13 navigation-bar modifiers (deprecated)

extension View {
    public func navigationBarTitle(_ title: Text) -> some View { navigationTitle(title) }
    public func navigationBarTitle(_ titleKey: LocalizedStringKey) -> some View { navigationTitle(titleKey) }
    @_disfavoredOverload public func navigationBarTitle<S: StringProtocol>(_ title: S) -> some View { navigationTitle(Text(title)) }
    public func navigationBarTitle(_ title: Text, displayMode: NavigationBarItem.TitleDisplayMode) -> some View {
        navigationTitle(title).navigationBarTitleDisplayMode(displayMode)
    }
    public func navigationBarTitle(_ titleKey: LocalizedStringKey, displayMode: NavigationBarItem.TitleDisplayMode) -> some View {
        navigationTitle(titleKey).navigationBarTitleDisplayMode(displayMode)
    }
    @_disfavoredOverload public func navigationBarTitle<S: StringProtocol>(_ title: S, displayMode: NavigationBarItem.TitleDisplayMode) -> some View {
        navigationTitle(Text(title)).navigationBarTitleDisplayMode(displayMode)
    }
    public func navigationBarItems<L: View, T: View>(leading: L, trailing: T) -> some View {
        toolbar {
            ToolbarItem(placement: .navigationBarLeading) { leading }
            ToolbarItem(placement: .navigationBarTrailing) { trailing }
        }
    }
    public func navigationBarItems<L: View>(leading: L) -> some View { toolbar { ToolbarItem(placement: .navigationBarLeading) { leading } } }
    public func navigationBarItems<T: View>(trailing: T) -> some View { toolbar { ToolbarItem(placement: .navigationBarTrailing) { trailing } } }
    /// iOS 13 (deprecated)
    public func statusBar(hidden: Bool) -> some View { statusBarHidden(hidden) }
    /// iOS 13 (deprecated): `.autocapitalization(.words)`
    public func autocapitalization(_ style: UITextAutocapitalizationType) -> some View {
        let m: TextInputAutocapitalization = style == .none ? .never : style == .words ? .words : style == .allCharacters ? .characters : .sentences
        return textInputAutocapitalization(m)
    }
    /// iOS 15 (deprecated): search with suggestions in one modifier
    public func searchable<S: View>(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil,
                                    @ViewBuilder suggestions: () -> S) -> some View {
        searchable(text: text, placement: placement, prompt: prompt).searchSuggestions(suggestions)
    }
    /// a list row's insets on some edges (iOS 26)
    public func listRowInsets(_ edges: Edge.Set = .all, _ length: CGFloat?) -> some View {
        let l = length ?? 16
        return listRowInsets(EdgeInsets(top: edges.contains(.top) ? l : 0, leading: edges.contains(.leading) ? l : 0,
                                        bottom: edges.contains(.bottom) ? l : 0, trailing: edges.contains(.trailing) ? l : 0))
    }
}
