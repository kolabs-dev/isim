// isim Accelerate Swift overlay: Quadrature (issue #543), over isim's C quadrature_integrate. Adapted.
@_exported import Accelerate

/// Numerical integration of a function over a finite interval.
public struct Quadrature {
    public enum Integrator {
        case qng
        case qag(pointsPerInterval: QAGPointsPerInterval, maxIntervals: Int)
        case qags(maxIntervals: Int)
        public static let nonAdaptive: Integrator = .qng
        public static func adaptive(pointsPerInterval: QAGPointsPerInterval = .fifteen, maxIntervals: Int) -> Integrator {
            .qag(pointsPerInterval: pointsPerInterval, maxIntervals: maxIntervals)
        }
        public static func adaptiveWithSingularities(maxIntervals: Int) -> Integrator { .qags(maxIntervals: maxIntervals) }
    }
    public struct QAGPointsPerInterval {
        public let points: Int
        init(points: Int) { self.points = points }
        public static let fifteen = QAGPointsPerInterval(points: 15)
        public static let twentyOne = QAGPointsPerInterval(points: 21)
        public static let thirtyOne = QAGPointsPerInterval(points: 31)
        public static let fortyOne = QAGPointsPerInterval(points: 41)
        public static let fiftyOne = QAGPointsPerInterval(points: 51)
        public static let sixtyOne = QAGPointsPerInterval(points: 61)
    }
    public enum Error: Swift.Error {
        case generic
        case invalidArgument
        case `internal`
        case integrateMaxEval
        case badIntegrandBehaviour
        public init(quadratureStatus status: quadrature_status) {
            switch status {
            case QUADRATURE_INVALID_ARG_ERROR: self = .invalidArgument
            case QUADRATURE_INTERNAL_ERROR: self = .internal
            case QUADRATURE_INTEGRATE_MAX_EVAL_ERROR: self = .integrateMaxEval
            case QUADRATURE_INTEGRATE_BAD_BEHAVIOUR_ERROR: self = .badIntegrandBehaviour
            default: self = .generic
            }
        }
        public var errorDescription: String {
            switch self {
            case .generic: return "Generic error."
            case .invalidArgument: return "Invalid Argument."
            case .internal: return "This is a bug in the Quadrature code, please file a bug report."
            case .integrateMaxEval: return "The requested accuracy limit could not be reached with the allowed number of evals/subdivisions."
            case .badIntegrandBehaviour: return "Extremely bad integrand behaviour, or excessive roundoff error occurs at some points of the integration interval."
            }
        }
    }

    public var absoluteTolerance: Double
    public var relativeTolerance: Double
    let integrator: Integrator

    public init(integrator: Integrator, absoluteTolerance: Double = 1.0e-8, relativeTolerance: Double = 1.0e-2) {
        self.integrator = integrator
        self.absoluteTolerance = absoluteTolerance
        self.relativeTolerance = relativeTolerance
    }

    final class _Box {
        let body: (UnsafeBufferPointer<Double>, UnsafeMutableBufferPointer<Double>) -> ()
        init(_ body: @escaping (UnsafeBufferPointer<Double>, UnsafeMutableBufferPointer<Double>) -> ()) { self.body = body }
    }

    public func integrate(over interval: ClosedRange<Double>,
                          integrand: (_ input: UnsafeBufferPointer<Double>, _ result: UnsafeMutableBufferPointer<Double>) -> ())
        -> Result<(integralResult: Double, estimatedAbsoluteError: Double), Quadrature.Error> {
        withoutActuallyEscaping(integrand) { integrand in
            let box = _Box(integrand)
            var options = quadrature_integrate_options()
            options.abs_tolerance = absoluteTolerance
            options.rel_tolerance = relativeTolerance
            switch integrator {
            case .qng: options.integrator = QUADRATURE_INTEGRATE_QNG
            case .qag(let p, let m): options.integrator = QUADRATURE_INTEGRATE_QAG; options.qag_points_per_interval = p.points; options.max_intervals = m
            case .qags(let m): options.integrator = QUADRATURE_INTEGRATE_QAGS; options.max_intervals = m
            }
            var status = QUADRATURE_SUCCESS, error = 0.0
            let result: Double = withExtendedLifetime(box) {
                var fn = quadrature_integrate_function(fun: { arg, n, x, y in
                    let b = Unmanaged<_Box>.fromOpaque(arg!).takeUnretainedValue()
                    b.body(UnsafeBufferPointer(start: x, count: n), UnsafeMutableBufferPointer(start: y, count: n))
                }, fun_arg: Unmanaged.passUnretained(box).toOpaque())
                return quadrature_integrate(&fn, interval.lowerBound, interval.upperBound, &options, &status, &error, 0, nil)
            }
            return status == QUADRATURE_SUCCESS ? .success((result, error)) : .failure(Quadrature.Error(quadratureStatus: status))
        }
    }

    public func integrate(over interval: ClosedRange<Double>, integrand: (Double) -> Double)
        -> Result<(integralResult: Double, estimatedAbsoluteError: Double), Quadrature.Error> {
        integrate(over: interval) { x, y in for i in 0..<x.count { y[i] = integrand(x[i]) } }
    }
}
