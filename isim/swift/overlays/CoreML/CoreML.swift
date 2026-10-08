// isim Core ML (self-authored, iOS API names): the data API (MLFeatureValue, MLFeatureProvider, MLDictionaryFeatureProvider,
// MLMultiArray, MLModelConfiguration, MLModelDescription, MLFeatureDescription, MLBatchProvider) and MLModel.
//
// Models: Xcode compiles .mlmodel files into .mlmodelc bundles whose format is Apple's and undocumented, and running
// neural networks needs Apple's runtime; isim has neither. What isim does instead (adapted):
//   - MLModel.compileModel(at:) "compiles" a .mlmodel (the open protobuf spec published with coremltools) into an
//     isim .mlmodelc directory that holds the spec (model.mlmodel) — not Apple's format.
//   - MLModel(contentsOf:) loads such an isim .mlmodelc (or a .mlmodelc that contains a model.mlmodel spec). The
//     description (inputs, outputs, metadata) is read from the spec for every model type.
//   - prediction(from:) runs only generalized linear models (GLMRegressor, GLMClassifier). Every other model type
//     (neural networks, ML programs, trees, pipelines, ...) fails with a clear error. An Apple-compiled .mlmodelc
//     without the spec fails to load with a clear error.
import Foundation
import CoreVideo

// MARK: - errors

public let MLModelErrorDomain = "com.apple.CoreML"
public struct MLModelError: CustomNSError, LocalizedError, Sendable, Hashable {
    public enum Code: Int, Sendable { case generic = 0, featureType = 1, io = 3, customLayer = 4, customModel = 5, update = 6, parameters = 7, modelDecryptionKeyFetch = 8, modelDecryption = 9, modelCollection = 10, predictionCancelled = 11 }
    public let code: Code
    let _message: String
    public init(_ code: Code) { self.code = code; _message = "Core ML error \(code.rawValue)" }
    init(_ code: Code, _ message: String) { self.code = code; _message = message }
    public static var errorDomain: String { MLModelErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: _message] }
    public var errorDescription: String? { _message }
    public static let generic = Code.generic, featureType = Code.featureType, io = Code.io
}
/// Core ML errors are NSErrors in MLModelErrorDomain (isim's Swift runtime does not bridge CustomNSError user info).
func _mlError(_ code: MLModelError.Code, _ message: String) -> NSError {
    NSError(domain: MLModelErrorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
}

// MARK: - features

@objc public enum MLFeatureType: Int, Sendable {
    case invalid = 0, int64 = 1, double = 2, string = 3, image = 4, multiArray = 5, dictionary = 6, sequence = 7, state = 8
}
@objc public enum MLMultiArrayDataType: Int, Sendable {
    case double = 65600, float32 = 65568, float16 = 65552, int32 = 131104, int8 = 131080
    public static let float64 = MLMultiArrayDataType.double
    public static let float = MLMultiArrayDataType.float32
    var size: Int { switch self { case .double: return 8; case .float32, .int32: return 4; case .float16: return 2; case .int8: return 1 } }
}

open class MLMultiArray: NSObject, @unchecked Sendable {
    public let shape: [NSNumber]
    public let strides: [NSNumber]
    public let dataType: MLMultiArrayDataType
    public let dataPointer: UnsafeMutableRawPointer
    let _owned: Bool
    let _deallocator: ((UnsafeMutableRawPointer) -> Void)?
    public var count: Int { shape.reduce(1) { $0 * $1.integerValue } }

    public init(shape: [NSNumber], dataType: MLMultiArrayDataType) throws {
        guard !shape.isEmpty, shape.allSatisfy({ $0.integerValue > 0 }) else { throw _mlError(.generic, "MLMultiArray shape must be non-empty with positive dimensions") }
        self.shape = shape; self.dataType = dataType
        var st: [Int] = [], acc = 1
        for d in shape.reversed() { st.insert(acc, at: 0); acc *= d.integerValue }
        strides = st.map { NSNumber(value: $0) }
        dataPointer = UnsafeMutableRawPointer.allocate(byteCount: max(1, acc * dataType.size), alignment: 16)
        dataPointer.initializeMemory(as: UInt8.self, repeating: 0, count: acc * dataType.size)
        _owned = true; _deallocator = nil
    }
    public init(dataPointer: UnsafeMutableRawPointer, shape: [NSNumber], dataType: MLMultiArrayDataType, strides: [NSNumber],
                deallocator: ((UnsafeMutableRawPointer) -> Void)? = nil) throws {
        guard shape.count == strides.count, !shape.isEmpty else { throw _mlError(.generic, "shape and strides must have the same rank") }
        self.dataPointer = dataPointer; self.shape = shape; self.strides = strides; self.dataType = dataType
        _owned = false; _deallocator = deallocator
    }
    /// iOS 15.4+: a scalar-filled array
    public convenience init(_ values: [Double]) throws {
        try self.init(shape: [NSNumber(value: values.count)], dataType: .double)
        for (i, v) in values.enumerated() { self[i] = NSNumber(value: v) }
    }
    deinit { if _owned { dataPointer.deallocate() } else { _deallocator?(dataPointer) } }

    func _offset(_ linear: Int) -> Int {
        // linear index in row-major logical order -> element offset using strides
        var rem = linear, off = 0
        for (d, s) in zip(shape, strides).reversed() { off += (rem % d.integerValue) * s.integerValue; rem /= d.integerValue }
        return off
    }
    func _get(_ off: Int) -> Double {
        switch dataType {
        case .double: return dataPointer.load(fromByteOffset: off * 8, as: Double.self)
        case .float32: return Double(dataPointer.load(fromByteOffset: off * 4, as: Float.self))
        case .float16: return Double(Float(_half: dataPointer.load(fromByteOffset: off * 2, as: UInt16.self)))
        case .int32: return Double(dataPointer.load(fromByteOffset: off * 4, as: Int32.self))
        case .int8: return Double(dataPointer.load(fromByteOffset: off, as: Int8.self))
        }
    }
    func _set(_ off: Int, _ v: Double) {
        switch dataType {
        case .double: dataPointer.storeBytes(of: v, toByteOffset: off * 8, as: Double.self)
        case .float32: dataPointer.storeBytes(of: Float(v), toByteOffset: off * 4, as: Float.self)
        case .float16: dataPointer.storeBytes(of: Float(v)._half, toByteOffset: off * 2, as: UInt16.self)
        case .int32: dataPointer.storeBytes(of: Int32(clamping: Int(v.rounded())), toByteOffset: off * 4, as: Int32.self)
        case .int8: dataPointer.storeBytes(of: Int8(clamping: Int(v.rounded())), toByteOffset: off, as: Int8.self)
        }
    }
    open subscript(index: Int) -> NSNumber {
        get { NSNumber(value: _get(_offset(index))) }
        set { _set(_offset(index), newValue.doubleValue) }
    }
    open subscript(key: [NSNumber]) -> NSNumber {
        get { NSNumber(value: _get(zip(key, strides).reduce(0) { $0 + $1.0.integerValue * $1.1.integerValue })) }
        set { _set(zip(key, strides).reduce(0) { $0 + $1.0.integerValue * $1.1.integerValue }, newValue.doubleValue) }
    }
    open func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try body(UnsafeRawBufferPointer(start: dataPointer, count: count * dataType.size))
    }
    open func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawBufferPointer, [Int]) throws -> R) rethrows -> R {
        try body(UnsafeMutableRawBufferPointer(start: dataPointer, count: count * dataType.size), strides.map(\.integerValue))
    }
    var _values: [Double] { (0..<count).map { _get(_offset($0)) } }
    open override var description: String { "MLMultiArray(shape: \(shape), dataType: \(dataType.rawValue), values: \(_values.prefix(16)))" }
}
extension Float {
    init(_half h: UInt16) {
        let s = UInt32(h >> 15) << 31, e = Int((h >> 10) & 0x1F), m = UInt32(h & 0x3FF)
        if e == 0 { self = (h >> 15 == 1 ? -1 : 1) * Float(m) / 16_777_216; return }
        if e == 31 { self = Float(bitPattern: s | 0x7F80_0000 | (m << 13)); return }
        self = Float(bitPattern: s | UInt32(e - 15 + 127) << 23 | (m << 13))
    }
    var _half: UInt16 {
        let b = bitPattern, s = UInt16((b >> 16) & 0x8000)
        let e = Int((b >> 23) & 0xFF) - 127 + 15, m = (b >> 13) & 0x3FF
        if e <= 0 { return s }
        if e >= 31 { return s | 0x7C00 }
        return s | UInt16(e) << 10 | UInt16(m)
    }
}

open class MLFeatureValue: NSObject, @unchecked Sendable {
    public let type: MLFeatureType
    public let int64Value: Int64
    public let doubleValue: Double
    public let stringValue: String
    public let multiArrayValue: MLMultiArray?
    public let dictionaryValue: [AnyHashable: NSNumber]
    public let imageBufferValue: CVPixelBuffer?
    public let sequenceValue: MLSequence?
    public var isUndefined: Bool { type == .invalid }
    init(type: MLFeatureType, int64: Int64 = 0, double: Double = 0, string: String = "", array: MLMultiArray? = nil,
         dict: [AnyHashable: NSNumber] = [:], image: CVPixelBuffer? = nil, sequence: MLSequence? = nil) {
        self.type = type; int64Value = int64; doubleValue = double; stringValue = string; multiArrayValue = array
        dictionaryValue = dict; imageBufferValue = image; sequenceValue = sequence
    }
    public convenience init(int64 value: Int64) { self.init(type: .int64, int64: value, double: Double(value)) }
    public convenience init(double value: Double) { self.init(type: .double, int64: Int64(value), double: value) }
    public convenience init(string value: String) { self.init(type: .string, string: value) }
    public convenience init(multiArray value: MLMultiArray) { self.init(type: .multiArray, array: value) }
    public convenience init(pixelBuffer value: CVPixelBuffer) { self.init(type: .image, image: value) }
    public convenience init(sequence value: MLSequence) { self.init(type: .sequence, sequence: value) }
    public convenience init(dictionary value: [AnyHashable: NSNumber]) throws { self.init(type: .dictionary, dict: value) }
    public convenience init(undefined type: MLFeatureType) { self.init(type: .invalid) }
    public func isEqual(to other: MLFeatureValue) -> Bool {
        guard type == other.type else { return false }
        switch type {
        case .int64: return int64Value == other.int64Value
        case .double: return doubleValue == other.doubleValue
        case .string: return stringValue == other.stringValue
        case .multiArray: return multiArrayValue?._values == other.multiArrayValue?._values
        case .dictionary: return dictionaryValue == other.dictionaryValue
        default: return self === other
        }
    }
    open override var description: String {
        switch type {
        case .int64: return "\(int64Value)"
        case .double: return "\(doubleValue)"
        case .string: return stringValue
        case .multiArray: return multiArrayValue?.description ?? "nil"
        case .dictionary: return "\(dictionaryValue)"
        default: return "MLFeatureValue(type: \(type.rawValue))"
        }
    }
}
open class MLSequence: NSObject, @unchecked Sendable {
    public let type: MLFeatureType
    public let stringValues: [String]
    public let int64Values: [NSNumber]
    init(type: MLFeatureType, strings: [String], ints: [NSNumber]) { self.type = type; stringValues = strings; int64Values = ints }
    public class func empty(of type: MLFeatureType) -> MLSequence { MLSequence(type: type, strings: [], ints: []) }
    public convenience init(strings: [String]) { self.init(type: .string, strings: strings, ints: []) }
    public convenience init(int64s: [NSNumber]) { self.init(type: .int64, strings: [], ints: int64s) }
}

public protocol MLFeatureProvider {
    var featureNames: Set<String> { get }
    func featureValue(for featureName: String) -> MLFeatureValue?
}
open class MLDictionaryFeatureProvider: NSObject, MLFeatureProvider, @unchecked Sendable {
    public let dictionary: [String: MLFeatureValue]
    public init(dictionary: [String: Any]) throws {
        var d: [String: MLFeatureValue] = [:]
        for (k, v) in dictionary {
            switch v {
            case let f as MLFeatureValue: d[k] = f
            case let a as MLMultiArray: d[k] = MLFeatureValue(multiArray: a)
            case let s as String: d[k] = MLFeatureValue(string: s)
            case let i as Int: d[k] = MLFeatureValue(int64: Int64(i))
            case let i as Int64: d[k] = MLFeatureValue(int64: i)
            case let x as Double: d[k] = MLFeatureValue(double: x)
            case let x as Float: d[k] = MLFeatureValue(double: Double(x))
            case let n as NSNumber: d[k] = MLFeatureValue(double: n.doubleValue)
            case let p as CVPixelBuffer: d[k] = MLFeatureValue(pixelBuffer: p)
            case let m as [AnyHashable: NSNumber]: d[k] = try MLFeatureValue(dictionary: m)
            default: throw _mlError(.featureType, "unsupported value for feature '\(k)': \(type(of: v))")
            }
        }
        self.dictionary = d
    }
    public var featureNames: Set<String> { Set(dictionary.keys) }
    public func featureValue(for featureName: String) -> MLFeatureValue? { dictionary[featureName] }
    public subscript(featureName: String) -> MLFeatureValue? { dictionary[featureName] }
}
public protocol MLBatchProvider {
    var count: Int { get }
    func features(at index: Int) -> MLFeatureProvider
}
open class MLArrayBatchProvider: NSObject, MLBatchProvider, @unchecked Sendable {
    public let array: [MLFeatureProvider]
    public init(array: [MLFeatureProvider]) { self.array = array }
    public init(dictionary: [String: [Any]]) throws {
        let n = dictionary.values.map(\.count).max() ?? 0
        array = try (0..<n).map { i in try MLDictionaryFeatureProvider(dictionary: dictionary.compactMapValues { i < $0.count ? $0[i] : nil }) }
    }
    public var count: Int { array.count }
    public func features(at index: Int) -> MLFeatureProvider { array[index] }
}

// MARK: - descriptions and configuration

open class MLMultiArrayConstraint: NSObject, @unchecked Sendable {
    public let shape: [NSNumber]
    public let dataType: MLMultiArrayDataType
    init(shape: [NSNumber], dataType: MLMultiArrayDataType) { self.shape = shape; self.dataType = dataType }
}
open class MLFeatureDescription: NSObject, @unchecked Sendable {
    public let name: String
    public let type: MLFeatureType
    public let isOptional: Bool
    public let multiArrayConstraint: MLMultiArrayConstraint?
    let _shortDescription: String
    init(name: String, type: MLFeatureType, optional: Bool, array: MLMultiArrayConstraint?, description: String) {
        self.name = name; self.type = type; isOptional = optional; multiArrayConstraint = array; _shortDescription = description
    }
    open func isAllowedValue(_ value: MLFeatureValue) -> Bool { value.type == type || (isOptional && value.isUndefined) || (type == .double && value.type == .int64) }
    open override var description: String { "\(name) : \(type.rawValue)" }
}
public struct MLModelMetadataKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let description = MLModelMetadataKey(rawValue: "MLModelDescriptionKey")
    public static let versionString = MLModelMetadataKey(rawValue: "MLModelVersionStringKey")
    public static let author = MLModelMetadataKey(rawValue: "MLModelAuthorKey")
    public static let license = MLModelMetadataKey(rawValue: "MLModelLicenseKey")
    public static let creatorDefinedKey = MLModelMetadataKey(rawValue: "MLModelCreatorDefinedKey")
}
open class MLModelDescription: NSObject, @unchecked Sendable {
    public let inputDescriptionsByName: [String: MLFeatureDescription]
    public let outputDescriptionsByName: [String: MLFeatureDescription]
    public let predictedFeatureName: String?
    public let predictedProbabilitiesName: String?
    public let metadata: [MLModelMetadataKey: Any]
    public let classLabels: [Any]?
    public var isUpdatable: Bool { false }
    init(inputs: [MLFeatureDescription], outputs: [MLFeatureDescription], predicted: String?, probabilities: String?, metadata: [MLModelMetadataKey: Any], labels: [Any]?) {
        inputDescriptionsByName = Dictionary(inputs.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        outputDescriptionsByName = Dictionary(outputs.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        predictedFeatureName = predicted; predictedProbabilitiesName = probabilities; self.metadata = metadata; classLabels = labels
    }
}
@objc public enum MLComputeUnits: Int, Sendable { case cpuOnly = 0, cpuAndGPU = 1, all = 2, cpuAndNeuralEngine = 3 }
open class MLModelConfiguration: NSObject, @unchecked Sendable, NSCopying {
    open var computeUnits: MLComputeUnits = .all
    open var allowLowPrecisionAccumulationOnGPU = false
    open var modelDisplayName: String?
    open var parameters: [AnyHashable: Any]?
    open var preferredMetalDevice: AnyObject?
    public override init() { super.init() }
    public func copy(with zone: NSZone? = nil) -> Any {
        let c = MLModelConfiguration(); c.computeUnits = computeUnits; c.allowLowPrecisionAccumulationOnGPU = allowLowPrecisionAccumulationOnGPU
        c.modelDisplayName = modelDisplayName; c.parameters = parameters; return c
    }
}
open class MLPredictionOptions: NSObject, @unchecked Sendable {
    open var usesCPUOnly = false
    open var outputBackings: [String: Any] = [:]
    public override init() { super.init() }
}

// MARK: - the model spec (protobuf)

/// Minimal protobuf reader for the Core ML model spec (coremltools' Model.proto and friends).
struct _PB {
    let b: [UInt8]
    var i = 0
    init(_ b: [UInt8]) { self.b = b }
    init(_ s: ArraySlice<UInt8>) { b = Array(s) }
    var atEnd: Bool { i >= b.count }
    mutating func varint() throws -> UInt64 {
        var r: UInt64 = 0, s: UInt64 = 0
        while true {
            guard i < b.count, s < 64 else { throw _mlError(.io, "malformed model spec") }
            let c = b[i]; i += 1
            r |= UInt64(c & 0x7F) << s
            if c & 0x80 == 0 { return r }
            s += 7
        }
    }
    /// (field, wire type, payload): varint value, or bytes for length-delimited, or raw 8/4 bytes
    mutating func next() throws -> (Int, Int, UInt64, ArraySlice<UInt8>) {
        let key = try varint()
        let f = Int(key >> 3), w = Int(key & 7)
        switch w {
        case 0: return (f, w, try varint(), [])
        case 1: guard i + 8 <= b.count else { throw _mlError(.io, "malformed model spec") }; defer { i += 8 }; return (f, w, 0, b[i..<i + 8])
        case 2:
            let n = Int(try varint())
            guard n >= 0, i + n <= b.count else { throw _mlError(.io, "malformed model spec") }
            defer { i += n }; return (f, w, 0, b[i..<i + n])
        case 5: guard i + 4 <= b.count else { throw _mlError(.io, "malformed model spec") }; defer { i += 4 }; return (f, w, 0, b[i..<i + 4])
        default: throw _mlError(.io, "malformed model spec (wire type \(w))")
        }
    }
    static func double(_ s: ArraySlice<UInt8>) -> Double { var v: UInt64 = 0; for (k, x) in s.enumerated() { v |= UInt64(x) << (8 * UInt64(k)) }; return Double(bitPattern: v) }
    /// repeated double: packed (wire 2) or not (wire 1)
    static func doubles(_ w: Int, _ s: ArraySlice<UInt8>) -> [Double] {
        if w == 1 { return [double(s)] }
        let a = Array(s); return stride(from: 0, to: a.count - 7, by: 8).map { double(a[$0..<$0 + 8]) }
    }
    static func string(_ s: ArraySlice<UInt8>) -> String { String(decoding: s, as: UTF8.self) }
}

/// What isim reads from a model spec.
struct _MLSpec {
    var version = 0
    var inputs: [MLFeatureDescription] = []
    var outputs: [MLFeatureDescription] = []
    var predicted: String?, probabilities: String?
    var metadata: [MLModelMetadataKey: Any] = [:]
    var kind = "unknown"
    // GLM
    var weights: [[Double]] = [], offsets: [Double] = []
    var transform = 0              // regressor: 0 none, 1 logit, 2 probit; classifier: 0 logit, 1 probit
    var encoding = 0               // 0 reference class, 1 one vs rest
    var labels: [Any] = []

    static let kinds: [Int: String] = [200: "pipelineClassifier", 201: "pipelineRegressor", 202: "pipeline", 300: "glmRegressor", 301: "supportVectorRegressor",
        302: "treeEnsembleRegressor", 303: "neuralNetworkRegressor", 304: "bayesianProbitRegressor", 400: "glmClassifier", 401: "supportVectorClassifier",
        402: "treeEnsembleClassifier", 403: "neuralNetworkClassifier", 404: "kNearestNeighborsClassifier", 500: "neuralNetwork",
        501: "itemSimilarityRecommender", 502: "mlProgram", 555: "customModel", 556: "linkedModel", 600: "oneHotEncoder", 601: "imputer",
        602: "featureVectorizer", 603: "dictVectorizer", 604: "scaler", 606: "categoricalMapping", 607: "normalizer", 609: "arrayFeatureExtractor",
        610: "nonMaximumSuppression", 900: "identity", 2000: "textClassifier", 2001: "wordTagger", 2002: "visionFeaturePrint",
        2003: "soundAnalysisPreprocessing", 2004: "gazetteer", 2005: "wordEmbedding", 2006: "audioFeaturePrint", 3000: "serializedModel"]

    init(_ data: [UInt8]) throws {
        var p = _PB(data)
        while !p.atEnd {
            let (f, _, v, s) = try p.next()
            switch f {
            case 1: version = Int(v)
            case 2: try parseDescription(s)
            case 300: kind = "glmRegressor"; try parseGLM(s, classifier: false)
            case 400: kind = "glmClassifier"; try parseGLM(s, classifier: true)
            default: if let k = _MLSpec.kinds[f] { kind = k }
            }
        }
    }
    mutating func parseDescription(_ s: ArraySlice<UInt8>) throws {
        var p = _PB(s)
        while !p.atEnd {
            let (f, _, _, d) = try p.next()
            switch f {
            case 1: inputs.append(try _MLSpec.feature(d))
            case 10: outputs.append(try _MLSpec.feature(d))
            case 11: predicted = _PB.string(d)
            case 12: probabilities = _PB.string(d)
            case 100:
                var m = _PB(d)
                var user: [String: String] = [:]
                while !m.atEnd {
                    let (g, _, _, x) = try m.next()
                    switch g {
                    case 1: metadata[.description] = _PB.string(x)
                    case 2: metadata[.versionString] = _PB.string(x)
                    case 3: metadata[.author] = _PB.string(x)
                    case 4: metadata[.license] = _PB.string(x)
                    case 100:
                        var e = _PB(x); var k = "", val = ""
                        while !e.atEnd { let (h, _, _, y) = try e.next(); if h == 1 { k = _PB.string(y) } else if h == 2 { val = _PB.string(y) } }
                        user[k] = val
                    default: break
                    }
                }
                if !user.isEmpty { metadata[.creatorDefinedKey] = user }
            default: break
            }
        }
    }
    static func feature(_ s: ArraySlice<UInt8>) throws -> MLFeatureDescription {
        var p = _PB(s)
        var name = "", desc = "", type = MLFeatureType.invalid, optional = false, array: MLMultiArrayConstraint?
        while !p.atEnd {
            let (f, _, _, d) = try p.next()
            if f == 1 { name = _PB.string(d) } else if f == 2 { desc = _PB.string(d) }
            else if f == 3 {
                var t = _PB(d)
                while !t.atEnd {
                    let (g, _, v, x) = try t.next()
                    switch g {
                    case 1: type = .int64
                    case 2: type = .double
                    case 3: type = .string
                    case 4: type = .image
                    case 5:
                        type = .multiArray
                        var a = _PB(x); var shape: [NSNumber] = [], dt = MLMultiArrayDataType.double
                        while !a.atEnd {
                            let (h, w, v2, y) = try a.next()
                            if h == 1 {
                                if w == 0 { shape.append(NSNumber(value: Int(v2))) }
                                else { var q = _PB(y); while !q.atEnd { shape.append(NSNumber(value: Int(try q.varint()))) } }
                            } else if h == 2 { dt = MLMultiArrayDataType(rawValue: Int(v2)) ?? .double }
                        }
                        array = MLMultiArrayConstraint(shape: shape, dataType: dt)
                    case 6: type = .dictionary
                    case 7: type = .sequence
                    case 8: type = .state
                    case 1000: optional = v != 0
                    default: break
                    }
                }
            }
        }
        return MLFeatureDescription(name: name, type: type, optional: optional, array: array, description: desc)
    }
    mutating func parseGLM(_ s: ArraySlice<UInt8>, classifier: Bool) throws {
        var p = _PB(s)
        while !p.atEnd {
            let (f, w, v, d) = try p.next()
            switch f {
            case 1:
                var row: [Double] = []
                var q = _PB(d)
                while !q.atEnd { let (g, w2, _, x) = try q.next(); if g == 1 { row += _PB.doubles(w2, x) } }
                weights.append(row)
            case 2: offsets += _PB.doubles(w, d)
            case 3: transform = Int(v)
            case 4: encoding = Int(v)
            case 100 where classifier, 101 where classifier:
                var q = _PB(d)
                while !q.atEnd {
                    let (g, w2, v2, x) = try q.next()
                    guard g == 1 else { continue }
                    if f == 100 { labels.append(_PB.string(x)) }
                    else if w2 == 0 { labels.append(Int64(bitPattern: v2)) }
                    else { var r = _PB(x); while !r.atEnd { labels.append(Int64(bitPattern: try r.varint())) } }
                }
            default: break
            }
        }
    }
}

// MARK: - MLModel

open class MLModel: NSObject, @unchecked Sendable {
    public let modelDescription: MLModelDescription
    public let configuration: MLModelConfiguration
    let _spec: _MLSpec

    /// Loads an isim-compiled model (a .mlmodelc directory holding model.mlmodel, made by MLModel.compileModel(at:)).
    public init(contentsOf url: URL, configuration: MLModelConfiguration) throws {
        var specURL = url
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            throw _mlError(.io, "no model at \(url.path)")
        }
        if isDir.boolValue {
            specURL = url.appendingPathComponent("model.mlmodel")
            guard FileManager.default.fileExists(atPath: specURL.path) else {
                throw _mlError(.io, "\(url.lastPathComponent) is a model compiled by Xcode; isim cannot read Apple's compiled model format. Bundle the .mlmodel and compile it at run time with MLModel.compileModel(at:)")
            }
        } else if url.pathExtension == "mlmodel" {
            throw _mlError(.io, "\(url.lastPathComponent) is not compiled; call MLModel.compileModel(at:) first (as on iOS)")
        }
        let data = try Data(contentsOf: specURL)
        _spec = try _MLSpec([UInt8](data))
        self.configuration = configuration
        modelDescription = MLModelDescription(inputs: _spec.inputs, outputs: _spec.outputs, predicted: _spec.predicted, probabilities: _spec.probabilities,
                                              metadata: _spec.metadata, labels: _spec.labels.isEmpty ? nil : _spec.labels)
        super.init()
    }
    public convenience init(contentsOf url: URL) throws { try self.init(contentsOf: url, configuration: MLModelConfiguration()) }
    open class func load(contentsOf url: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> MLModel {
        try MLModel(contentsOf: url, configuration: configuration)
    }
    open class func load(contentsOf url: URL, configuration: MLModelConfiguration, completionHandler handler: @escaping @Sendable (MLModel?, Error?) -> Void) {
        DispatchQueue.global().async {
            do { handler(try MLModel(contentsOf: url, configuration: configuration), nil) } catch { handler(nil, error) }
        }
    }
    /// isim: writes <name>.mlmodelc/model.mlmodel into the temporary directory (the spec, not Apple's compiled format).
    open class func compileModel(at modelURL: URL) throws -> URL { try _compile(modelURL) }
    static func _compile(_ modelURL: URL) throws -> URL {
        let data = try Data(contentsOf: modelURL)
        _ = try _MLSpec([UInt8](data))          // validate
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("isim-coreml-\(UUID().uuidString)/" + modelURL.deletingPathExtension().lastPathComponent + ".mlmodelc")
        guard (try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)) != nil,
              FileManager.default.createFile(atPath: (path as NSString).appendingPathComponent("model.mlmodel"), contents: data, attributes: nil) else {
            throw _mlError(.io, "cannot write the compiled model to \(path)")
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
    open class func compileModel(at modelURL: URL) async throws -> URL { try _compile(modelURL) }
    open class var availableComputeDevices: [Any] { [] }
    /// isim: "glmRegressor", "neuralNetwork", ... (the spec's model type)
    open var _isimModelType: String { _spec.kind }

    open func prediction(from input: MLFeatureProvider) throws -> MLFeatureProvider { try prediction(from: input, options: MLPredictionOptions()) }
    open func prediction(from input: MLFeatureProvider, options: MLPredictionOptions) throws -> MLFeatureProvider {
        switch _spec.kind {
        case "glmRegressor", "glmClassifier": return try _glm(input)
        default:
            throw _mlError(.generic, "isim cannot run \(_spec.kind) models: only generalized linear models (GLMRegressor, GLMClassifier) run without Apple's Core ML runtime")
        }
    }
    open func prediction(from input: MLFeatureProvider) async throws -> MLFeatureProvider { try prediction(from: input, options: MLPredictionOptions()) }
    open func predictions(from inputBatch: MLBatchProvider, options: MLPredictionOptions = MLPredictionOptions()) throws -> MLBatchProvider {
        MLArrayBatchProvider(array: try (0..<inputBatch.count).map { try prediction(from: inputBatch.features(at: $0), options: options) })
    }

    /// The inputs as one vector: the spec's inputs in order (doubles/ints, or the values of a multi-array).
    func _vector(_ input: MLFeatureProvider) throws -> [Double] {
        var x: [Double] = []
        for d in _spec.inputs {
            guard let v = input.featureValue(for: d.name) else {
                if d.isOptional { continue }
                throw _mlError(.featureType, "missing input feature '\(d.name)'")
            }
            switch v.type {
            case .double: x.append(v.doubleValue)
            case .int64: x.append(Double(v.int64Value))
            case .multiArray: x += v.multiArrayValue?._values ?? []
            default: throw _mlError(.featureType, "input '\(d.name)' must be a number or multi-array for a linear model")
            }
        }
        return x
    }
    func _glm(_ input: MLFeatureProvider) throws -> MLFeatureProvider {
        let x = try _vector(input)
        let z: [Double] = try _spec.weights.enumerated().map { i, w in
            guard w.count == x.count else { throw _mlError(.featureType, "the model expects \(w.count) input values, got \(x.count)") }
            return zip(w, x).reduce(0) { $0 + $1.0 * $1.1 } + (i < _spec.offsets.count ? _spec.offsets[i] : 0)
        }
        func logit(_ v: Double) -> Double { 1 / (1 + exp(-v)) }
        func probit(_ v: Double) -> Double { 0.5 * (1 + erf(v / 2.0.squareRoot())) }
        let outName = _spec.predicted ?? _spec.outputs.first?.name ?? "prediction"
        var out: [String: Any] = [:]
        if _spec.kind == "glmRegressor" {
            let y = z.map { _spec.transform == 1 ? logit($0) : _spec.transform == 2 ? probit($0) : $0 }
            if y.count == 1, _spec.outputs.first(where: { $0.name == outName })?.type != .multiArray { out[outName] = MLFeatureValue(double: y[0]) }
            else { out[outName] = MLFeatureValue(multiArray: try MLMultiArray(y)) }
        } else {
            let f: (Double) -> Double = _spec.transform == 1 ? probit : logit
            let labels = _spec.labels
            guard !labels.isEmpty else { throw _mlError(.generic, "the classifier has no class labels") }
            var probs: [Double]
            if z.count == 1 && labels.count == 2 {
                // binary: one weight row gives the probability of the second label (as coremltools exports scikit-learn models)
                let p = f(z[0]); probs = [1 - p, p]
            } else {
                probs = z.map(f)
                if _spec.encoding == 0 && probs.count == labels.count - 1 { probs.append(max(0, 1 - probs.reduce(0, +))) }   // reference class
                let s = probs.reduce(0, +); if s > 0 { probs = probs.map { $0 / s } }
            }
            guard probs.count == labels.count else { throw _mlError(.generic, "the classifier's weights do not match its \(labels.count) labels") }
            let best = probs.indices.max { probs[$0] < probs[$1] }!
            var dict: [AnyHashable: NSNumber] = [:]
            for (l, p) in zip(labels, probs) { if let s = l as? String { dict[s] = NSNumber(value: p) } else if let i = l as? Int64 { dict[i] = NSNumber(value: p) } }
            if let s = labels[best] as? String { out[outName] = MLFeatureValue(string: s) } else if let i = labels[best] as? Int64 { out[outName] = MLFeatureValue(int64: i) }
            out[_spec.probabilities ?? (outName + "Probability")] = try MLFeatureValue(dictionary: dict)
        }
        return try MLDictionaryFeatureProvider(dictionary: out)
    }
}
