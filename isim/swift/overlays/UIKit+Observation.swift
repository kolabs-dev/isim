// isim UIKit overlay, observation part (self-authored): the tracking function UIKit calls around layoutSubviews,
// updateProperties and the view controller layout callbacks (iOS 26 automatic observation tracking; UIUpdates.m
// looks it up by name, so Objective-C-only apps run without it).
import Observation

@_cdecl("isim_uikit_observation_track")
public func _isimUIKitObservationTrack(_ body: @convention(block) () -> Void, _ onChange: @escaping @convention(block) () -> Void) {
    if #available(iOS 17.0, *) {
        nonisolated(unsafe) let change = onChange
        withObservationTracking { body() } onChange: { change() }
    } else {
        body()
    }
}
