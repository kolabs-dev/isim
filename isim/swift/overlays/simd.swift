// isim simd (subset), self-authored: the C vector type names (vector_float2, simd_int2, ...) as the Swift
// standard library's SIMD types, and common geometric functions. Used by SpriteKit and GameplayKit.

public typealias vector_float2 = SIMD2<Float>
public typealias vector_float3 = SIMD3<Float>
public typealias vector_float4 = SIMD4<Float>
public typealias vector_double2 = SIMD2<Double>
public typealias vector_double3 = SIMD3<Double>
public typealias vector_double4 = SIMD4<Double>
public typealias vector_int2 = SIMD2<Int32>
public typealias vector_int3 = SIMD3<Int32>
public typealias vector_int4 = SIMD4<Int32>
public typealias vector_uint2 = SIMD2<UInt32>
public typealias vector_uint3 = SIMD3<UInt32>
public typealias vector_uint4 = SIMD4<UInt32>
public typealias simd_float2 = SIMD2<Float>
public typealias simd_float3 = SIMD3<Float>
public typealias simd_float4 = SIMD4<Float>
public typealias simd_double2 = SIMD2<Double>
public typealias simd_double3 = SIMD3<Double>
public typealias simd_double4 = SIMD4<Double>
public typealias simd_int2 = SIMD2<Int32>
public typealias simd_int3 = SIMD3<Int32>
public typealias simd_int4 = SIMD4<Int32>
public typealias simd_uint2 = SIMD2<UInt32>
public typealias simd_uint3 = SIMD3<UInt32>
public typealias simd_uint4 = SIMD4<UInt32>

@inlinable public func simd_dot<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint { (a * b).sum() }
@inlinable public func simd_length_squared<V: SIMD>(_ v: V) -> V.Scalar where V.Scalar: FloatingPoint { (v * v).sum() }
@inlinable public func simd_length<V: SIMD>(_ v: V) -> V.Scalar where V.Scalar: FloatingPoint { (v * v).sum().squareRoot() }
@inlinable public func simd_distance<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint { simd_length(a - b) }
@inlinable public func simd_distance_squared<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint { simd_length_squared(a - b) }
@inlinable public func simd_normalize<V: SIMD>(_ v: V) -> V where V.Scalar: FloatingPoint {
    let l = simd_length(v)
    return l > 0 ? v / l : v
}
@inlinable public func simd_mix<V: SIMD>(_ a: V, _ b: V, _ t: V) -> V where V.Scalar: FloatingPoint { a + (b - a) * t }
@inlinable public func simd_clamp<V: SIMD>(_ v: V, _ lo: V, _ hi: V) -> V where V.Scalar: Comparable { v.clamped(lowerBound: lo, upperBound: hi) }
@inlinable public func simd_min<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar: Comparable { pointwiseMin(a, b) }
@inlinable public func simd_max<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar: Comparable { pointwiseMax(a, b) }
@inlinable public func simd_abs<V: SIMD>(_ v: V) -> V where V.Scalar: FloatingPoint { var r = v; for i in r.indices { r[i] = abs(r[i]) }; return r }
@inlinable public func simd_cross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}
@inlinable public func simd_cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
    SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}

// the overloaded Swift spellings (simd module on iOS)
@inlinable public func dot<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint { simd_dot(a, b) }
@inlinable public func length<V: SIMD>(_ v: V) -> V.Scalar where V.Scalar: FloatingPoint { simd_length(v) }
@inlinable public func length_squared<V: SIMD>(_ v: V) -> V.Scalar where V.Scalar: FloatingPoint { simd_length_squared(v) }
@inlinable public func distance<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint { simd_distance(a, b) }
@inlinable public func distance_squared<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint { simd_distance_squared(a, b) }
@inlinable public func normalize<V: SIMD>(_ v: V) -> V where V.Scalar: FloatingPoint { simd_normalize(v) }
@inlinable public func mix<V: SIMD>(_ a: V, _ b: V, t: V.Scalar) -> V where V.Scalar: FloatingPoint { a + (b - a) * t }
@inlinable public func cross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> { simd_cross(a, b) }
@inlinable public func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> { simd_cross(a, b) }
