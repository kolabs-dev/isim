// isim CarPlay: the alert, action sheet, information, point of interest, search, voice control and contact templates.
import Foundation
import MapKit
import UIKit

@objc(CPAlertTemplate)
open class CPAlertTemplate: CPTemplate {
    @objc open private(set) var titleVariants: [String]
    @objc open private(set) var actions: [CPAlertAction]
    @objc open class var maximumActionCount: Int { 2 }
    @objc public init(titleVariants: [String], actions: [CPAlertAction]) {
        self.titleVariants = titleVariants; self.actions = Array(actions.prefix(Self.maximumActionCount))
        super.init()
    }
    public required init?(coder c: NSCoder) {
        titleVariants = _cpDecodeStrings(c, "titles")
        actions = (c.decodeObject(of: [NSArray.self, CPAlertAction.self], forKey: "actions") as? [CPAlertAction]) ?? []
        super.init(coder: c)
    }
    open override func encode(with c: NSCoder) { super.encode(with: c); c.encode(titleVariants, forKey: "titles"); c.encode(actions, forKey: "actions") }
}

@objc(CPActionSheetTemplate)
open class CPActionSheetTemplate: CPTemplate {
    @objc open private(set) var title: String?
    @objc open private(set) var message: String?
    @objc open private(set) var actions: [CPAlertAction]
    @objc public init(title: String?, message: String?, actions: [CPAlertAction]) {
        self.title = title; self.message = message; self.actions = actions
        super.init()
    }
    public required init?(coder c: NSCoder) {
        title = c.decodeObject(of: NSString.self, forKey: "title") as String?
        message = c.decodeObject(of: NSString.self, forKey: "message") as String?
        actions = (c.decodeObject(of: [NSArray.self, CPAlertAction.self], forKey: "actions") as? [CPAlertAction]) ?? []
        super.init(coder: c)
    }
    open override func encode(with c: NSCoder) { super.encode(with: c); c.encode(title, forKey: "title"); c.encode(message, forKey: "message"); c.encode(actions, forKey: "actions") }
}

// MARK: - information

@objc(CPInformationItem)
open class CPInformationItem: NSObject, NSSecureCoding {
    @objc open private(set) var title: String?
    @objc open private(set) var detail: String?
    @objc public init(title: String?, detail: String?) { self.title = title; self.detail = detail; super.init() }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with c: NSCoder) { c.encode(title, forKey: "title"); c.encode(detail, forKey: "detail") }
    public required init?(coder c: NSCoder) {
        title = c.decodeObject(of: NSString.self, forKey: "title") as String?
        detail = c.decodeObject(of: NSString.self, forKey: "detail") as String?
        super.init()
    }
}

@objc(CPInformationRatingItem)
open class CPInformationRatingItem: CPInformationItem {
    @objc open private(set) var rating: NSNumber?
    @objc open private(set) var maximumRating: NSNumber?
    @objc public init(rating: NSNumber?, maximumRating: NSNumber?, title: String?, detail: String?) {
        self.rating = rating; self.maximumRating = maximumRating
        super.init(title: title, detail: detail)
    }
    open override func encode(with c: NSCoder) { super.encode(with: c); c.encode(rating, forKey: "rating"); c.encode(maximumRating, forKey: "max") }
    public required init?(coder c: NSCoder) {
        rating = c.decodeObject(of: NSNumber.self, forKey: "rating"); maximumRating = c.decodeObject(of: NSNumber.self, forKey: "max")
        super.init(coder: c)
    }
}

@objc(CPInformationTemplate)
open class CPInformationTemplate: CPTemplate, CPBarButtonProviding {
    @objc open private(set) var layout: CPInformationTemplateLayout
    @objc open var title: String { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var items: [CPInformationItem] { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var actions: [CPTextButton] { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var leadingNavigationBarButtons: [CPBarButton] { get { _leading } set { _leading = newValue } }
    @objc open var trailingNavigationBarButtons: [CPBarButton] { get { _trailing } set { _trailing = newValue } }
    @objc open var backButton: CPBarButton? { get { _back } set { _back = newValue } }
    @objc public init(title: String, layout: CPInformationTemplateLayout, items: [CPInformationItem], actions: [CPTextButton]) {
        self.title = title; self.layout = layout; self.items = Array(items.prefix(10)); self.actions = Array(actions.prefix(3))
        super.init()
    }
    public required init?(coder c: NSCoder) {
        title = (c.decodeObject(of: NSString.self, forKey: "title") as String?) ?? ""
        layout = .init(rawValue: c.decodeInteger(forKey: "layout")) ?? .leading
        items = (c.decodeObject(of: [NSArray.self, CPInformationItem.self, CPInformationRatingItem.self], forKey: "items") as? [CPInformationItem]) ?? []
        actions = []
        super.init(coder: c)
    }
    open override func encode(with c: NSCoder) { super.encode(with: c); c.encode(title, forKey: "title"); c.encode(layout.rawValue, forKey: "layout"); c.encode(items, forKey: "items") }
    override var _barTitle: String? { title }
}

// MARK: - points of interest

@objc(CPPointOfInterest)
open class CPPointOfInterest: NSObject, NSSecureCoding {
    @objc open var location: MKMapItem { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var title: String { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var subtitle: String? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var summary: String? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var detailTitle: String? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var detailSubtitle: String? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var detailSummary: String? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var pinImage: UIImage? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var selectedPinImage: UIImage? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var primaryButton: CPTextButton? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var secondaryButton: CPTextButton? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var userInfo: Any?
    @objc open class var pinImageSize: CGSize { CGSize(width: 40, height: 40) }
    @objc open class var selectedPinImageSize: CGSize { CGSize(width: 60, height: 60) }
    @objc public init(location: MKMapItem, title: String, subtitle: String?, summary: String?, detailTitle: String?, detailSubtitle: String?,
                      detailSummary: String?, pinImage: UIImage?, selectedPinImage: UIImage?) {
        self.location = location; self.title = title; self.subtitle = subtitle; self.summary = summary; self.detailTitle = detailTitle
        self.detailSubtitle = detailSubtitle; self.detailSummary = detailSummary; self.pinImage = pinImage; self.selectedPinImage = selectedPinImage
        super.init()
    }
    @objc public convenience init(location: MKMapItem, title: String, subtitle: String?, summary: String?, detailTitle: String?, detailSubtitle: String?,
                                  detailSummary: String?, pinImage: UIImage?) {
        self.init(location: location, title: title, subtitle: subtitle, summary: summary, detailTitle: detailTitle, detailSubtitle: detailSubtitle,
                  detailSummary: detailSummary, pinImage: pinImage, selectedPinImage: nil)
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) {
        c.encode(title, forKey: "title"); c.encode(subtitle, forKey: "subtitle"); c.encode(summary, forKey: "summary")
        c.encode(location.placemark.coordinate.latitude, forKey: "lat"); c.encode(location.placemark.coordinate.longitude, forKey: "lon")
    }
    public required init?(coder c: NSCoder) {
        title = (c.decodeObject(of: NSString.self, forKey: "title") as String?) ?? ""
        subtitle = c.decodeObject(of: NSString.self, forKey: "subtitle") as String?
        summary = c.decodeObject(of: NSString.self, forKey: "summary") as String?
        location = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: c.decodeDouble(forKey: "lat"), longitude: c.decodeDouble(forKey: "lon"))))
        super.init()
    }
}

/// Swift only in isim: MKCoordinateRegion is a Swift struct in isim's MapKit, so the protocol is not @objc
public protocol CPPointOfInterestTemplateDelegate: NSObjectProtocol {
    func pointOfInterestTemplate(_ pointOfInterestTemplate: CPPointOfInterestTemplate, didChangeMapRegion region: MKCoordinateRegion)
    func pointOfInterestTemplate(_ pointOfInterestTemplate: CPPointOfInterestTemplate, didSelectPointOfInterest pointOfInterest: CPPointOfInterest)
}
extension CPPointOfInterestTemplateDelegate {
    public func pointOfInterestTemplate(_ pointOfInterestTemplate: CPPointOfInterestTemplate, didSelectPointOfInterest pointOfInterest: CPPointOfInterest) {}
}

@objc(CPPointOfInterestTemplate)
open class CPPointOfInterestTemplate: CPTemplate, CPBarButtonProviding {
    open weak var pointOfInterestDelegate: (any CPPointOfInterestTemplateDelegate)? { didSet { _regionSent = false; _CPCar.shared.setNeedsRender() } }
    var _regionSent = false
    @objc open var title: String { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open private(set) var pointsOfInterest: [CPPointOfInterest]
    @objc open var selectedIndex: Int { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var leadingNavigationBarButtons: [CPBarButton] { get { _leading } set { _leading = newValue } }
    @objc open var trailingNavigationBarButtons: [CPBarButton] { get { _trailing } set { _trailing = newValue } }
    @objc open var backButton: CPBarButton? { get { _back } set { _back = newValue } }
    @objc public init(title: String, pointsOfInterest: [CPPointOfInterest], selectedIndex: Int) {
        self.title = title; self.pointsOfInterest = Array(pointsOfInterest.prefix(12)); self.selectedIndex = selectedIndex
        super.init()
    }
    public required init?(coder c: NSCoder) {
        title = (c.decodeObject(of: NSString.self, forKey: "title") as String?) ?? ""
        pointsOfInterest = (c.decodeObject(of: [NSArray.self, CPPointOfInterest.self], forKey: "pois") as? [CPPointOfInterest]) ?? []
        selectedIndex = c.decodeInteger(forKey: "selected")
        super.init(coder: c)
    }
    open override func encode(with c: NSCoder) { super.encode(with: c); c.encode(title, forKey: "title"); c.encode(pointsOfInterest, forKey: "pois"); c.encode(selectedIndex, forKey: "selected") }
    @objc open func setPointsOfInterest(_ pointsOfInterest: [CPPointOfInterest], selectedIndex: Int) {
        self.pointsOfInterest = Array(pointsOfInterest.prefix(12)); self.selectedIndex = selectedIndex
        _CPCar.shared.setNeedsRender()
    }
    /// the region its map shows: around its points of interest
    var _region: MKCoordinateRegion {
        let cs = pointsOfInterest.map { $0.location.placemark.coordinate }
        guard let f = cs.first else { return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.009), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)) }
        var (a, b, c, d) = (f.latitude, f.latitude, f.longitude, f.longitude)
        for p in cs { a = min(a, p.latitude); b = max(b, p.latitude); c = min(c, p.longitude); d = max(d, p.longitude) }
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (a + b) / 2, longitude: (c + d) / 2),
                                  span: MKCoordinateSpan(latitudeDelta: max(b - a, 0.01) * 1.4, longitudeDelta: max(d - c, 0.01) * 1.4))
    }
    func _select(_ i: Int) {
        guard i >= 0, i < pointsOfInterest.count else { return }
        selectedIndex = i
        pointOfInterestDelegate?.pointOfInterestTemplate(self, didSelectPointOfInterest: pointsOfInterest[i])
    }
    override var _barTitle: String? { title }
}

// MARK: - search

@objc(CPSearchTemplateDelegate)
public protocol CPSearchTemplateDelegate: NSObjectProtocol {
    @objc(searchTemplate:updatedSearchText:completionHandler:)
    func searchTemplate(_ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String, completionHandler: @escaping ([CPListItem]) -> Void)
    @objc(searchTemplate:selectedResult:completionHandler:)
    func searchTemplate(_ searchTemplate: CPSearchTemplate, selectedResult item: CPListItem, completionHandler: @escaping () -> Void)
    @objc optional func searchTemplateSearchButtonPressed(_ searchTemplate: CPSearchTemplate)
}

/// a navigation app's search: `carplay search TEXT` types the text (CarPlay's keyboard, or dictation), the delegate
/// answers with results the screen lists
@objc(CPSearchTemplate)
open class CPSearchTemplate: CPTemplate, CPBarButtonProviding {
    @objc open weak var delegate: (any CPSearchTemplateDelegate)?
    @objc open var leadingNavigationBarButtons: [CPBarButton] { get { _leading } set { _leading = newValue } }
    @objc open var trailingNavigationBarButtons: [CPBarButton] { get { _trailing } set { _trailing = newValue } }
    @objc open var backButton: CPBarButton? { get { _back } set { _back = newValue } }
    var _text = ""
    var _results: [CPListItem] = []
    public override init() { super.init() }
    public required init?(coder c: NSCoder) { super.init(coder: c) }
    func _type(_ text: String) {
        _text = text
        delegate?.searchTemplate(self, updatedSearchText: text) { [weak self] items in
            DispatchQueue.main.async { self?._results = items; _CPCar.shared.setNeedsRender() }
        }
        _CPCar.shared.setNeedsRender()
    }
    func _search() { delegate?.searchTemplateSearchButtonPressed?(self) }
    override var _barTitle: String? { nil }
}

// MARK: - voice control

@objc(CPVoiceControlState)
open class CPVoiceControlState: NSObject, NSSecureCoding {
    @objc open private(set) var identifier: String
    @objc open private(set) var titleVariants: [String]?
    @objc open private(set) var image: UIImage?
    @objc open private(set) var backgroundImage: UIImage?
    @objc open private(set) var repeats: Bool
    @objc open var actionButtons: [CPButton] = [] { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open class var maximumActionButtonCount: Int { 2 }
    @objc public init(identifier: String, titleVariants: [String]?, image: UIImage?, repeats: Bool) {
        self.identifier = identifier; self.titleVariants = titleVariants; self.image = image; self.repeats = repeats
        super.init()
    }
    @objc public convenience init(identifier: String, titleVariants: [String]?, image: UIImage?, backgroundImage: UIImage?, repeats: Bool) {
        self.init(identifier: identifier, titleVariants: titleVariants, image: image, repeats: repeats)
        self.backgroundImage = backgroundImage
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(identifier, forKey: "id"); c.encode(titleVariants, forKey: "titles"); c.encode(repeats, forKey: "repeats") }
    public required init?(coder c: NSCoder) {
        identifier = (c.decodeObject(of: NSString.self, forKey: "id") as String?) ?? ""
        titleVariants = c.decodeObject(of: [NSArray.self, NSString.self], forKey: "titles") as? [String]
        repeats = c.decodeBool(forKey: "repeats")
        super.init()
    }
}

@objc(CPVoiceControlTemplate)
open class CPVoiceControlTemplate: CPTemplate, CPBarButtonProviding {
    @objc open private(set) var voiceControlStates: [CPVoiceControlState]
    @objc open private(set) var activeStateIdentifier: String?
    @objc open var leadingNavigationBarButtons: [CPBarButton] { get { _leading } set { _leading = newValue } }
    @objc open var trailingNavigationBarButtons: [CPBarButton] { get { _trailing } set { _trailing = newValue } }
    @objc open var backButton: CPBarButton? { get { _back } set { _back = newValue } }
    @objc public init(voiceControlStates: [CPVoiceControlState]) {
        self.voiceControlStates = voiceControlStates; activeStateIdentifier = voiceControlStates.first?.identifier
        super.init()
    }
    public required init?(coder c: NSCoder) {
        voiceControlStates = (c.decodeObject(of: [NSArray.self, CPVoiceControlState.self], forKey: "states") as? [CPVoiceControlState]) ?? []
        super.init(coder: c)
    }
    open override func encode(with c: NSCoder) { super.encode(with: c); c.encode(voiceControlStates, forKey: "states") }
    @objc(activateVoiceControlStateWithIdentifier:) open func activateVoiceControlState(withIdentifier identifier: String) {
        guard voiceControlStates.contains(where: { $0.identifier == identifier }) else { return }
        activeStateIdentifier = identifier; _CPCar.shared.setNeedsRender()
    }
    var _active: CPVoiceControlState? { voiceControlStates.first { $0.identifier == activeStateIdentifier } }
    override var _hasBar: Bool { !(_leading.isEmpty && _trailing.isEmpty && _back == nil) }
}

// MARK: - contacts

@objc(CPContactCallButton)
open class CPContactCallButton: CPButton {
    @objc public init(handler: ((CPButton) -> Void)?) { super.init(_title: "Call", image: UIImage(systemName: "phone.fill"), handler: handler) }
    override var _symbol: String? { "phone.fill" }
}
@objc(CPContactDirectionsButton)
open class CPContactDirectionsButton: CPButton {
    @objc public init(handler: ((CPButton) -> Void)?) { super.init(_title: "Directions", image: UIImage(systemName: "car.fill"), handler: handler) }
    override var _symbol: String? { "car.fill" }
}
/// a message button: CarPlay starts Siri's message flow to the address (isim logs it)
@objc(CPContactMessageButton)
open class CPContactMessageButton: CPButton {
    @objc open private(set) var phoneOrEmail: String
    @objc public init(phoneOrEmail: String) {
        self.phoneOrEmail = phoneOrEmail
        super.init(_title: "Message", image: UIImage(systemName: "message.fill")) { b in
            NSLog("isim CarPlay: Siri compose a message to %@", (b as? CPContactMessageButton)?.phoneOrEmail ?? "")
        }
    }
    override var _symbol: String? { "message.fill" }
}

@objc(CPContact)
open class CPContact: NSObject, NSSecureCoding {
    @objc open var name: String { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var image: UIImage { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var subtitle: String? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var informativeText: String? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var actions: [CPButton]? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc public init(name: String, image: UIImage) { self.name = name; self.image = image; super.init() }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(name, forKey: "name"); c.encode(image, forKey: "image"); c.encode(subtitle, forKey: "subtitle"); c.encode(informativeText, forKey: "info") }
    public required init?(coder c: NSCoder) {
        name = (c.decodeObject(of: NSString.self, forKey: "name") as String?) ?? ""
        image = c.decodeObject(of: UIImage.self, forKey: "image") ?? UIImage()
        subtitle = c.decodeObject(of: NSString.self, forKey: "subtitle") as String?
        informativeText = c.decodeObject(of: NSString.self, forKey: "info") as String?
        super.init()
    }
}

@objc(CPContactTemplate)
open class CPContactTemplate: CPTemplate, CPBarButtonProviding {
    @objc open var contact: CPContact { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var leadingNavigationBarButtons: [CPBarButton] { get { _leading } set { _leading = newValue } }
    @objc open var trailingNavigationBarButtons: [CPBarButton] { get { _trailing } set { _trailing = newValue } }
    @objc open var backButton: CPBarButton? { get { _back } set { _back = newValue } }
    @objc public init(contact: CPContact) { self.contact = contact; super.init() }
    public required init?(coder c: NSCoder) {
        guard let k = c.decodeObject(of: CPContact.self, forKey: "contact") else { return nil }
        contact = k
        super.init(coder: c)
    }
    open override func encode(with c: NSCoder) { super.encode(with: c); c.encode(contact, forKey: "contact") }
}
