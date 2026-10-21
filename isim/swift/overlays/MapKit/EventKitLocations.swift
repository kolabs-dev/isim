// EventKit's structured locations from map items (EKStructuredLocation(mapItem:) needs MapKit, so MapKit adds it).
import EventKit

extension EKStructuredLocation {
    /// the item's name as the title and its place as the location
    public convenience init(mapItem: MKMapItem) {
        self.init(title: mapItem.name ?? mapItem.placemark.title ?? "")
        geoLocation = CLLocation(latitude: mapItem.placemark.coordinate.latitude, longitude: mapItem.placemark.coordinate.longitude)
    }
    @objc(locationWithMapItem:) class func _objc_location(_ mapItem: MKMapItem) -> EKStructuredLocation { EKStructuredLocation(mapItem: mapItem) }
}
