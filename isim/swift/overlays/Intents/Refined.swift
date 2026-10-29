// isim Intents Swift overlay: Apple's refined Swift API over the Objective-C classes. INMediaDestination is a Swift enum
// (.library, .playlist(name)) over the Objective-C INMediaDestination (INMediaDestinationReference in Swift), used by
// INAddMediaIntent and INMediaDestinationResolutionResult; INObject's initializers under their displayString: labels; the
// rides, photos and workouts domains' CoreLocation and optional-number types.
@_exported import Intents
import Foundation
@_spi(isim) import CoreLocation
import Contacts

/// where Siri adds media: the library or a named playlist
@available(iOS 13.0, *)
public enum INMediaDestination: Sendable, Equatable {
    case library
    case playlist(String)

    public var playlistName: String? {
        if case .playlist(let name) = self { return name }
        return nil
    }
    var _reference: INMediaDestinationReference {
        switch self {
        case .library: return INMediaDestinationReference.library()
        case .playlist(let name): return INMediaDestinationReference.playlistDestination(withName: name)
        }
    }
    init?(_ reference: INMediaDestinationReference?) {
        guard let r = reference else { return nil }
        switch r.mediaDestinationType {
        case .library: self = .library
        case .playlist: self = .playlist(r.playlistName ?? "")
        default: return nil
        }
    }
}

@available(iOS 13.0, *)
extension INAddMediaIntent {
    public convenience init(mediaItems: [INMediaItem]?, mediaSearch: INMediaSearch?, mediaDestination: INMediaDestination?) {
        self.init(__mediaItems: mediaItems, mediaSearch: mediaSearch, mediaDestination: mediaDestination?._reference)
    }
    public var mediaDestination: INMediaDestination? { INMediaDestination(__mediaDestination) }
}

@available(iOS 13.0, *)
extension INMediaDestinationResolutionResult {
    public class func success(with resolvedMediaDestination: INMediaDestination) -> Self {
        __success(with: resolvedMediaDestination._reference)
    }
    public class func disambiguation(with mediaDestinationsToDisambiguate: [INMediaDestination]) -> Self {
        __disambiguation(with: mediaDestinationsToDisambiguate.map { $0._reference })
    }
    public class func confirmationRequired(with mediaDestinationToConfirm: INMediaDestination?) -> Self {
        __confirmationRequired(with: mediaDestinationToConfirm?._reference)
    }
}

/// CLRegion is the CoreLocation overlay's class (the Objective-C declaration takes it as an object)
@available(iOS 12.0, *)
extension INLocationRelevanceProvider {
    public convenience init(region: CLRegion) { self.init(__region: region) }
    public var region: CLRegion { __region as! CLRegion }
}

extension INObject {
    public convenience init(identifier: String?, displayString: String) {
        self.init(identifier: identifier, display: displayString)
    }
    public convenience init(identifier: String?, displayString: String, pronunciationHint: String?) {
        self.init(identifier: identifier, display: displayString, pronunciationHint: pronunciationHint)
    }
    @available(iOS 14.0, *)
    public convenience init(identifier: String?, displayString: String, subtitleString: String?, displayImage: INImage?) {
        self.init(identifier: identifier, display: displayString, subtitle: subtitleString, image: displayImage)
    }
    @available(iOS 14.0, *)
    public convenience init(identifier: String?, displayString: String, pronunciationHint: String?, subtitleString: String?, displayImage: INImage?) {
        self.init(identifier: identifier, display: displayString, pronunciationHint: pronunciationHint, subtitle: subtitleString, image: displayImage)
    }
}

// ---------------- payments, rides, workouts and photos (issue #411) ----------------
// CLPlacemark and CLLocation are the CoreLocation overlay's classes, and Apple's Swift API uses Int?, Double? and Bool?
// where the Objective-C declarations use NSNumber: these are the typed forms of the refined (__) declarations.

/// a place for an intent (CLPlacemark (INIntentsAdditions))
extension CLPlacemark {
    @available(iOS 10.0, *)
    public convenience init(location: CLLocation, name: String?, postalAddress: CNPostalAddress?) {
        func field(_ v: String?) -> String? { v.flatMap { $0.isEmpty ? nil : $0 } }
        self.init(_isimName: name, location: location, thoroughfare: field(postalAddress?.street), locality: field(postalAddress?.city),
                  administrativeArea: field(postalAddress?.state), postalCode: field(postalAddress?.postalCode), country: field(postalAddress?.country),
                  isoCountryCode: field(postalAddress?.isoCountryCode))
    }
}

@available(iOS 10.0, *)
extension INPlacemarkResolutionResult {
    public class func success(with resolvedPlacemark: CLPlacemark) -> Self { __success(with: resolvedPlacemark) }
    public class func disambiguation(with placemarksToDisambiguate: [CLPlacemark]) -> Self { __disambiguation(with: placemarksToDisambiguate) }
    public class func confirmationRequired(with placemarkToConfirm: CLPlacemark?) -> Self { __confirmationRequired(with: placemarkToConfirm) }
}

@available(iOS 10.0, *)
extension INPriceRange {
    public convenience init(firstPrice: NSDecimalNumber, secondPrice: NSDecimalNumber, currencyCode: String) {
        self.init(rangeBetweenPrice: firstPrice, andPrice: secondPrice, currencyCode: currencyCode)
    }
}

@available(iOS 10.0, *)
extension INRideOption {
    public var usesMeteredFare: Bool? {
        get { __usesMeteredFare?.boolValue }
        set { __usesMeteredFare = newValue.map { NSNumber(value: $0) } }
    }
}

@available(iOS 10.0, *)
extension INRideVehicle {
    public var location: CLLocation? {
        get { __location as? CLLocation }
        set { __location = newValue }
    }
}

@available(iOS 10.0, *)
extension INRideStatus {
    public var pickupLocation: CLPlacemark? {
        get { __pickupLocation as? CLPlacemark }
        set { __pickupLocation = newValue }
    }
    public var dropOffLocation: CLPlacemark? {
        get { __dropOffLocation as? CLPlacemark }
        set { __dropOffLocation = newValue }
    }
    public var waypoints: [CLPlacemark]? {
        get { __waypoints?.compactMap { $0 as? CLPlacemark } }
        set { __waypoints = newValue }
    }
}

@available(iOS 10.0, *)
extension INListRideOptionsIntent {
    public convenience init(pickupLocation: CLPlacemark?, dropOffLocation: CLPlacemark?) {
        self.init(__pickupLocation: pickupLocation, dropOffLocation: dropOffLocation)
    }
    public var pickupLocation: CLPlacemark? { __pickupLocation as? CLPlacemark }
    public var dropOffLocation: CLPlacemark? { __dropOffLocation as? CLPlacemark }
}

@available(iOS 10.0, *)
extension INRequestRideIntent {
    @available(iOS 10.3, *)
    public convenience init(pickupLocation: CLPlacemark?, dropOffLocation: CLPlacemark?, rideOptionName: INSpeakableString?, partySize: Int?,
                            paymentMethod: INPaymentMethod?, scheduledPickupTime: INDateComponentsRange?) {
        self.init(__pickupLocation: pickupLocation, dropOffLocation: dropOffLocation, rideOptionName: rideOptionName,
                  partySize: partySize.map { NSNumber(value: $0) }, paymentMethod: paymentMethod, scheduledPickupTime: scheduledPickupTime)
    }
    public var pickupLocation: CLPlacemark? { __pickupLocation as? CLPlacemark }
    public var dropOffLocation: CLPlacemark? { __dropOffLocation as? CLPlacemark }
    public var partySize: Int? { __partySize.map { Int($0.int64Value) } }
}

@available(iOS 10.0, *)
extension INStartWorkoutIntent {
    public convenience init(workoutName: INSpeakableString?, goalValue: Double?, workoutGoalUnitType: INWorkoutGoalUnitType,
                            workoutLocationType: INWorkoutLocationType, isOpenEnded: Bool?) {
        self.init(__workoutName: workoutName, goalValue: goalValue.map { NSNumber(value: $0) }, workoutGoalUnitType: workoutGoalUnitType,
                  workoutLocationType: workoutLocationType, isOpenEnded: isOpenEnded.map { NSNumber(value: $0) })
    }
    public var goalValue: Double? { __goalValue?.doubleValue }
    public var isOpenEnded: Bool? { __isOpenEnded?.boolValue }
}

@available(iOS 10.0, *)
extension INSearchForPhotosIntent {
    public convenience init(dateCreated: INDateComponentsRange?, locationCreated: CLPlacemark?, albumName: String?, searchTerms: [String]?,
                            includedAttributes: INPhotoAttributeOptions, excludedAttributes: INPhotoAttributeOptions, peopleInPhoto: [INPerson]?) {
        self.init(__dateCreated: dateCreated, locationCreated: locationCreated, albumName: albumName, searchTerms: searchTerms,
                  includedAttributes: includedAttributes, excludedAttributes: excludedAttributes, peopleInPhoto: peopleInPhoto)
    }
    public var locationCreated: CLPlacemark? { __locationCreated as? CLPlacemark }
}

@available(iOS 10.0, *)
extension INStartPhotoPlaybackIntent {
    public convenience init(dateCreated: INDateComponentsRange?, locationCreated: CLPlacemark?, albumName: String?, searchTerms: [String]?,
                            includedAttributes: INPhotoAttributeOptions, excludedAttributes: INPhotoAttributeOptions, peopleInPhoto: [INPerson]?) {
        self.init(__dateCreated: dateCreated, locationCreated: locationCreated, albumName: albumName, searchTerms: searchTerms,
                  includedAttributes: includedAttributes, excludedAttributes: excludedAttributes, peopleInPhoto: peopleInPhoto)
    }
    public var locationCreated: CLPlacemark? { __locationCreated as? CLPlacemark }
}

@available(iOS 10.0, *)
extension INSearchForPhotosIntentResponse {
    public var searchResultsCount: Int? {
        get { __searchResultsCount.map { Int($0.int64Value) } }
        set { __searchResultsCount = newValue.map { NSNumber(value: $0) } }
    }
}

@available(iOS 10.0, *)
extension INStartPhotoPlaybackIntentResponse {
    public var searchResultsCount: Int? {
        get { __searchResultsCount.map { Int($0.int64Value) } }
        set { __searchResultsCount = newValue.map { NSNumber(value: $0) } }
    }
}
