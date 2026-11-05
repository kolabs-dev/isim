// isim CoreSpotlight (iOS 27, issue #859): SpotlightSearchTool, a Foundation Models tool that searches the app's
// Spotlight index (and files in the folders it is given) for a model, and its pipeline: sources, custom stages and the
// replies the app can follow. Adapted: the model's arguments (a query, an optional grouping attribute and limit) run as a
// CSSearchQuery over isim's index; custom stages then transform the results in order, as their input and output types
// allow; each run is a reply on , and its summary is the tool's output to the model.
import Foundation
import FoundationModels

/// A Spotlight attribute a search can match, fetch or group by (its raw value is the attribute set's property name).
@available(iOS 27.0, *)
public struct SearchableItemAttribute: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let accountHandles = SearchableItemAttribute(rawValue: "accountHandles")
    public static let accountIdentifier = SearchableItemAttribute(rawValue: "accountIdentifier")
    public static let acquisitionMake = SearchableItemAttribute(rawValue: "acquisitionMake")
    public static let acquisitionModel = SearchableItemAttribute(rawValue: "acquisitionModel")
    public static let addedDate = SearchableItemAttribute(rawValue: "addedDate")
    public static let album = SearchableItemAttribute(rawValue: "album")
    public static let allDay = SearchableItemAttribute(rawValue: "allDay")
    public static let alternateNames = SearchableItemAttribute(rawValue: "alternateNames")
    public static let altitude = SearchableItemAttribute(rawValue: "altitude")
    public static let aperture = SearchableItemAttribute(rawValue: "aperture")
    public static let artist = SearchableItemAttribute(rawValue: "artist")
    public static let audiences = SearchableItemAttribute(rawValue: "audiences")
    public static let audioBitRate = SearchableItemAttribute(rawValue: "audioBitRate")
    public static let audioChannelCount = SearchableItemAttribute(rawValue: "audioChannelCount")
    public static let audioEncodingApplication = SearchableItemAttribute(rawValue: "audioEncodingApplication")
    public static let audioSampleRate = SearchableItemAttribute(rawValue: "audioSampleRate")
    public static let audioTrackNumber = SearchableItemAttribute(rawValue: "audioTrackNumber")
    public static let authorAddresses = SearchableItemAttribute(rawValue: "authorAddresses")
    public static let authorEmailAddresses = SearchableItemAttribute(rawValue: "authorEmailAddresses")
    public static let authorNames = SearchableItemAttribute(rawValue: "authorNames")
    public static let bitsPerSample = SearchableItemAttribute(rawValue: "bitsPerSample")
    public static let cameraOwner = SearchableItemAttribute(rawValue: "cameraOwner")
    public static let city = SearchableItemAttribute(rawValue: "city")
    public static let codecs = SearchableItemAttribute(rawValue: "codecs")
    public static let colorSpace = SearchableItemAttribute(rawValue: "colorSpace")
    public static let comment = SearchableItemAttribute(rawValue: "comment")
    public static let completionDate = SearchableItemAttribute(rawValue: "completionDate")
    public static let composer = SearchableItemAttribute(rawValue: "composer")
    public static let contactKeywords = SearchableItemAttribute(rawValue: "contactKeywords")
    public static let containerDisplayName = SearchableItemAttribute(rawValue: "containerDisplayName")
    public static let containerIdentifier = SearchableItemAttribute(rawValue: "containerIdentifier")
    public static let containerOrder = SearchableItemAttribute(rawValue: "containerOrder")
    public static let containerTitle = SearchableItemAttribute(rawValue: "containerTitle")
    public static let contentCreationDate = SearchableItemAttribute(rawValue: "contentCreationDate")
    public static let contentDescription = SearchableItemAttribute(rawValue: "contentDescription")
    public static let contentModificationDate = SearchableItemAttribute(rawValue: "contentModificationDate")
    public static let contentRating = SearchableItemAttribute(rawValue: "contentRating")
    public static let contentSources = SearchableItemAttribute(rawValue: "contentSources")
    public static let contentType = SearchableItemAttribute(rawValue: "contentType")
    public static let contentTypeTree = SearchableItemAttribute(rawValue: "contentTypeTree")
    public static let contentURL = SearchableItemAttribute(rawValue: "contentURL")
    public static let contributors = SearchableItemAttribute(rawValue: "contributors")
    public static let copyright = SearchableItemAttribute(rawValue: "copyright")
    public static let country = SearchableItemAttribute(rawValue: "country")
    public static let coverage = SearchableItemAttribute(rawValue: "coverage")
    public static let creator = SearchableItemAttribute(rawValue: "creator")
    public static let darkThumbnailURL = SearchableItemAttribute(rawValue: "darkThumbnailURL")
    public static let deliveryType = SearchableItemAttribute(rawValue: "deliveryType")
    public static let director = SearchableItemAttribute(rawValue: "director")
    public static let displayName = SearchableItemAttribute(rawValue: "displayName")
    public static let domainIdentifier = SearchableItemAttribute(rawValue: "domainIdentifier")
    public static let downloadedDate = SearchableItemAttribute(rawValue: "downloadedDate")
    public static let dueDate = SearchableItemAttribute(rawValue: "dueDate")
    public static let duration = SearchableItemAttribute(rawValue: "duration")
    public static let editors = SearchableItemAttribute(rawValue: "editors")
    public static let emailAddresses = SearchableItemAttribute(rawValue: "emailAddresses")
    public static let encodingApplications = SearchableItemAttribute(rawValue: "encodingApplications")
    public static let endDate = SearchableItemAttribute(rawValue: "endDate")
    public static let exifGPSVersion = SearchableItemAttribute(rawValue: "exifGPSVersion")
    public static let exifVersion = SearchableItemAttribute(rawValue: "exifVersion")
    public static let exposureMode = SearchableItemAttribute(rawValue: "exposureMode")
    public static let exposureProgram = SearchableItemAttribute(rawValue: "exposureProgram")
    public static let exposureTime = SearchableItemAttribute(rawValue: "exposureTime")
    public static let exposureTimeString = SearchableItemAttribute(rawValue: "exposureTimeString")
    public static let fNumber = SearchableItemAttribute(rawValue: "fNumber")
    public static let fileSize = SearchableItemAttribute(rawValue: "fileSize")
    public static let flashOn = SearchableItemAttribute(rawValue: "flashOn")
    public static let focalLength = SearchableItemAttribute(rawValue: "focalLength")
    public static let focalLength35mmEquivalent = SearchableItemAttribute(rawValue: "focalLength35mmEquivalent")
    public static let fontNames = SearchableItemAttribute(rawValue: "fontNames")
    public static let fullyFormattedAddress = SearchableItemAttribute(rawValue: "fullyFormattedAddress")
    public static let generalMIDISequence = SearchableItemAttribute(rawValue: "generalMIDISequence")
    public static let genre = SearchableItemAttribute(rawValue: "genre")
    public static let gpsAreaInformation = SearchableItemAttribute(rawValue: "gpsAreaInformation")
    public static let gpsDateStamp = SearchableItemAttribute(rawValue: "gpsDateStamp")
    public static let gpsDestinationBearing = SearchableItemAttribute(rawValue: "gpsDestinationBearing")
    public static let gpsDestinationDistance = SearchableItemAttribute(rawValue: "gpsDestinationDistance")
    public static let gpsDestinationLatitude = SearchableItemAttribute(rawValue: "gpsDestinationLatitude")
    public static let gpsDestinationLongitude = SearchableItemAttribute(rawValue: "gpsDestinationLongitude")
    public static let gpsDifferential = SearchableItemAttribute(rawValue: "gpsDifferential")
    public static let gpsDilutionOfPrecision = SearchableItemAttribute(rawValue: "gpsDilutionOfPrecision")
    public static let gpsMapDatum = SearchableItemAttribute(rawValue: "gpsMapDatum")
    public static let gpsMeasureMode = SearchableItemAttribute(rawValue: "gpsMeasureMode")
    public static let gpsProcessingMethod = SearchableItemAttribute(rawValue: "gpsProcessingMethod")
    public static let gpsStatus = SearchableItemAttribute(rawValue: "gpsStatus")
    public static let gpsTrack = SearchableItemAttribute(rawValue: "gpsTrack")
    public static let hasAlphaChannel = SearchableItemAttribute(rawValue: "hasAlphaChannel")
    public static let headline = SearchableItemAttribute(rawValue: "headline")
    public static let identifier = SearchableItemAttribute(rawValue: "identifier")
    public static let imageDirection = SearchableItemAttribute(rawValue: "imageDirection")
    public static let importantDates = SearchableItemAttribute(rawValue: "importantDates")
    public static let information = SearchableItemAttribute(rawValue: "information")
    public static let instantMessageAddresses = SearchableItemAttribute(rawValue: "instantMessageAddresses")
    public static let instructions = SearchableItemAttribute(rawValue: "instructions")
    public static let isoSpeed = SearchableItemAttribute(rawValue: "isoSpeed")
    public static let keySignature = SearchableItemAttribute(rawValue: "keySignature")
    public static let keywords = SearchableItemAttribute(rawValue: "keywords")
    public static let kind = SearchableItemAttribute(rawValue: "kind")
    public static let languages = SearchableItemAttribute(rawValue: "languages")
    public static let lastUsedDate = SearchableItemAttribute(rawValue: "lastUsedDate")
    public static let latitude = SearchableItemAttribute(rawValue: "latitude")
    public static let layerNames = SearchableItemAttribute(rawValue: "layerNames")
    public static let lensModel = SearchableItemAttribute(rawValue: "lensModel")
    public static let likelyJunk = SearchableItemAttribute(rawValue: "likelyJunk")
    public static let local = SearchableItemAttribute(rawValue: "local")
    public static let longitude = SearchableItemAttribute(rawValue: "longitude")
    public static let lyricist = SearchableItemAttribute(rawValue: "lyricist")
    public static let mailboxIdentifiers = SearchableItemAttribute(rawValue: "mailboxIdentifiers")
    public static let maximumAperture = SearchableItemAttribute(rawValue: "maximumAperture")
    public static let mediaTypes = SearchableItemAttribute(rawValue: "mediaTypes")
    public static let metadataModificationDate = SearchableItemAttribute(rawValue: "metadataModificationDate")
    public static let meteringMode = SearchableItemAttribute(rawValue: "meteringMode")
    public static let musicalGenre = SearchableItemAttribute(rawValue: "musicalGenre")
    public static let musicalInstrumentCategory = SearchableItemAttribute(rawValue: "musicalInstrumentCategory")
    public static let musicalInstrumentName = SearchableItemAttribute(rawValue: "musicalInstrumentName")
    public static let namedLocation = SearchableItemAttribute(rawValue: "namedLocation")
    public static let organizations = SearchableItemAttribute(rawValue: "organizations")
    public static let orientation = SearchableItemAttribute(rawValue: "orientation")
    public static let originalFormat = SearchableItemAttribute(rawValue: "originalFormat")
    public static let originalSource = SearchableItemAttribute(rawValue: "originalSource")
    public static let pageCount = SearchableItemAttribute(rawValue: "pageCount")
    public static let pageHeight = SearchableItemAttribute(rawValue: "pageHeight")
    public static let pageWidth = SearchableItemAttribute(rawValue: "pageWidth")
    public static let participants = SearchableItemAttribute(rawValue: "participants")
    public static let path = SearchableItemAttribute(rawValue: "path")
    public static let performers = SearchableItemAttribute(rawValue: "performers")
    public static let phoneNumbers = SearchableItemAttribute(rawValue: "phoneNumbers")
    public static let pixelCount = SearchableItemAttribute(rawValue: "pixelCount")
    public static let pixelHeight = SearchableItemAttribute(rawValue: "pixelHeight")
    public static let pixelWidth = SearchableItemAttribute(rawValue: "pixelWidth")
    public static let playCount = SearchableItemAttribute(rawValue: "playCount")
    public static let postalCode = SearchableItemAttribute(rawValue: "postalCode")
    public static let producer = SearchableItemAttribute(rawValue: "producer")
    public static let profileName = SearchableItemAttribute(rawValue: "profileName")
    public static let projects = SearchableItemAttribute(rawValue: "projects")
    public static let publishers = SearchableItemAttribute(rawValue: "publishers")
    public static let rankingHint = SearchableItemAttribute(rawValue: "rankingHint")
    public static let rating = SearchableItemAttribute(rawValue: "rating")
    public static let ratingDescription = SearchableItemAttribute(rawValue: "ratingDescription")
    public static let recipientAddresses = SearchableItemAttribute(rawValue: "recipientAddresses")
    public static let recipientEmailAddresses = SearchableItemAttribute(rawValue: "recipientEmailAddresses")
    public static let recipientNames = SearchableItemAttribute(rawValue: "recipientNames")
    public static let recordingDate = SearchableItemAttribute(rawValue: "recordingDate")
    public static let redEyeOn = SearchableItemAttribute(rawValue: "redEyeOn")
    public static let relatedUniqueIdentifier = SearchableItemAttribute(rawValue: "relatedUniqueIdentifier")
    public static let resolutionHeightDPI = SearchableItemAttribute(rawValue: "resolutionHeightDPI")
    public static let resolutionWidthDPI = SearchableItemAttribute(rawValue: "resolutionWidthDPI")
    public static let rights = SearchableItemAttribute(rawValue: "rights")
    public static let role = SearchableItemAttribute(rawValue: "role")
    public static let securityMethod = SearchableItemAttribute(rawValue: "securityMethod")
    public static let speed = SearchableItemAttribute(rawValue: "speed")
    public static let startDate = SearchableItemAttribute(rawValue: "startDate")
    public static let stateOrProvince = SearchableItemAttribute(rawValue: "stateOrProvince")
    public static let streamable = SearchableItemAttribute(rawValue: "streamable")
    public static let subThoroughfare = SearchableItemAttribute(rawValue: "subThoroughfare")
    public static let subject = SearchableItemAttribute(rawValue: "subject")
    public static let supportsNavigation = SearchableItemAttribute(rawValue: "supportsNavigation")
    public static let supportsPhoneCall = SearchableItemAttribute(rawValue: "supportsPhoneCall")
    public static let tempo = SearchableItemAttribute(rawValue: "tempo")
    public static let textContent = SearchableItemAttribute(rawValue: "textContent")
    public static let theme = SearchableItemAttribute(rawValue: "theme")
    public static let thoroughfare = SearchableItemAttribute(rawValue: "thoroughfare")
    public static let thumbnailData = SearchableItemAttribute(rawValue: "thumbnailData")
    public static let thumbnailURL = SearchableItemAttribute(rawValue: "thumbnailURL")
    public static let timeSignature = SearchableItemAttribute(rawValue: "timeSignature")
    public static let timestamp = SearchableItemAttribute(rawValue: "timestamp")
    public static let title = SearchableItemAttribute(rawValue: "title")
    public static let totalBitRate = SearchableItemAttribute(rawValue: "totalBitRate")
    public static let url = SearchableItemAttribute(rawValue: "url")
    public static let userCreated = SearchableItemAttribute(rawValue: "userCreated")
    public static let userCurated = SearchableItemAttribute(rawValue: "userCurated")
    public static let userOwned = SearchableItemAttribute(rawValue: "userOwned")
    public static let version = SearchableItemAttribute(rawValue: "version")
    public static let videoBitRate = SearchableItemAttribute(rawValue: "videoBitRate")
    public static let weakRelatedUniqueIdentifier = SearchableItemAttribute(rawValue: "weakRelatedUniqueIdentifier")
    public static let whiteBalance = SearchableItemAttribute(rawValue: "whiteBalance")
}

/// One found item.
@available(iOS 27.0, *)
public struct SearchableItem: @unchecked Sendable, Hashable {
    public let item: CSSearchableItem
    init(_ item: CSSearchableItem) { self.item = item }
    public static func == (a: SearchableItem, b: SearchableItem) -> Bool { a.item.uniqueIdentifier == b.item.uniqueIdentifier }
    public func hash(into h: inout Hasher) { h.combine(item.uniqueIdentifier) }
    /// a value of the item for an attribute
    func _value(_ a: SearchableItemAttribute) -> Any? { item.attributeSet._value(a.rawValue) }
    var _title: String { item.attributeSet.title ?? item.attributeSet.displayName ?? item.uniqueIdentifier }
}
/// A found item with how well it matches.
@available(iOS 27.0, *)
public struct ScoredSearchableItem: Sendable, Hashable {
    public let item: SearchableItem
    public let score: Double
    public init(item: SearchableItem, score: Double) { self.item = item; self.score = score }
}
@available(iOS 27.0, *)
public struct SearchCount: Sendable, Hashable {
    public let value: Int
    public let header: String?
    public init(value: Int, header: String? = nil) { self.value = value; self.header = header }
}
@available(iOS 27.0, *)
public struct SearchStatistic: Sendable, Hashable {
    public let name: String
    public let value: Double
    public let header: String?
    public init(name: String, value: Double, header: String? = nil) { self.name = name; self.value = value; self.header = header }
}
@available(iOS 27.0, *)
public struct SearchTextResult: Sendable, Hashable {
    public let body: String
    public let header: String?
    public init(body: String, header: String? = nil) { self.body = body; self.header = header }
}
/// Results as a table.
@available(iOS 27.0, *)
public struct SearchResultsTable: Sendable, Hashable {
    public enum ValueType: Sendable, Hashable { case string, integer, double, boolean, date }
    public enum Value: Sendable, Hashable { case string(String), integer(Int), double(Double), boolean(Bool), date(Date), none }
    public struct Column: Sendable, Hashable {
        public let name: String
        public let type: ValueType
        public init(name: String, type: ValueType) { self.name = name; self.type = type }
    }
    public struct Row: Sendable, Hashable {
        public let values: [Value]
        public init(values: [Value]) { self.values = values }
    }
    public let header: String?
    public let columns: [Column]
    public let rows: [Row]
    public init(header: String? = nil, columns: [Column], rows: [Row]) { self.header = header; self.columns = columns; self.rows = rows }
}

/// The kind of data a pipeline stage takes or makes.
@available(iOS 27.0, *)
public enum SearchPipelineDataType: Sendable, Hashable, Codable, CaseIterable { case items, scoredItems, groupedItems, count, statistic, table, text }
/// What flows between the stages of a search.
@available(iOS 27.0, *)
public struct SearchPipelineData: Sendable {
    public enum Payload: Sendable {
        case items([SearchableItem])
        case scoredItems([ScoredSearchableItem])
        case groupedItems([SearchableItemAttribute: [SearchableItem]])
        case count(Int)
        case statistic(name: String, value: Double)
        case table(SearchResultsTable)
        case text(String)
    }
    public let payload: Payload
    public init(payload: Payload) { self.payload = payload }
    public static func items(_ items: [SearchableItem]) -> SearchPipelineData { .init(payload: .items(items)) }
    public static func scoredItems(_ items: [ScoredSearchableItem]) -> SearchPipelineData { .init(payload: .scoredItems(items)) }
    public static func groupedItems(_ groups: [SearchableItemAttribute: [SearchableItem]]) -> SearchPipelineData { .init(payload: .groupedItems(groups)) }
    public static func count(_ n: Int) -> SearchPipelineData { .init(payload: .count(n)) }
    public static func statistic(name: String, value: Double) -> SearchPipelineData { .init(payload: .statistic(name: name, value: value)) }
    public static func table(_ t: SearchResultsTable) -> SearchPipelineData { .init(payload: .table(t)) }
    public static func text(_ s: String) -> SearchPipelineData { .init(payload: .text(s)) }
    var _type: SearchPipelineDataType {
        switch payload {
        case .items: return .items; case .scoredItems: return .scoredItems; case .groupedItems: return .groupedItems
        case .count: return .count; case .statistic: return .statistic; case .table: return .table; case .text: return .text
        }
    }
}

/// A step the app adds to the search pipeline (the model can ask for it by name).
@available(iOS 27.0, *)
public protocol CustomStage: Generable, Codable, Sendable {
    static var name: String { get }
    static var description: String { get }
    static var inputTypes: [SearchPipelineDataType] { get }
    static var outputType: SearchPipelineDataType { get }
    func execute(items: [SearchableItem]) async throws -> SearchPipelineData
    func execute(scoredItems: [ScoredSearchableItem]) async throws -> SearchPipelineData
    func execute(groupedItems: [SearchableItemAttribute: [SearchableItem]]) async throws -> SearchPipelineData
    func execute(count: Int) async throws -> SearchPipelineData
    func execute(statistic: String, value: Double) async throws -> SearchPipelineData
    func execute(table: SearchResultsTable) async throws -> SearchPipelineData
    func execute(text: String) async throws -> SearchPipelineData
}
@available(iOS 27.0, *)
extension CustomStage {
    public static var name: String { String(describing: Self.self) }
    public static var description: String { "" }
    /// the input as it is (a stage implements the inputs it takes)
    public func execute(items: [SearchableItem]) async throws -> SearchPipelineData { .items(items) }
    public func execute(scoredItems: [ScoredSearchableItem]) async throws -> SearchPipelineData { .scoredItems(scoredItems) }
    public func execute(groupedItems: [SearchableItemAttribute: [SearchableItem]]) async throws -> SearchPipelineData { .groupedItems(groupedItems) }
    public func execute(count: Int) async throws -> SearchPipelineData { .count(count) }
    public func execute(statistic: String, value: Double) async throws -> SearchPipelineData { .statistic(name: statistic, value: value) }
    public func execute(table: SearchResultsTable) async throws -> SearchPipelineData { .table(table) }
    public func execute(text: String) async throws -> SearchPipelineData { .text(text) }
    func _run(_ d: SearchPipelineData) async throws -> SearchPipelineData {
        switch d.payload {
        case .items(let x): return try await execute(items: x)
        case .scoredItems(let x): return try await execute(scoredItems: x)
        case .groupedItems(let x): return try await execute(groupedItems: x)
        case .count(let x): return try await execute(count: x)
        case .statistic(let n, let v): return try await execute(statistic: n, value: v)
        case .table(let x): return try await execute(table: x)
        case .text(let x): return try await execute(text: x)
        }
    }
}

/// The person the search is for ("my notes"): their names and addresses.
@available(iOS 27.0, *)
public struct ResolvedContact: Sendable, Hashable {
    public var displayName: String
    public var names: [String] = []
    public var nameComponents: [PersonNameComponents] = []
    public var emailAddresses: [String] = []
    public var phoneNumbers: [String] = []
    public init(displayName: String) { self.displayName = displayName; names = [displayName] }
}
@available(iOS 27.0, *)
public protocol ContactResolver: Sendable {
    func userIdentity() -> ResolvedContact
}

/// The app's Spotlight index as a source.
@available(iOS 27.0, *)
public struct CoreSpotlightSource: @unchecked Sendable {
    public var searchableIndexDelegate: (any CSSearchableIndexDelegate)?
    public var fetchAttributes: [SearchableItemAttribute]
    public var maximumResultCount: Int?
    public init(fetchAttributes: [SearchableItemAttribute] = []) { self.init(searchableIndexDelegate: nil, fetchAttributes: fetchAttributes) }
    public init(searchableIndexDelegate: (any CSSearchableIndexDelegate)? = nil, fetchAttributes: [SearchableItemAttribute] = []) {
        self.searchableIndexDelegate = searchableIndexDelegate; self.fetchAttributes = fetchAttributes
    }
}
/// Files in folders as a source (by name).
@available(iOS 27.0, *)
public struct FileSource: Sendable {
    public var scopes: [URL] = []
    public var fetchAttributes: [SearchableItemAttribute]
    public var maximumResultCount: Int?
    public init(fetchAttributes: [SearchableItemAttribute] = []) { self.fetchAttributes = fetchAttributes }
}
@available(iOS 27.0, *)
public struct SearchSource: @unchecked Sendable {
    enum _Kind { case spotlight(CoreSpotlightSource), files(FileSource) }
    let _kind: _Kind
    public static func coreSpotlight(_ source: CoreSpotlightSource) -> SearchSource { SearchSource(_kind: .spotlight(source)) }
    public static var coreSpotlight: SearchSource { .coreSpotlight(CoreSpotlightSource()) }
    public static func files(_ source: FileSource) -> SearchSource { SearchSource(_kind: .files(source)) }
    public static var files: SearchSource { .files(FileSource()) }
}

// MARK: - the tool

@available(iOS 27.0, *)
public struct SpotlightSearchTool: Tool, @unchecked Sendable {
    public typealias Arguments = GeneratedContent
    /// How the tool describes searching to the model.
    public enum FormatLevel: Sendable, Hashable { case compact, structured }
    public struct GuidanceProfile: Sendable, Hashable {
        public var textMatch: Bool?
        public var similarityMatch: Bool?
        public var numericMatch: Bool?
        public var dates: Bool?
        public var people: Bool?
        public var contentType: Bool?
        public var attributes: [SearchableItemAttribute]?
        public init(textMatch: Bool? = nil, similarityMatch: Bool? = nil, numericMatch: Bool? = nil, dates: Bool? = nil, people: Bool? = nil,
                    contentType: Bool? = nil, attributes: [SearchableItemAttribute]? = nil) {
            self.textMatch = textMatch; self.similarityMatch = similarityMatch; self.numericMatch = numericMatch; self.dates = dates
            self.people = people; self.contentType = contentType; self.attributes = attributes
        }
    }
    /// The kind of content the app's index holds, and the attributes that play each role.
    public struct ContentDomain: Sendable, Hashable {
        public struct Items: Sendable, Hashable {
            public var title: [SearchableItemAttribute]?, text: [SearchableItemAttribute]?, created: [SearchableItemAttribute]?, modified: [SearchableItemAttribute]?
            public init(title: [SearchableItemAttribute]? = nil, text: [SearchableItemAttribute]? = nil, created: [SearchableItemAttribute]? = nil,
                        modified: [SearchableItemAttribute]? = nil) { self.title = title; self.text = text; self.created = created; self.modified = modified }
        }
        public struct Documents: Sendable, Hashable {
            public var authors: [SearchableItemAttribute]?, keywords: [SearchableItemAttribute]?, created: [SearchableItemAttribute]?, modified: [SearchableItemAttribute]?
            public init(authors: [SearchableItemAttribute]? = nil, keywords: [SearchableItemAttribute]? = nil, created: [SearchableItemAttribute]? = nil,
                        modified: [SearchableItemAttribute]? = nil) { self.authors = authors; self.keywords = keywords; self.created = created; self.modified = modified }
        }
        public struct Communications: Sendable, Hashable {
            public var authors: [SearchableItemAttribute]?, recipients: [SearchableItemAttribute]?, sent: [SearchableItemAttribute]?
            public var received: [SearchableItemAttribute]?, topic: [SearchableItemAttribute]?
            public init(authors: [SearchableItemAttribute]? = nil, recipients: [SearchableItemAttribute]? = nil, sent: [SearchableItemAttribute]? = nil,
                        received: [SearchableItemAttribute]? = nil, topic: [SearchableItemAttribute]? = nil) {
                self.authors = authors; self.recipients = recipients; self.sent = sent; self.received = received; self.topic = topic
            }
        }
        public struct Calendar: Sendable, Hashable {
            public var organizer: [SearchableItemAttribute]?, attendees: [SearchableItemAttribute]?, location: [SearchableItemAttribute]?, date: [SearchableItemAttribute]?
            public init(organizer: [SearchableItemAttribute]? = nil, attendees: [SearchableItemAttribute]? = nil, location: [SearchableItemAttribute]? = nil,
                        date: [SearchableItemAttribute]? = nil) { self.organizer = organizer; self.attendees = attendees; self.location = location; self.date = date }
        }
        public struct VisualMedia: Sendable, Hashable {
            public var people: [SearchableItemAttribute]?, description: [SearchableItemAttribute]?, location: [SearchableItemAttribute]?, date: [SearchableItemAttribute]?
            public init(people: [SearchableItemAttribute]? = nil, description: [SearchableItemAttribute]? = nil, location: [SearchableItemAttribute]? = nil,
                        date: [SearchableItemAttribute]? = nil) { self.people = people; self.description = description; self.location = location; self.date = date }
        }
        public struct Audio: Sendable, Hashable {
            public var artist: [SearchableItemAttribute]?, album: [SearchableItemAttribute]?, transcription: [SearchableItemAttribute]?, date: [SearchableItemAttribute]?
            public init(artist: [SearchableItemAttribute]? = nil, album: [SearchableItemAttribute]? = nil, transcription: [SearchableItemAttribute]? = nil,
                        date: [SearchableItemAttribute]? = nil) { self.artist = artist; self.album = album; self.transcription = transcription; self.date = date }
        }
        let _name: String
        let _attributes: [SearchableItemAttribute]
        static func _make(_ name: String, _ lists: [[SearchableItemAttribute]?]) -> ContentDomain { ContentDomain(_name: name, _attributes: lists.compactMap { $0 }.flatMap { $0 }) }
        public static func items(_ c: Items) -> ContentDomain { _make("items", [c.title, c.text, c.created, c.modified]) }
        public static var items: ContentDomain { items(Items(title: [.title, .displayName], text: [.textContent, .contentDescription], created: [.contentCreationDate], modified: [.contentModificationDate])) }
        public static func documents(_ c: Documents) -> ContentDomain { _make("documents", [c.authors, c.keywords, c.created, c.modified]) }
        public static var documents: ContentDomain { documents(Documents(authors: [.authorNames], keywords: [.keywords], created: [.contentCreationDate], modified: [.contentModificationDate])) }
        public static func communications(_ c: Communications) -> ContentDomain { _make("communications", [c.authors, c.recipients, c.sent, c.received, c.topic]) }
        public static var communications: ContentDomain { communications(Communications(authors: [.authorNames], recipients: [.recipientNames], topic: [.subject])) }
        public static func calendar(_ c: Calendar) -> ContentDomain { _make("calendar", [c.organizer, c.attendees, c.location, c.date]) }
        public static var calendar: ContentDomain { calendar(Calendar(organizer: [.authorNames], attendees: [.participants], location: [.namedLocation], date: [.startDate, .endDate])) }
        public static func visualMedia(_ c: VisualMedia) -> ContentDomain { _make("visualMedia", [c.people, c.description, c.location, c.date]) }
        public static var visualMedia: ContentDomain { visualMedia(VisualMedia(people: [.participants], description: [.contentDescription], location: [.namedLocation], date: [.contentCreationDate])) }
        public static func audio(_ c: Audio) -> ContentDomain { _make("audio", [c.artist, c.album, c.transcription, c.date]) }
        public static var audio: ContentDomain { audio(Audio(artist: [.artist], album: [.album], transcription: [.textContent], date: [.recordingDate])) }
    }
    public enum GuidanceLevel: Sendable, Hashable {
        case complete
        case focused(ContentDomain = .items)
        case dynamic(GuidanceProfile)
    }
    /// How much the tool tells the model about searching.
    public struct Guide: Sendable, Hashable {
        public let level: GuidanceLevel
        public let format: FormatLevel
        public init(level: GuidanceLevel = .complete, format: FormatLevel = .structured) { self.level = level; self.format = format }
        public static var complete: Guide { Guide(level: .complete) }
        public static func focused(_ domain: ContentDomain = .items) -> Guide { Guide(level: .focused(domain)) }
        public static func dynamic(_ profile: GuidanceProfile) -> Guide { Guide(level: .dynamic(profile)) }
    }
    public struct Configuration: @unchecked Sendable {
        public var sources: [SearchSource]
        public var guide: Guide?
        public var contactResolver: (any ContactResolver)?
        public var customStages: [any CustomStage]
        public var maximumResponseSize: Int?
        public init(sources: [SearchSource] = [], guide: Guide? = nil, contactResolver: (any ContactResolver)? = nil,
                    customStages: [any CustomStage] = [], maximumResponseSize: Int? = nil) {
            self.sources = sources; self.guide = guide; self.contactResolver = contactResolver; self.customStages = customStages
            self.maximumResponseSize = maximumResponseSize
        }
    }
    /// One search the model ran, and what it found.
    public struct SearchReply: @unchecked Sendable {
        public enum Status: Sendable, Hashable { case complete, partial }
        public enum Content: @unchecked Sendable {
            case items([SearchableItem])
            case scoredItems([ScoredSearchableItem])
            case groupedItems([SearchableItemAttribute: [SearchableItem]])
            case count(SearchCount)
            case statistic(SearchStatistic)
            case table(SearchResultsTable)
            case text(SearchTextResult)
        }
        public struct QueryToken: Sendable, Hashable { let _id: UUID }
        public struct StageToken: Sendable, Hashable { let _id: UUID }
        public let content: Content
        public let label: String?
        public let status: Status
        public let queryToken: QueryToken
        public let stageToken: StageToken
    }

    public let configuration: Configuration
    public var name: String = "searchSpotlight"
    final class _Replies: @unchecked Sendable {
        let stream: AsyncStream<SearchReply>
        let continuation: AsyncStream<SearchReply>.Continuation
        init() { (stream, continuation) = AsyncStream<SearchReply>.makeStream(bufferingPolicy: .unbounded) }
    }
    let _replies = _Replies()
    public init(configuration: Configuration = Configuration(sources: [.coreSpotlight])) { self.configuration = configuration }
    /// every search's reply, as the model runs them
    public var searchResults: some AsyncSequence<SearchReply, Never> { _replies.stream }

    public var description: String {
        var d = "Searches the app's content in Spotlight. Pass query (words to find, or a Spotlight query such as title == \"*trip*\"cd),"
            + " optionally groupBy (an attribute name) and limit."
        if let g = configuration.guide {
            switch g.level {
            case .complete: break
            case .focused(let domain): d += " The content is \(domain._name); useful attributes: \(domain._attributes.map(\.rawValue).joined(separator: ", "))."
            case .dynamic(let p): if let a = p.attributes { d += " Useful attributes: \(a.map(\.rawValue).joined(separator: ", "))." }
            }
        }
        if let me = configuration.contactResolver?.userIdentity() { d += " \"Me\" is \(me.displayName)." }
        let stages = configuration.customStages.map { type(of: $0) }
        if !stages.isEmpty { d += " Its results then go through: " + stages.map { "\($0.name) (\($0.description))" }.joined(separator: "; ") + "." }
        return d
    }
    public var includesSchemaInInstructions: Bool { true }
    public var parameters: GenerationSchema {
        (try? GenerationSchema(root: DynamicGenerationSchema(name: "SpotlightSearch", description: "A Spotlight search", properties: [
            .init(name: "query", description: "Words to find, or a Spotlight query", schema: DynamicGenerationSchema(type: String.self)),
            .init(name: "groupBy", description: "An attribute to group the results by", schema: DynamicGenerationSchema(type: String.self), isOptional: true),
            .init(name: "limit", description: "At most this many results", schema: DynamicGenerationSchema(type: Int.self), isOptional: true),
        ]), dependencies: [])) ?? GeneratedContent.generationSchema
    }

    public func call(arguments: GeneratedContent) async throws -> String {
        let query = (try? arguments.value(String.self, forProperty: "query")) ?? ""
        let group = (try? arguments.value(String?.self, forProperty: "groupBy")) ?? nil
        let limit = (try? arguments.value(Int?.self, forProperty: "limit")) ?? nil
        var items: [SearchableItem] = []
        let sources = configuration.sources.isEmpty ? [SearchSource.coreSpotlight] : configuration.sources
        for s in sources {
            switch s._kind {
            case .spotlight(let src):
                let ctx = CSSearchQueryContext()
                ctx.fetchAttributes = src.fetchAttributes.map(\.rawValue)
                var found = (try? CSSearchQuery(queryString: _isimSpotlightQuery(query), queryContext: ctx)._matches()) ?? []
                if let m = src.maximumResultCount { found = Array(found.prefix(m)) }
                items += found.map(SearchableItem.init)
            case .files(let src):
                items += _isimFiles(query, src)
            }
        }
        if let limit { items = Array(items.prefix(limit)) }
        var data: SearchPipelineData = .items(items)
        if let g = group {
            let a = SearchableItemAttribute(rawValue: g)
            data = .groupedItems(Dictionary(grouping: items) { _ in a })
        }
        for stage in configuration.customStages where type(of: stage).inputTypes.contains(data._type) {
            data = try await stage._run(data)
        }
        let reply = SearchReply(content: _isimContent(data), label: query, status: .complete, queryToken: .init(_id: UUID()), stageToken: .init(_id: UUID()))
        _replies.continuation.yield(reply)
        var out = _isimSummary(data)
        if let max = configuration.maximumResponseSize, out.count > max { out = String(out.prefix(max)) }
        return out
    }
}

/// words to a Spotlight query over the usual text attributes; a query in Spotlight's own syntax as it is
@available(iOS 27.0, *)
func _isimSpotlightQuery(_ q: String) -> String {
    let trimmed = q.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return "true" }
    if trimmed.contains("==") || trimmed.contains("!=") || trimmed.contains("<") || trimmed.contains(">") { return trimmed }
    let fields = ["title", "displayName", "contentDescription", "textContent", "keywords"]
    return trimmed.split(separator: " ").map { w in
        let word = w.replacingOccurrences(of: "\"", with: "")
        return "(" + fields.map { "\($0) == \"*\(word)*\"cd" }.joined(separator: " || ") + ")"
    }.joined(separator: " && ")
}
@available(iOS 27.0, *)
func _isimFiles(_ q: String, _ src: FileSource) -> [SearchableItem] {
    let words = q.lowercased().split(separator: " ").map(String.init)
    var out: [SearchableItem] = []
    for scope in src.scopes {
        guard let e = FileManager.default.enumerator(at: scope, includingPropertiesForKeys: nil) else { continue }
        for case let url as URL in e {
            let name = url.lastPathComponent.lowercased()
            guard words.allSatisfy({ name.contains($0) }) else { continue }
            let a = CSSearchableItemAttributeSet(contentType: .item)
            a.displayName = url.lastPathComponent; a.title = url.lastPathComponent; a.contentURL = url; a.path = url.path
            out.append(SearchableItem(CSSearchableItem(uniqueIdentifier: url.path, domainIdentifier: "files", attributeSet: a)))
            if let m = src.maximumResultCount, out.count >= m { return out }
        }
    }
    return out
}
@available(iOS 27.0, *)
func _isimContent(_ d: SearchPipelineData) -> SpotlightSearchTool.SearchReply.Content {
    switch d.payload {
    case .items(let x): return .items(x)
    case .scoredItems(let x): return .scoredItems(x)
    case .groupedItems(let x): return .groupedItems(x)
    case .count(let n): return .count(SearchCount(value: n))
    case .statistic(let n, let v): return .statistic(SearchStatistic(name: n, value: v))
    case .table(let t): return .table(t)
    case .text(let s): return .text(SearchTextResult(body: s))
    }
}
/// what the model reads
@available(iOS 27.0, *)
func _isimSummary(_ d: SearchPipelineData) -> String {
    func line(_ i: SearchableItem) -> String {
        let a = i.item.attributeSet
        return "- \(i._title)" + (a.contentDescription.map { ": \($0)" } ?? "")
    }
    func cell(_ v: SearchResultsTable.Value) -> String {
        switch v {
        case .string(let s): return s
        case .integer(let i): return "\(i)"
        case .double(let x): return "\(x)"
        case .boolean(let b): return "\(b)"
        case .date(let d): return d.formatted()
        case .none: return ""
        }
    }
    switch d.payload {
    case .items(let x): return x.isEmpty ? "No results." : "\(x.count) result(s):\n" + x.map(line).joined(separator: "\n")
    case .scoredItems(let x): return "\(x.count) result(s):\n" + x.map { line($0.item) + " (score \($0.score))" }.joined(separator: "\n")
    case .groupedItems(let g): return g.map { k, v in "\(k.rawValue):\n" + v.map(line).joined(separator: "\n") }.joined(separator: "\n")
    case .count(let n): return "\(n) result(s)."
    case .statistic(let n, let v): return "\(n): \(v)"
    case .table(let t):
        return ([t.columns.map(\.name).joined(separator: " | ")] + t.rows.map { $0.values.map(cell).joined(separator: " | ") }).joined(separator: "\n")
    case .text(let s): return s
    }
}

// MARK: - the index's description (iOS 18, a class as in Apple's SDK)

/// The index an IndexedEntityQuery reindexes.
@available(iOS 18.0, *)
@objc(CSSearchableIndexDescription) open class CSSearchableIndexDescription: NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {
    let _name: String
    let _protection: FileProtectionType?
    init(name: String, protectionClass: FileProtectionType? = nil) { _name = name; _protection = protectionClass; super.init() }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        _name = coder.decodeObject(forKey: "name") as? String ?? "default"
        _protection = (coder.decodeObject(forKey: "protectionClass") as? String).map(FileProtectionType.init(rawValue:))
        super.init()
    }
    open func encode(with coder: NSCoder) {
        coder.encode(_name, forKey: "name")
        if let p = _protection { coder.encode(p.rawValue, forKey: "protectionClass") }
    }
    open func copy(with zone: NSZone? = nil) -> Any { CSSearchableIndexDescription(name: _name, protectionClass: _protection) }
    /// the file protection of the index's items
    @available(iOS 27.0, *)
    open var protectionClass: FileProtectionType? { _protection }
    /// the index's name ("default" for the default index)
    public var _isimName: String { _name }
}
