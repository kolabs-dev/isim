// isim SwiftUI: onContinueUserActivity (universal links arrive as NSUserActivityTypeBrowsingWeb activities).
import Foundation

extension View {
    public func onContinueUserActivity(_ activityType: String, perform action: @escaping (NSUserActivity) -> Void) -> some View {
        _modify { ctx, c in
            ctx.graph.registerActivityHandler(ctx.path, activityType, action)
            return _resolve(c, ctx.child("activity"))
        }
    }
    /// Advertising activities (Handoff/Spotlight) is accepted and ignored on isim.
    public func userActivity(_ activityType: String, isActive: Bool = true, _ update: @escaping (NSUserActivity) -> Void) -> some View { self }
}
