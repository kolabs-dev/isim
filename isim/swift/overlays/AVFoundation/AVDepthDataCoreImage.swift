// isim AVFoundation: Core Image's depth APIs (issue #380). Apple declares CIImage(depthData:) in Core Image; isim's
// AVDepthData lives in this overlay, so the CIImage extension does too (an app that has an AVDepthData imports
// AVFoundation). The image shows the depth map (one float channel as luminance), and keeps the AVDepthData it was made
// from for depthData.
import CoreImage
import ObjectiveC

nonisolated(unsafe) private var kIsimDepthData: UInt8 = 0

extension CIImage {
    /// the depth (or disparity) map as an image
    public convenience init?(depthData: AVDepthData) { self.init(depthData: depthData, options: nil) }
    public convenience init?(depthData: AVDepthData, options: [CIImageOption: Any]?) {
        self.init(cvPixelBuffer: depthData.depthDataMap, options: options)
        objc_setAssociatedObject(self, &kIsimDepthData, depthData, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    /// the depth data the image was made from (CIImage(depthData:)), or nil
    public var depthData: AVDepthData? { objc_getAssociatedObject(self, &kIsimDepthData) as? AVDepthData }
}
