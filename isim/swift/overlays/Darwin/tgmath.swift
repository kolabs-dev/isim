// The type-generic math of Apple's Darwin overlay (tgmath): Float forms of <math.h>'s functions, and the generic
// FloatingPoint ones, so `tan(angle)` with a Float angle compiles as on iOS. Self-authored after Swift's tgmath.swift.gyb.

@_transparent public func fabs<T: FloatingPoint>(_ x: T) -> T { x.magnitude }
@_transparent public func sqrt<T: FloatingPoint>(_ x: T) -> T { x.squareRoot() }
@_transparent public func fma<T: FloatingPoint>(_ x: T, _ y: T, _ z: T) -> T { z.addingProduct(x, y) }
@_transparent public func remainder<T: FloatingPoint>(_ x: T, _ y: T) -> T { x.remainder(dividingBy: y) }
@_transparent public func fmod<T: FloatingPoint>(_ x: T, _ y: T) -> T { x.truncatingRemainder(dividingBy: y) }
@_transparent public func ceil<T: FloatingPoint>(_ x: T) -> T { x.rounded(.up) }
@_transparent public func floor<T: FloatingPoint>(_ x: T) -> T { x.rounded(.down) }
@_transparent public func round<T: FloatingPoint>(_ x: T) -> T { x.rounded() }
@_transparent public func trunc<T: FloatingPoint>(_ x: T) -> T { x.rounded(.towardZero) }
@_transparent public func scalbn<T: FloatingPoint>(_ x: T, _ n: Int) -> T { T(sign: .plus, exponent: T.Exponent(n), significand: x) }
@_transparent public func modf<T: FloatingPoint>(_ x: T) -> (T, T) {
    let i = x.rounded(.towardZero)
    return (i, x - i)
}
@_transparent public func frexp<T: BinaryFloatingPoint>(_ x: T) -> (T, Int) {
    guard x.isFinite, !x.isZero else { return (x, 0) }
    return (x.significand / 2, Int(x.exponent + 1))
}
@_transparent public func ilogb<T: BinaryFloatingPoint>(_ x: T) -> Int { Int(x.exponent) }

@_transparent public func acos(_ x: Float) -> Float { acosf(x) }
@_transparent public func asin(_ x: Float) -> Float { asinf(x) }
@_transparent public func atan(_ x: Float) -> Float { atanf(x) }
@_transparent public func tan(_ x: Float) -> Float { tanf(x) }
@_transparent public func acosh(_ x: Float) -> Float { acoshf(x) }
@_transparent public func asinh(_ x: Float) -> Float { asinhf(x) }
@_transparent public func atanh(_ x: Float) -> Float { atanhf(x) }
@_transparent public func cosh(_ x: Float) -> Float { coshf(x) }
@_transparent public func sinh(_ x: Float) -> Float { sinhf(x) }
@_transparent public func tanh(_ x: Float) -> Float { tanhf(x) }
@_transparent public func expm1(_ x: Float) -> Float { expm1f(x) }
@_transparent public func log1p(_ x: Float) -> Float { log1pf(x) }
@_transparent public func logb(_ x: Float) -> Float { logbf(x) }
@_transparent public func cbrt(_ x: Float) -> Float { cbrtf(x) }
@_transparent public func erf(_ x: Float) -> Float { erff(x) }
@_transparent public func erfc(_ x: Float) -> Float { erfcf(x) }
@_transparent public func tgamma(_ x: Float) -> Float { tgammaf(x) }
@_transparent public func nearbyint(_ x: Float) -> Float { nearbyintf(x) }
@_transparent public func rint(_ x: Float) -> Float { rintf(x) }
@_transparent public func cos(_ x: Float) -> Float { cosf(x) }
@_transparent public func sin(_ x: Float) -> Float { sinf(x) }
@_transparent public func exp(_ x: Float) -> Float { expf(x) }
@_transparent public func exp2(_ x: Float) -> Float { exp2f(x) }
@_transparent public func log(_ x: Float) -> Float { logf(x) }
@_transparent public func log10(_ x: Float) -> Float { log10f(x) }
@_transparent public func log2(_ x: Float) -> Float { log2f(x) }
@_transparent public func atan2(_ y: Float, _ x: Float) -> Float { atan2f(y, x) }
@_transparent public func hypot(_ x: Float, _ y: Float) -> Float { hypotf(x, y) }
@_transparent public func pow(_ x: Float, _ y: Float) -> Float { powf(x, y) }
@_transparent public func copysign(_ x: Float, _ y: Float) -> Float { copysignf(x, y) }
@_transparent public func nextafter(_ x: Float, _ y: Float) -> Float { nextafterf(x, y) }
@_transparent public func fdim(_ x: Float, _ y: Float) -> Float { fdimf(x, y) }
@_transparent public func fmax(_ x: Float, _ y: Float) -> Float { fmaxf(x, y) }
@_transparent public func fmin(_ x: Float, _ y: Float) -> Float { fminf(x, y) }
