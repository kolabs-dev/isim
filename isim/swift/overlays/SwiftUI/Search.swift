// isim SwiftUI: `.searchable` — a search field under the navigation title of a List (or above other content), with a
// Cancel button while searching; `\.isSearching`, `\.dismissSearch`, `.onSubmit(of: .search)`, `isPresented:` binding.
// While searching, `searchSuggestions` replace the content with a list of suggestions (rows with `searchCompletion`
// fill the field) and `searchScopes` show a segmented scope bar under the field.
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
    func _searchable(_ text: Binding<String>, _ isPresented: Binding<Bool>?, _ prompt: String) -> some View {
        _modify { ctx, c in
            let g = ctx.graph, key = ctx.path + "#searching"
            let st = (g.storage[key] as? _StateStorage<Bool>) ?? { let s = _StateStorage(false); g.storage[key] = s; return s }()
            g.usedKeys.insert(key)
            let searching = isPresented ?? Binding(get: { st.value }, set: { [weak g] v in if st.value != v { st.value = v; g?.invalidate() } })
            let cfg = _SearchConfig(text: text, prompt: prompt, path: ctx.path, searching: searching, graph: g)
            let wasList = ctx.nav?.contentIsList ?? false
            ctx.nav?.contentIsList = false
            let extras = ctx.environment._searchExtras ?? _SearchExtras()
            let inner = ctx.child("search").with {
                $0.isSearching = searching.wrappedValue
                $0.dismissSearch = DismissSearchAction { text.wrappedValue = ""; searching.wrappedValue = false; UIApplication.shared._isim_firstResponder?.resignFirstResponder() }
                $0._searchExtras = extras
            }
            var node = _resolve(c, inner)
            // searchScopes: a segmented scope bar under the field while searching (or once text is entered)
            if let picker = extras.scopes, searching.wrappedValue || (extras.scopeOnText && !text.wrappedValue.isEmpty) {
                cfg.scopeNode = _resolve(picker, inner.child("scopes"))
            }
            // searchSuggestions: while searching, a list of suggestions instead of the content
            if let sug = extras.suggestions, searching.wrappedValue {
                // the suggestions list takes the content list's place (same views: the field keeps the keyboard)
                var env = inner.environment; env._searchCompletion = cfg
                let at = _innerList(node)?.path ?? inner.path + "/suggestions"
                let list = _makeList(sug, _Context(graph: g, path: at, environment: env, nav: ctx.nav))
                if _collectsRows(list) { node = list }
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
extension EnvironmentValues {
    var _searchExtras: _SearchExtras? { get { self[_SearchExtrasKey.self] } set { self[_SearchExtrasKey.self] = newValue } }
    var _searchCompletion: _SearchConfig? { get { self[_SearchCompletionKey.self] } set { self[_SearchCompletionKey.self] = newValue } }
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

/// The search bar: magnifying glass, text field, Cancel while searching.
final class _SUISearchBar: UIView {
    let field = _SUISearchTextField(frame: .zero)
    let back = UIView()
    let glass = UIImageView()
    let cancel = _SUIControl(frame: .zero)
    let cancelLabel = UILabel()
    var config: _SearchConfig?
    override init(frame: CGRect) {
        super.init(frame: frame)
        back.backgroundColor = .tertiarySystemFill; back.layer.cornerRadius = 10
        addSubview(back)
        glass.image = UIImage(systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15)); glass.tintColor = .secondaryLabel
        back.addSubview(glass)
        field.font = .systemFont(ofSize: 17); field.returnKeyType = .search; field.accessibilityIdentifier = "search-field"
        back.addSubview(field)
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
        setNeedsLayout()
    }
    var active: Bool { config?.searching.wrappedValue == true }
    override func layoutSubviews() {
        super.layoutSubviews()
        let cw: CGFloat = active ? ceil(cancelLabel.sizeThatFits(CGSize(width: 200, height: 40)).width) + 12 : 0
        back.frame = CGRect(x: 0, y: 0, width: bounds.width - cw, height: bounds.height)
        cancel.isHidden = !active
        cancel.frame = CGRect(x: bounds.width - cw, y: 0, width: cw, height: bounds.height)
        cancelLabel.frame = CGRect(x: 12, y: 0, width: cw - 12, height: bounds.height)
        let gs = glass.image?.size ?? CGSize(width: 16, height: 16)
        glass.frame = CGRect(x: 8, y: (bounds.height - gs.height) / 2, width: gs.width, height: gs.height)
        field.frame = CGRect(x: 8 + gs.width + 6, y: 0, width: max(0, back.bounds.width - gs.width - 22), height: bounds.height)
    }
    func begin() { if config?.searching.wrappedValue != true { config?.searching.wrappedValue = true } }
    func end() {
        field.text = ""
        config?.text.wrappedValue = ""
        config?.searching.wrappedValue = false
        _ = field.resignFirstResponder()
    }
}
final class _SUISearchTextField: UITextField {
    weak var bar: _SUISearchBar?
    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(changed), for: .editingChanged)
        addTarget(self, action: #selector(began), for: .editingDidBegin)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc func changed() { bar?.config?.text.wrappedValue = text ?? "" }
    @objc func began() { bar?.begin() }
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
