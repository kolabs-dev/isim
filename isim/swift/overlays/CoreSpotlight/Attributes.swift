// isim CoreSpotlight: CSSearchableItemAttributeSet with all of Apple's attributes (kept in one dictionary by name, so
// that they are indexed and searchable: Query.swift), custom attributes (CSCustomAttributeKey), CSPerson and
// CSLocalizedString. The property-list form (_isimPlist) is what the Spotlight index keeps.
import Foundation
import UniformTypeIdentifiers

@objc(CSSearchableItemAttributeSet) open class CSSearchableItemAttributeSet: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    /// the attributes by name (Apple's property names), and the custom attributes by key name
    var _values: [String: Any] = [:]
    var _custom: [String: Any] = [:]

    public init(contentType: UTType) { super.init(); self.contentType = contentType.identifier }
    public init(itemContentType: String) { super.init(); self.contentType = itemContentType }
    init(_isimPlist p: [String: Any]) {
        super.init()
        for (k, v) in p where !k.hasPrefix("$") { _values[k] = _CSPlist.decode(v) }
        if let c = p["$custom"] as? [String: Any] { for (k, v) in c { _custom[k] = _CSPlist.decode(v) } }
    }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        super.init()
        guard let p = coder.decodeObject(forKey: "isim") as? [String: Any] else { return nil }
        for (k, v) in p where !k.hasPrefix("$") { _values[k] = _CSPlist.decode(v) }
        if let c = p["$custom"] as? [String: Any] { for (k, v) in c { _custom[k] = _CSPlist.decode(v) } }
    }
    open func encode(with coder: NSCoder) { coder.encode(_isimPlist as NSDictionary, forKey: "isim") }
    open func copy(with zone: NSZone? = nil) -> Any {
        let c = CSSearchableItemAttributeSet(_isimPlist: [:])
        c._values = _values; c._custom = _custom
        return c
    }
    /// the attributes as a property list (what the index keeps)
    var _isimPlist: [String: Any] {
        var p: [String: Any] = [:]
        for (k, v) in _values { if let e = _CSPlist.encode(v) { p[k] = e } }
        if !_custom.isEmpty { p["$custom"] = _custom.compactMapValues(_CSPlist.encode) }
        return p
    }
    /// an attribute by name, or a custom attribute's (the query language's names)
    func _value(_ name: String) -> Any? { _values[name] ?? _custom[name] }
    open override var description: String { "<CSSearchableItemAttributeSet \(_values.keys.sorted().joined(separator: ", "))>" }

    // MARK: custom attributes
    open func setValue(_ value: (any NSSecureCoding)?, forCustomKey key: CSCustomAttributeKey) { _custom[key.keyName] = value }
    open func value(forCustomKey key: CSCustomAttributeKey) -> (any NSSecureCoding)? { _custom[key.keyName] as? any NSSecureCoding }

    // MARK: the content type
    @objc(contentType) open var contentType: String? { get { _values["contentType"] as? String } set { _values["contentType"] = newValue } }
    @available(iOS 16.0, *)
    open var sharedItemContentType: UTType? {
        get { (_values["sharedItemContentType"] as? String).flatMap { UTType($0) } }
        set { _values["sharedItemContentType"] = newValue?.identifier }
    }

    // MARK: Apple's attributes (general, documents, media, images, events, places, messages, ...)
    @objc(accountHandles) open var accountHandles: [String]? { get { _values["accountHandles"] as? [String] } set { _values["accountHandles"] = newValue } }
    @objc(accountIdentifier) open var accountIdentifier: String? { get { _values["accountIdentifier"] as? String } set { _values["accountIdentifier"] = newValue } }
    @objc(acquisitionMake) open var acquisitionMake: String? { get { _values["acquisitionMake"] as? String } set { _values["acquisitionMake"] = newValue } }
    @objc(acquisitionModel) open var acquisitionModel: String? { get { _values["acquisitionModel"] as? String } set { _values["acquisitionModel"] = newValue } }
    @objc(actionIdentifiers) open var actionIdentifiers: [String] { get { _values["actionIdentifiers"] as? [String] ?? [] } set { _values["actionIdentifiers"] = newValue } }
    @objc(addedDate) open var addedDate: Date? { get { _values["addedDate"] as? Date } set { _values["addedDate"] = newValue } }
    @objc(additionalRecipients) open var additionalRecipients: [CSPerson]? { get { _values["additionalRecipients"] as? [CSPerson] } set { _values["additionalRecipients"] = newValue } }
    @objc(album) open var album: String? { get { _values["album"] as? String } set { _values["album"] = newValue } }
    @objc(allDay) open var allDay: NSNumber? { get { _values["allDay"] as? NSNumber } set { _values["allDay"] = newValue } }
    @objc(alternateNames) open var alternateNames: [String]? { get { _values["alternateNames"] as? [String] } set { _values["alternateNames"] = newValue } }
    @objc(altitude) open var altitude: NSNumber? { get { _values["altitude"] as? NSNumber } set { _values["altitude"] = newValue } }
    @objc(aperture) open var aperture: NSNumber? { get { _values["aperture"] as? NSNumber } set { _values["aperture"] = newValue } }
    @objc(artist) open var artist: String? { get { _values["artist"] as? String } set { _values["artist"] = newValue } }
    @objc(audiences) open var audiences: [String]? { get { _values["audiences"] as? [String] } set { _values["audiences"] = newValue } }
    @objc(audioBitRate) open var audioBitRate: NSNumber? { get { _values["audioBitRate"] as? NSNumber } set { _values["audioBitRate"] = newValue } }
    @objc(audioChannelCount) open var audioChannelCount: NSNumber? { get { _values["audioChannelCount"] as? NSNumber } set { _values["audioChannelCount"] = newValue } }
    @objc(audioEncodingApplication) open var audioEncodingApplication: String? { get { _values["audioEncodingApplication"] as? String } set { _values["audioEncodingApplication"] = newValue } }
    @objc(audioSampleRate) open var audioSampleRate: NSNumber? { get { _values["audioSampleRate"] as? NSNumber } set { _values["audioSampleRate"] = newValue } }
    @objc(audioTrackNumber) open var audioTrackNumber: NSNumber? { get { _values["audioTrackNumber"] as? NSNumber } set { _values["audioTrackNumber"] = newValue } }
    @objc(authorAddresses) open var authorAddresses: [String]? { get { _values["authorAddresses"] as? [String] } set { _values["authorAddresses"] = newValue } }
    @objc(authorEmailAddresses) open var authorEmailAddresses: [String]? { get { _values["authorEmailAddresses"] as? [String] } set { _values["authorEmailAddresses"] = newValue } }
    @objc(authorNames) open var authorNames: [String]? { get { _values["authorNames"] as? [String] } set { _values["authorNames"] = newValue } }
    @objc(authors) open var authors: [CSPerson]? { get { _values["authors"] as? [CSPerson] } set { _values["authors"] = newValue } }
    @objc(bitsPerSample) open var bitsPerSample: NSNumber? { get { _values["bitsPerSample"] as? NSNumber } set { _values["bitsPerSample"] = newValue } }
    @objc(cameraOwner) open var cameraOwner: String? { get { _values["cameraOwner"] as? String } set { _values["cameraOwner"] = newValue } }
    @objc(city) open var city: String? { get { _values["city"] as? String } set { _values["city"] = newValue } }
    @objc(codecs) open var codecs: [String]? { get { _values["codecs"] as? [String] } set { _values["codecs"] = newValue } }
    @objc(colorSpace) open var colorSpace: String? { get { _values["colorSpace"] as? String } set { _values["colorSpace"] = newValue } }
    @objc(comment) open var comment: String? { get { _values["comment"] as? String } set { _values["comment"] = newValue } }
    @objc(completionDate) open var completionDate: Date? { get { _values["completionDate"] as? Date } set { _values["completionDate"] = newValue } }
    @objc(composer) open var composer: String? { get { _values["composer"] as? String } set { _values["composer"] = newValue } }
    @objc(contactKeywords) open var contactKeywords: [String]? { get { _values["contactKeywords"] as? [String] } set { _values["contactKeywords"] = newValue } }
    @objc(containerDisplayName) open var containerDisplayName: String? { get { _values["containerDisplayName"] as? String } set { _values["containerDisplayName"] = newValue } }
    @objc(containerIdentifier) open var containerIdentifier: String? { get { _values["containerIdentifier"] as? String } set { _values["containerIdentifier"] = newValue } }
    @objc(containerOrder) open var containerOrder: NSNumber? { get { _values["containerOrder"] as? NSNumber } set { _values["containerOrder"] = newValue } }
    @objc(containerTitle) open var containerTitle: String? { get { _values["containerTitle"] as? String } set { _values["containerTitle"] = newValue } }
    @objc(contentCreationDate) open var contentCreationDate: Date? { get { _values["contentCreationDate"] as? Date } set { _values["contentCreationDate"] = newValue } }
    @objc(contentDescription) open var contentDescription: String? { get { _values["contentDescription"] as? String } set { _values["contentDescription"] = newValue } }
    @objc(contentModificationDate) open var contentModificationDate: Date? { get { _values["contentModificationDate"] as? Date } set { _values["contentModificationDate"] = newValue } }
    @objc(contentRating) open var contentRating: NSNumber? { get { _values["contentRating"] as? NSNumber } set { _values["contentRating"] = newValue } }
    @objc(contentSources) open var contentSources: [String]? { get { _values["contentSources"] as? [String] } set { _values["contentSources"] = newValue } }
    @objc(contentTypeTree) open var contentTypeTree: [String]? { get { _values["contentTypeTree"] as? [String] } set { _values["contentTypeTree"] = newValue } }
    @objc(contentURL) open var contentURL: URL? { get { _values["contentURL"] as? URL } set { _values["contentURL"] = newValue } }
    @objc(contributors) open var contributors: [String]? { get { _values["contributors"] as? [String] } set { _values["contributors"] = newValue } }
    @objc(copyright) open var copyright: String? { get { _values["copyright"] as? String } set { _values["copyright"] = newValue } }
    @objc(country) open var country: String? { get { _values["country"] as? String } set { _values["country"] = newValue } }
    @objc(coverage) open var coverage: [String]? { get { _values["coverage"] as? [String] } set { _values["coverage"] = newValue } }
    @objc(creator) open var creator: String? { get { _values["creator"] as? String } set { _values["creator"] = newValue } }
    @objc(darkThumbnailURL) open var darkThumbnailURL: URL? { get { _values["darkThumbnailURL"] as? URL } set { _values["darkThumbnailURL"] = newValue } }
    @objc(deliveryType) open var deliveryType: NSNumber? { get { _values["deliveryType"] as? NSNumber } set { _values["deliveryType"] = newValue } }
    @objc(director) open var director: String? { get { _values["director"] as? String } set { _values["director"] = newValue } }
    @objc(displayName) open var displayName: String? { get { _values["displayName"] as? String } set { _values["displayName"] = newValue } }
    @objc(domainIdentifier) open var domainIdentifier: String? { get { _values["domainIdentifier"] as? String } set { _values["domainIdentifier"] = newValue } }
    @objc(downloadedDate) open var downloadedDate: Date? { get { _values["downloadedDate"] as? Date } set { _values["downloadedDate"] = newValue } }
    @objc(dueDate) open var dueDate: Date? { get { _values["dueDate"] as? Date } set { _values["dueDate"] = newValue } }
    @objc(duration) open var duration: NSNumber? { get { _values["duration"] as? NSNumber } set { _values["duration"] = newValue } }
    @objc(editors) open var editors: [String]? { get { _values["editors"] as? [String] } set { _values["editors"] = newValue } }
    @objc(emailAddresses) open var emailAddresses: [String]? { get { _values["emailAddresses"] as? [String] } set { _values["emailAddresses"] = newValue } }
    @objc(emailHeaders) open var emailHeaders: [String : [Any]]? { get { _values["emailHeaders"] as? [String : [Any]] } set { _values["emailHeaders"] = newValue } }
    @objc(encodingApplications) open var encodingApplications: [String]? { get { _values["encodingApplications"] as? [String] } set { _values["encodingApplications"] = newValue } }
    @objc(endDate) open var endDate: Date? { get { _values["endDate"] as? Date } set { _values["endDate"] = newValue } }
    @objc(EXIFVersion) open var exifVersion: String? { get { _values["exifVersion"] as? String } set { _values["exifVersion"] = newValue } }
    @objc(EXIFGPSVersion) open var exifgpsVersion: String? { get { _values["exifgpsVersion"] as? String } set { _values["exifgpsVersion"] = newValue } }
    @objc(exposureMode) open var exposureMode: NSNumber? { get { _values["exposureMode"] as? NSNumber } set { _values["exposureMode"] = newValue } }
    @objc(exposureProgram) open var exposureProgram: String? { get { _values["exposureProgram"] as? String } set { _values["exposureProgram"] = newValue } }
    @objc(exposureTime) open var exposureTime: NSNumber? { get { _values["exposureTime"] as? NSNumber } set { _values["exposureTime"] = newValue } }
    @objc(exposureTimeString) open var exposureTimeString: String? { get { _values["exposureTimeString"] as? String } set { _values["exposureTimeString"] = newValue } }
    @objc(fNumber) open var fNumber: NSNumber? { get { _values["fNumber"] as? NSNumber } set { _values["fNumber"] = newValue } }
    @objc(fileSize) open var fileSize: NSNumber? { get { _values["fileSize"] as? NSNumber } set { _values["fileSize"] = newValue } }
    @objc(flashOn) open var flashOn: NSNumber? { get { _values["flashOn"] as? NSNumber } set { _values["flashOn"] = newValue } }
    @objc(focalLength35mm) open var focalLength35mm: NSNumber? { get { _values["focalLength35mm"] as? NSNumber } set { _values["focalLength35mm"] = newValue } }
    @objc(focalLength) open var focalLength: NSNumber? { get { _values["focalLength"] as? NSNumber } set { _values["focalLength"] = newValue } }
    @objc(fontNames) open var fontNames: [String]? { get { _values["fontNames"] as? [String] } set { _values["fontNames"] = newValue } }
    @objc(fullyFormattedAddress) open var fullyFormattedAddress: String? { get { _values["fullyFormattedAddress"] as? String } set { _values["fullyFormattedAddress"] = newValue } }
    @objc(generalMIDISequence) open var generalMIDISequence: NSNumber? { get { _values["generalMIDISequence"] as? NSNumber } set { _values["generalMIDISequence"] = newValue } }
    @objc(genre) open var genre: String? { get { _values["genre"] as? String } set { _values["genre"] = newValue } }
    @objc(GPSAreaInformation) open var gpsAreaInformation: String? { get { _values["gpsAreaInformation"] as? String } set { _values["gpsAreaInformation"] = newValue } }
    @objc(GPSDateStamp) open var gpsDateStamp: Date? { get { _values["gpsDateStamp"] as? Date } set { _values["gpsDateStamp"] = newValue } }
    @objc(GPSDestBearing) open var gpsDestBearing: NSNumber? { get { _values["gpsDestBearing"] as? NSNumber } set { _values["gpsDestBearing"] = newValue } }
    @objc(GPSDestDistance) open var gpsDestDistance: NSNumber? { get { _values["gpsDestDistance"] as? NSNumber } set { _values["gpsDestDistance"] = newValue } }
    @objc(GPSDestLatitude) open var gpsDestLatitude: NSNumber? { get { _values["gpsDestLatitude"] as? NSNumber } set { _values["gpsDestLatitude"] = newValue } }
    @objc(GPSDestLongitude) open var gpsDestLongitude: NSNumber? { get { _values["gpsDestLongitude"] as? NSNumber } set { _values["gpsDestLongitude"] = newValue } }
    @objc(GPSDifferental) open var gpsDifferental: NSNumber? { get { _values["gpsDifferental"] as? NSNumber } set { _values["gpsDifferental"] = newValue } }
    @objc(GPSMapDatum) open var gpsMapDatum: String? { get { _values["gpsMapDatum"] as? String } set { _values["gpsMapDatum"] = newValue } }
    @objc(GPSMeasureMode) open var gpsMeasureMode: String? { get { _values["gpsMeasureMode"] as? String } set { _values["gpsMeasureMode"] = newValue } }
    @objc(GPSProcessingMethod) open var gpsProcessingMethod: String? { get { _values["gpsProcessingMethod"] as? String } set { _values["gpsProcessingMethod"] = newValue } }
    @objc(GPSStatus) open var gpsStatus: String? { get { _values["gpsStatus"] as? String } set { _values["gpsStatus"] = newValue } }
    @objc(GPSTrack) open var gpsTrack: NSNumber? { get { _values["gpsTrack"] as? NSNumber } set { _values["gpsTrack"] = newValue } }
    @objc(GPSDOP) open var gpsdop: NSNumber? { get { _values["gpsdop"] as? NSNumber } set { _values["gpsdop"] = newValue } }
    @objc(hasAlphaChannel) open var hasAlphaChannel: NSNumber? { get { _values["hasAlphaChannel"] as? NSNumber } set { _values["hasAlphaChannel"] = newValue } }
    @objc(headline) open var headline: String? { get { _values["headline"] as? String } set { _values["headline"] = newValue } }
    @objc(hiddenAdditionalRecipients) open var hiddenAdditionalRecipients: [CSPerson]? { get { _values["hiddenAdditionalRecipients"] as? [CSPerson] } set { _values["hiddenAdditionalRecipients"] = newValue } }
    @objc(HTMLContentData) open var htmlContentData: Data? { get { _values["htmlContentData"] as? Data } set { _values["htmlContentData"] = newValue } }
    @objc(identifier) open var identifier: String? { get { _values["identifier"] as? String } set { _values["identifier"] = newValue } }
    @objc(imageDirection) open var imageDirection: NSNumber? { get { _values["imageDirection"] as? NSNumber } set { _values["imageDirection"] = newValue } }
    @objc(importantDates) open var importantDates: [Date]? { get { _values["importantDates"] as? [Date] } set { _values["importantDates"] = newValue } }
    @objc(information) open var information: String? { get { _values["information"] as? String } set { _values["information"] = newValue } }
    @objc(instantMessageAddresses) open var instantMessageAddresses: [String]? { get { _values["instantMessageAddresses"] as? [String] } set { _values["instantMessageAddresses"] = newValue } }
    @objc(instructions) open var instructions: String? { get { _values["instructions"] as? String } set { _values["instructions"] = newValue } }
    @objc(isPriority) open var isPriority: NSNumber? { get { _values["isPriority"] as? NSNumber } set { _values["isPriority"] = newValue } }
    @objc(ISOSpeed) open var isoSpeed: NSNumber? { get { _values["isoSpeed"] as? NSNumber } set { _values["isoSpeed"] = newValue } }
    @objc(keySignature) open var keySignature: String? { get { _values["keySignature"] as? String } set { _values["keySignature"] = newValue } }
    @objc(keywords) open var keywords: [String]? { get { _values["keywords"] as? [String] } set { _values["keywords"] = newValue } }
    @objc(kind) open var kind: String? { get { _values["kind"] as? String } set { _values["kind"] = newValue } }
    @objc(languages) open var languages: [String]? { get { _values["languages"] as? [String] } set { _values["languages"] = newValue } }
    @objc(lastUsedDate) open var lastUsedDate: Date? { get { _values["lastUsedDate"] as? Date } set { _values["lastUsedDate"] = newValue } }
    @objc(latitude) open var latitude: NSNumber? { get { _values["latitude"] as? NSNumber } set { _values["latitude"] = newValue } }
    @objc(layerNames) open var layerNames: [String]? { get { _values["layerNames"] as? [String] } set { _values["layerNames"] = newValue } }
    @objc(lensModel) open var lensModel: String? { get { _values["lensModel"] as? String } set { _values["lensModel"] = newValue } }
    @objc(likelyJunk) open var likelyJunk: NSNumber { get { _values["likelyJunk"] as? NSNumber ?? NSNumber(value: false) } set { _values["likelyJunk"] = newValue } }
    @objc(local) open var local: NSNumber? { get { _values["local"] as? NSNumber } set { _values["local"] = newValue } }
    @objc(longitude) open var longitude: NSNumber? { get { _values["longitude"] as? NSNumber } set { _values["longitude"] = newValue } }
    @objc(lyricist) open var lyricist: String? { get { _values["lyricist"] as? String } set { _values["lyricist"] = newValue } }
    @objc(mailboxIdentifiers) open var mailboxIdentifiers: [String]? { get { _values["mailboxIdentifiers"] as? [String] } set { _values["mailboxIdentifiers"] = newValue } }
    @objc(maxAperture) open var maxAperture: NSNumber? { get { _values["maxAperture"] as? NSNumber } set { _values["maxAperture"] = newValue } }
    @objc(mediaTypes) open var mediaTypes: [String]? { get { _values["mediaTypes"] as? [String] } set { _values["mediaTypes"] = newValue } }
    @objc(metadataModificationDate) open var metadataModificationDate: Date? { get { _values["metadataModificationDate"] as? Date } set { _values["metadataModificationDate"] = newValue } }
    @objc(meteringMode) open var meteringMode: String? { get { _values["meteringMode"] as? String } set { _values["meteringMode"] = newValue } }
    @objc(musicalGenre) open var musicalGenre: String? { get { _values["musicalGenre"] as? String } set { _values["musicalGenre"] = newValue } }
    @objc(musicalInstrumentCategory) open var musicalInstrumentCategory: String? { get { _values["musicalInstrumentCategory"] as? String } set { _values["musicalInstrumentCategory"] = newValue } }
    @objc(musicalInstrumentName) open var musicalInstrumentName: String? { get { _values["musicalInstrumentName"] as? String } set { _values["musicalInstrumentName"] = newValue } }
    @objc(namedLocation) open var namedLocation: String? { get { _values["namedLocation"] as? String } set { _values["namedLocation"] = newValue } }
    @objc(organizations) open var organizations: [String]? { get { _values["organizations"] as? [String] } set { _values["organizations"] = newValue } }
    @objc(orientation) open var orientation: NSNumber? { get { _values["orientation"] as? NSNumber } set { _values["orientation"] = newValue } }
    @objc(originalFormat) open var originalFormat: String? { get { _values["originalFormat"] as? String } set { _values["originalFormat"] = newValue } }
    @objc(originalSource) open var originalSource: String? { get { _values["originalSource"] as? String } set { _values["originalSource"] = newValue } }
    @objc(pageCount) open var pageCount: NSNumber? { get { _values["pageCount"] as? NSNumber } set { _values["pageCount"] = newValue } }
    @objc(pageHeight) open var pageHeight: NSNumber? { get { _values["pageHeight"] as? NSNumber } set { _values["pageHeight"] = newValue } }
    @objc(pageWidth) open var pageWidth: NSNumber? { get { _values["pageWidth"] as? NSNumber } set { _values["pageWidth"] = newValue } }
    @objc(participants) open var participants: [String]? { get { _values["participants"] as? [String] } set { _values["participants"] = newValue } }
    @objc(path) open var path: String? { get { _values["path"] as? String } set { _values["path"] = newValue } }
    @objc(performers) open var performers: [String]? { get { _values["performers"] as? [String] } set { _values["performers"] = newValue } }
    @objc(phoneNumbers) open var phoneNumbers: [String]? { get { _values["phoneNumbers"] as? [String] } set { _values["phoneNumbers"] = newValue } }
    @objc(pixelCount) open var pixelCount: NSNumber? { get { _values["pixelCount"] as? NSNumber } set { _values["pixelCount"] = newValue } }
    @objc(pixelHeight) open var pixelHeight: NSNumber? { get { _values["pixelHeight"] as? NSNumber } set { _values["pixelHeight"] = newValue } }
    @objc(pixelWidth) open var pixelWidth: NSNumber? { get { _values["pixelWidth"] as? NSNumber } set { _values["pixelWidth"] = newValue } }
    @objc(playCount) open var playCount: NSNumber? { get { _values["playCount"] as? NSNumber } set { _values["playCount"] = newValue } }
    @objc(postalCode) open var postalCode: String? { get { _values["postalCode"] as? String } set { _values["postalCode"] = newValue } }
    @objc(primaryRecipients) open var primaryRecipients: [CSPerson]? { get { _values["primaryRecipients"] as? [CSPerson] } set { _values["primaryRecipients"] = newValue } }
    @objc(producer) open var producer: String? { get { _values["producer"] as? String } set { _values["producer"] = newValue } }
    @objc(profileName) open var profileName: String? { get { _values["profileName"] as? String } set { _values["profileName"] = newValue } }
    @objc(projects) open var projects: [String]? { get { _values["projects"] as? [String] } set { _values["projects"] = newValue } }
    @objc(providerDataTypeIdentifiers) open var providerDataTypeIdentifiers: [String]? { get { _values["providerDataTypeIdentifiers"] as? [String] } set { _values["providerDataTypeIdentifiers"] = newValue } }
    @objc(providerFileTypeIdentifiers) open var providerFileTypeIdentifiers: [String]? { get { _values["providerFileTypeIdentifiers"] as? [String] } set { _values["providerFileTypeIdentifiers"] = newValue } }
    @objc(providerInPlaceFileTypeIdentifiers) open var providerInPlaceFileTypeIdentifiers: [String]? { get { _values["providerInPlaceFileTypeIdentifiers"] as? [String] } set { _values["providerInPlaceFileTypeIdentifiers"] = newValue } }
    @objc(publishers) open var publishers: [String]? { get { _values["publishers"] as? [String] } set { _values["publishers"] = newValue } }
    @objc(rankingHint) open var rankingHint: NSNumber? { get { _values["rankingHint"] as? NSNumber } set { _values["rankingHint"] = newValue } }
    @objc(rating) open var rating: NSNumber? { get { _values["rating"] as? NSNumber } set { _values["rating"] = newValue } }
    @objc(ratingDescription) open var ratingDescription: String? { get { _values["ratingDescription"] as? String } set { _values["ratingDescription"] = newValue } }
    @objc(recipientAddresses) open var recipientAddresses: [String]? { get { _values["recipientAddresses"] as? [String] } set { _values["recipientAddresses"] = newValue } }
    @objc(recipientEmailAddresses) open var recipientEmailAddresses: [String]? { get { _values["recipientEmailAddresses"] as? [String] } set { _values["recipientEmailAddresses"] = newValue } }
    @objc(recipientNames) open var recipientNames: [String]? { get { _values["recipientNames"] as? [String] } set { _values["recipientNames"] = newValue } }
    @objc(recordingDate) open var recordingDate: Date? { get { _values["recordingDate"] as? Date } set { _values["recordingDate"] = newValue } }
    @objc(redEyeOn) open var redEyeOn: NSNumber? { get { _values["redEyeOn"] as? NSNumber } set { _values["redEyeOn"] = newValue } }
    @objc(relatedUniqueIdentifier) open var relatedUniqueIdentifier: String? { get { _values["relatedUniqueIdentifier"] as? String } set { _values["relatedUniqueIdentifier"] = newValue } }
    @objc(resolutionHeightDPI) open var resolutionHeightDPI: NSNumber? { get { _values["resolutionHeightDPI"] as? NSNumber } set { _values["resolutionHeightDPI"] = newValue } }
    @objc(resolutionWidthDPI) open var resolutionWidthDPI: NSNumber? { get { _values["resolutionWidthDPI"] as? NSNumber } set { _values["resolutionWidthDPI"] = newValue } }
    @objc(rights) open var rights: String? { get { _values["rights"] as? String } set { _values["rights"] = newValue } }
    @objc(role) open var role: String? { get { _values["role"] as? String } set { _values["role"] = newValue } }
    @objc(securityMethod) open var securityMethod: String? { get { _values["securityMethod"] as? String } set { _values["securityMethod"] = newValue } }
    @objc(speed) open var speed: NSNumber? { get { _values["speed"] as? NSNumber } set { _values["speed"] = newValue } }
    @objc(startDate) open var startDate: Date? { get { _values["startDate"] as? Date } set { _values["startDate"] = newValue } }
    @objc(stateOrProvince) open var stateOrProvince: String? { get { _values["stateOrProvince"] as? String } set { _values["stateOrProvince"] = newValue } }
    @objc(streamable) open var streamable: NSNumber? { get { _values["streamable"] as? NSNumber } set { _values["streamable"] = newValue } }
    @objc(subThoroughfare) open var subThoroughfare: String? { get { _values["subThoroughfare"] as? String } set { _values["subThoroughfare"] = newValue } }
    @objc(subject) open var subject: String? { get { _values["subject"] as? String } set { _values["subject"] = newValue } }
    @objc(supportsNavigation) open var supportsNavigation: NSNumber? { get { _values["supportsNavigation"] as? NSNumber } set { _values["supportsNavigation"] = newValue } }
    @objc(supportsPhoneCall) open var supportsPhoneCall: NSNumber? { get { _values["supportsPhoneCall"] as? NSNumber } set { _values["supportsPhoneCall"] = newValue } }
    @objc(tempo) open var tempo: NSNumber? { get { _values["tempo"] as? NSNumber } set { _values["tempo"] = newValue } }
    @objc(textContent) open var textContent: String? { get { _values["textContent"] as? String } set { _values["textContent"] = newValue } }
    @objc(textContentSummary) open var textContentSummary: String? { get { _values["textContentSummary"] as? String } set { _values["textContentSummary"] = newValue } }
    @objc(theme) open var theme: String? { get { _values["theme"] as? String } set { _values["theme"] = newValue } }
    @objc(thoroughfare) open var thoroughfare: String? { get { _values["thoroughfare"] as? String } set { _values["thoroughfare"] = newValue } }
    @objc(thumbnailData) open var thumbnailData: Data? { get { _values["thumbnailData"] as? Data } set { _values["thumbnailData"] = newValue } }
    @objc(thumbnailURL) open var thumbnailURL: URL? { get { _values["thumbnailURL"] as? URL } set { _values["thumbnailURL"] = newValue } }
    @objc(timeSignature) open var timeSignature: String? { get { _values["timeSignature"] as? String } set { _values["timeSignature"] = newValue } }
    @objc(timestamp) open var timestamp: Date? { get { _values["timestamp"] as? Date } set { _values["timestamp"] = newValue } }
    @objc(title) open var title: String? { get { _values["title"] as? String } set { _values["title"] = newValue } }
    @objc(totalBitRate) open var totalBitRate: NSNumber? { get { _values["totalBitRate"] as? NSNumber } set { _values["totalBitRate"] = newValue } }
    @objc(transcribedTextContent) open var transcribedTextContent: String? { get { _values["transcribedTextContent"] as? String } set { _values["transcribedTextContent"] = newValue } }
    @objc(URL) open var url: URL? { get { _values["url"] as? URL } set { _values["url"] = newValue } }
    @objc(userCreated) open var userCreated: NSNumber? { get { _values["userCreated"] as? NSNumber } set { _values["userCreated"] = newValue } }
    @objc(userCurated) open var userCurated: NSNumber? { get { _values["userCurated"] as? NSNumber } set { _values["userCurated"] = newValue } }
    @objc(userOwned) open var userOwned: NSNumber? { get { _values["userOwned"] as? NSNumber } set { _values["userOwned"] = newValue } }
    @objc(version) open var version: String? { get { _values["version"] as? String } set { _values["version"] = newValue } }
    @objc(videoBitRate) open var videoBitRate: NSNumber? { get { _values["videoBitRate"] as? NSNumber } set { _values["videoBitRate"] = newValue } }
    @objc(weakRelatedUniqueIdentifier) open var weakRelatedUniqueIdentifier: String? { get { _values["weakRelatedUniqueIdentifier"] as? String } set { _values["weakRelatedUniqueIdentifier"] = newValue } }
    @objc(whiteBalance) open var whiteBalance: NSNumber? { get { _values["whiteBalance"] as? NSNumber } set { _values["whiteBalance"] = newValue } }
}

/// the property-list form of attribute values: strings, numbers, dates, data and arrays as they are; URLs, people and
/// localized strings as tagged dictionaries
enum _CSPlist {
    static func encode(_ v: Any) -> Any? {
        switch v {
        case let s as CSLocalizedString: return ["$localized": s._strings]
        case let s as String: return s
        case let n as NSNumber: return n
        case let d as Date: return d
        case let d as Data: return d
        case let u as URL: return ["$url": u.absoluteString]
        case let p as CSPerson: return p._plist
        case let b as Bool: return NSNumber(value: b)
        case let i as Int: return NSNumber(value: i)
        case let x as Double: return NSNumber(value: x)
        case let a as [Any]: return a.compactMap(encode)
        case let d as [String: Any]: return ["$dict": d.compactMapValues(encode)]
        default: return "\(v)"
        }
    }
    static func decode(_ v: Any) -> Any {
        if let a = v as? [Any] { return a.map(decode) }
        guard let d = v as? [String: Any] else { return v }
        if let u = d["$url"] as? String { return URL(string: u) ?? u }
        if let s = d["$localized"] as? [String: String] { return CSLocalizedString(localizedStrings: s) }
        if d["$person"] != nil { return CSPerson(_plist: d) }
        if let x = d["$dict"] as? [String: Any] { return x.mapValues(decode) }
        return d
    }
}

/// a person an item is from, to or about
@objc(CSPerson) open class CSPerson: NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {
    open private(set) var displayName: String?
    open private(set) var handles: [String]
    open private(set) var handleIdentifier: String
    open var contactIdentifier: String?
    public init(displayName: String?, handles: [String], handleIdentifier: String) {
        self.displayName = displayName; self.handles = handles; self.handleIdentifier = handleIdentifier
        super.init()
    }
    init(_plist d: [String: Any]) {
        displayName = d["displayName"] as? String; handles = d["handles"] as? [String] ?? []
        handleIdentifier = d["handleIdentifier"] as? String ?? ""; contactIdentifier = d["contactIdentifier"] as? String
        super.init()
    }
    var _plist: [String: Any] {
        var d: [String: Any] = ["$person": true, "handles": handles, "handleIdentifier": handleIdentifier]
        d["displayName"] = displayName; d["contactIdentifier"] = contactIdentifier
        return d
    }
    public static var supportsSecureCoding: Bool { true }
    public required convenience init?(coder: NSCoder) {
        guard let d = coder.decodeObject(forKey: "isim") as? [String: Any] else { return nil }
        self.init(_plist: d)
    }
    open func encode(with coder: NSCoder) { coder.encode(_plist as NSDictionary, forKey: "isim") }
    open func copy(with zone: NSZone? = nil) -> Any { CSPerson(_plist: _plist) }
    open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? CSPerson else { return false }
        return o.handles == handles && o.handleIdentifier == handleIdentifier && o.displayName == displayName
    }
    open override var hash: Int { handleIdentifier.hashValue ^ handles.count }
}

/// a custom attribute an app adds to its items (setValue(_:forCustomKey:)); queries find it by its key name
@objc(CSCustomAttributeKey) open class CSCustomAttributeKey: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    open private(set) var keyName: String
    open private(set) var isSearchable: Bool
    open private(set) var isSearchableByDefault: Bool
    open private(set) var isUnique: Bool
    open private(set) var isMultiValued: Bool
    public convenience init?(keyName: String) {
        self.init(keyName: keyName, searchable: true, searchableByDefault: false, unique: false, multiValued: false)
    }
    /// nil for a name Spotlight reserves (com.apple…, kMD…) or one with characters other than letters, digits, _ . -
    public init?(keyName: String, searchable: Bool, searchableByDefault: Bool, unique: Bool, multiValued: Bool) {
        let ok = !keyName.isEmpty && !keyName.hasPrefix("com.apple") && !keyName.hasPrefix("kMD")
            && keyName.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || "_.-".unicodeScalars.contains($0)) }
        guard ok else { return nil }
        self.keyName = keyName; isSearchable = searchable; isSearchableByDefault = searchableByDefault; isUnique = unique; isMultiValued = multiValued
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        guard let k = coder.decodeObject(forKey: "keyName") as? String else { return nil }
        keyName = k; isSearchable = coder.decodeBool(forKey: "searchable"); isSearchableByDefault = coder.decodeBool(forKey: "searchableByDefault")
        isUnique = coder.decodeBool(forKey: "unique"); isMultiValued = coder.decodeBool(forKey: "multiValued")
        super.init()
    }
    open func encode(with coder: NSCoder) {
        coder.encode(keyName, forKey: "keyName"); coder.encode(isSearchable, forKey: "searchable"); coder.encode(isSearchableByDefault, forKey: "searchableByDefault")
        coder.encode(isUnique, forKey: "unique"); coder.encode(isMultiValued, forKey: "multiValued")
    }
    open func copy(with zone: NSZone? = nil) -> Any {
        CSCustomAttributeKey(keyName: keyName, searchable: isSearchable, searchableByDefault: isSearchableByDefault, unique: isUnique, multiValued: isMultiValued)!
    }
}

/// a string in several languages: the one for the user's preferred language
@objc(CSLocalizedString) open class CSLocalizedString: NSString, @unchecked Sendable {
    var _strings: [String: String] = [:]
    public init(localizedStrings: [AnyHashable: Any]) {
        for (k, v) in localizedStrings { if let k = k as? String, let v = v as? String { _strings[k] = v } }
        super.init()
    }
    public required init?(coder: NSCoder) {
        _strings = coder.decodeObject(forKey: "strings") as? [String: String] ?? [:]
        super.init()
    }
    /// NSString's designated initializer (an empty string): the literal initializers are inherited
    public override init() { super.init() }
    open override func encode(with coder: NSCoder) { coder.encode(_strings as NSDictionary, forKey: "strings") }
    /// the string in the first preferred language it has (then its base language, English, any)
    open func localizedString() -> String {
        for lang in Locale.preferredLanguages {
            if let s = _strings[lang] { return s }
            if let base = lang.split(separator: "-").first, let s = _strings[String(base)] { return s }
        }
        return _strings["en"] ?? _strings.keys.sorted().first.flatMap { _strings[$0] } ?? ""
    }
    open override var length: Int { (localizedString() as NSString).length }
    open override func character(at index: Int) -> unichar { (localizedString() as NSString).character(at: index) }
}
