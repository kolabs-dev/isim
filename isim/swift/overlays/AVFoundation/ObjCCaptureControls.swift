// isim AVFoundation for Objective-C (issue #811): the Camera Control's controls and the session's controls delegate,
// the depth data output, the data output synchronizer and its synchronized data, depth data and the system pressure
// state, over the Swift classes (their Objective-C names: OBJC_NAMES in buildlib/swift.py). Delegates and actions are
// called on the dispatch_queue_t given; the depth delegate's CMTime argument goes through AVFoundation.m
// (isim_av_call_depth), the members with a CMTime / CMSampleBufferRef / CVPixelBufferRef through categories there.
import Foundation
import UIKit
import CoreMedia
import CoreVideo

// MARK: controls

extension AVCaptureControl {
    @objc(isEnabled) var _objc_isEnabled: Bool { isEnabled }
    @objc(setEnabled:) func _objc_setEnabled(_ b: Bool) { isEnabled = b }
}
/// an action block and its dispatch_queue_t (retained)
final class _ObjCAction: _ObjCQueuedDelegate {}
extension AVCaptureSlider {
    @objc(initWithLocalizedTitle:symbolName:minValue:maxValue:) convenience init(_objcTitle t: String, symbolName s: String, minValue a: Float, maxValue b: Float) {
        self.init(t, symbolName: s, in: min(a, b)...max(a, b))
    }
    @objc(initWithLocalizedTitle:symbolName:minValue:maxValue:step:) convenience init(_objcTitle t: String, symbolName s: String, minValue a: Float,
                                                                                     maxValue b: Float, step: Float) {
        self.init(t, symbolName: s, in: min(a, b)...max(a, b), step: step)
    }
    @objc(initWithLocalizedTitle:symbolName:values:) convenience init(_objcTitle t: String, symbolName s: String, values: [NSNumber]) {
        self.init(t, symbolName: s, values: values.map(\.floatValue))
    }
    @objc(value) var _objc_value: Float { value }
    @objc(setValue:) func _objc_setValue(_ v: Float) { value = v }
    @objc(localizedTitle) var _objc_title: String { localizedTitle }
    @objc(symbolName) var _objc_symbol: String { symbolName }
    @objc(prominentValues) var _objc_prominent: [NSNumber] { get { prominentValues.map { NSNumber(value: $0) } } set { prominentValues = newValue.map(\.floatValue) } }
    @objc(localizedValueFormat) var _objc_format: String? { get { localizedValueFormat } set { localizedValueFormat = newValue } }
    @objc(accessibilityIdentifier) var _objc_axid: String? { get { accessibilityIdentifier } set { accessibilityIdentifier = newValue } }
    @objc(setActionQueue:action:) func _objc_setAction(_ q: dispatch_queue_t, _ action: @escaping @Sendable (Float) -> Void) {
        let box = _ObjCAction(self, q)
        setActionQueue(DispatchQueue.global()) { v in _isimOn(box.queue) { action(v) } }
    }
}
extension AVCaptureIndexPicker {
    @objc(initWithLocalizedTitle:symbolName:numberOfIndexes:) convenience init(_objcTitle t: String, symbolName s: String, numberOfIndexes n: Int) {
        self.init(t, symbolName: s, numberOfIndexes: n)
    }
    @objc(initWithLocalizedTitle:symbolName:numberOfIndexes:localizedTitleTransform:)
    convenience init(_objcTitle t: String, symbolName s: String, numberOfIndexes n: Int, localizedTitleTransform f: @escaping @Sendable (Int) -> String) {
        self.init(title: t, symbol: s, titles: (0..<max(0, n)).map(f))
    }
    @objc(initWithLocalizedTitle:symbolName:localizedIndexTitles:) convenience init(_objcTitle t: String, symbolName s: String, localizedIndexTitles: [String]) {
        self.init(t, symbolName: s, localizedIndexTitles: localizedIndexTitles)
    }
    @objc(selectedIndex) var _objc_index: Int { selectedIndex }
    @objc(setSelectedIndex:) func _objc_setIndex(_ i: Int) { selectedIndex = i }
    @objc(localizedTitle) var _objc_title: String { localizedTitle }
    @objc(symbolName) var _objc_symbol: String { symbolName }
    @objc(numberOfIndexes) var _objc_count: Int { numberOfIndexes }
    @objc(localizedIndexTitles) var _objc_titles: [String] { localizedIndexTitles }
    @objc(accessibilityIdentifier) var _objc_axid: String? { get { accessibilityIdentifier } set { accessibilityIdentifier = newValue } }
    @objc(setActionQueue:action:) func _objc_setAction(_ q: dispatch_queue_t, _ action: @escaping @Sendable (Int) -> Void) {
        let box = _ObjCAction(self, q)
        setActionQueue(DispatchQueue.global()) { i in _isimOn(box.queue) { action(i) } }
    }
}
extension AVCaptureSystemZoomSlider {
    @objc(initWithDevice:) convenience init(_objcDevice d: AVCaptureDevice) { self.init(device: d) }
    @objc(initWithDevice:action:) convenience init(_objcDevice d: AVCaptureDevice, action: @escaping @Sendable (CGFloat) -> Void) { self.init(device: d, action: action) }
}
extension AVCaptureSystemExposureBiasSlider {
    @objc(initWithDevice:) convenience init(_objcDevice d: AVCaptureDevice) { self.init(device: d) }
    @objc(initWithDevice:action:) convenience init(_objcDevice d: AVCaptureDevice, action: @escaping @Sendable (Float) -> Void) { self.init(device: d, action: action) }
}
final class _ObjCControlsDelegate: _ObjCQueuedDelegate, AVCaptureSessionControlsDelegate {
    private func send(_ sel: String, _ s: AVCaptureSession) { _isimOn(queue) { [weak self] in _isimSend(self?.target, sel, [s]) } }
    func sessionControlsDidBecomeActive(_ session: AVCaptureSession) { send("sessionControlsDidBecomeActive:", session) }
    func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) { send("sessionControlsWillEnterFullscreenAppearance:", session) }
    func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) { send("sessionControlsWillExitFullscreenAppearance:", session) }
    func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) { send("sessionControlsDidBecomeInactive:", session) }
}
@available(iOS 18.0, *)
extension AVCaptureSession {
    @objc(supportsControls) var _objc_supportsControls: Bool { supportsControls }
    @objc(maxControlsCount) var _objc_maxControls: Int { maxControlsCount }
    @objc(controls) var _objc_controls: [AVCaptureControl] { controls }
    @objc(canAddControl:) func _objc_canAddControl(_ c: AVCaptureControl) -> Bool { canAddControl(c) }
    @objc(addControl:) func _objc_addControl(_ c: AVCaptureControl) { addControl(c) }
    @objc(removeControl:) func _objc_removeControl(_ c: AVCaptureControl) { removeControl(c) }
    @objc(setControlsDelegate:queue:) func _objc_setControlsDelegate(_ d: NSObject?, _ q: dispatch_queue_t?) {
        let a = d.map { _ObjCControlsDelegate($0, q) }
        objc_setAssociatedObject(self, _isimControlsKey, a, .OBJC_ASSOCIATION_RETAIN)
        setControlsDelegate(a, queue: nil)
    }
    @objc(controlsDelegate) var _objc_controlsDelegate: NSObject? { (controlsDelegate as? _ObjCControlsDelegate)?.target }
    @objc(controlsDelegateCallbackQueue) var _objc_controlsQueue: dispatch_queue_t? { (controlsDelegate as? _ObjCControlsDelegate)?.queue }
}
private let _isimControlsKey = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)

// MARK: system pressure

extension AVCaptureDevice.SystemPressureState {
    @objc(level) var _objc_level: String { level.rawValue }
    @objc(factors) var _objc_factors: UInt { factors.rawValue }
}

// MARK: depth data

extension AVDepthData {
    @objc(_isim_depthDataMap) var _isimMap: UnsafeMutableRawPointer { Unmanaged.passUnretained(depthDataMap).toOpaque() }
    @objc(depthDataType) var _objc_type: OSType { depthDataType }
    @objc(availableDepthDataTypes) var _objc_types: [NSNumber] { availableDepthDataTypes.map { NSNumber(value: $0) } }
    @objc(isDepthDataFiltered) var _objc_filtered: Bool { isDepthDataFiltered }
    @objc(depthDataAccuracy) var _objc_accuracy: Accuracy { depthDataAccuracy }
    @objc(depthDataQuality) var _objc_quality: Quality { depthDataQuality }
    @objc(cameraCalibrationData) var _objc_calibration: AVCameraCalibrationData? { cameraCalibrationData }
    @objc(depthDataByConvertingToDepthDataType:) func _objc_convert(_ t: OSType) -> AVDepthData { converting(toDepthDataType: t) }
    @objc(_isim_depthDataByReplacingDepthDataMap:error:) func _isimReplace(_ p: UnsafeMutableRawPointer) throws -> AVDepthData {
        try replacingDepthDataMap(with: Unmanaged<CVBuffer>.fromOpaque(p).takeUnretainedValue())
    }
    @objc(dictionaryRepresentationForAuxiliaryDataType:) func _objc_dict(_ out: AutoreleasingUnsafeMutablePointer<NSString?>?) -> [AnyHashable: Any]? {
        dictionaryRepresentation(forAuxiliaryDataType: out)
    }
    @objc(depthDataFromDictionaryRepresentation:error:) class func _objc_fromDict(_ d: [AnyHashable: Any]) throws -> AVDepthData {
        try AVDepthData(fromDictionaryRepresentation: d)
    }
}

// MARK: the depth data output

/// calls an Objective-C depth delegate with its CMTime argument (AVFoundation.m)
private typealias _DepthCall = @convention(c) (UnsafeMutableRawPointer, Selector, UnsafeMutableRawPointer, UnsafeMutableRawPointer, UnsafeRawPointer,
                                               UnsafeMutableRawPointer, Int, Int32) -> Void
private let _isimCallDepth: _DepthCall? = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "isim_av_call_depth").map { unsafeBitCast($0, to: _DepthCall.self) }
final class _ObjCDepthDelegate: _ObjCQueuedDelegate, AVCaptureDepthDataOutputDelegate {
    private func call(_ name: String, _ output: AVCaptureDepthDataOutput, _ data: AVDepthData, _ t: CMTime, _ c: AVCaptureConnection,
                      _ reason: AVCaptureOutput.DataDroppedReason, dropped: Bool) {
        _isimOn(queue) { [weak self] in
            guard let target = self?.target, let f = _isimCallDepth else { return }
            let sel = NSSelectorFromString(name)
            guard target.responds(to: sel) else { return }
            var time = t
            withUnsafePointer(to: &time) { tp in
                f(_isimOpaque(target)!, sel, _isimOpaque(output)!, _isimOpaque(data)!, UnsafeRawPointer(tp), _isimOpaque(c)!, reason.rawValue, dropped ? 1 : 0)
            }
        }
    }
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        call("depthDataOutput:didOutputDepthData:timestamp:connection:", output, depthData, timestamp, connection, .none, dropped: false)
    }
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didDrop depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection,
                         reason: AVCaptureOutput.DataDroppedReason) {
        call("depthDataOutput:didDropDepthData:timestamp:connection:reason:", output, depthData, timestamp, connection, reason, dropped: true)
    }
}
extension AVCaptureDepthDataOutput {
    @objc(alwaysDiscardsLateDepthData) var _objc_discards: Bool { get { alwaysDiscardsLateDepthData } set { alwaysDiscardsLateDepthData = newValue } }
    @objc(isFilteringEnabled) var _objc_filtering: Bool { isFilteringEnabled }
    @objc(setFilteringEnabled:) func _objc_setFiltering(_ b: Bool) { isFilteringEnabled = b }
    @objc(setDelegate:callbackQueue:) func _objc_setDelegate(_ d: NSObject?, _ q: dispatch_queue_t?) {
        let a = d.map { _ObjCDepthDelegate($0, q) }
        _isimKeep(self, a)
        setDelegate(a, callbackQueue: nil)
    }
    @objc(delegate) var _objc_delegate: NSObject? { (delegate as? _ObjCDepthDelegate)?.target }
    @objc(delegateCallbackQueue) var _objc_queue: dispatch_queue_t? { (delegate as? _ObjCDepthDelegate)?.queue }
}

// MARK: the synchronizer

final class _ObjCSynchronizerDelegate: _ObjCQueuedDelegate, AVCaptureDataOutputSynchronizerDelegate {
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput c: AVCaptureSynchronizedDataCollection) {
        _isimOn(queue) { [weak self] in _isimSend(self?.target, "dataOutputSynchronizer:didOutputSynchronizedDataCollection:", [synchronizer, c]) }
    }
}
extension AVCaptureDataOutputSynchronizer {
    @objc(initWithDataOutputs:) convenience init(_objcOutputs o: [AVCaptureOutput]) { self.init(dataOutputs: o) }
    @objc(dataOutputs) var _objc_outputs: [AVCaptureOutput] { dataOutputs }
    @objc(setDelegate:queue:) func _objc_setDelegate(_ d: NSObject?, _ q: dispatch_queue_t?) {
        let a = d.map { _ObjCSynchronizerDelegate($0, q) }
        _isimKeep(self, a)
        setDelegate(a, queue: nil)
    }
    @objc(delegate) var _objc_delegate: NSObject? { (delegate as? _ObjCSynchronizerDelegate)?.target }
    @objc(delegateCallbackQueue) var _objc_queue: dispatch_queue_t? { (delegate as? _ObjCSynchronizerDelegate)?.queue }
}
extension AVCaptureSynchronizedDataCollection {
    @objc(synchronizedDataForCaptureOutput:) func _objc_data(_ o: AVCaptureOutput) -> AVCaptureSynchronizedData? { synchronizedData(for: o) }
    @objc(objectForKeyedSubscript:) func _objc_subscript(_ o: AVCaptureOutput) -> AVCaptureSynchronizedData? { self[o] }
    @objc(count) var _objc_count: Int { count }
    @objc(_isim_outputs) var _isimOutputs: [AVCaptureOutput] { _order }
}
extension AVCaptureSynchronizedData {
    @objc(_isim_timestamp:) func _isimTimestamp(_ out: UnsafeMutableRawPointer) { timestamp._isimStore(out) }
}
extension AVCaptureSynchronizedSampleBufferData {
    @objc(_isim_sampleBuffer) var _isimBuffer: UnsafeMutableRawPointer { Unmanaged.passUnretained(sampleBuffer).toOpaque() }
    @objc(sampleBufferWasDropped) var _objc_dropped: Bool { sampleBufferWasDropped }
    @objc(droppedReason) var _objc_reason: AVCaptureOutput.DataDroppedReason { droppedReason }
}
extension AVCaptureSynchronizedDepthData {
    @objc(depthData) var _objc_depth: AVDepthData { depthData }
    @objc(depthDataWasDropped) var _objc_dropped: Bool { depthDataWasDropped }
    @objc(droppedReason) var _objc_reason: AVCaptureOutput.DataDroppedReason { droppedReason }
}
extension AVCaptureSynchronizedMetadataObjectData {
    @objc(metadataObjects) var _objc_objects: [AVMetadataObject] { metadataObjects }
}
extension AVCaptureDevice {
    @objc(activeDepthDataFormat) var _objc_depthFormat: Format? { get { activeDepthDataFormat } set { activeDepthDataFormat = newValue } }
}
