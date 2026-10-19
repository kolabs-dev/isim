// isim SwiftUI: `.searchable` — a search field under the navigation title of a List (or above other content), with a
// Cancel button while searching; `\.isSearching`, `\.dismissSearch`, `.onSubmit(of: .search)`, `isPresented:` binding.
// While searching, `searchSuggestions` replace the content with a list of suggestions (rows with `searchCompletion`
// fill the field) and `searchScopes` show a segmented scope bar under the field.
// The field is a UISearchTextField: `searchable(text:tokens:…)` shows the tokens in it (rendered from the token
// views' text and image), Delete at the start of the text removes the last one, `suggestedTokens` are the suggestions
// while the text is empty, and `searchCompletion(_ token:)` rows add a token. `searchFocused` binds its focus.
import UIKit

public struct SearchFieldPlacement: Sendable {
    let id: Int
    public static let automatic = SearchFieldPlacement(id: 0), toolbar = SearchFieldPlacement(id: 1), sidebar = SearchFieldPlacement(id: 2)
    public static let navigationBarDrawer = SearchFieldPlacement(id: 3)
    public static func navigationBarDrawer(displayMode: NavigationBarDrawerDisplayMode) -> SearchFieldPlacement { SearchFieldPlacement(id: 3) }
    public struct NavigationBarDrawerDisplayMode: Sendable { let id: Int; public static let automatic = Self(id: 0), always = Self(id: 1) }
}
public struct DismissSearchAction {
    let action: () -> Void
    @MainActor public func callAsFunction() { action() }
}
struct _IsSearchingKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _DismissSearchKey: EnvironmentKey { static var defaultValue: DismissSearchAction { DismissSearchAction(action: {}) } }
extension EnvironmentValues {
    public var isSearching: Bool { get { self[_IsSearchingKey.self] } set { self[_IsSearchingKey.self] = newValue } }
    public var dismissSearch: DismissSearchAction { get { self[_DismissSearchKey.self] } set { self[_DismissSearchKey.self] = newValue } }
}

/// One searchable modifier: its text, prompt and searching state.
@MainActor final class _SearchConfig {
    let text: Binding<String>, prompt: String, path: String
    let searching: Binding<Bool>
    weak var graph: _Graph?
    weak var bar: _SUISearchBar?
    /// the scope bar (searchScopes) while it shows
    var scopeNode: _Node?
    /// searchable(text:tokens:…) and searchFocused
    var tokens: _SearchTokens?
    var focus: _FocusLink?
    init(text: Binding<String>, prompt: String, path: String, searching: Binding<Bool>, graph: _Graph) {
        self.text = text; self.prompt = prompt; self.path = path; self.searching = searching; self.graph = graph
    }
    func submit() {
        guard let g = graph else { return }
        // .onSubmit(of: .search) registered on this modifier or an ancestor
        let k = g.storage.keys.filter { $0.hasSuffix("#searchsubmit") && path.hasPrefix(String($0.dropLast("#searchsubmit".count))) }.max { $0.count < $1.count }
        if let k, let box = g.storage[k] as? _SubmitBox { box.action() }
    }
}
final class _SubmitBox: _AnyStorage { let action: () -> Void; init(_ a: @escaping () -> Void) { action = a } }

extension View {
    public func searchable(text: Binding<String>, isPresented: Binding<Bool>? = nil, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil) -> some View {
        _searchable(text, isPresented, prompt?.string ?? "Search")
    }
    public func searchable(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey) -> some View {
        _searchable(text, nil, prompt.resolved())
    }
    @_disfavoredOverload public func searchable<S: StringProtocol>(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: S) -> some View {
        _searchable(text, nil, String(prompt))
    }
    public func searchable(text: Binding<String>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey) -> some View {
        _searchable(text, isPresented, prompt.resolved())
    }
    @_disfavoredOverload public func searchable(text: Binding<String>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic, prompt: some StringProtocol) -> some View {
        _searchable(text, isPresented, String(prompt))
    }
    func _searchable(_ text: Binding<String>, _ isPresented: Binding<Bool>?, _ prompt: String, tokens: (@MainActor (_Context) -> _SearchTokens)? = nil) -> some View {
        _modify { ctx, c in
            let g = ctx.graph, key = ctx.path + "#searching"
            let st = (g.storage[key] as? _StateStorage<Bool>) ?? { let s = _StateStorage(false); g.storage[key] = s; return s }()
            g.usedKeys.insert(key)
            let searching = isPresented ?? Binding(get: { st.value }, set: { [weak g] v in if st.value != v { st.value = v; g?.invalidate() } })
            let cfg = _SearchConfig(text: text, prompt: prompt, path: ctx.path, searching: searching, graph: g)
            let wasList = ctx.nav?.contentIsList ?? false
            ctx.nav?.contentIsList = false
            let extras = ctx.environment._searchExtras ?? _SearchExtras()
            cfg.focus = ctx.environment._searchFocus
            let inner = ctx.child("search").with {
                $0.isSearching = searching.wrappedValue
                $0.dismissSearch = DismissSearchAction { text.wrappedValue = ""; searching.wrappedValue = false; UIApplication.shared._isim_firstResponder?.resignFirstResponder() }
                $0._searchExtras = extras
                $0._searchFocus = nil
                $0._searchConfig = cfg
            }
            cfg.tokens = tokens?(inner.child("tokens"))
            var node = _resolve(c, inner)
            // searchScopes: a segmented scope bar under the field while searching (or once text is entered)
            if let picker = extras.scopes, searching.wrappedValue || (extras.scopeOnText && !text.wrappedValue.isEmpty) {
                cfg.scopeNode = _resolve(picker, inner.child("scopes"))
            }
            // searchSuggestions: while searching, a list of suggestions instead of the content
            // (or the suggested tokens while the text is empty)
            let sugViews = [extras.suggestions, text.wrappedValue.isEmpty ? cfg.tokens?.suggestions : nil].compactMap { $0 }
            for sug in sugViews where searching.wrappedValue {
                // the suggestions list takes the content list's place (same views: the field keeps the keyboard)
                var env = inner.environment; env._searchCompletion = cfg
                let at = _innerList(node)?.path ?? inner.path + "/suggestions"
                let list = _makeList(sug, _Context(graph: g, path: at, environment: env, nav: ctx.nav))
                if _collectsRows(list) { node = list; break }
            }
            // iPhone iOS 26, in a TabView's search tab: the field is in the tab bar
            if ctx.environment._inSearchTab, let host = ctx.environment._tabSearchHost {
                host.config = cfg
                ctx.nav?.contentIsList = wasList
                return node
            }
            if let lv = ctx.nav, lv.contentIsList { lv.search = cfg; return node }         // the List shows the field under its title
            ctx.nav?.contentIsList = wasList
            let field = _SearchFieldNode(path: ctx.path + "/field", config: cfg)
            let padded = _PaddingNode(path: ctx.path + "/fieldpad", insets: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16), child: field)
            var parts: [_Node] = [padded]
            if let s = cfg.scopeNode { parts.append(_PaddingNode(path: ctx.path + "/scopepad", insets: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16), child: s)) }
            return _StackNode(path: ctx.path, axis: .vertical, spacing: 8, alignment: .center, children: parts + [node])
        }
    }
    /// Suggestions shown while searching (in place of the content); give rows `searchCompletion` to fill the field.
    public func searchSuggestions<S: View>(@ViewBuilder _ suggestions: () -> S) -> some View {
        let v = AnyView(suggestions())
        return _modify { ctx, c in
            let ex = ctx.environment._searchExtras ?? _SearchExtras()
            ex.suggestions = v
            return _resolve(c, ctx.child("sugg").with { $0._searchExtras = ex })
        }
    }
    /// A suggestion row that puts `completion` in the search field when tapped.
    public func searchCompletion(_ completion: String) -> some View {
        _modify { ctx, c in
            let n = _resolve(c, ctx.child("compl"))
            guard let cfg = ctx.environment._searchCompletion else { return n }
            return _ButtonNode(path: ctx.path, child: n, action: { [weak cfg] in
                cfg?.text.wrappedValue = completion
                cfg?.bar?.field.text = completion
            }, inList: ctx.environment._inList, enabled: true)
        }
    }
    /// A suggestion row that adds `token` to the search field's tokens when tapped.
    public func searchCompletion<T: Identifiable>(_ token: T) -> some View {
        _modify { ctx, c in
            let n = _resolve(c, ctx.child("compl"))
            guard let cfg = ctx.environment._searchCompletion, let add = cfg.tokens?.append else { return n }
            return _ButtonNode(path: ctx.path, child: n, action: { [weak cfg] in
                add(token)
                cfg?.text.wrappedValue = ""
                cfg?.bar?.field.text = ""
            }, inList: ctx.environment._inList, enabled: true)
        }
    }
    /// Binds the focus of the nearest searchable's field: true when it has the keyboard; setting it focuses or
    /// unfocuses the field.
    @available(iOS 18.0, *)
    public func searchFocused(_ binding: FocusState<Bool>.Binding) -> some View {
        _searchFocused(_FocusLink(get: { binding.wrappedValue }, set: { binding.wrappedValue = $0 }))
    }
    @available(iOS 18.0, *)
    public func searchFocused<V: Hashable>(_ binding: FocusState<V>.Binding, equals value: V) -> some View {
        _searchFocused(_FocusLink(get: { binding.wrappedValue == value }, set: { on in
            if on { binding.wrappedValue = value }
            else if binding.wrappedValue == value, let none = (V.self as? ExpressibleByNilLiteral.Type)?.init(nilLiteral: ()) as? V { binding.wrappedValue = none }
        }))
    }
    /// Applied around a searchable (it reads the link from the environment) or inside its content (it sets it on the
    /// searchable's config, which mounts the field after the content resolves).
    func _searchFocused(_ link: _FocusLink) -> some View {
        _modify { ctx, c in
            ctx.environment._searchConfig?.focus = link
            return _resolve(c, ctx.child("sfocus").with { $0._searchFocus = link })
        }
    }
    /// A scope bar (segmented) under the search field while searching.
    public func searchScopes<V: Hashable, S: View>(_ scope: Binding<V>, @ViewBuilder scopes: () -> S) -> some View {
        _scopes(AnyView(Picker("Scope", selection: scope) { scopes() }.pickerStyle(.segmented).accessibilityIdentifier("search-scopes")), onText: false)
    }
    public func searchScopes<V: Hashable, S: View>(_ scope: Binding<V>, activation: SearchScopeActivation, @ViewBuilder _ scopes: () -> S) -> some View {
        _scopes(AnyView(Picker("Scope", selection: scope) { scopes() }.pickerStyle(.segmented).accessibilityIdentifier("search-scopes")), onText: activation.id == 1)
    }
    func _scopes(_ picker: AnyView, onText: Bool) -> some View {
        _modify { ctx, c in
            let ex = ctx.environment._searchExtras ?? _SearchExtras()
            ex.scopes = picker; ex.scopeOnText = onText
            return _resolve(c, ctx.child("scopes").with { $0._searchExtras = ex })
        }
    }
}
/// When a scope bar shows: `.onTextEntry` once text is typed, otherwise while searching.
public struct SearchScopeActivation: Sendable {
    let id: Int
    public static let automatic = Self(id: 0), onTextEntry = Self(id: 1), onSearchPresentation = Self(id: 2)
}
/// searchSuggestions / searchScopes for the enclosing (or enclosed) searchable.
@MainActor final class _SearchExtras { var suggestions: AnyView?; var scopes: AnyView?; var scopeOnText = false }
struct _SearchExtrasKey: EnvironmentKey { static var defaultValue: _SearchExtras? { nil } }
struct _SearchCompletionKey: EnvironmentKey { static var defaultValue: _SearchConfig? { nil } }
struct _SearchConfigKey: EnvironmentKey { static var defaultValue: _SearchConfig? { nil } }
struct _SearchFocusKey: EnvironmentKey { static var defaultValue: _FocusLink? { nil } }
extension EnvironmentValues {
    var _searchExtras: _SearchExtras? { get { self[_SearchExtrasKey.self] } set { self[_SearchExtrasKey.self] = newValue } }
    var _searchCompletion: _SearchConfig? { get { self[_SearchCompletionKey.self] } set { self[_SearchCompletionKey.self] = newValue } }
    /// the searchable around (searchFocused inside its content), the searchFocused around (for a searchable inside)
    var _searchConfig: _SearchConfig? { get { self[_SearchConfigKey.self] } set { self[_SearchConfigKey.self] = newValue } }
    var _searchFocus: _FocusLink? { get { self[_SearchFocusKey.self] } set { self[_SearchFocusKey.self] = newValue } }
}

// MARK: - Tokens

/// The tokens of a searchable(text:tokens:…): their labels (from the token views), removal, adding, and the
/// suggested tokens as rows.
@MainActor final class _SearchTokens {
    var labels: [(text: String, image: UIImage?)] = []
    var remove: (Int) -> Void = { _ in }
    var append: ((Any) -> Void)?
    var suggestions: AnyView?
}
extension View {
    func _tokenSearchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        _ text: Binding<String>, _ tokens: Binding<C>, _ suggested: Binding<C>?, _ isPresented: Binding<Bool>?, _ prompt: String,
        _ token: @escaping (Binding<C.Element>) -> T) -> some View {
        _searchable(text, isPresented, prompt) { ctx in
            let t = _SearchTokens()
            func element(_ i: Int) -> Binding<C.Element> {
                Binding(get: { let c = tokens.wrappedValue; return c[c.index(c.startIndex, offsetBy: i)] },
                        set: { v in var c = tokens.wrappedValue; let k = c.index(c.startIndex, offsetBy: i); c.replaceSubrange(k...k, with: [v]); tokens.wrappedValue = c })
            }
            t.labels = (0..<tokens.wrappedValue.count).map { i in
                let n = _resolve(token(element(i)), ctx.child("token\(i)"))
                return (_collectText(n).joined(separator: " "), _firstImage(n))
            }
            t.remove = { i in
                var c = tokens.wrappedValue
                guard i >= 0, i < c.count else { return }
                c.remove(at: c.index(c.startIndex, offsetBy: i))
                tokens.wrappedValue = c
            }
            t.append = { e in if let e = e as? C.Element { tokens.wrappedValue.append(e) } }
            if let s = suggested?.wrappedValue, !s.isEmpty {
                let all = Array(s)
                t.suggestions = AnyView(ForEach(0..<all.count, id: \.self) { i in
                    Button { tokens.wrappedValue.append(all[i]) } label: { token(.constant(all[i])) }
                        .accessibilityIdentifier("search-token-suggestion-\(i)")
                })
            }
            return t
        }
    }

    // tokens
    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, tokens: Binding<C>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil,
        @ViewBuilder token: @escaping (C.Element) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, tokens, nil, nil, prompt?.string ?? "Search") { token($0.wrappedValue) }
    }
    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, tokens: Binding<C>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey,
        @ViewBuilder token: @escaping (C.Element) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, tokens, nil, nil, prompt.resolved()) { token($0.wrappedValue) }
    }
    @_disfavoredOverload public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View, S: StringProtocol>(
        text: Binding<String>, tokens: Binding<C>, placement: SearchFieldPlacement = .automatic, prompt: S,
        @ViewBuilder token: @escaping (C.Element) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, tokens, nil, nil, String(prompt)) { token($0.wrappedValue) }
    }
    // tokens, suggested tokens
    public func searchable<C: MutableCollection & RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, tokens: Binding<C>, suggestedTokens: Binding<C>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil,
        @ViewBuilder token: @escaping (C.Element) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, tokens, suggestedTokens, nil, prompt?.string ?? "Search") { token($0.wrappedValue) }
    }
    public func searchable<C: MutableCollection & RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, tokens: Binding<C>, suggestedTokens: Binding<C>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey,
        @ViewBuilder token: @escaping (C.Element) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, tokens, suggestedTokens, nil, prompt.resolved()) { token($0.wrappedValue) }
    }
    @_disfavoredOverload public func searchable<C: MutableCollection & RandomAccessCollection & RangeReplaceableCollection, T: View, S: StringProtocol>(
        text: Binding<String>, tokens: Binding<C>, suggestedTokens: Binding<C>, placement: SearchFieldPlacement = .automatic, prompt: S,
        @ViewBuilder token: @escaping (C.Element) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, tokens, suggestedTokens, nil, String(prompt)) { token($0.wrappedValue) }
    }
    // tokens, isPresented
    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, tokens: Binding<C>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil,
        @ViewBuilder token: @escaping (C.Element) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, tokens, nil, isPresented, prompt?.string ?? "Search") { token($0.wrappedValue) }
    }
    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, tokens: Binding<C>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey,
        @ViewBuilder token: @escaping (C.Element) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, tokens, nil, isPresented, prompt.resolved()) { token($0.wrappedValue) }
    }
    @_disfavoredOverload public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View, S: StringProtocol>(
        text: Binding<String>, tokens: Binding<C>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic, prompt: S,
        @ViewBuilder token: @escaping (C.Element) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, tokens, nil, isPresented, String(prompt)) { token($0.wrappedValue) }
    }
    // tokens, suggested tokens, isPresented
    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, tokens: Binding<C>, suggestedTokens: Binding<C>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic,
        prompt: Text? = nil, @ViewBuilder token: @escaping (C.Element) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, tokens, suggestedTokens, isPresented, prompt?.string ?? "Search") { token($0.wrappedValue) }
    }
    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, tokens: Binding<C>, suggestedTokens: Binding<C>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic,
        prompt: LocalizedStringKey, @ViewBuilder token: @escaping (C.Element) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, tokens, suggestedTokens, isPresented, prompt.resolved()) { token($0.wrappedValue) }
    }
    @_disfavoredOverload public func searchable<C: MutableCollection & RandomAccessCollection & RangeReplaceableCollection, T: View, S: StringProtocol>(
        text: Binding<String>, tokens: Binding<C>, suggestedTokens: Binding<C>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic,
        prompt: S, @ViewBuilder token: @escaping (C.Element) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, tokens, suggestedTokens, isPresented, String(prompt)) { token($0.wrappedValue) }
    }
    // editable tokens (the token view gets a binding to its token)
    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, editableTokens: Binding<C>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil,
        @ViewBuilder token: @escaping (Binding<C.Element>) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, editableTokens, nil, nil, prompt?.string ?? "Search", token)
    }
    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, editableTokens: Binding<C>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey,
        @ViewBuilder token: @escaping (Binding<C.Element>) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, editableTokens, nil, nil, prompt.resolved(), token)
    }
    @_disfavoredOverload public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, editableTokens: Binding<C>, placement: SearchFieldPlacement = .automatic, prompt: some StringProtocol,
        @ViewBuilder token: @escaping (Binding<C.Element>) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, editableTokens, nil, nil, String(prompt), token)
    }
    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, editableTokens: Binding<C>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil,
        @ViewBuilder token: @escaping (Binding<C.Element>) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, editableTokens, nil, isPresented, prompt?.string ?? "Search", token)
    }
    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, editableTokens: Binding<C>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey,
        @ViewBuilder token: @escaping (Binding<C.Element>) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, editableTokens, nil, isPresented, prompt.resolved(), token)
    }
    @_disfavoredOverload public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, editableTokens: Binding<C>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic, prompt: some StringProtocol,
        @ViewBuilder token: @escaping (Binding<C.Element>) -> T) -> some View where C.Element: Identifiable {
        _tokenSearchable(text, editableTokens, nil, isPresented, String(prompt), token)
    }
}
/// the List a searchable's content shows (through its modifiers)
@MainActor func _innerList(_ n: _Node) -> _ListNode? {
    var x: _Node? = n
    while let c = x { if let l = c as? _ListNode { return l }; x = c.children.count == 1 ? c.children[0] : nil }
    return nil
}
/// a list with at least one row (empty suggestions leave the content)
@MainActor func _collectsRows(_ n: _Node) -> Bool { (n as? _ListNode)?.sections.contains { !$0.rows.isEmpty } ?? true }
extension UIApplication {
    @MainActor var _isim_firstResponder: UIResponder? {
        func find(_ v: UIView) -> UIView? { if v.isFirstResponder { return v }; for s in v.subviews { if let f = find(s) { return f } }; return nil }
        for w in windows { if let f = find(w) { return f } }
        return nil
    }
}

final class _SearchFieldNode: _Node {
    let config: _SearchConfig
    init(path: String, config: _SearchConfig) { self.config = config; super.init(path: path, children: []) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: min(p.width ?? 320, 1e6), height: 36) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUISearchBar(frame: .zero) }
        v.configure(config)
        return v
    }
}

/// The search bar: the search text field (its rounded background, magnifying glass and tokens), Cancel while searching.
final class _SUISearchBar: UIView {
    let field = _SUISearchTextField(frame: .zero)
    let cancel = _SUIControl(frame: .zero)
    let cancelLabel = UILabel()
    var config: _SearchConfig?
    override init(frame: CGRect) {
        super.init(frame: frame)
        field.font = .systemFont(ofSize: 17); field.returnKeyType = .search; field.accessibilityIdentifier = "search-field"
        addSubview(field)
        cancelLabel.text = "Cancel"; cancelLabel.textColor = _accentUIColor(); cancelLabel.font = .systemFont(ofSize: 17)
        cancel.addSubview(cancelLabel); cancel.accessibilityIdentifier = "search-cancel"
        addSubview(cancel)
        field.bar = self
        cancel.action = { [weak self] in self?.end() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func configure(_ c: _SearchConfig) {
        config = c
        c.bar = self
        field.placeholder = c.prompt
        if !field.isFirstResponder, field.text != c.text.wrappedValue { field.text = c.text.wrappedValue }
        let labels = c.tokens?.labels ?? []
        if field.tokenTexts != labels.map(\.text) || field.tokens.count != labels.count {
            field.tokenTexts = labels.map(\.text)
            field.tokens = labels.map { UISearchToken(icon: $0.image, text: $0.text) }
        }
        // searchFocused: the binding moves the keyboard to or from the field
        if let f = c.focus {
            c.graph?.postRender.append { [weak field] in
                guard let field else { return }
                let want = f.get()
                if want && !field.isFirstResponder { _ = field.becomeFirstResponder() }
                else if !want && field.isFirstResponder { _ = field.resignFirstResponder() }
            }
        }
        setNeedsLayout()
    }
    var active: Bool { config?.searching.wrappedValue == true }
    override func layoutSubviews() {
        super.layoutSubviews()
        let cw: CGFloat = active ? ceil(cancelLabel.sizeThatFits(CGSize(width: 200, height: 40)).width) + 12 : 0
        cancel.isHidden = !active
        cancel.frame = CGRect(x: bounds.width - cw, y: 0, width: cw, height: bounds.height)
        cancelLabel.frame = CGRect(x: 12, y: 0, width: cw - 12, height: bounds.height)
        field.frame = CGRect(x: 0, y: 0, width: max(0, bounds.width - cw), height: bounds.height)
    }
    func begin() { if config?.searching.wrappedValue != true { config?.searching.wrappedValue = true } }
    func end() {
        field.text = ""
        config?.text.wrappedValue = ""
        config?.searching.wrappedValue = false
        _ = field.resignFirstResponder()
    }
}
final class _SUISearchTextField: UISearchTextField {
    weak var bar: _SUISearchBar?
    var tokenTexts: [String] = []
    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(changed), for: .editingChanged)
        addTarget(self, action: #selector(began), for: .editingDidBegin)
        addTarget(self, action: #selector(ended), for: .editingDidEnd)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc func changed() {
        // Delete at the start of the text removed the last token
        if let t = bar?.config?.tokens, tokens.count < t.labels.count { t.remove(t.labels.count - 1) }
        if bar?.config?.text.wrappedValue != text ?? "" { bar?.config?.text.wrappedValue = text ?? "" }
    }
    @objc func began() { bar?.begin(); if let f = bar?.config?.focus, !f.get() { f.set(true) } }
    @objc func ended() { if let f = bar?.config?.focus, f.get() { f.set(false) } }
    override func insertText(_ t: String) {
        if t == "\n" { bar?.config?.submit(); _ = resignFirstResponder(); return }
        super.insertText(t)
    }
}

/// `.onSubmit(of: .search)` and `.onSubmit(of: .text)`.
public struct SubmitTriggers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let text = SubmitTriggers(rawValue: 1), search = SubmitTriggers(rawValue: 2)
}
@MainActor func _registerSearchSubmit(_ ctx: _Context, _ triggers: SubmitTriggers, _ action: @escaping () -> Void) {
    guard triggers.contains(.search) else { return }
    let key = ctx.path + "#searchsubmit"
    ctx.graph.storage[key] = _SubmitBox(action)
    ctx.graph.usedKeys.insert(key)
}
