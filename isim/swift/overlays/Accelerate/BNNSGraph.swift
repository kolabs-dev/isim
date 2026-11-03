// isim Accelerate overlay: BNNSGraph's Swift API (issue #824): BNNSGraph.Context over bnns_graph.h, and BNNSGraph.Builder,
// which records operations into isim's graph engine (frameworks/Accelerate/bnns_graph*.c) through the _isim_bnns_graph_*
// entry points. Apple's compiled model files cannot be read (their formats are undocumented): Context(compileFromPath:)
// throws.

// MARK: - the engine's entry points (frameworks/Accelerate/bnns_graph.c)

@_silgen_name("_isim_bnns_graph_new") func _isimGraphNew() -> OpaquePointer?
@_silgen_name("_isim_bnns_graph_argument")
func _isimGraphArgument(_ g: OpaquePointer, _ name: UnsafePointer<CChar>?, _ t: UInt32, _ rank: Int32, _ shape: UnsafePointer<Int64>?, _ intent: Int32) -> Int32
@_silgen_name("_isim_bnns_graph_constant")
func _isimGraphConstant(_ g: OpaquePointer, _ t: UInt32, _ rank: Int32, _ shape: UnsafePointer<Int64>?, _ values: UnsafePointer<Float>?) -> Int32
@_silgen_name("_isim_bnns_graph_op")
func _isimGraphOp(_ g: OpaquePointer, _ op: Int32, _ nin: Int32, _ inputs: UnsafePointer<Int32>?, _ nf: Int32, _ f: UnsafePointer<Float>?,
                  _ ni: Int32, _ ia: UnsafePointer<Int64>?, _ t: UInt32) -> Int32
@_silgen_name("_isim_bnns_graph_pick") func _isimGraphPick(_ g: OpaquePointer, _ node: Int32, _ k: Int32, _ t: UInt32) -> Int32
@_silgen_name("_isim_bnns_graph_set_outputs") func _isimGraphSetOutputs(_ g: OpaquePointer, _ count: Int32, _ nodes: UnsafePointer<Int32>?) -> Int32
@_silgen_name("_isim_bnns_graph_node_shape")
func _isimGraphNodeShape(_ g: OpaquePointer, _ node: Int32, _ rank: UnsafeMutablePointer<Int32>, _ shape: UnsafeMutablePointer<Int64>) -> Int32
@_silgen_name("_isim_bnns_graph_finish") func _isimGraphFinish(_ g: OpaquePointer) -> bnns_graph_t
@_silgen_name("_isim_bnns_graph_release") func _isimGraphRelease(_ g: OpaquePointer)

// operation numbers (bnns_graph_engine.h)
enum _GOp: Int32 {
    case unary = 10, binary, select, fma, reduce, argReduce, argSort, topK, cumSum, softmax, matmul, linear, conv, pool, norm, prelu,
         reshape, reshapeDynamic, transpose, shapeOf, slice, sliceSet, pad, concat, gather, gatherAxis, gatherND, scatter,
         scatterAxis, scatterND, cast, rnn, gru, lstm
}

public enum BNNSGraph {
    public protocol PointerArgument {
        associatedtype Element
        var baseAddress: UnsafeMutablePointer<Self.Element>? { get }
        var count: Int { get }
    }

    public struct CompileOptions {
        public init() {}
        public init(useSingleThread: Bool = false, generateDebugInfo: Bool = false,
                    optimizationPreference: BNNSGraph.CompileOptions.OptimizationPreference = .performance) {
            self.useSingleThread = useSingleThread; self.generateDebugInfo = generateDebugInfo; self.optimizationPreference = optimizationPreference
        }
        public var useSingleThread: Bool = false
        public var generateDebugInfo: Bool = false
        public struct OptimizationPreference: Equatable {
            @usableFromInline internal var value: BNNSGraphOptimizationPreference
            @usableFromInline @inline(__always) internal init(_ value: BNNSGraphOptimizationPreference) { self.value = value }
            @inlinable public static var performance: BNNSGraph.CompileOptions.OptimizationPreference { Self(BNNSGraphOptimizationPreferencePerformance) }
            @inlinable public static var internalRepresentationSize: BNNSGraph.CompileOptions.OptimizationPreference {
                Self(BNNSGraphOptimizationPreferenceIRSize)
            }
        }
        public var optimizationPreference: BNNSGraph.CompileOptions.OptimizationPreference = .performance
        func make() -> bnns_graph_compile_options_t {
            let o = BNNSGraphCompileOptionsMakeDefault()
            BNNSGraphCompileOptionsSetTargetSingleThread(o, useSingleThread)
            BNNSGraphCompileOptionsSetGenerateDebugInfo(o, generateDebugInfo)
            BNNSGraphCompileOptionsSetOptimizationPreference(o, optimizationPreference.value)
            return o
        }
    }

    public struct Shape: ExpressibleByArrayLiteral {
        public init(arrayLiteral elements: Int...) { dimensions = elements }
        public typealias ArrayLiteralElement = Int
        public var dimensions: [Int]
        public init(_ shape: [Int]) { dimensions = shape }
    }

    public enum Error: Swift.Error {
        case unableToCreateGraph
        case unableToCreateContext
        case unableToExecute
        case unableToSetDynamicShapes
        case unableToMakeGraph(_: String)
    }

    public protocol TensorDescriptor {
        var tensorData: UnsafeMutableRawPointer? { get }
    }

    public class Context {
        let graph: bnns_graph_t
        let context: bnns_graph_context_t
        var _builderGraph: OpaquePointer?

        init(graph: bnns_graph_t, builderGraph: OpaquePointer?) throws {
            self.graph = graph
            context = BNNSGraphContextMake(graph)
            _builderGraph = builderGraph
            if context.data == nil { throw BNNSGraph.Error.unableToCreateContext }
        }
        deinit {
            BNNSGraphContextDestroy(context)
            if let g = _builderGraph { _isimGraphRelease(g) }
        }
        static func _compile(_ path: String, _ functionName: String?, _ options: BNNSGraph.CompileOptions) throws -> bnns_graph_t {
            let o = options.make()
            defer { BNNSGraphCompileOptionsDestroy(o) }
            let g = BNNSGraphCompileFromFile(path, functionName, o)
            if g.data == nil { throw BNNSGraph.Error.unableToCreateGraph }
            return g
        }
        public convenience init(compileFromPath path: String, functionName: String? = nil, options: BNNSGraph.CompileOptions = CompileOptions()) throws {
            try self.init(graph: Context._compile(path, functionName, options), builderGraph: nil)
        }
        public convenience init(compileFromPath path: String, functionName: String? = nil, options: BNNSGraph.CompileOptions = CompileOptions()) async throws {
            try self.init(graph: Context._compile(path, functionName, options), builderGraph: nil)
        }

        public func setDynamicShapes(_ shapes: [BNNSGraph.Shape], forFunction function: String? = nil) async throws -> [BNNSGraph.Shape] {
            try _setDynamicShapes(shapes, function)
        }
        func _setDynamicShapes(_ shapes: [BNNSGraph.Shape], _ function: String?) throws -> [BNNSGraph.Shape] {
            var flat = shapes.flatMap { $0.dimensions.map { UInt64(Swift.max($0, 0)) } }
            let r: Int32 = flat.withUnsafeMutableBufferPointer { fb in
                var at = 0
                var cshapes: [bnns_graph_shape_t] = shapes.map { s in
                    defer { at += s.dimensions.count }
                    return bnns_graph_shape_t(rank: s.dimensions.count, shape: fb.baseAddress.map { $0 + at })
                }
                return BNNSGraphContextSetDynamicShapes(context, function, cshapes.count, &cshapes)
            }
            if r != 0 { throw BNNSGraph.Error.unableToSetDynamicShapes }
            let names = argumentNames(forFunction: function)
            return names.map { n in BNNSGraph.Shape(tensor(forFunction: function, argument: n, fillKnownDynamicShapes: true).map { _tensorShape($0) } ?? []) }
        }
        public func setBatchSize(_ batchSize: Int, forFunction function: String? = nil) async { _setBatchSize(batchSize, function) }
        public func setBatchSize(_ batchSize: Int, forFunction function: String? = nil) { _setBatchSize(batchSize, function) }
        func _setBatchSize(_ batchSize: Int, _ function: String?) { _ = BNNSGraphContextSetBatchSize(context, function, UInt64(batchSize)) }
        var _nanChecks = false
        public var checkForNaNsAndInfinities: Bool {
            get { _nanChecks }
            set { _nanChecks = newValue; BNNSGraphContextEnableNanAndInfChecks(context, newValue) }
        }
        var _advance = 0
        public var streamingAdvanceCount: Int {
            get { _advance }
            set { _advance = newValue; _ = BNNSGraphContextSetStreamingAdvanceCount(context, newValue) }
        }

        public func executeFunction(_ function: String? = nil, arguments: inout [BNNSTensor]) throws { try _execute(function, &arguments) }
        public func executeFunction(_ function: String? = nil, arguments: inout [BNNSTensor]) async throws { try _execute(function, &arguments) }
        func _execute(_ function: String?, _ arguments: inout [BNNSTensor]) throws {
            _ = BNNSGraphContextSetArgumentType(context, BNNSGraphArgumentTypeTensor)
            let r: Int32 = arguments.withUnsafeMutableBufferPointer { tb in
                var args: [bnns_graph_argument_t] = (0..<tb.count).map { k in
                    var a = bnns_graph_argument_t()
                    a.tensor = tb.baseAddress! + k
                    return a
                }
                return BNNSGraphContextExecute(context, function, args.count, &args, 0, nil)
            }
            if r != 0 { throw BNNSGraph.Error.unableToExecute }
        }
        public func executeFunction<T>(_ function: String? = nil, arguments: [T]) throws where T: BNNSGraph.PointerArgument {
            _ = BNNSGraphContextSetArgumentType(context, BNNSGraphArgumentTypePointer)
            var args: [bnns_graph_argument_t] = arguments.map { p in
                var a = bnns_graph_argument_t()
                a.data_ptr = UnsafeMutableRawPointer(p.baseAddress)
                a.data_ptr_size = p.count * MemoryLayout<T.Element>.stride
                return a
            }
            if BNNSGraphContextExecute(context, function, args.count, &args, 0, nil) != 0 { throw BNNSGraph.Error.unableToExecute }
        }
        public func argumentPosition(forFunction function: String? = nil, argument: String) -> Int {
            BNNSGraphGetArgumentPosition(graph, function, argument)   /* -1 (SIZE_MAX) when there is no such argument */
        }
        public func tensor(forFunction function: String? = nil, argument: String, fillKnownDynamicShapes: Bool) -> BNNSTensor? {
            var t = BNNSTensor()
            return BNNSGraphContextGetTensor(context, function, argument, fillKnownDynamicShapes, &t) == 0 ? t : nil
        }
        public func allocateTensor(forFunction function: String? = nil, argument: String, fillKnownDynamicShapes: Bool) -> BNNSTensor? {
            guard var t = tensor(forFunction: function, argument: argument, fillKnownDynamicShapes: fillKnownDynamicShapes) else { return nil }
            let n = withUnsafePointer(to: t) { BNNSTensorGetAllocationSize($0) }
            guard n >= 0 else { return nil }   /* SIZE_MAX: unknown */
            t.data = UnsafeMutableRawPointer.allocate(byteCount: Swift.max(n, 1), alignment: 64)
            t.data_size_in_bytes = n
            return t
        }
        public func argumentCount(forFunction function: String? = nil) -> Int { BNNSGraphGetArgumentCount(graph, function) }
        public var functionCount: Int { BNNSGraphGetFunctionCount(graph) }
        public func argumentNames(forFunction function: String? = nil) -> [String] {
            let n = argumentCount(forFunction: function)
            var names = [UnsafePointer<CChar>?](repeating: nil, count: n)
            _ = BNNSGraphGetArgumentNames(graph, function, n, &names)
            return names.map { $0.map { String(cString: $0) } ?? "" }
        }
        public var functionNames: [String] {
            let n = functionCount
            var names = [UnsafePointer<CChar>?](repeating: nil, count: n)
            _ = BNNSGraphGetFunctionNames(graph, n, &names)
            return names.map { $0.map { String(cString: $0) } ?? "" }
        }
    }

    public static func makeContext(options: BNNSGraph.CompileOptions = CompileOptions(),
                                   _ block: (inout BNNSGraph.Builder) -> [any BNNSGraph.TensorDescriptor]) throws -> BNNSGraph.Context {
        guard let g = _isimGraphNew() else { throw BNNSGraph.Error.unableToCreateGraph }
        var builder = Builder(box: Builder._Box(g))
        let outputs = block(&builder)
        var ids: [Int32] = []
        for o in outputs {
            guard let t = o as? _BuilderTensor, t._node >= 0 else { throw BNNSGraph.Error.unableToMakeGraph("an output is not a tensor of this builder") }
            ids.append(t._node)
        }
        if builder.box.failed { throw BNNSGraph.Error.unableToMakeGraph(builder.box.message) }
        _ = _isimGraphSetOutputs(g, Int32(ids.count), ids)
        let graph = _isimGraphFinish(g)
        if graph.data == nil { throw BNNSGraph.Error.unableToMakeGraph("the graph's shapes do not resolve") }
        builder.box.handedOff = true
        return try Context(graph: graph, builderGraph: g)
    }
}
extension BNNSGraph.Context: @unchecked Sendable {}
extension UnsafeMutableBufferPointer: BNNSGraph.PointerArgument where Element: BNNSScalar {}

func _tensorShape(_ t: BNNSTensor) -> [Int] {
    let r = Int(t.rank)
    return withUnsafeBytes(of: t.shape) { Array($0.bindMemory(to: Int.self).prefix(r)) }
}

// MARK: - the builder

protocol _BuilderTensor { var _node: Int32 { get } }

extension BNNSGraph {
    public struct Builder {
        final class _Box {
            let g: OpaquePointer
            var failed = false, message = ""
            var handedOff = false
            init(_ g: OpaquePointer) { self.g = g }
            deinit { if !handedOff { _isimGraphRelease(g) } }
            func fail(_ m: String) { if !failed { failed = true; message = m } }
        }
        let box: _Box

        public struct Tensor<T>: BNNSGraph.TensorDescriptor, CustomStringConvertible, _BuilderTensor where T: BNNSScalar {
            let box: _Box
            let _node: Int32
            init(box: _Box, node: Int32) { self.box = box; _node = node; if node < 0 { box.fail("an operation could not be added") } }
            public var tensorData: UnsafeMutableRawPointer? { nil }
            public var description: String { "BNNSGraph.Builder.Tensor<\(T.self)>(shape: \(shape.map { "\($0)" } ?? "unknown"))" }
            public var dataType: BNNSDataType? { T.bnnsDataType }
            public var rank: Int? { shape?.count }
            public var shape: [Int]? {
                var r: Int32 = 0
                var s = [Int64](repeating: 0, count: 8)
                guard _node >= 0, _isimGraphNodeShape(box.g, _node, &r, &s) == 0 else { return nil }
                return s.prefix(Int(r)).map { Int($0) }
            }
            public var stride: [Int]? {
                guard let s = shape else { return nil }
                var st = [Int](repeating: 1, count: s.count), n = 1
                for k in Swift.stride(from: s.count - 1, through: 0, by: -1) { st[k] = n; n *= s[k] }
                return st
            }
        }

        public enum Intent: Hashable {
            case input
            case inputOutput
        }

        public func argument<T>(name: String? = nil, dataType: T.Type, shape: [Int], intent: BNNSGraph.Builder.Intent = .input) -> BNNSGraph.Builder.Tensor<T>
            where T: BNNSScalar {
            let s = shape.map { Int64($0) }
            let id: Int32 = name.withOptionalCString { n in
                _isimGraphArgument(box.g, n, T.bnnsDataType.rawValue, Int32(s.count), s,
                                   Int32(intent == .input ? BNNSGraphArgumentIntentIn.rawValue : BNNSGraphArgumentIntentInOut.rawValue))
            }
            return Tensor(box: box, node: id)
        }
        public func constant<T>(name: String? = nil, value: T) -> BNNSGraph.Builder.Tensor<T> where T: BNNSScalar {
            _constant(T.self, [], [_bnnsFloat(value)])
        }
        public func constant<T>(name: String? = nil, values: some AccelerateBuffer<T>, shape: [Int]? = nil) -> BNNSGraph.Builder.Tensor<T>
            where T: BNNSScalar {
            let v: [Float] = values.withUnsafeBufferPointer { $0.map { _bnnsFloat($0) } }
            return _constant(T.self, shape ?? [v.count], v)
        }
        func _constant<T: BNNSScalar>(_ t: T.Type, _ shape: [Int], _ values: [Float]) -> Tensor<T> {
            let s = shape.map { Int64($0) }
            let count = shape.reduce(1, *)
            let v = values.count == count ? values : (0..<count).map { values.isEmpty ? 0 : values[$0 % values.count] }
            return Tensor(box: box, node: _isimGraphConstant(box.g, T.bnnsDataType.rawValue, Int32(s.count), s, v))
        }
        public func constant(values: Array<Array<Float16>>, rowMajor: Bool = false) -> BNNSGraph.Builder.Tensor<Float16> {
            let (shape, flat) = _matrix(values.map { $0.map { Float($0) } }, rowMajor)
            return _constant(Float16.self, shape, flat)
        }
        public func constant(values: Array<Array<Float>>, rowMajor: Bool = false) -> BNNSGraph.Builder.Tensor<Float> {
            let (shape, flat) = _matrix(values, rowMajor)
            return _constant(Float.self, shape, flat)
        }
        /// The inner arrays are rows when rowMajor, columns otherwise; the tensor is (rows, columns) either way.
        func _matrix(_ v: [[Float]], _ rowMajor: Bool) -> ([Int], [Float]) {
            let outer = v.count, inner = v.first?.count ?? 0
            if rowMajor { return ([outer, inner], v.flatMap { $0 }) }
            var flat = [Float](repeating: 0, count: outer * inner)
            for c in 0..<outer { for r in 0..<inner where r < v[c].count { flat[r * outer + c] = v[c][r] } }
            return ([inner, outer], flat)
        }
        public func concatenate<T>(_ tensors: [BNNSGraph.Builder.Tensor<T>], axis: Int) -> BNNSGraph.Builder.Tensor<T> where T: BNNSScalar {
            _op(T.self, .concat, tensors.map { $0._node }, ints: [axis])
        }

        func _op<U: BNNSScalar>(_ t: U.Type, _ op: _GOp, _ inputs: [Int32], floats: [Float] = [], ints: [Int] = []) -> Tensor<U> {
            let ia = ints.map { Int64($0) }
            let id = _isimGraphOp(box.g, op.rawValue, Int32(inputs.count), inputs, Int32(floats.count), floats, Int32(ia.count), ia, U.bnnsDataType.rawValue)
            return Tensor(box: box, node: id)
        }
        func _pick<U: BNNSScalar>(_ t: U.Type, _ node: Int32, _ k: Int) -> Tensor<U> {
            Tensor(box: box, node: _isimGraphPick(box.g, node, Int32(k), U.bnnsDataType.rawValue))
        }

        public protocol OperationParameter<Element> {
            associatedtype Element: BNNSScalar
            func graphBuilderTensor(_ builder: BNNSGraph.Builder) -> BNNSGraph.Builder.Tensor<Self.Element>
        }

        public protocol SliceIndex {}
        public struct SliceRange: BNNSGraph.Builder.SliceIndex, Equatable, Sendable {
            public let startIndex: Int
            public let endIndex: Int
            public static let fillAll = BNNSGraph.Builder.SliceRange(startIndex: 0, endIndex: Int.max)
            public init(startIndex: Int = 0, endIndex: Int) { self.startIndex = startIndex; self.endIndex = endIndex }
        }

        public enum ScatterMode: Hashable, Sendable {
            case update, add, subtract, multiply, divide, maximum, minimum
            var code: Int {
                switch self {
                case .update: return 0
                case .add: return 1
                case .subtract: return 2
                case .multiply: return 3
                case .divide: return 4
                case .maximum: return 5
                case .minimum: return 6
                }
            }
        }
        public enum Direction: Hashable, Sendable {
            case forward
            case reverse
        }
        public enum Activation: Hashable, Sendable {
            case hardSigmoid, linear, relu, scaledTanh, sigmoid, tanh
            var code: Int {
                switch self {
                case .hardSigmoid: return 0
                case .linear: return 1
                case .relu: return 2
                case .scaledTanh: return 3
                case .sigmoid: return 4
                case .tanh: return 5
                }
            }
        }
        public enum SortOrder: Hashable, Sendable {
            case ascending
            case descending
        }
        public enum PoolingFunction: Hashable, Sendable {
            case average(includePadding: Bool)
            case l2Norm
            case max
        }
        public enum CeilingMode: Hashable, Sendable {
            case floor
            case ceiling
        }
        public enum Padding: Hashable, Sendable {
            case constant(value: Float)
            case reflection
            case replication
        }
        public typealias PoolingPadding = BNNSGraph.Builder.ConvolutionPadding
        public enum ConvolutionPadding: Hashable, Sendable {
            case valid
            case custom(padding: [Int])
            case same
            case lower
            func encode(_ spatial: Int) -> (kind: Int, custom: [Int]) {
                switch self {
                case .valid: return (0, [Int](repeating: 0, count: 2 * spatial))
                case let .custom(p): return (1, (p + [Int](repeating: 0, count: Swift.max(0, 2 * spatial - p.count))).prefix(2 * spatial).map { $0 })
                case .same: return (2, [Int](repeating: 0, count: 2 * spatial))
                case .lower: return (3, [Int](repeating: 0, count: 2 * spatial))
                }
            }
        }
    }
}

func _bnnsFloat<T: BNNSScalar>(_ v: T) -> Float {
    switch v {
    case let x as Float: return x
    case let x as Float16: return Float(x)
    case let x as Int8: return Float(x)
    case let x as Int16: return Float(x)
    case let x as Int32: return Float(x)
    case let x as Int64: return Float(x)
    case let x as UInt8: return Float(x)
    case let x as UInt16: return Float(x)
    case let x as UInt32: return Float(x)
    case let x as UInt64: return Float(x)
    case let x as Bool: return x ? 1 : 0
    default: return 0
    }
}

extension Optional where Wrapped == String {
    func withOptionalCString<R>(_ body: (UnsafePointer<CChar>?) -> R) -> R {
        if let s = self { return s.withCString { body($0) } }
        return body(nil)
    }
}

// MARK: - operation parameters

extension BNNSGraph.Builder.Tensor: BNNSGraph.Builder.OperationParameter {
    public typealias Element = T
    public func graphBuilderTensor(_ builder: BNNSGraph.Builder) -> BNNSGraph.Builder.Tensor<T> { self }
}
extension Array: BNNSGraph.Builder.OperationParameter where Element: BNNSScalar {
    public func graphBuilderTensor(_ builder: BNNSGraph.Builder) -> BNNSGraph.Builder.Tensor<Element> { builder.constant(values: self) }
}
extension ContiguousArray: BNNSGraph.Builder.OperationParameter where Element: BNNSScalar {
    public func graphBuilderTensor(_ builder: BNNSGraph.Builder) -> BNNSGraph.Builder.Tensor<Element> { builder.constant(values: Array(self)) }
}
extension ArraySlice: BNNSGraph.Builder.OperationParameter where Element: BNNSScalar {
    public func graphBuilderTensor(_ builder: BNNSGraph.Builder) -> BNNSGraph.Builder.Tensor<Element> { builder.constant(values: Array(self)) }
}
extension UnsafeBufferPointer: BNNSGraph.Builder.OperationParameter where Element: BNNSScalar {
    public func graphBuilderTensor(_ builder: BNNSGraph.Builder) -> BNNSGraph.Builder.Tensor<Element> { builder.constant(values: Array(self)) }
}
extension UnsafeMutableBufferPointer: BNNSGraph.Builder.OperationParameter where Element: BNNSScalar {
    public func graphBuilderTensor(_ builder: BNNSGraph.Builder) -> BNNSGraph.Builder.Tensor<Element> { builder.constant(values: Array(self)) }
}
extension Float16: BNNSGraph.Builder.OperationParameter {
    public typealias Element = Float16
    public func graphBuilderTensor(_ builder: BNNSGraph.Builder) -> BNNSGraph.Builder.Tensor<Float16> { builder.constant(value: self) }
}
extension Float: BNNSGraph.Builder.OperationParameter {
    public typealias Element = Float
    public func graphBuilderTensor(_ builder: BNNSGraph.Builder) -> BNNSGraph.Builder.Tensor<Float> { builder.constant(value: self) }
}

extension Range: BNNSGraph.Builder.SliceIndex where Bound == Int {}
extension ClosedRange: BNNSGraph.Builder.SliceIndex where Bound == Int {}
extension PartialRangeFrom: BNNSGraph.Builder.SliceIndex where Bound == Int {}
extension PartialRangeThrough: BNNSGraph.Builder.SliceIndex where Bound == Int {}
extension PartialRangeUpTo: BNNSGraph.Builder.SliceIndex where Bound == Int {}
extension Int: BNNSGraph.Builder.SliceIndex {}

// MARK: - the tensor operations

extension BNNSGraph.Builder.Tensor {
    var _builder: BNNSGraph.Builder { BNNSGraph.Builder(box: box) }
    func _p<P: BNNSGraph.Builder.OperationParameter>(_ p: P) -> Int32 where P.Element == T { p.graphBuilderTensor(_builder)._node }
    func _anyP(_ p: any BNNSGraph.Builder.OperationParameter<T>) -> Int32 { p.graphBuilderTensor(_builder)._node }
    func _unary(_ fn: Int, _ a: Float = 0, _ b: Float = 0) -> BNNSGraph.Builder.Tensor<T> {
        _builder._op(T.self, .unary, [_node], floats: [a, b], ints: [fn])
    }
    func _binary(_ fn: Int, _ other: Int32) -> BNNSGraph.Builder.Tensor<T> { _builder._op(T.self, .binary, [_node, other], ints: [fn]) }
    func _compare(_ fn: Int, _ other: Int32) -> BNNSGraph.Builder.Tensor<Bool> { _builder._op(Bool.self, .binary, [_node, other], ints: [fn]) }
    func _reduce(_ fn: Int, _ axes: [Int], _ keep: Bool) -> BNNSGraph.Builder.Tensor<T> {
        _builder._op(T.self, .reduce, [_node], ints: [fn, keep ? 1 : 0, axes.count] + axes)
    }

    // reductions
    public func sum(axes: [Int], keepDimensions: Bool) -> BNNSGraph.Builder.Tensor<T> { _reduce(0, axes, keepDimensions) }
    public func sumOfSquares(axes: [Int], keepDimensions: Bool) -> BNNSGraph.Builder.Tensor<T> { _reduce(1, axes, keepDimensions) }
    public func product(axes: [Int], keepDimensions: Bool) -> BNNSGraph.Builder.Tensor<T> { _reduce(2, axes, keepDimensions) }
    public func mean(axes: [Int], keepDimensions: Bool) -> BNNSGraph.Builder.Tensor<T> { _reduce(3, axes, keepDimensions) }
    public func minimum(axes: [Int], keepDimensions: Bool) -> BNNSGraph.Builder.Tensor<T> { _reduce(4, axes, keepDimensions) }
    public func maximum(axes: [Int], keepDimensions: Bool) -> BNNSGraph.Builder.Tensor<T> { _reduce(5, axes, keepDimensions) }
    public func l1Norm(axes: [Int], keepDimensions: Bool) -> BNNSGraph.Builder.Tensor<T> { _reduce(6, axes, keepDimensions) }
    public func l2Norm(axes: [Int], keepDimensions: Bool) -> BNNSGraph.Builder.Tensor<T> { _reduce(7, axes, keepDimensions) }
    public func logSum(axes: [Int], keepDimensions: Bool) -> BNNSGraph.Builder.Tensor<T> { _reduce(8, axes, keepDimensions) }
    public func logSumExp(axes: [Int], keepDimensions: Bool) -> BNNSGraph.Builder.Tensor<T> { _reduce(9, axes, keepDimensions) }

    // normalizations
    func _norm(_ kind: Int, _ inputs: [Int32], _ eps: Float, _ axes: [Int] = []) -> BNNSGraph.Builder.Tensor<T> {
        _builder._op(T.self, .norm, [_node] + inputs, floats: [eps], ints: [kind, axes.count] + axes)
    }
    public func batchNorm(mean: some BNNSGraph.Builder.OperationParameter<T>, variance: some BNNSGraph.Builder.OperationParameter<T>,
                          weight: some BNNSGraph.Builder.OperationParameter<T>, bias: some BNNSGraph.Builder.OperationParameter<T>,
                          epsilon: Float = .ulpOfOne.squareRoot()) -> BNNSGraph.Builder.Tensor<T> {
        _norm(0, [_p(mean), _p(variance), _p(weight), _p(bias)], epsilon)
    }
    public func batchNorm(mean: some BNNSGraph.Builder.OperationParameter<T>, variance: some BNNSGraph.Builder.OperationParameter<T>,
                          epsilon: Float = .ulpOfOne.squareRoot()) -> BNNSGraph.Builder.Tensor<T> {
        _norm(0, [_p(mean), _p(variance)], epsilon)
    }
    public func channelNorm(weight: some BNNSGraph.Builder.OperationParameter<T>, bias: some BNNSGraph.Builder.OperationParameter<T>,
                            epsilon: Float = .ulpOfOne.squareRoot()) -> BNNSGraph.Builder.Tensor<T> { _norm(1, [_p(weight), _p(bias)], epsilon) }
    public func channelNorm(epsilon: Float = .ulpOfOne.squareRoot()) -> BNNSGraph.Builder.Tensor<T> { _norm(1, [], epsilon) }
    public func instanceNorm(weight: some BNNSGraph.Builder.OperationParameter<T>, bias: some BNNSGraph.Builder.OperationParameter<T>,
                             epsilon: Float = .ulpOfOne.squareRoot()) -> BNNSGraph.Builder.Tensor<T> { _norm(2, [_p(weight), _p(bias)], epsilon) }
    public func instanceNorm(epsilon: Float = .ulpOfOne.squareRoot()) -> BNNSGraph.Builder.Tensor<T> { _norm(2, [], epsilon) }
    public func layerNorm(weight: some BNNSGraph.Builder.OperationParameter<T>, bias: some BNNSGraph.Builder.OperationParameter<T>, axes: [Int],
                          epsilon: Float = .ulpOfOne.squareRoot()) -> BNNSGraph.Builder.Tensor<T> { _norm(3, [_p(weight), _p(bias)], epsilon, axes) }
    public func layerNorm(axes: [Int], epsilon: Float = .ulpOfOne.squareRoot()) -> BNNSGraph.Builder.Tensor<T> { _norm(3, [], epsilon, axes) }
    public func l2Norm(epsilon: Float = .ulpOfOne.squareRoot()) -> BNNSGraph.Builder.Tensor<T> { _norm(4, [], epsilon) }
    public func rmsNorm(scale: some BNNSGraph.Builder.OperationParameter<T>, epsilon: Float = .ulpOfOne.squareRoot()) -> BNNSGraph.Builder.Tensor<T> {
        _norm(5, [_p(scale)], epsilon)
    }

    // slicing
    func _sliceSpec(_ ranges: [any BNNSGraph.Builder.SliceIndex]) -> [Int] {
        var spec: [Int] = []
        for r in ranges {
            switch r {
            case let i as Int: spec += [i, i + 1, 1, 1]
            case let x as Range<Int>: spec += [x.lowerBound, x.upperBound, 1, 0]
            case let x as ClosedRange<Int>: spec += [x.lowerBound, x.upperBound + 1, 1, 0]
            case let x as PartialRangeFrom<Int>: spec += [x.lowerBound, Int.max / 2, 1, 0]
            case let x as PartialRangeThrough<Int>: spec += [0, x.upperBound + 1, 1, 0]
            case let x as PartialRangeUpTo<Int>: spec += [0, x.upperBound, 1, 0]
            case let x as BNNSGraph.Builder.SliceRange: spec += [x.startIndex, x.endIndex == Int.max ? Int.max / 2 : x.endIndex, 1, 0]
            default: spec += [0, Int.max / 2, 1, 0]
            }
        }
        return spec
    }
    public subscript(ranges: any BNNSGraph.Builder.SliceIndex...) -> BNNSGraph.Builder.Tensor<T> {
        get { _builder._op(T.self, .slice, [_node], ints: _sliceSpec(ranges)) }
        set(newValue) { self = _builder._op(T.self, .sliceSet, [_node, newValue._node], ints: _sliceSpec(ranges)) }
    }

    // pooling
    public func pooling(_ function: BNNSGraph.Builder.PoolingFunction, kernelSize: [Int], strides: [Int], padding: BNNSGraph.Builder.PoolingPadding,
                        ceilingMode: BNNSGraph.Builder.CeilingMode) -> BNNSGraph.Builder.Tensor<T> {
        let fn: Int
        switch function {
        case .max: fn = 0
        case let .average(inc): fn = inc ? 2 : 1
        case .l2Norm: fn = 3
        }
        let ns = kernelSize.count, pd = padding.encode(ns)
        let st = strides.isEmpty ? [Int](repeating: 1, count: ns) : strides
        return _builder._op(T.self, .pool, [_node], ints: [fn, ceilingMode == .ceiling ? 1 : 0, pd.kind, ns] + kernelSize + st + pd.custom)
    }

    // matrix products and convolutions
    public func matmul(transpose: Bool = false, other: some BNNSGraph.Builder.OperationParameter<T>, transposeOther: Bool = false,
                       bias: some BNNSGraph.Builder.OperationParameter<T>) -> BNNSGraph.Builder.Tensor<T> {
        _builder._op(T.self, .matmul, [_node, _p(other), _p(bias)], ints: [transpose ? 1 : 0, transposeOther ? 1 : 0])
    }
    public func matmul(transpose: Bool = false, other: some BNNSGraph.Builder.OperationParameter<T>, transposeOther: Bool = false) -> BNNSGraph.Builder.Tensor<T> {
        _builder._op(T.self, .matmul, [_node, _p(other)], ints: [transpose ? 1 : 0, transposeOther ? 1 : 0])
    }
    public func linear(weight: some BNNSGraph.Builder.OperationParameter<T>, bias: some BNNSGraph.Builder.OperationParameter<T>) -> BNNSGraph.Builder.Tensor<T> {
        _builder._op(T.self, .linear, [_node, _p(weight), _p(bias)])
    }
    public func linear(weight: some BNNSGraph.Builder.OperationParameter<T>) -> BNNSGraph.Builder.Tensor<T> {
        _builder._op(T.self, .linear, [_node, _p(weight)])
    }
    public func cast<U>(to type: U.Type) -> BNNSGraph.Builder.Tensor<U> where U: BNNSScalar { _builder._op(U.self, .cast, [_node]) }
    func _conv(_ transposed: Bool, _ weight: Int32, _ bias: Int32?, _ strides: [Int], _ padding: BNNSGraph.Builder.ConvolutionPadding, _ dilations: [Int]?,
               _ groups: Int, _ outputPadding: [Int]?) -> BNNSGraph.Builder.Tensor<T> {
        let ns = Swift.max((rank ?? 4) - 2, 1), pd = padding.encode(ns)
        let st = strides.isEmpty ? [Int](repeating: 1, count: ns) : strides
        let dl = dilations ?? [Int](repeating: 1, count: ns), op = outputPadding ?? [Int](repeating: 0, count: ns)
        return _builder._op(T.self, .conv, [_node, weight] + (bias.map { [$0] } ?? []),
                            ints: [transposed ? 1 : 0, groups, pd.kind, ns] + st + dl + pd.custom + op)
    }
    public func conv(weight: some BNNSGraph.Builder.OperationParameter<T>, strides: [Int], padding: BNNSGraph.Builder.ConvolutionPadding,
                     dilations: [Int]? = nil, groupCount: Int = 1) -> BNNSGraph.Builder.Tensor<T> {
        _conv(false, _p(weight), nil, strides, padding, dilations, groupCount, nil)
    }
    public func conv(weight: some BNNSGraph.Builder.OperationParameter<T>, strides: [Int], bias: some BNNSGraph.Builder.OperationParameter<T>,
                     padding: BNNSGraph.Builder.ConvolutionPadding, dilations: [Int]? = nil, groupCount: Int = 1) -> BNNSGraph.Builder.Tensor<T> {
        _conv(false, _p(weight), _p(bias), strides, padding, dilations, groupCount, nil)
    }
    public func convTranspose(weight: some BNNSGraph.Builder.OperationParameter<T>, strides: [Int], padding: BNNSGraph.Builder.ConvolutionPadding,
                              outputPaddingValues: [Int]? = nil, dilations: [Int]? = nil, groupCount: Int = 1) -> BNNSGraph.Builder.Tensor<T> {
        _conv(true, _p(weight), nil, strides, padding, dilations, groupCount, outputPaddingValues)
    }
    public func convTranspose(weight: some BNNSGraph.Builder.OperationParameter<T>, strides: [Int], bias: some BNNSGraph.Builder.OperationParameter<T>,
                              padding: BNNSGraph.Builder.ConvolutionPadding, outputPaddingValues: [Int]? = nil, dilations: [Int]? = nil,
                              groupCount: Int = 1) -> BNNSGraph.Builder.Tensor<T> {
        _conv(true, _p(weight), _p(bias), strides, padding, dilations, groupCount, outputPaddingValues)
    }

    // activations and element functions
    public func softmax(axis: Int) -> BNNSGraph.Builder.Tensor<T> { _builder._op(T.self, .softmax, [_node], ints: [axis, 0]) }
    public func logSoftmax(axis: Int) -> BNNSGraph.Builder.Tensor<T> { _builder._op(T.self, .softmax, [_node], ints: [axis, 1]) }
    public func softplus(alpha: Float) -> BNNSGraph.Builder.Tensor<T> { _unary(38, alpha) }
    public func relu() -> BNNSGraph.Builder.Tensor<T> { _unary(23) }
    public func relu6() -> BNNSGraph.Builder.Tensor<T> { _unary(24) }
    public func leakyReLU(alpha: Float = 0.01) -> BNNSGraph.Builder.Tensor<T> { _unary(25, alpha) }
    public func sigmoid() -> BNNSGraph.Builder.Tensor<T> { _unary(26) }
    public func clampedReLU(alpha: Float, beta: Float) -> BNNSGraph.Builder.Tensor<T> { _unary(27, alpha, beta) }
    public func scaledTanh(alpha: Float, beta: Float) -> BNNSGraph.Builder.Tensor<T> { _unary(28, alpha, beta) }
    public func hardSigmoid(alpha: Float, beta: Float) -> BNNSGraph.Builder.Tensor<T> { _unary(29, alpha, beta) }
    public func softsign() -> BNNSGraph.Builder.Tensor<T> { _unary(30) }
    public func elu(alpha: Float) -> BNNSGraph.Builder.Tensor<T> { _unary(31, alpha) }
    public func thresholdedReLU(alpha: Float) -> BNNSGraph.Builder.Tensor<T> { _unary(32, alpha) }
    public func hardSwish() -> BNNSGraph.Builder.Tensor<T> { _unary(33) }
    public func silu() -> BNNSGraph.Builder.Tensor<T> { _unary(34) }
    public func erf() -> BNNSGraph.Builder.Tensor<T> { _unary(22) }
    public func gelu() -> BNNSGraph.Builder.Tensor<T> { _unary(35) }
    public func geluTanhApproximation() -> BNNSGraph.Builder.Tensor<T> { _unary(36) }
    public func geluSigmoidApproximation() -> BNNSGraph.Builder.Tensor<T> { _unary(37) }
    public func prelu(alpha: [Float]) -> BNNSGraph.Builder.Tensor<T> {
        let a = _builder._constant(Float.self, [alpha.count], alpha)
        return _builder._op(T.self, .prelu, [_node, a._node])
    }
    public func fma(y: some BNNSGraph.Builder.OperationParameter<T>, z: some BNNSGraph.Builder.OperationParameter<T>) -> BNNSGraph.Builder.Tensor<T> {
        _builder._op(T.self, .fma, [_node, _p(y), _p(z)])
    }
    public func unsqueeze(axis: Int) -> BNNSGraph.Builder.Tensor<T> {
        var s = shape ?? []
        let a = axis < 0 ? axis + s.count + 1 : axis
        s.insert(1, at: Swift.min(Swift.max(a, 0), s.count))
        return reshape(to: s)
    }
    public func squeeze(axis: Int) -> BNNSGraph.Builder.Tensor<T> {
        var s = shape ?? []
        let a = axis < 0 ? axis + s.count : axis
        if a >= 0 && a < s.count && s[a] == 1 { s.remove(at: a) }
        return reshape(to: s)
    }
    public func cos() -> BNNSGraph.Builder.Tensor<T> { _unary(11) }
    public func cosh() -> BNNSGraph.Builder.Tensor<T> { _unary(17) }
    public func sin() -> BNNSGraph.Builder.Tensor<T> { _unary(10) }
    public func sinh() -> BNNSGraph.Builder.Tensor<T> { _unary(16) }
    public func tan() -> BNNSGraph.Builder.Tensor<T> { _unary(12) }
    public func tanh() -> BNNSGraph.Builder.Tensor<T> { _unary(18) }
    public func acos() -> BNNSGraph.Builder.Tensor<T> { _unary(14) }
    public func acosh() -> BNNSGraph.Builder.Tensor<T> { _unary(20) }
    public func asin() -> BNNSGraph.Builder.Tensor<T> { _unary(13) }
    public func asinh() -> BNNSGraph.Builder.Tensor<T> { _unary(19) }
    public func atan() -> BNNSGraph.Builder.Tensor<T> { _unary(15) }
    public func atanh() -> BNNSGraph.Builder.Tensor<T> { _unary(21) }
    public func exp() -> BNNSGraph.Builder.Tensor<T> { _unary(7) }
    public func exp2() -> BNNSGraph.Builder.Tensor<T> { _unary(8) }
    public func log(epsilon: Float = .ulpOfOne.squareRoot()) -> BNNSGraph.Builder.Tensor<T> { _unary(9, epsilon) }
    public func sqrt() -> BNNSGraph.Builder.Tensor<T> { _unary(4) }
    public func rsqrt(epsilon: Float = .ulpOfOne.squareRoot()) -> BNNSGraph.Builder.Tensor<T> { _unary(5, epsilon) }
    public func pow(y: some BNNSGraph.Builder.OperationParameter<T>) -> BNNSGraph.Builder.Tensor<T> { _binary(5, _p(y)) }
    public func max(y: some BNNSGraph.Builder.OperationParameter<T>) -> BNNSGraph.Builder.Tensor<T> { _binary(6, _p(y)) }
    public func min(y: some BNNSGraph.Builder.OperationParameter<T>) -> BNNSGraph.Builder.Tensor<T> { _binary(7, _p(y)) }
    public func abs() -> BNNSGraph.Builder.Tensor<T> { _unary(0) }
    public func ceil() -> BNNSGraph.Builder.Tensor<T> { _unary(1) }
    public func clip(to bounds: ClosedRange<Float>) -> BNNSGraph.Builder.Tensor<T> { _unary(39, bounds.lowerBound, bounds.upperBound) }
    public func floor() -> BNNSGraph.Builder.Tensor<T> { _unary(2) }
    public func reciprocal(epsilon: Float = .ulpOfOne.squareRoot()) -> BNNSGraph.Builder.Tensor<T> { _unary(6, epsilon) }
    public func round() -> BNNSGraph.Builder.Tensor<T> { _unary(3) }
    public func threshold(to lowerBound: Float) -> BNNSGraph.Builder.Tensor<T> { _unary(40, lowerBound) }

    // indices, sorting, shapes
    public func argMin(axis: Int, keepDimension: Bool) -> BNNSGraph.Builder.Tensor<Int32> {
        _builder._op(Int32.self, .argReduce, [_node], ints: [0, axis, keepDimension ? 1 : 0])
    }
    public func argMax(axis: Int, keepDimension: Bool) -> BNNSGraph.Builder.Tensor<Int32> {
        _builder._op(Int32.self, .argReduce, [_node], ints: [1, axis, keepDimension ? 1 : 0])
    }
    public func argSort(axis: Int, sortOrder: BNNSGraph.Builder.SortOrder) -> BNNSGraph.Builder.Tensor<Int32> {
        _builder._op(Int32.self, .argSort, [_node], ints: [axis, sortOrder == .descending ? 1 : 0])
    }
    public func cumulativeSum(axis: Int) -> BNNSGraph.Builder.Tensor<T> { _builder._op(T.self, .cumSum, [_node], ints: [axis]) }
    public func pad(_ type: BNNSGraph.Builder.Padding, padding: [Int]) -> BNNSGraph.Builder.Tensor<T> {
        let mode: Int, value: Float
        switch type {
        case let .constant(v): mode = 0; value = v
        case .reflection: mode = 1; value = 0
        case .replication: mode = 2; value = 0
        }
        return _builder._op(T.self, .pad, [_node], floats: [value], ints: [mode, padding.count / 2] + padding)
    }
    public func tensorShape() -> BNNSGraph.Builder.Tensor<Int32> { _builder._op(Int32.self, .shapeOf, [_node]) }
    public func reshape(to shape: some BNNSGraph.Builder.OperationParameter<Int32>) -> BNNSGraph.Builder.Tensor<T> {
        _builder._op(T.self, .reshapeDynamic, [_node, shape.graphBuilderTensor(_builder)._node])
    }
    public func reshape(to shape: [Int]) -> BNNSGraph.Builder.Tensor<T> { _builder._op(T.self, .reshape, [_node], ints: [shape.count] + shape) }
    public func transpose(axes: [Int]) -> BNNSGraph.Builder.Tensor<T> { _builder._op(T.self, .transpose, [_node], ints: axes) }
    public func topK(_ k: Int, axis: Int, findLargest: Bool) -> (values: BNNSGraph.Builder.Tensor<T>, indices: BNNSGraph.Builder.Tensor<Int32>) {
        let t = _builder._op(T.self, .topK, [_node], ints: [k, axis, findLargest ? 1 : 0])
        return (_builder._pick(T.self, t._node, 0), _builder._pick(Int32.self, t._node, 1))
    }

    // gathering and scattering
    public func gather(indices: some BNNSGraph.Builder.OperationParameter<Int32>, axis: Int, batchDimensionCount: Int) -> BNNSGraph.Builder.Tensor<T> {
        _builder._op(T.self, .gather, [_node, indices.graphBuilderTensor(_builder)._node], ints: [axis, batchDimensionCount])
    }
    public func gatherAlongAxis(indices: some BNNSGraph.Builder.OperationParameter<Int32>, axis: Int) -> BNNSGraph.Builder.Tensor<T> {
        _builder._op(T.self, .gatherAxis, [_node, indices.graphBuilderTensor(_builder)._node], ints: [axis])
    }
    public func gatherND(indices: some BNNSGraph.Builder.OperationParameter<Int32>, batchDimensionCount: Int) -> BNNSGraph.Builder.Tensor<T> {
        _builder._op(T.self, .gatherND, [_node, indices.graphBuilderTensor(_builder)._node], ints: [batchDimensionCount])
    }
    public func scatter(updates: BNNSGraph.Builder.Tensor<T>, indices: some BNNSGraph.Builder.OperationParameter<Int32>,
                        mode: BNNSGraph.Builder.ScatterMode, axis: Int) -> BNNSGraph.Builder.Tensor<T> {
        _builder._op(T.self, .scatter, [_node, updates._node, indices.graphBuilderTensor(_builder)._node], ints: [axis, mode.code])
    }
    public func scatterAlongAxis(updates: BNNSGraph.Builder.Tensor<T>, indices: some BNNSGraph.Builder.OperationParameter<Int32>,
                                 mode: BNNSGraph.Builder.ScatterMode, axis: Int) -> BNNSGraph.Builder.Tensor<T> {
        _builder._op(T.self, .scatterAxis, [_node, updates._node, indices.graphBuilderTensor(_builder)._node], ints: [axis, mode.code])
    }
    public func scatterND(updates: BNNSGraph.Builder.Tensor<T>, indices: some BNNSGraph.Builder.OperationParameter<Int32>,
                          mode: BNNSGraph.Builder.ScatterMode) -> BNNSGraph.Builder.Tensor<T> {
        _builder._op(T.self, .scatterND, [_node, updates._node, indices.graphBuilderTensor(_builder)._node], ints: [mode.code])
    }

    // recurrent layers (CoreML conventions: x [sequence, batch, input], weights [gates × hidden, input], bias [gates × hidden])
    public func rnn(initialHiddenStates: BNNSGraph.Builder.Tensor<T>, inputHiddenWeight: BNNSGraph.Builder.Tensor<T>,
                    hiddenHiddenWeight: BNNSGraph.Builder.Tensor<T>, bias: BNNSGraph.Builder.Tensor<T>, direction: BNNSGraph.Builder.Direction,
                    activation: BNNSGraph.Builder.Activation, outputSequence: Bool) -> (output: BNNSGraph.Builder.Tensor<T>, hiddenStates: BNNSGraph.Builder.Tensor<T>) {
        let t = _builder._op(T.self, .rnn, [_node, initialHiddenStates._node, inputHiddenWeight._node, hiddenHiddenWeight._node, bias._node],
                             ints: [direction == .reverse ? 1 : 0, activation.code, outputSequence ? 1 : 0])
        return (t, _builder._pick(T.self, t._node, 1))
    }
    public func gru(initialHiddenStates: BNNSGraph.Builder.Tensor<T>, inputHiddenWeight: BNNSGraph.Builder.Tensor<T>,
                    hiddenHiddenWeight: BNNSGraph.Builder.Tensor<T>, bias: BNNSGraph.Builder.Tensor<T>, inputBias: BNNSGraph.Builder.Tensor<T>,
                    direction: BNNSGraph.Builder.Direction, activation: BNNSGraph.Builder.Activation, recurrentActivation: BNNSGraph.Builder.Activation,
                    applyResetGateAfterMatMul: Bool, outputSequence: Bool) -> (output: BNNSGraph.Builder.Tensor<T>, hiddenStates: BNNSGraph.Builder.Tensor<T>) {
        let t = _builder._op(T.self, .gru, [_node, initialHiddenStates._node, inputHiddenWeight._node, hiddenHiddenWeight._node, bias._node, inputBias._node],
                             ints: [direction == .reverse ? 1 : 0, activation.code, recurrentActivation.code, applyResetGateAfterMatMul ? 1 : 0,
                                    outputSequence ? 1 : 0])
        return (t, _builder._pick(T.self, t._node, 1))
    }
    public func lstm(initialHiddenStates: BNNSGraph.Builder.Tensor<T>, initialCellStates: BNNSGraph.Builder.Tensor<T>,
                     inputHiddenWeight: BNNSGraph.Builder.Tensor<T>, hiddenHiddenWeight: BNNSGraph.Builder.Tensor<T>, bias: BNNSGraph.Builder.Tensor<T>,
                     direction: BNNSGraph.Builder.Direction, activation: BNNSGraph.Builder.Activation, recurrentActivation: BNNSGraph.Builder.Activation,
                     cellActivation: BNNSGraph.Builder.Activation, outputSequence: Bool)
        -> (output: BNNSGraph.Builder.Tensor<T>, hiddenStates: BNNSGraph.Builder.Tensor<T>, memoryStates: BNNSGraph.Builder.Tensor<T>) {
        let t = _builder._op(T.self, .lstm, [_node, initialHiddenStates._node, initialCellStates._node, inputHiddenWeight._node,
                                             hiddenHiddenWeight._node, bias._node],
                             ints: [direction == .reverse ? 1 : 0, activation.code, recurrentActivation.code, cellActivation.code,
                                    outputSequence ? 1 : 0, 0])
        return (t, _builder._pick(T.self, t._node, 1), _builder._pick(T.self, t._node, 2))
    }
    public func bidirectionalLSTM(initialHiddenStates: BNNSGraph.Builder.Tensor<T>, initialCellStates: BNNSGraph.Builder.Tensor<T>,
                                  inputHiddenWeight: BNNSGraph.Builder.Tensor<T>, hiddenHiddenWeight: BNNSGraph.Builder.Tensor<T>,
                                  bias: BNNSGraph.Builder.Tensor<T>, inputHiddenWeightBack: BNNSGraph.Builder.Tensor<T>,
                                  hiddenHiddenWeightBack: BNNSGraph.Builder.Tensor<T>, biasBack: BNNSGraph.Builder.Tensor<T>,
                                  activation: BNNSGraph.Builder.Activation, recurrentActivation: BNNSGraph.Builder.Activation,
                                  cellActivation: BNNSGraph.Builder.Activation, outputSequence: Bool)
        -> (output: BNNSGraph.Builder.Tensor<T>, hiddenStates: BNNSGraph.Builder.Tensor<T>, memoryStates: BNNSGraph.Builder.Tensor<T>) {
        let t = _builder._op(T.self, .lstm, [_node, initialHiddenStates._node, initialCellStates._node, inputHiddenWeight._node,
                                             hiddenHiddenWeight._node, bias._node, inputHiddenWeightBack._node, hiddenHiddenWeightBack._node,
                                             biasBack._node],
                             ints: [0, activation.code, recurrentActivation.code, cellActivation.code, outputSequence ? 1 : 0, 1])
        return (t, _builder._pick(T.self, t._node, 1), _builder._pick(T.self, t._node, 2))
    }
}

extension BNNSGraph.Builder.Tensor where T == Bool {
    public func select<U>(_ valueIfTrue: BNNSGraph.Builder.Tensor<U>, _ valueIfFalse: BNNSGraph.Builder.Tensor<U>) -> BNNSGraph.Builder.Tensor<U>
        where U: BNNSScalar {
        _builder._op(U.self, .select, [_node, valueIfTrue._node, valueIfFalse._node])
    }
    public func select<U>(_ valueIfTrue: BNNSGraph.Builder.Tensor<U>, _ valueIfFalse: any BNNSGraph.Builder.OperationParameter<U>) -> BNNSGraph.Builder.Tensor<U>
        where U: BNNSScalar {
        _builder._op(U.self, .select, [_node, valueIfTrue._node, valueIfFalse.graphBuilderTensor(_builder)._node])
    }
    public func select<U>(_ valueIfTrue: any BNNSGraph.Builder.OperationParameter<U>, _ valueIfFalse: BNNSGraph.Builder.Tensor<U>) -> BNNSGraph.Builder.Tensor<U>
        where U: BNNSScalar {
        _builder._op(U.self, .select, [_node, valueIfTrue.graphBuilderTensor(_builder)._node, valueIfFalse._node])
    }
    prefix public static func .! (rhs: BNNSGraph.Builder.Tensor<Bool>) -> BNNSGraph.Builder.Tensor<Bool> { rhs._unary(41) }
    public static func .& (lhs: BNNSGraph.Builder.Tensor<Bool>, rhs: BNNSGraph.Builder.Tensor<Bool>) -> BNNSGraph.Builder.Tensor<Bool> { lhs._compare(14, rhs._node) }
    public static func .| (lhs: BNNSGraph.Builder.Tensor<Bool>, rhs: BNNSGraph.Builder.Tensor<Bool>) -> BNNSGraph.Builder.Tensor<Bool> { lhs._compare(15, rhs._node) }
    public static func .^ (lhs: BNNSGraph.Builder.Tensor<Bool>, rhs: BNNSGraph.Builder.Tensor<Bool>) -> BNNSGraph.Builder.Tensor<Bool> { lhs._compare(16, rhs._node) }
}

extension BNNSGraph.Builder.Tensor where T: BNNSGraph.Builder.OperationParameter {
    public static func .== (lhs: BNNSGraph.Builder.Tensor<T>, rhs: BNNSGraph.Builder.Tensor<T>) -> BNNSGraph.Builder.Tensor<Bool> { lhs._compare(8, rhs._node) }
    public static func .!= (lhs: BNNSGraph.Builder.Tensor<T>, rhs: BNNSGraph.Builder.Tensor<T>) -> BNNSGraph.Builder.Tensor<Bool> { lhs._compare(9, rhs._node) }
    public static func .< (lhs: BNNSGraph.Builder.Tensor<T>, rhs: BNNSGraph.Builder.Tensor<T>) -> BNNSGraph.Builder.Tensor<Bool> { lhs._compare(10, rhs._node) }
    public static func .<= (lhs: BNNSGraph.Builder.Tensor<T>, rhs: BNNSGraph.Builder.Tensor<T>) -> BNNSGraph.Builder.Tensor<Bool> { lhs._compare(11, rhs._node) }
    public static func .> (lhs: BNNSGraph.Builder.Tensor<T>, rhs: BNNSGraph.Builder.Tensor<T>) -> BNNSGraph.Builder.Tensor<Bool> { lhs._compare(12, rhs._node) }
    public static func .>= (lhs: BNNSGraph.Builder.Tensor<T>, rhs: BNNSGraph.Builder.Tensor<T>) -> BNNSGraph.Builder.Tensor<Bool> { lhs._compare(13, rhs._node) }
}

extension BNNSGraph.Builder.OperationParameter {
    @_disfavoredOverload public static func * (lhs: Self, rhs: BNNSGraph.Builder.Tensor<Self.Element>) -> BNNSGraph.Builder.Tensor<Self.Element> {
        rhs._builder._op(Element.self, .binary, [lhs.graphBuilderTensor(rhs._builder)._node, rhs._node], ints: [2])
    }
    public static func * (lhs: BNNSGraph.Builder.Tensor<Self.Element>, rhs: Self) -> BNNSGraph.Builder.Tensor<Self.Element> {
        lhs._binary(2, rhs.graphBuilderTensor(lhs._builder)._node)
    }
    @_disfavoredOverload public static func + (lhs: Self, rhs: BNNSGraph.Builder.Tensor<Self.Element>) -> BNNSGraph.Builder.Tensor<Self.Element> {
        rhs._builder._op(Element.self, .binary, [lhs.graphBuilderTensor(rhs._builder)._node, rhs._node], ints: [0])
    }
    public static func + (lhs: BNNSGraph.Builder.Tensor<Self.Element>, rhs: Self) -> BNNSGraph.Builder.Tensor<Self.Element> {
        lhs._binary(0, rhs.graphBuilderTensor(lhs._builder)._node)
    }
    @_disfavoredOverload public static func / (lhs: Self, rhs: BNNSGraph.Builder.Tensor<Self.Element>) -> BNNSGraph.Builder.Tensor<Self.Element> {
        rhs._builder._op(Element.self, .binary, [lhs.graphBuilderTensor(rhs._builder)._node, rhs._node], ints: [3])
    }
    public static func / (lhs: BNNSGraph.Builder.Tensor<Self.Element>, rhs: Self) -> BNNSGraph.Builder.Tensor<Self.Element> {
        lhs._binary(3, rhs.graphBuilderTensor(lhs._builder)._node)
    }
    @_disfavoredOverload public static func - (lhs: Self, rhs: BNNSGraph.Builder.Tensor<Self.Element>) -> BNNSGraph.Builder.Tensor<Self.Element> {
        rhs._builder._op(Element.self, .binary, [lhs.graphBuilderTensor(rhs._builder)._node, rhs._node], ints: [1])
    }
    public static func - (lhs: BNNSGraph.Builder.Tensor<Self.Element>, rhs: Self) -> BNNSGraph.Builder.Tensor<Self.Element> {
        lhs._binary(1, rhs.graphBuilderTensor(lhs._builder)._node)
    }
    public static func % (lhs: BNNSGraph.Builder.Tensor<Self.Element>, rhs: Self) -> BNNSGraph.Builder.Tensor<Self.Element> {
        lhs._binary(4, rhs.graphBuilderTensor(lhs._builder)._node)
    }
}
