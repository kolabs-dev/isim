// isim AVFoundation for Objective-C (sdk-src/Frameworks/AVFoundation): the classes carry Apple's Objective-C names and
// these members Apple's selectors. Swift's CMTime is the CoreMedia overlay's struct, not Objective-C's C struct, so the
// methods that take or return a CMTime (-currentTime, -duration, -seekToTime:, periodic time observers) are Objective-C
// categories in AVFoundation.framework (frameworks/AVFoundation/AVFoundation.m) built on the `_isim_` entry points here.
import Foundation
import UIKit
import CoreMedia

extension CMTime {
    /// value, timescale, flags, epoch: Objective-C's CMTime fields
    var _isimParts: [NSNumber] { [NSNumber(value: value), NSNumber(value: timescale), NSNumber(value: flags.rawValue), NSNumber(value: epoch)] }
    init(_isimValue v: Int64, timescale: Int32, flags: UInt32, epoch: Int64) {
        self.init(value: v, timescale: timescale, flags: CMTimeFlags(rawValue: flags), epoch: epoch)
    }
}

extension AVAudioSession {
    @objc(category) var _objc_category: String { category.rawValue }
    @objc(mode) var _objc_mode: String { mode.rawValue }
    @objc(categoryOptions) var _objc_categoryOptions: UInt { categoryOptions.rawValue }
    @objc(setCategory:error:) func _objc_setCategory(_ c: String) throws { try setCategory(Category(rawValue: c)) }
    @objc(setCategory:withOptions:error:) func _objc_setCategory(_ c: String, options: UInt) throws {
        try setCategory(Category(rawValue: c), options: CategoryOptions(rawValue: options))
    }
    @objc(setCategory:mode:options:error:) func _objc_setCategory(_ c: String, mode: String, options: UInt) throws {
        try setCategory(Category(rawValue: c), mode: Mode(rawValue: mode), options: CategoryOptions(rawValue: options))
    }
    @objc(setMode:error:) func _objc_setMode(_ m: String) throws { try setMode(Mode(rawValue: m)) }
    @objc(setActive:error:) func _objc_setActive(_ a: Bool) throws { try setActive(a) }
    @objc(setActive:withOptions:error:) func _objc_setActive(_ a: Bool, options: UInt) throws { try setActive(a, options: SetActiveOptions(rawValue: options)) }
    @objc(currentRoute) var _objc_currentRoute: AVAudioSessionRouteDescription { currentRoute }
    @objc(outputNumberOfChannels) var _objc_outputChannels: Int { outputNumberOfChannels }
}

extension AVAudioSessionPortDescription {
    @objc(portType) var _objc_portType: String { portType.rawValue }
}

extension AVAsset {
    @objc(assetWithURL:) class func _objc_asset(_ url: URL) -> AVAsset { AVURLAsset(url: url) }
    @objc(_isim_duration) var _isimDuration: [NSNumber] { duration._isimParts }
    @objc(tracks) var _objc_tracks: [AVAssetTrack] { tracks }
    @objc(tracksWithMediaType:) func _objc_tracks(_ type: String) -> [AVAssetTrack] { tracks(withMediaType: AVMediaType(rawValue: type)) }
    @objc(isPlayable) var _objc_playable: Bool { isPlayable }
    @objc(loadValuesAsynchronouslyForKeys:completionHandler:) func _objc_load(_ keys: [String], _ handler: (() -> Void)?) {
        loadValuesAsynchronously(forKeys: keys) { handler?() }
    }
    @objc(statusOfValueForKey:error:) func _objc_status(_ key: String, _ error: UnsafeMutablePointer<NSError?>?) -> Int {
        statusOfValue(forKey: key, error: error).rawValue
    }
}
extension AVURLAsset {
    @objc(URLAssetWithURL:options:) class func _objc_urlAsset(_ url: URL, options: [String: Any]?) -> AVURLAsset { AVURLAsset(url: url, options: options) }
}
extension AVAssetTrack {
    @objc(mediaType) var _objc_mediaType: String { mediaType.rawValue }
    @objc(naturalSize) var _objc_naturalSize: CGSize { naturalSize }
    @objc(nominalFrameRate) var _objc_fps: Float { nominalFrameRate }
    @objc(estimatedDataRate) var _objc_dataRate: Float { estimatedDataRate }
}

extension AVPlayerItem {
    @objc(playerItemWithURL:) class func _objc_item(_ url: URL) -> AVPlayerItem { AVPlayerItem(url: url) }
    @objc(playerItemWithAsset:) class func _objc_item(asset: AVAsset) -> AVPlayerItem { AVPlayerItem(asset: asset) }
    @objc(asset) var _objc_asset: AVAsset { asset }
    @objc(_isim_duration) var _isimDuration: [NSNumber] { duration._isimParts }
    @objc(_isim_currentTime) var _isimCurrentTime: [NSNumber] { currentTime()._isimParts }
    @objc(_isim_seekValue:timescale:flags:epoch:completionHandler:)
    func _isimSeek(_ v: Int64, timescale: Int32, flags: UInt32, epoch: Int64, completionHandler: ((Bool) -> Void)?) {
        seek(to: CMTime(_isimValue: v, timescale: timescale, flags: flags, epoch: epoch), completionHandler: completionHandler)
    }
    @objc(cancelPendingSeeks) func _objc_cancelPendingSeeks() { cancelPendingSeeks() }
}

extension AVPlayer {
    @objc(playerWithPlayerItem:) class func _objc_player(_ item: AVPlayerItem?) -> AVPlayer { AVPlayer(playerItem: item) }
    @objc(playerWithURL:) class func _objc_player(url: URL) -> AVPlayer { AVPlayer(url: url) }
    @objc(_isim_currentTime) var _isimCurrentTime: [NSNumber] { currentTime()._isimParts }
    @objc(_isim_seekValue:timescale:flags:epoch:completionHandler:)
    func _isimSeek(_ v: Int64, timescale: Int32, flags: UInt32, epoch: Int64, completionHandler: ((Bool) -> Void)?) {
        seek(to: CMTime(_isimValue: v, timescale: timescale, flags: flags, epoch: epoch)) { completionHandler?($0) }
    }
    /// the block gets the time as Objective-C CMTime parts (the category builds the CMTime and moves to the caller's queue)
    @objc(_isim_addPeriodicTimeObserverValue:timescale:usingBlock:)
    func _isimAddPeriodic(_ v: Int64, timescale: Int32, block: @escaping ([NSNumber]) -> Void) -> Any {
        nonisolated(unsafe) let b = block
        return addPeriodicTimeObserver(forInterval: CMTime(value: v, timescale: timescale), queue: nil) { t in b(t._isimParts) }
    }
    @objc(_isim_addBoundaryTimeObserverForTimes:usingBlock:)
    func _isimAddBoundary(_ times: [NSValue], block: @escaping () -> Void) -> Any {
        nonisolated(unsafe) let b = block
        return addBoundaryTimeObserver(forTimes: times, queue: nil) { b() }
    }
}

extension AVPlayerLayer {
    @objc(videoGravity) var _objc_videoGravity: String {
        get { videoGravity.rawValue } set { videoGravity = AVLayerVideoGravity(rawValue: newValue) }
    }
    @objc(videoRect) var _objc_videoRect: CGRect { videoRect }
}
