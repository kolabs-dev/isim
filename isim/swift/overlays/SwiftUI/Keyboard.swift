// Hardware keyboard in SwiftUI: .keyboardShortcut on buttons (exposed as UIKeyCommands by the hosting
// controller) and .onKeyPress (hosting controller presses). isim has no SwiftUI focus system for keys:
// onKeyPress handlers anywhere in the hierarchy receive presses, the innermost (most recently resolved) first.
import UIKit

public struct KeyEquivalent: Hashable, Sendable, ExpressibleByExtendedGraphemeClusterLiteral {
    public var character: Character
    public init(_ character: Character) { self.character = character }
    public init(extendedGraphemeClusterLiteral c: Character) { character = c }
    public static let upArrow = KeyEquivalent("\u{F700}"), downArrow = KeyEquivalent("\u{F701}")
    public static let leftArrow = KeyEquivalent("\u{F702}"), rightArrow = KeyEquivalent("\u{F703}")
    public static let escape = KeyEquivalent("\u{1B}"), delete = KeyEquivalent("\u{8}"), deleteForward = KeyEquivalent("\u{F728}")
    public static let home = KeyEquivalent("\u{F729}"), end = KeyEquivalent("\u{F72B}"), pageUp = KeyEquivalent("\u{F72C}"), pageDown = KeyEquivalent("\u{F72D}")
    public static let clear = KeyEquivalent("\u{F739}"), tab = KeyEquivalent("\t"), space = KeyEquivalent(" "), `return` = KeyEquivalent("\r")
    /// the UIKeyCommand input for this key
    var _input: String {
        switch self {
        case .upArrow: return UIKeyCommand.inputUpArrow
        case .downArrow: return UIKeyCommand.inputDownArrow
        case .leftArrow: return UIKeyCommand.inputLeftArrow
        case .rightArrow: return UIKeyCommand.inputRightArrow
        case .escape: return UIKeyCommand.inputEscape
        case .home: return UIKeyCommand.inputHome
        case .end: return UIKeyCommand.inputEnd
        case .pageUp: return UIKeyCommand.inputPageUp
        case .pageDown: return UIKeyCommand.inputPageDown
        case .deleteForward: return UIKeyCommand.inputDelete
        case .delete: return "\u{8}"
        default: return String(character).lowercased()
        }
    }
}

public struct EventModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let capsLock = EventModifiers(rawValue: 1), shift = EventModifiers(rawValue: 2), control = EventModifiers(rawValue: 4)
    public static let option = EventModifiers(rawValue: 8), command = EventModifiers(rawValue: 16), numericPad = EventModifiers(rawValue: 32)
    public static let all: EventModifiers = [.capsLock, .shift, .control, .option, .command, .numericPad]
    var _uikit: UIKeyModifierFlags {
        var f: UIKeyModifierFlags = []
        if contains(.shift) { f.insert(.shift) }; if contains(.control) { f.insert(.control) }
        if contains(.option) { f.insert(.alternate) }; if contains(.command) { f.insert(.command) }
        if contains(.capsLock) { f.insert(.alphaShift) }; if contains(.numericPad) { f.insert(.numericPad) }
        return f
    }
    init(_ f: UIKeyModifierFlags) {
        var m: EventModifiers = []
        if f.contains(.shift) { m.insert(.shift) }; if f.contains(.control) { m.insert(.control) }
        if f.contains(.alternate) { m.insert(.option) }; if f.contains(.command) { m.insert(.command) }
        if f.contains(.alphaShift) { m.insert(.capsLock) }
        self = m
    }
}

public struct KeyboardShortcut: Hashable, Sendable {
    public var key: KeyEquivalent
    public var modifiers: EventModifiers
    public init(_ key: KeyEquivalent, modifiers: EventModifiers = .command) { self.key = key; self.modifiers = modifiers }
    public static let defaultAction = KeyboardShortcut(.return, modifiers: [])
    public static let cancelAction = KeyboardShortcut(.escape, modifiers: [])
}

public struct KeyPress: Sendable {
    public struct Phases: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let down = Phases(rawValue: 1), `repeat` = Phases(rawValue: 2), up = Phases(rawValue: 4)
        public static let all: Phases = [.down, .repeat, .up]
    }
    public enum Result: Sendable { case handled, ignored }
    public let key: KeyEquivalent
    public let characters: String
    public let modifiers: EventModifiers
    public let phase: Phases
}

// ---- registration (graph storage, so handlers of views that left the hierarchy disappear) ----
final class _ShortcutBox: _AnyStorage {
    var shortcut: KeyboardShortcut; var action: () -> Void; var enabled: Bool
    init(_ s: KeyboardShortcut, _ a: @escaping () -> Void, _ e: Bool) { shortcut = s; action = a; enabled = e }
}
final class _KeyPressBox: _AnyStorage {
    var keys: Set<KeyEquivalent>?; var characters: CharacterSet?; var phases: KeyPress.Phases; var order: Int
    var action: (KeyPress) -> KeyPress.Result
    init(keys: Set<KeyEquivalent>?, characters: CharacterSet?, phases: KeyPress.Phases, order: Int, action: @escaping (KeyPress) -> KeyPress.Result) {
        self.keys = keys; self.characters = characters; self.phases = phases; self.order = order; self.action = action
    }
}
private struct _ShortcutEnvKey: EnvironmentKey { static let defaultValue: KeyboardShortcut? = nil }
extension EnvironmentValues {
    var _keyboardShortcut: KeyboardShortcut? { get { self[_ShortcutEnvKey.self] } set { self[_ShortcutEnvKey.self] = newValue } }
}
private var _keyPressOrder = 0

/// called by Button: registers the button's action for the shortcut in its environment
@MainActor func _registerShortcut(_ ctx: _Context, _ action: @escaping () -> Void) {
    guard let s = ctx.environment._keyboardShortcut else { return }
    let key = ctx.path + "#shortcut"
    ctx.graph.usedKeys.insert(key)
    if let b = ctx.graph.storage[key] as? _ShortcutBox { b.shortcut = s; b.action = action; b.enabled = ctx.environment.isEnabled }
    else { ctx.graph.storage[key] = _ShortcutBox(s, action, ctx.environment.isEnabled) }
}

extension View {
    public func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> some View {
        environment(\._keyboardShortcut, KeyboardShortcut(key, modifiers: modifiers))
    }
    public func keyboardShortcut(_ shortcut: KeyboardShortcut?) -> some View { environment(\._keyboardShortcut, shortcut) }

    private func _onKeyPress(keys: Set<KeyEquivalent>?, characters: CharacterSet?, phases: KeyPress.Phases, action: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        _modify { ctx, c in
            let key = ctx.path + "#keypress"
            ctx.graph.usedKeys.insert(key)
            _keyPressOrder += 1
            if let b = ctx.graph.storage[key] as? _KeyPressBox { b.keys = keys; b.characters = characters; b.phases = phases; b.action = action; b.order = _keyPressOrder }
            else { ctx.graph.storage[key] = _KeyPressBox(keys: keys, characters: characters, phases: phases, order: _keyPressOrder, action: action) }
            return _resolve(c, ctx.child("kp"))
        }
    }
    public func onKeyPress(_ key: KeyEquivalent, action: @escaping () -> KeyPress.Result) -> some View {
        _onKeyPress(keys: [key], characters: nil, phases: .down) { _ in action() }
    }
    public func onKeyPress(_ key: KeyEquivalent, phases: KeyPress.Phases, action: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        _onKeyPress(keys: [key], characters: nil, phases: phases, action: action)
    }
    public func onKeyPress(keys: Set<KeyEquivalent>, phases: KeyPress.Phases = [.down, .repeat], action: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        _onKeyPress(keys: keys, characters: nil, phases: phases, action: action)
    }
    public func onKeyPress(characters: CharacterSet, phases: KeyPress.Phases = [.down, .repeat], action: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        _onKeyPress(keys: nil, characters: characters, phases: phases, action: action)
    }
    public func onKeyPress(phases: KeyPress.Phases = [.down, .repeat], action: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        _onKeyPress(keys: nil, characters: nil, phases: phases, action: action)
    }
}

// ---- dispatch from the hosting controllers ----
@MainActor func _suiKeyCommands(_ g: _Graph, target: Selector) -> [UIKeyCommand] {
    g.storage.values.compactMap { $0 as? _ShortcutBox }.filter(\.enabled).map {
        UIKeyCommand(input: $0.shortcut.key._input, modifierFlags: $0.shortcut.modifiers._uikit, action: target)
    }
}
@MainActor func _suiPerformShortcut(_ g: _Graph, _ cmd: UIKeyCommand) {
    let mask: UIKeyModifierFlags = [.shift, .control, .alternate, .command]
    for b in g.storage.values.compactMap({ $0 as? _ShortcutBox }) where b.enabled {
        if b.shortcut.key._input.caseInsensitiveCompare(cmd.input ?? "") == .orderedSame
            && b.shortcut.modifiers._uikit.intersection(mask) == cmd.modifierFlags.intersection(mask) { b.action(); g.invalidate(); return }
    }
}
private func _keyEquivalent(_ k: UIKey) -> KeyEquivalent {
    switch k.charactersIgnoringModifiers {
    case UIKeyCommand.inputUpArrow: return .upArrow
    case UIKeyCommand.inputDownArrow: return .downArrow
    case UIKeyCommand.inputLeftArrow: return .leftArrow
    case UIKeyCommand.inputRightArrow: return .rightArrow
    case UIKeyCommand.inputEscape: return .escape
    case UIKeyCommand.inputHome: return .home
    case UIKeyCommand.inputEnd: return .end
    case UIKeyCommand.inputPageUp: return .pageUp
    case UIKeyCommand.inputPageDown: return .pageDown
    case UIKeyCommand.inputDelete: return .deleteForward
    case "\u{8}": return .delete
    case "\r": return .return
    default: return KeyEquivalent(k.charactersIgnoringModifiers.first ?? " ")
    }
}
/// returns true when a handler took the press
@MainActor func _suiHandlePresses(_ g: _Graph, _ presses: Set<UIPress>, up: Bool) -> Bool {
    let boxes = g.storage.values.compactMap { $0 as? _KeyPressBox }.sorted { $0.order > $1.order }
    var handled = false
    for p in presses {
        guard let k = p.key else { continue }
        let kp = KeyPress(key: _keyEquivalent(k), characters: k.characters, modifiers: EventModifiers(k.modifierFlags), phase: up ? .up : .down)
        for b in boxes where b.phases.contains(kp.phase) {
            if let keys = b.keys, !keys.contains(kp.key) { continue }
            if let cs = b.characters, !(kp.characters.unicodeScalars.first.map { cs.contains($0) } ?? false) { continue }
            if b.action(kp) == .handled { handled = true; break }
        }
    }
    if handled { g.invalidate() }
    return handled
}
