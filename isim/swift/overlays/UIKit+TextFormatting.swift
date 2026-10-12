// The text formatting panel (iOS 18), Swift refinements: the delegate protocol with ChangeValue, the formatting
// descriptor and styles as value types, TextAlignment.nsTextAlignment. See UITextFormattingViewController.m.
import ObjectiveC
import Foundation

@available(iOS 18.0, *)
extension UITextFormattingViewController.TextAlignment {
    public var nsTextAlignment: NSTextAlignment {
        switch rawValue {
        case "left": return .left
        case "center": return .center
        case "right": return .right
        case "justified": return .justified
        default: return .natural
        }
    }
}

@available(iOS 18.0, *)
extension UITextFormattingViewController {
    /// a named set of attributes applied to whole paragraphs (Title, Heading, Body ...)
    public struct FormattingStyle: Hashable, @unchecked Sendable {
        public var styleKey: String
        public var title: String
        public var attributes: [NSAttributedString.Key: Any]
        public init(styleKey: String, title: String, attributes: [NSAttributedString.Key: Any]) {
            self.styleKey = styleKey; self.title = title; self.attributes = attributes
        }
        public static func == (a: Self, b: Self) -> Bool { a.styleKey == b.styleKey && a.title == b.title && NSDictionary(dictionary: a.attributes).isEqual(to: b.attributes) }
        public func hash(into h: inout Hasher) { h.combine(styleKey); h.combine(title) }
        init(_ o: __UITextFormattingViewControllerFormattingStyle) { self.init(styleKey: o.styleKey, title: o.title, attributes: o.attributes) }
        var objc: __UITextFormattingViewControllerFormattingStyle { __UITextFormattingViewControllerFormattingStyle(styleKey: styleKey, title: title, attributes: attributes) }
    }

    /// the formatting of the selection the panel shows
    public struct FormattingDescriptor: Hashable, @unchecked Sendable {
        public var fonts: [UIFont] = []
        public var textColors: [UIColor] = []
        public var textAlignments: Set<TextAlignment> = []
        public var textLists: Set<TextList> = []
        public var highlights: Set<Highlight> = []
        public var underlinePresent = false
        public var strikethroughPresent = false
        public var lineHeight: CGFloat = 0
        public var formattingStyleKey: String?
        public init() {}
        public init(attributes: [NSAttributedString.Key: Any]) { self.init(__UITextFormattingViewControllerFormattingDescriptor(attributes: attributes)) }
        public init(string: NSAttributedString, range: NSRange) { self.init(__UITextFormattingViewControllerFormattingDescriptor(string: string, range: range)) }
        init(_ o: __UITextFormattingViewControllerFormattingDescriptor) {
            fonts = o.fonts; textColors = o.textColors; textAlignments = o.textAlignments; textLists = o.textLists; highlights = o.highlights
            underlinePresent = o.underlinePresent; strikethroughPresent = o.strikethroughPresent; lineHeight = o.lineHeight; formattingStyleKey = o.formattingStyleKey
        }
        var objc: __UITextFormattingViewControllerFormattingDescriptor {
            let o = __UITextFormattingViewControllerFormattingDescriptor()
            o.fonts = fonts; o.textColors = textColors; o.textAlignments = textAlignments; o.textLists = textLists; o.highlights = highlights
            o.underlinePresent = underlinePresent; o.strikethroughPresent = strikethroughPresent; o.lineHeight = lineHeight; o.formattingStyleKey = formattingStyleKey
            return o
        }
    }

    /// a change the person made in the panel
    public enum ChangeValue: @unchecked Sendable {
        case font(UIFont)
        case textColor(UIColor)
        case highlight(Highlight?)
        case underline(Bool)
        case strikethrough(Bool)
        case textAlignment(TextAlignment)
        case textList(TextList?)
        case lineHeightPointSize(Double)
        case formattingStyle(String)
        case increaseFontSize
        case decreaseFontSize
        case increaseIndentation
        case decreaseIndentation
        init?(_ o: __UITextFormattingViewControllerChangeValue) {
            let v = o.value
            switch o.changeType.rawValue {
            case "font": guard let f = v as? UIFont else { return nil }; self = .font(f)
            case "textColor": guard let c = v as? UIColor else { return nil }; self = .textColor(c)
            case "highlight": self = .highlight((v as? String).map { Highlight(rawValue: $0) })
            case "underline": self = .underline((v as? NSNumber)?.boolValue ?? false)
            case "strikethrough": self = .strikethrough((v as? NSNumber)?.boolValue ?? false)
            case "textAlignment": self = .textAlignment(TextAlignment(rawValue: v as? String ?? "natural"))
            case "textList": self = .textList((v as? String).map { TextList(rawValue: $0) })
            case "lineHeightPointSize": self = .lineHeightPointSize((v as? NSNumber)?.doubleValue ?? 0)
            case "formattingStyle": self = .formattingStyle(v as? String ?? "")
            case "increaseFontSize": self = .increaseFontSize
            case "decreaseFontSize": self = .decreaseFontSize
            case "increaseIndentation": self = .increaseIndentation
            case "decreaseIndentation": self = .decreaseIndentation
            default: return nil
            }
        }
    }

    @MainActor public protocol Delegate: AnyObject {
        func textFormattingViewController(_ viewController: UITextFormattingViewController, didChangeValue changeValue: ChangeValue)
        func textFormattingViewController(_ viewController: UITextFormattingViewController, shouldPresentFontPicker fontPicker: UIFontPickerViewController) -> Bool
        func textFormattingViewController(_ viewController: UITextFormattingViewController, shouldPresentColorPicker colorPicker: UIColorPickerViewController) -> Bool
        func textFormattingDidFinish(_ viewController: UITextFormattingViewController)
    }

    public var formattingDescriptor: FormattingDescriptor? {
        get { __formattingDescriptor.map(FormattingDescriptor.init) }
        set { __formattingDescriptor = newValue?.objc }
    }
    public weak var delegate: (any Delegate)? {
        get { (objc_getAssociatedObject(self, &_isimFormattingAdapterKey) as? _IsimTextFormattingAdapter)?.target }
        set {
            let adapter = newValue.map { _IsimTextFormattingAdapter($0) }
            objc_setAssociatedObject(self, &_isimFormattingAdapterKey, adapter, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
            __delegate = adapter
        }
    }
}
@available(iOS 18.0, *)
extension UITextFormattingViewController.Delegate {
    public func textFormattingViewController(_ viewController: UITextFormattingViewController, didChangeValue changeValue: UITextFormattingViewController.ChangeValue) {}
    public func textFormattingViewController(_ viewController: UITextFormattingViewController, shouldPresentFontPicker fontPicker: UIFontPickerViewController) -> Bool { true }
    public func textFormattingViewController(_ viewController: UITextFormattingViewController, shouldPresentColorPicker colorPicker: UIColorPickerViewController) -> Bool { true }
    public func textFormattingDidFinish(_ viewController: UITextFormattingViewController) {}
}

nonisolated(unsafe) private var _isimFormattingAdapterKey: UInt8 = 0
/// forwards the Objective-C delegate calls to the Swift delegate
@available(iOS 18.0, *)
final class _IsimTextFormattingAdapter: NSObject, __UITextFormattingViewControllerDelegate {
    weak var target: (any UITextFormattingViewController.Delegate)?
    init(_ d: any UITextFormattingViewController.Delegate) { target = d }
    func textFormattingViewController(_ viewController: UITextFormattingViewController, didChangeValue changeValue: __UITextFormattingViewControllerChangeValue) {
        if let v = UITextFormattingViewController.ChangeValue(changeValue) { target?.textFormattingViewController(viewController, didChangeValue: v) }
    }
    func textFormattingViewController(_ viewController: UITextFormattingViewController, shouldPresentFontPicker fontPicker: UIFontPickerViewController) -> Bool {
        target?.textFormattingViewController(viewController, shouldPresentFontPicker: fontPicker) ?? true
    }
    func textFormattingViewController(_ viewController: UITextFormattingViewController, shouldPresentColorPicker colorPicker: UIColorPickerViewController) -> Bool {
        target?.textFormattingViewController(viewController, shouldPresentColorPicker: colorPicker) ?? true
    }
    func textFormattingDidFinish(_ viewController: UITextFormattingViewController) { target?.textFormattingDidFinish(viewController) }
}

@available(iOS 18.0, *)
extension UITextFormattingViewController.Configuration {
    public var formattingStyles: [UITextFormattingViewController.FormattingStyle]? {
        get { __formattingStyles?.map(UITextFormattingViewController.FormattingStyle.init) }
        set { __formattingStyles = newValue?.map(\.objc) }
    }
}

// MARK: - NSTextAlignment -> Core Text's alignment (NSTextAlignment.init(_:) comes from the header)
extension CTTextAlignment {
    public init(_ nsTextAlignment: NSTextAlignment) { self = NSTextAlignmentToCTTextAlignment(nsTextAlignment) }
}
