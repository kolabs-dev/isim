// isim SwiftUI: onContinueUserActivity (universal links arrive as NSUserActivityTypeBrowsingWeb activities),
// transformEnvironment, and a plain-string accessor for other isim modules (MapKit's Marker monograms).
import Foundation

extension View {
    public func onContinueUserActivity(_ activityType: String, perform action: @escaping (NSUserActivity) -> Void) -> some View {
        _modify { ctx, c in
            ctx.graph.registerActivityHandler(ctx.path, activityType, action)
            return _resolve(c, ctx.child("activity"))
        }
    }
    /// Advertises a user activity while the view is shown: made current, and indexed for the home screen's Spotlight
    /// when isEligibleForSearch (no Handoff on isim).
    public func userActivity(_ activityType: String, isActive: Bool = true, _ update: @escaping (NSUserActivity) -> Void) -> some View {
        _modify { ctx, c in
            if isActive {
                let first = _SUIAdvertised.activities[ctx.path] == nil
                let a = _SUIAdvertised.activities[ctx.path] ?? NSUserActivity(activityType: activityType)
                _SUIAdvertised.activities[ctx.path] = a
                update(a)
                if first { a.becomeCurrent() }
            } else { _SUIAdvertised.activities[ctx.path] = nil }
            return _resolve(c, ctx.child("useractivity"))
        }
    }
    public func userActivity<P>(_ activityType: String, element: P?, _ update: @escaping (P, NSUserActivity) -> Void) -> some View {
        userActivity(activityType, isActive: element != nil) { a in if let e = element { update(e, a) } }
    }
    public func handlesExternalEvents(preferring: Set<String>, allowing: Set<String>) -> some View { self }
}
@MainActor enum _SUIAdvertised { static var activities: [String: NSUserActivity] = [:] }

extension View {
    public func transformEnvironment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, transform: @escaping (inout V) -> Void) -> some View {
        _env { transform(&$0[keyPath: keyPath]) }
    }
}
extension Text {
    @_spi(isim) public var _isimPlainString: String { string }
}
