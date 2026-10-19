// isim SwiftUI: scene commands — `.commands { CommandMenu(...) { ... }; CommandGroup(after: .newItem) { ... } }` add
// to the app's main menu (UIMenuSystem: the iPad menu bar and the keyboard shortcuts overlay, the `mainmenu` script
// command), through UIKit's buildMenu(with:) on SwiftUI's application delegate. Buttons become menu actions; one with
// a .keyboardShortcut becomes a key command that works from the hardware keyboard. Pickers, Toggles, Menus and
// Dividers inside work as in context menus.
import UIKit

/// Content of a scene's main menu.
public protocol Commands {
    associatedtype Body: Commands
    @CommandsBuilder @MainActor var body: Body { get }
}
/// One menu or group of the main menu, with its content (resolved when the menu is built).
struct _CommandEntry {
    enum Kind { case menu(String), before(CommandGroupPlacement), after(CommandGroupPlacement), replacing(CommandGroupPlacement) }
    let kind: Kind
    let content: AnyView
}
protocol _PrimitiveCommands { @MainActor var _entries: [_CommandEntry] { get } }
extension Never: Commands {}
@MainActor func _commandEntries(_ c: any Commands) -> [_CommandEntry] {
    if let p = c as? _PrimitiveCommands { return p._entries }
    func body<C: Commands>(_ c: C) -> any Commands { c.body }
    return _commandEntries(body(c))
}

/// A menu of its own in the main menu (before the Window menu, like iPadOS).
public struct CommandMenu<Content: View>: Commands, _PrimitiveCommands {
    let title: String, content: Content
    public init(_ nameKey: LocalizedStringKey, @ViewBuilder content: () -> Content) { title = nameKey.resolved(); self.content = content() }
    public init(_ name: Text, @ViewBuilder content: () -> Content) { title = name.string; self.content = content() }
    @_disfavoredOverload public init<S: StringProtocol>(_ name: S, @ViewBuilder content: () -> Content) { title = String(name); self.content = content() }
    public var body: Never { fatalError() }
    var _entries: [_CommandEntry] { [_CommandEntry(kind: .menu(title), content: AnyView(content))] }
}
/// Items before, after or instead of a standard group of the main menu.
public struct CommandGroup<Content: View>: Commands, _PrimitiveCommands {
    let kind: _CommandEntry.Kind, content: Content
    public init(before group: CommandGroupPlacement, @ViewBuilder addition: () -> Content) { kind = .before(group); content = addition() }
    public init(after group: CommandGroupPlacement, @ViewBuilder addition: () -> Content) { kind = .after(group); content = addition() }
    public init(replacing group: CommandGroupPlacement, @ViewBuilder addition: () -> Content) { kind = .replacing(group); content = addition() }
    public var body: Never { fatalError() }
    var _entries: [_CommandEntry] { [_CommandEntry(kind: kind, content: AnyView(content))] }
}
/// No commands.
public struct EmptyCommands: Commands, _PrimitiveCommands {
    public init() {}
    public var body: Never { fatalError() }
    var _entries: [_CommandEntry] { [] }
}
public struct _TupleCommands<each C: Commands>: Commands, _PrimitiveCommands {
    let items: (repeat each C)
    public var body: Never { fatalError() }
    var _entries: [_CommandEntry] {
        var out: [_CommandEntry] = []
        for c in repeat each items { out += _commandEntries(c) }
        return out
    }
}
extension Optional: Commands where Wrapped: Commands {
    public typealias Body = Never
    public var body: Never { fatalError() }
}
extension Optional: _PrimitiveCommands where Wrapped: Commands {
    var _entries: [_CommandEntry] { map { _commandEntries($0) } ?? [] }
}
/// if / else in a CommandsBuilder (SwiftUI's _ConditionalContent is a View here, so commands have their own).
public struct _ConditionalCommands<TrueContent: Commands, FalseContent: Commands>: Commands, _PrimitiveCommands {
    enum Storage { case trueContent(TrueContent), falseContent(FalseContent) }
    let storage: Storage
    public var body: Never { fatalError() }
    var _entries: [_CommandEntry] {
        switch storage { case .trueContent(let t): return _commandEntries(t); case .falseContent(let f): return _commandEntries(f) }
    }
}
public struct _LimitedCommands: Commands, _PrimitiveCommands {
    let base: any Commands
    public var body: Never { fatalError() }
    var _entries: [_CommandEntry] { _commandEntries(base) }
}

@resultBuilder public struct CommandsBuilder {
    public static func buildExpression<Content: Commands>(_ content: Content) -> Content { content }
    public static func buildBlock() -> EmptyCommands { EmptyCommands() }
    public static func buildBlock<C: Commands>(_ content: C) -> C { content }
    public static func buildBlock<each C: Commands>(_ content: repeat each C) -> _TupleCommands<repeat each C> { _TupleCommands(items: (repeat each content)) }
    public static func buildIf<C: Commands>(_ content: C?) -> C? { content }
    public static func buildEither<T: Commands, F: Commands>(first: T) -> _ConditionalCommands<T, F> { _ConditionalCommands(storage: .trueContent(first)) }
    public static func buildEither<T: Commands, F: Commands>(second: F) -> _ConditionalCommands<T, F> { _ConditionalCommands(storage: .falseContent(second)) }
    public static func buildLimitedAvailability(_ content: any Commands) -> _LimitedCommands { _LimitedCommands(base: content) }
}

/// A standard group of the main menu.
public struct CommandGroupPlacement: Sendable {
    let menu: String
    public static let appInfo = CommandGroupPlacement(menu: "com.apple.menu.about")
    public static let appSettings = CommandGroupPlacement(menu: "com.apple.menu.preferences")
    public static let systemServices = CommandGroupPlacement(menu: "com.apple.menu.services")
    public static let appVisibility = CommandGroupPlacement(menu: "com.apple.menu.hide")
    public static let appTermination = CommandGroupPlacement(menu: "com.apple.menu.quit")
    public static let newItem = CommandGroupPlacement(menu: "com.apple.menu.new-item")
    public static let saveItem = CommandGroupPlacement(menu: "com.apple.menu.close")
    public static let importExport = CommandGroupPlacement(menu: "com.apple.menu.document")
    public static let printItem = CommandGroupPlacement(menu: "com.apple.menu.print")
    public static let undoRedo = CommandGroupPlacement(menu: "com.apple.menu.undo-redo")
    public static let pasteboard = CommandGroupPlacement(menu: "com.apple.menu.standard-edit")
    public static let textEditing = CommandGroupPlacement(menu: "com.apple.menu.find")
    public static let textFormatting = CommandGroupPlacement(menu: "com.apple.menu.format")
    public static let toolbar = CommandGroupPlacement(menu: "com.apple.menu.toolbar")
    public static let sidebar = CommandGroupPlacement(menu: "com.apple.menu.sidebar")
    public static let windowSize = CommandGroupPlacement(menu: "com.apple.menu.fullscreen")
    public static let windowArrangement = CommandGroupPlacement(menu: "com.apple.menu.bring-all-to-front")
    public static let help = CommandGroupPlacement(menu: "com.apple.menu.help")
}

extension Scene {
    /// Adds menus and groups to the app's main menu.
    public func commands<Content: Commands>(@CommandsBuilder content: () -> Content) -> some Scene {
        let entries = _commandEntries(content())
        return _ModifiedScene(base: self, transform: { $0 }, apply: { c in c.commands += entries })
    }
}

// MARK: - The main menu

/// The commands of the app's scenes, built into the main menu by SwiftUI's application delegate.
@MainActor final class _SUICommands {
    static var entries: [_CommandEntry] = []
    /// the actions of the key commands in the menu (UIKeyCommand.propertyList is the index)
    static var actions: [() -> Void] = []
    static var graph: _Graph?
    /// The elements of a command's content: actions, with key commands for buttons with keyboard shortcuts.
    static func elements(_ content: AnyView) -> [UIMenuElement] {
        let g = graph ?? _Graph(root: { EmptyView() })
        graph = g
        let ctx = _Context(graph: g, path: "commands\(actions.count)", environment: EnvironmentValues(), nav: nil)
        let node = _resolve(content, ctx.with { $0._inList = false })
        return _menuElements(node, shortcuts: g)
    }
    static func build(_ b: UIMenuBuilder) {
        actions = []
        for e in entries {
            let items = elements(e.content)
            switch e.kind {
            case .menu(let title):
                let m = UIMenu(title: title, identifier: UIMenu.Identifier("isim.swiftui.commands.\(title)"), children: items)
                if b.menu(for: .window) != nil { b.insertSibling(m, beforeMenu: .window) } else { b.insertSibling(m, afterMenu: .view) }
            case .before(let p):
                let id = UIMenu.Identifier(p.menu)
                if b.menu(for: id) != nil { b.insertSibling(UIMenu(title: "", options: .displayInline, children: items), beforeMenu: id) }
            case .after(let p):
                let id = UIMenu.Identifier(p.menu)
                if b.menu(for: id) != nil { b.insertSibling(UIMenu(title: "", options: .displayInline, children: items), afterMenu: id) }
            case .replacing(let p):
                let id = UIMenu.Identifier(p.menu)
                if b.menu(for: id) != nil { b.replaceChildren(ofMenu: id) { _ in items } }
            }
        }
    }
}
extension _SUIAppDelegate {
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        _SUICommands.build(builder)
    }
    @objc func _isimSwiftUICommand(_ c: UIKeyCommand) {
        if let i = c.propertyList as? Int, i < _SUICommands.actions.count { _SUICommands.actions[i]() }
    }
}
