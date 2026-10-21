// isim Intents Swift overlay: Apple's refined Swift API over the Objective-C classes. INMediaDestination is a Swift enum
// (.library, .playlist(name)) over the Objective-C INMediaDestination (INMediaDestinationReference in Swift), used by
// INAddMediaIntent and INMediaDestinationResolutionResult; INObject's initializers under their displayString: labels.
@_exported import Intents
import Foundation
import CoreLocation

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
