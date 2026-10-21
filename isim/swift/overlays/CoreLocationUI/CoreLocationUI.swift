// isim CoreLocationUI Swift overlay: SwiftUI's LocationButton. Like CLLocationButton (the Objective-C framework), a tap
// grants when-in-use location authorization for the rest of the run (temporary, like iOS), then runs the action.
@_exported import CoreLocationUI
import SwiftUI
import CoreLocation

@available(iOS 15.0, *)
public struct LocationButton: View {
    /// the button's text
    public struct Title: Equatable, Sendable {
        let text: String
        public static let currentLocation = Title(text: "Current Location")
        public static let sendCurrentLocation = Title(text: "Send Current Location")
        public static let sendMyCurrentLocation = Title(text: "Send My Current Location")
        public static let shareCurrentLocation = Title(text: "Share Current Location")
        public static let shareMyCurrentLocation = Title(text: "Share My Current Location")
    }
    let title: Title?
    let action: () -> Void
    /// an icon-only button
    public init(action: @escaping () -> Void) { title = nil; self.action = action }
    public init(_ title: Title, action: @escaping () -> Void) { self.title = title; self.action = action }

    public var body: some View {
        Button {
            let grant = NSSelectorFromString("_isim_grantLocationButtonAuthorization")
            if (CLLocationManager.self as AnyObject).responds(to: grant) { _ = (CLLocationManager.self as AnyObject).perform(grant) }
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                if let title { Text(title.text) }
            }
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.accentColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(title?.text ?? "Current Location")
    }
}
