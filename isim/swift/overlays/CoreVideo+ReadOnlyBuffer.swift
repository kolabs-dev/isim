// isim CoreVideo: CVReadOnlyPixelBuffer (iOS 26), the read-only, sendable form of a pixel buffer that Vision's Swift
// observations hand out (issue #852). Adapted: a wrapper of the CVPixelBuffer it was made from. Not in isim yet:
// CVMutablePixelBuffer and init(_:) from one.
import Foundation

@available(iOS 26.0, *)
public final class CVReadOnlyPixelBuffer: @unchecked Sendable {
    let _buffer: CVPixelBuffer
    /// wraps the buffer, which the caller no longer writes to
    public init(unsafeBuffer: sending CVPixelBuffer) { _buffer = unsafeBuffer }
    /// the pixel buffer underneath, for APIs that take one (read it, do not write it)
    public func withUnsafeBuffer<R>(_ body: (CVPixelBuffer) throws -> sending R) rethrows -> sending R { try body(_buffer) }
}
