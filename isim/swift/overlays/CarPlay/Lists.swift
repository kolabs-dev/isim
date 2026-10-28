// isim CarPlay: the list, grid and tab bar templates and their items.
import Foundation
import UIKit

@objc(CPListTemplateItem)
public protocol CPListTemplateItem: NSObjectProtocol {
    @objc var text: String? { get }
    @objc var userInfo: Any? { get set }
    @objc var isEnabled: Bool { @objc(isEnabled) get @objc(setEnabled:) set }
}

@objc(CPSelectableListItem)
public protocol CPSelectableListItem: CPListTemplateItem {
    @objc var handler: ((any CPSelectableListItem, @escaping () -> Void) -> Void)? { get set }
}

@objc(CPPlayableItem)
public protocol CPPlayableItem: NSObjectProtocol {
    @objc var playbackConfiguration: CPPlaybackConfiguration? { get set }
}

/// a list item's state while CarPlay waits for its handler to call completion (a spinner on the row)
var _cpWaiting = Set<ObjectIdentifier>()

@objc(CPListItem)
open class CPListItem: NSObject, CPSelectableListItem, CPPlayableItem {
    @objc(CPAssistantCellPosition) public enum AssistantCellPosition: Int, @unchecked Sendable { case top = 0, bottom }
    @objc(CPAssistantCellVisibility) public enum AssistantCellVisibility: Int, @unchecked Sendable { case off = 0, whileLimitedUIActive, always }

    var _text: String?, _detail: String?, _image: UIImage?, _accessoryImage: UIImage?
    @objc open var text: String? { _text }
    @objc open var detailText: String? { _detail }
    @objc open var image: UIImage? { _image }
    @objc open var accessoryImage: UIImage? { _accessoryImage }
    @objc open var accessoryType: CPListItemAccessoryType = .none { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var userInfo: Any?
    var _isEnabled: Bool = true
    @objc open var isEnabled: Bool {
        @objc(isEnabled) get { _isEnabled }
        @objc(setEnabled:) set { _isEnabled = newValue; _CPCar.shared.setNeedsRender() }
    }
    @objc open var handler: ((any CPSelectableListItem, @escaping () -> Void) -> Void)?
    var _isExplicitContent: Bool = false
    @objc open var isExplicitContent: Bool {
        @objc(isExplicitContent) get { _isExplicitContent }
        @objc(setExplicitContent:) set { _isExplicitContent = newValue; _CPCar.shared.setNeedsRender() }
    }
    var _isPlaying: Bool = false
    @objc open var isPlaying: Bool {
        @objc(isPlaying) get { _isPlaying }
        @objc(setPlaying:) set { _isPlaying = newValue; _CPCar.shared.setNeedsRender() }
    }
    @objc open var playingIndicatorLocation: CPListItemPlayingIndicatorLocation = .trailing { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var playbackProgress: CGFloat = 0 { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var playbackConfiguration: CPPlaybackConfiguration? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var showsDisclosureIndicator: Bool {
        get { accessoryType == .disclosureIndicator }
        set { accessoryType = newValue ? .disclosureIndicator : .none }
    }
    @objc open var showsExplicitLabel: Bool { get { isExplicitContent } set { isExplicitContent = newValue } }
    @objc open class var maximumImageSize: CGSize { CGSize(width: 44, height: 44) }

    @objc public init(text: String?, detailText: String?, image: UIImage?, accessoryImage: UIImage?, accessoryType: CPListItemAccessoryType) {
        _text = text; _detail = detailText; _image = image; _accessoryImage = accessoryImage; self.accessoryType = accessoryType
        super.init()
    }
    @objc public convenience init(text: String?, detailText: String?, image: UIImage?) {
        self.init(text: text, detailText: detailText, image: image, accessoryImage: nil, accessoryType: .none)
    }
    @objc public convenience init(text: String?, detailText: String?) { self.init(text: text, detailText: detailText, image: nil) }
    @objc public convenience init(text: String?, detailText: String?, image: UIImage?, showsDisclosureIndicator: Bool) {
        self.init(text: text, detailText: detailText, image: image, accessoryImage: nil, accessoryType: showsDisclosureIndicator ? .disclosureIndicator : .none)
    }
    @objc open func setText(_ text: String) { _text = text; _CPCar.shared.setNeedsRender() }
    @objc open func setDetailText(_ detailText: String?) { _detail = detailText; _CPCar.shared.setNeedsRender() }
    @objc open func setImage(_ image: UIImage?) { _image = image; _CPCar.shared.setNeedsRender() }
    @objc open func setAccessoryImage(_ accessoryImage: UIImage?) { _accessoryImage = accessoryImage; _CPCar.shared.setNeedsRender() }
}

// MARK: - image rows

@objc(CPListImageRowItemElement)
open class CPListImageRowItemElement: NSObject {
    @objc open var image: UIImage { didSet { _CPCar.shared.setNeedsRender() } }
    var _isEnabled: Bool = true
    @objc open var isEnabled: Bool {
        @objc(isEnabled) get { _isEnabled }
        @objc(setEnabled:) set { _isEnabled = newValue; _CPCar.shared.setNeedsRender() }
    }
    @objc open override var accessibilityLabel: String? { get { _label } set { _label = newValue } }
    var _label: String?
    @objc open class var maximumImageSize: CGSize { CGSize(width: 64, height: 64) }
    init(_image: UIImage) { image = _image; super.init() }
    var _title: String? { nil }
}

@objc(CPListImageRowItemGridElement)
open class CPListImageRowItemGridElement: CPListImageRowItemElement {
    @objc public init(image: UIImage) { super.init(_image: image) }
}

@objc(CPListImageRowItemRowElement)
open class CPListImageRowItemRowElement: CPListImageRowItemElement {
    @objc open var title: String?
    @objc open var subtitle: String?
    @objc public init(image: UIImage, title: String?, subtitle: String?) { self.title = title; self.subtitle = subtitle; super.init(_image: image) }
    override var _title: String? { title }
}

@objc(CPListImageRowItemCardElement)
open class CPListImageRowItemCardElement: CPListImageRowItemElement, NSSecureCoding {
    @objc open var title: String
    @objc open var subtitle: String?
    @objc open var tintColor: UIColor?
    @objc open private(set) var thumbnail: CPThumbnailImage?
    @objc open private(set) var showsImageFullHeight: Bool = false
    @objc open class var maximumFullHeightImageSize: CGSize { CGSize(width: 180, height: 120) }
    @objc open override class var maximumImageSize: CGSize { CGSize(width: 120, height: 80) }
    @objc public init(image: UIImage, showsImageFullHeight: Bool, title: String?, subtitle: String?, tintColor: UIColor?) {
        self.title = title ?? ""; self.subtitle = subtitle; self.tintColor = tintColor; self.showsImageFullHeight = showsImageFullHeight
        super.init(_image: image)
    }
    @objc public init(thumbnail: CPThumbnailImage, title: String?, subtitle: String?, tintColor: UIColor?) {
        self.title = title ?? ""; self.subtitle = subtitle; self.tintColor = tintColor; self.thumbnail = thumbnail
        super.init(_image: thumbnail.image)
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(title, forKey: "title"); c.encode(subtitle, forKey: "subtitle"); c.encode(image, forKey: "image") }
    public required init?(coder c: NSCoder) {
        title = (c.decodeObject(of: NSString.self, forKey: "title") as String?) ?? ""
        subtitle = c.decodeObject(of: NSString.self, forKey: "subtitle") as String?
        super.init(_image: c.decodeObject(of: UIImage.self, forKey: "image") ?? UIImage())
    }
    override var _title: String? { title }
}

@objc(CPListImageRowItemCondensedElement)
open class CPListImageRowItemCondensedElement: CPListImageRowItemElement {
    @objc(CPListImageRowItemCondensedElementShape) public enum Shape: Int, @unchecked Sendable { case roundedRectangle = 0, circular }
    @objc open var title: String
    @objc open var subtitle: String?
    @objc open var accessorySymbolName: String?
    @objc open private(set) var imageShape: CPListImageRowItemCondensedElement.Shape
    @objc public init(image: UIImage, imageShape: CPListImageRowItemCondensedElement.Shape, title: String, subtitle: String?, accessorySymbolName: String?) {
        self.title = title; self.subtitle = subtitle; self.accessorySymbolName = accessorySymbolName; self.imageShape = imageShape
        super.init(_image: image)
    }
    override var _title: String? { title }
}

@objc(CPListImageRowItemImageGridElement)
open class CPListImageRowItemImageGridElement: CPListImageRowItemElement {
    @objc(CPListImageRowItemImageGridElementShape) public enum Shape: Int, @unchecked Sendable { case roundedRectangle = 0, circular }
    @objc open var title: String
    @objc open var accessorySymbolName: String?
    @objc open private(set) var imageShape: CPListImageRowItemImageGridElement.Shape
    @objc public init(image: UIImage, imageShape: CPListImageRowItemImageGridElement.Shape, title: String, accessorySymbolName: String?) {
        self.title = title; self.accessorySymbolName = accessorySymbolName; self.imageShape = imageShape
        super.init(_image: image)
    }
    override var _title: String? { title }
}

@objc(CPListImageRowItem)
open class CPListImageRowItem: NSObject, CPSelectableListItem {
    var _text: String?
    @objc open var text: String? { _text }
    @objc open private(set) var gridImages: [UIImage] = []
    @objc open var imageTitles: [String] = [] { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var elements: [CPListImageRowItemElement] = [] { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open private(set) var allowsMultipleLines: Bool = false
    @objc open var userInfo: Any?
    var _isEnabled: Bool = true
    @objc open var isEnabled: Bool {
        @objc(isEnabled) get { _isEnabled }
        @objc(setEnabled:) set { _isEnabled = newValue; _CPCar.shared.setNeedsRender() }
    }
    @objc open var handler: ((any CPSelectableListItem, @escaping () -> Void) -> Void)?
    @objc open var listImageRowHandler: ((CPListImageRowItem, Int, @escaping () -> Void) -> Void)?
    @objc open class var maximumImageSize: CGSize { CGSize(width: 64, height: 64) }

    @objc public init(text: String, images: [UIImage]) { _text = text; gridImages = Array(images.prefix(_cpMaxGridImages)); super.init() }
    @objc public init(text: String, images: [UIImage], imageTitles: [String]) {
        _text = text; gridImages = Array(images.prefix(_cpMaxGridImages)); self.imageTitles = imageTitles
        super.init()
    }
    init(_text: String?, elements: [CPListImageRowItemElement], multiline: Bool) {
        self._text = _text; self.elements = elements; allowsMultipleLines = multiline; gridImages = elements.map(\.image)
        super.init()
    }
    @objc public convenience init(text: String?, cardElements: [CPListImageRowItemCardElement], allowsMultipleLines: Bool) {
        self.init(_text: text, elements: cardElements, multiline: allowsMultipleLines)
    }
    @objc public convenience init(text: String?, condensedElements: [CPListImageRowItemCondensedElement], allowsMultipleLines: Bool) {
        self.init(_text: text, elements: condensedElements, multiline: allowsMultipleLines)
    }
    @objc public convenience init(text: String?, elements: [CPListImageRowItemRowElement], allowsMultipleLines: Bool) {
        self.init(_text: text, elements: elements, multiline: allowsMultipleLines)
    }
    @objc public convenience init(text: String?, gridElements: [CPListImageRowItemGridElement], allowsMultipleLines: Bool) {
        self.init(_text: text, elements: gridElements, multiline: allowsMultipleLines)
    }
    @objc public convenience init(text: String?, imageGridElements: [CPListImageRowItemImageGridElement], allowsMultipleLines: Bool) {
        self.init(_text: text, elements: imageGridElements, multiline: allowsMultipleLines)
    }
    @objc(updateImages:) open func update(_ gridImages: [UIImage]) {
        self.gridImages = Array(gridImages.prefix(_cpMaxGridImages)); _CPCar.shared.setNeedsRender()
    }
    /// the images it draws: its elements', else the grid images (with their titles)
    var _cells: [(UIImage, String?)] {
        elements.isEmpty ? gridImages.enumerated().map { ($0.element, $0.offset < imageTitles.count ? imageTitles[$0.offset] : nil) }
            : elements.map { ($0.image, $0._title) }
    }
}

// MARK: - messages

@objc(CPMessageListItemLeadingConfiguration)
open class CPMessageListItemLeadingConfiguration: NSObject {
    @objc open private(set) var leadingItem: CPMessageLeadingItem
    @objc open private(set) var leadingImage: UIImage?
    @objc open private(set) var isUnread: Bool
    @objc public init(leadingItem: CPMessageLeadingItem, leadingImage: UIImage?, unread: Bool) {
        self.leadingItem = leadingItem; self.leadingImage = leadingImage; isUnread = unread
        super.init()
    }
}

@objc(CPMessageListItemTrailingConfiguration)
open class CPMessageListItemTrailingConfiguration: NSObject {
    @objc open private(set) var trailingItem: CPMessageTrailingItem
    @objc open private(set) var trailingImage: UIImage?
    @objc public init(trailingItem: CPMessageTrailingItem, trailingImage: UIImage?) {
        self.trailingItem = trailingItem; self.trailingImage = trailingImage
        super.init()
    }
}

/// a conversation in a communication app's list: selecting it starts Siri's message flow for the conversation
@objc(CPMessageListItem)
open class CPMessageListItem: NSObject, CPListTemplateItem {
    @objc open var conversationIdentifier: String?
    @objc open var phoneOrEmailAddress: String?
    var _text: String?
    @objc open var text: String? { get { _text } set { _text = newValue; _CPCar.shared.setNeedsRender() } }
    @objc open var detailText: String? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var trailingText: String? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var leadingConfiguration: CPMessageListItemLeadingConfiguration { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var trailingConfiguration: CPMessageListItemTrailingConfiguration? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var leadingDetailTextImage: UIImage? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var userInfo: Any?
    var _isEnabled: Bool = true
    @objc open var isEnabled: Bool {
        @objc(isEnabled) get { _isEnabled }
        @objc(setEnabled:) set { _isEnabled = newValue; _CPCar.shared.setNeedsRender() }
    }
    @objc public init(conversationIdentifier: String, text: String, leadingConfiguration: CPMessageListItemLeadingConfiguration,
                      trailingConfiguration: CPMessageListItemTrailingConfiguration?, detailText: String?, trailingText: String?) {
        self.conversationIdentifier = conversationIdentifier; _text = text; self.leadingConfiguration = leadingConfiguration
        self.trailingConfiguration = trailingConfiguration; self.detailText = detailText; self.trailingText = trailingText
        super.init()
    }
    @objc public init(fullName: String, phoneOrEmailAddress: String, leadingConfiguration: CPMessageListItemLeadingConfiguration,
                      trailingConfiguration: CPMessageListItemTrailingConfiguration?, detailText: String?, trailingText: String?) {
        _text = fullName; self.phoneOrEmailAddress = phoneOrEmailAddress; self.leadingConfiguration = leadingConfiguration
        self.trailingConfiguration = trailingConfiguration; self.detailText = detailText; self.trailingText = trailingText
        super.init()
    }
}

// MARK: - sections and the list template

@objc(CPListSection)
open class CPListSection: NSObject, NSSecureCoding {
    @objc open private(set) var header: String?
    @objc open var headerSubtitle: String? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var headerImage: UIImage? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var headerButton: CPButton? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open private(set) var sectionIndexTitle: String?
    @objc open private(set) var items: [any CPListTemplateItem]

    @objc public init(items: [any CPListTemplateItem], header: String, headerSubtitle: String?, headerImage: UIImage?,
                      headerButton: CPButton?, sectionIndexTitle: String?) {
        self.items = items; self.header = header; self.headerSubtitle = headerSubtitle; self.headerImage = headerImage
        self.headerButton = headerButton; self.sectionIndexTitle = sectionIndexTitle
        super.init()
    }
    @objc public init(items: [any CPListTemplateItem], header: String?, sectionIndexTitle: String?) {
        self.items = items; self.header = header; self.sectionIndexTitle = sectionIndexTitle
        super.init()
    }
    @objc public convenience init(items: [any CPListTemplateItem]) { self.init(items: items, header: nil, sectionIndexTitle: nil) }
    // the iOS 12 initializers, for CPListItem arrays
    @nonobjc public convenience init(items: [CPListItem]) { self.init(items: items as [any CPListTemplateItem]) }
    @nonobjc public convenience init(items: [CPListItem], header: String?, sectionIndexTitle: String?) {
        self.init(items: items as [any CPListTemplateItem], header: header, sectionIndexTitle: sectionIndexTitle)
    }
    @objc(indexOfItem:) open func index(of item: any CPListTemplateItem) -> Int { items.firstIndex { $0 === item } ?? NSNotFound }
    @objc(itemAtIndex:) open func item(at index: Int) -> any CPListTemplateItem { items[index] }

    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(header, forKey: "header"); c.encode(sectionIndexTitle, forKey: "index") }
    public required init?(coder c: NSCoder) {
        header = c.decodeObject(of: NSString.self, forKey: "header") as String?
        sectionIndexTitle = c.decodeObject(of: NSString.self, forKey: "index") as String?
        items = []
        super.init()
    }
}

@objc(CPAssistantCellConfiguration)
open class CPAssistantCellConfiguration: NSObject, NSSecureCoding {
    @objc open private(set) var position: CPListItem.AssistantCellPosition
    @objc open private(set) var visibility: CPListItem.AssistantCellVisibility
    @objc open private(set) var assistantAction: CPAssistantCellActionType
    @objc public init(position: CPListItem.AssistantCellPosition, visibility: CPListItem.AssistantCellVisibility, assistantAction: CPAssistantCellActionType) {
        self.position = position; self.visibility = visibility; self.assistantAction = assistantAction
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) {
        c.encode(position.rawValue, forKey: "position"); c.encode(visibility.rawValue, forKey: "visibility"); c.encode(assistantAction.rawValue, forKey: "action")
    }
    public required init?(coder c: NSCoder) {
        position = .init(rawValue: c.decodeInteger(forKey: "position")) ?? .top
        visibility = .init(rawValue: c.decodeInteger(forKey: "visibility")) ?? .off
        assistantAction = .init(rawValue: c.decodeInteger(forKey: "action")) ?? .playMedia
        super.init()
    }
    /// whether the list shows the cell now
    var _shown: Bool { visibility == .always || (visibility == .whileLimitedUIActive && _CPCar.shared.limited.contains(.lists)) }
}

@objc(CPListTemplateDelegate)
public protocol CPListTemplateDelegate: NSObjectProtocol {
    @objc(listTemplate:didSelectListItem:completionHandler:)
    func listTemplate(_ listTemplate: CPListTemplate, didSelect item: CPListItem, completionHandler: @escaping () -> Void)
}

@objc(CPListTemplateDetailsHeader)
open class CPListTemplateDetailsHeader: NSObject, NSSecureCoding {
    @objc open var thumbnail: CPThumbnailImage { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var title: String? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var subtitle: String? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var bodyVariants: [NSAttributedString] = [] { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var actionButtons: [CPButton] { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var wantsAdaptiveBackgroundStyle: Bool = false
    @objc open class var maximumActionButtonCount: Int { 3 }
    @objc open class var maximumActionButtonSize: CGSize { CGSize(width: 40, height: 40) }
    @objc public init(thumbnail: CPThumbnailImage, title: String?, subtitle: String?, actionButtons: [CPButton]) {
        self.thumbnail = thumbnail; self.title = title; self.subtitle = subtitle
        self.actionButtons = Array(actionButtons.prefix(Self.maximumActionButtonCount))
        super.init()
    }
    @objc public convenience init(thumbnail: CPThumbnailImage, title: String?, subtitle: String?, bodyVariants: [NSAttributedString], actionButtons: [CPButton]) {
        self.init(thumbnail: thumbnail, title: title, subtitle: subtitle, actionButtons: actionButtons)
        self.bodyVariants = bodyVariants
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(title, forKey: "title"); c.encode(subtitle, forKey: "subtitle"); c.encode(thumbnail, forKey: "thumbnail") }
    public required init?(coder c: NSCoder) {
        guard let t = c.decodeObject(of: CPThumbnailImage.self, forKey: "thumbnail") else { return nil }
        thumbnail = t; actionButtons = []
        title = c.decodeObject(of: NSString.self, forKey: "title") as String?
        subtitle = c.decodeObject(of: NSString.self, forKey: "subtitle") as String?
        super.init()
    }
}

@objc(CPListTemplate)
open class CPListTemplate: CPTemplate, CPBarButtonProviding {
    @objc open weak var delegate: (any CPListTemplateDelegate)?
    @objc open private(set) var sections: [CPListSection]
    @objc open private(set) var title: String?
    @objc open var emptyViewTitleVariants: [String] = [] { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var emptyViewSubtitleVariants: [String] = [] { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var assistantCellConfiguration: CPAssistantCellConfiguration? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var headerGridButtons: [CPGridButton]? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var listHeader: CPListTemplateDetailsHeader? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var showsSpinnerWhileEmpty: Bool = false { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var leadingNavigationBarButtons: [CPBarButton] { get { _leading } set { _leading = newValue } }
    @objc open var trailingNavigationBarButtons: [CPBarButton] { get { _trailing } set { _trailing = newValue } }
    @objc open var backButton: CPBarButton? { get { _back } set { _back = newValue } }

    /// how many items and sections the car shows (fewer while it limits lists)
    @objc open class var maximumItemCount: Int { _CPCar.shared.limited.contains(.lists) ? 12 : 500 }
    @objc open class var maximumSectionCount: Int { _CPCar.shared.limited.contains(.lists) ? 1 : 50 }
    @objc open class var maximumHeaderGridButtonCount: Int { 4 }
    @objc open class var maximumGridButtonImageSize: CGSize { CGSize(width: 60, height: 60) }
    @objc open var itemCount: Int { sections.reduce(0) { $0 + $1.items.count } }
    @objc open var sectionCount: Int { sections.count }

    @objc public init(title: String?, sections: [CPListSection]) { self.title = title; self.sections = sections; super.init() }
    @objc public convenience init(title: String?, sections: [CPListSection], assistantCellConfiguration: CPAssistantCellConfiguration?) {
        self.init(title: title, sections: sections)
        self.assistantCellConfiguration = assistantCellConfiguration
    }
    @objc public convenience init(title: String?, sections: [CPListSection], assistantCellConfiguration: CPAssistantCellConfiguration?, headerGridButtons: [CPGridButton]?) {
        self.init(title: title, sections: sections, assistantCellConfiguration: assistantCellConfiguration)
        self.headerGridButtons = headerGridButtons.map { Array($0.prefix(Self.maximumHeaderGridButtonCount)) }
    }
    @objc public convenience init(title: String?, listHeader: CPListTemplateDetailsHeader?, sections: [CPListSection], assistantCellConfiguration: CPAssistantCellConfiguration?) {
        self.init(title: title, sections: sections, assistantCellConfiguration: assistantCellConfiguration)
        self.listHeader = listHeader
    }
    public required init?(coder c: NSCoder) {
        title = c.decodeObject(of: NSString.self, forKey: "title") as String?
        sections = (c.decodeObject(of: [NSArray.self, CPListSection.self], forKey: "sections") as? [CPListSection]) ?? []
        super.init(coder: c)
    }
    open override func encode(with c: NSCoder) { super.encode(with: c); c.encode(title, forKey: "title"); c.encode(sections, forKey: "sections") }

    @objc open func updateSections(_ sections: [CPListSection]) { self.sections = sections; _CPCar.shared.setNeedsRender() }
    @objc open func indexPath(for item: any CPListTemplateItem) -> IndexPath? {
        for (s, sec) in sections.enumerated() { if let r = sec.items.firstIndex(where: { $0 === item }) { return IndexPath(row: r, section: s) } }
        return nil
    }
    override var _barTitle: String? { title }
}

// MARK: - the grid

@objc(CPMessageGridItemConfiguration)
open class CPMessageGridItemConfiguration: NSObject {
    @objc open private(set) var conversationIdentifier: String
    var _isUnread: Bool
    @objc open var isUnread: Bool {
        @objc(isUnread) get { _isUnread }
        @objc(setUnread:) set { _isUnread = newValue; _CPCar.shared.setNeedsRender() }
    }
    @objc public init(conversationIdentifier: String, unread: Bool) { self.conversationIdentifier = conversationIdentifier; _isUnread = unread; super.init() }
}

@objc(CPGridButton)
open class CPGridButton: NSObject, NSSecureCoding {
    var _isEnabled: Bool = true
    @objc open var isEnabled: Bool {
        @objc(isEnabled) get { _isEnabled }
        @objc(setEnabled:) set { _isEnabled = newValue; _CPCar.shared.setNeedsRender() }
    }
    @objc open private(set) var titleVariants: [String]
    @objc open private(set) var image: UIImage
    @objc open private(set) var messageConfiguration: CPMessageGridItemConfiguration?
    var _handler: ((CPGridButton) -> Void)?
    @objc public init(titleVariants: [String], image: UIImage, messageConfiguration: CPMessageGridItemConfiguration?, handler: ((CPGridButton) -> Void)?) {
        self.titleVariants = titleVariants; self.image = image; self.messageConfiguration = messageConfiguration; _handler = handler
        super.init()
    }
    @objc public convenience init(titleVariants: [String], image: UIImage, handler: ((CPGridButton) -> Void)?) {
        self.init(titleVariants: titleVariants, image: image, messageConfiguration: nil, handler: handler)
    }
    @objc open func updateImage(_ image: UIImage) { self.image = image; _CPCar.shared.setNeedsRender() }
    @objc open func updateTitleVariants(_ titleVariants: [String]) { self.titleVariants = titleVariants; _CPCar.shared.setNeedsRender() }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(titleVariants, forKey: "titles"); c.encode(image, forKey: "image"); c.encode(isEnabled, forKey: "enabled") }
    public required init?(coder c: NSCoder) {
        titleVariants = _cpDecodeStrings(c, "titles")
        image = c.decodeObject(of: UIImage.self, forKey: "image") ?? UIImage()
        _isEnabled = c.containsValue(forKey: "enabled") ? c.decodeBool(forKey: "enabled") : true
        super.init()
    }
    func _tap() { if isEnabled { _handler?(self) } }
}

@objc(CPGridTemplate)
open class CPGridTemplate: CPTemplate, CPBarButtonProviding {
    @objc open private(set) var title: String
    @objc open private(set) var gridButtons: [CPGridButton]
    @objc open var leadingNavigationBarButtons: [CPBarButton] { get { _leading } set { _leading = newValue } }
    @objc open var trailingNavigationBarButtons: [CPBarButton] { get { _trailing } set { _trailing = newValue } }
    @objc open var backButton: CPBarButton? { get { _back } set { _back = newValue } }
    @objc open class var maximumGridButtonImageSize: CGSize { CGSize(width: 60, height: 60) }
    @objc public init(title: String?, gridButtons: [CPGridButton]) {
        self.title = title ?? ""; self.gridButtons = Array(gridButtons.prefix(_cpGridMaxItems))
        super.init()
    }
    public required init?(coder c: NSCoder) {
        title = (c.decodeObject(of: NSString.self, forKey: "title") as String?) ?? ""
        gridButtons = (c.decodeObject(of: [NSArray.self, CPGridButton.self], forKey: "buttons") as? [CPGridButton]) ?? []
        super.init(coder: c)
    }
    open override func encode(with c: NSCoder) { super.encode(with: c); c.encode(title, forKey: "title"); c.encode(gridButtons, forKey: "buttons") }
    @objc open func updateGridButtons(_ gridButtons: [CPGridButton]) { self.gridButtons = Array(gridButtons.prefix(_cpGridMaxItems)); _CPCar.shared.setNeedsRender() }
    @objc open func updateTitle(_ title: String) { self.title = title; _CPCar.shared.setNeedsRender() }
    override var _barTitle: String? { title }
}

// MARK: - the tab bar

@objc(CPTabBarTemplateDelegate)
public protocol CPTabBarTemplateDelegate: NSObjectProtocol {
    @objc(tabBarTemplate:didSelectTemplate:) func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate)
}

@objc(CPTabBarTemplate)
open class CPTabBarTemplate: CPTemplate {
    @objc open weak var delegate: (any CPTabBarTemplateDelegate)?
    @objc open private(set) var templates: [CPTemplate]
    var _selected = 0
    @objc open var selectedTemplate: CPTemplate? { _selected < templates.count ? templates[_selected] : nil }
    @objc open class var maximumTabCount: Int { 5 }
    @objc public init(templates: [CPTemplate]) {
        self.templates = Array(templates.prefix(Self.maximumTabCount))
        super.init()
    }
    public required init?(coder c: NSCoder) { templates = []; super.init(coder: c) }
    @objc open func updateTemplates(_ newTemplates: [CPTemplate]) {
        let keep = selectedTemplate
        templates = Array(newTemplates.prefix(Self.maximumTabCount))
        _selected = keep.flatMap { k in templates.firstIndex { $0 === k } } ?? 0
        for t in templates { t._controller = _controller }
        _CPCar.shared.setNeedsRender()
    }
    @objc(selectTemplate:) open func select(_ template: CPTemplate) { if let i = templates.firstIndex(where: { $0 === template }) { selectTemplate(at: i) } }
    @objc(selectTemplateAtIndex:) open func selectTemplate(at index: Int) {
        guard index >= 0, index < templates.count else { return }
        _selected = index; _CPCar.shared.setNeedsRender()
    }
    /// the user taps a tab
    func _userSelect(_ index: Int) {
        guard index < templates.count else { return }
        _selected = index
        delegate?.tabBarTemplate(self, didSelect: templates[index])
        _CPCar.shared.setNeedsRender()
    }
}
