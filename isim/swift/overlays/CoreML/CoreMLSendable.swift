// isim Core ML: MLSendableFeatureValue (iOS 18), the sendable feature value Vision's CoreMLFeatureValueObservation holds
// (issue #852). Adapted: a value over isim's MLFeatureValue (which is immutable); MLFeatureValue(_:) turns it back.
import Foundation

public struct MLSendableFeatureValue: Sendable, CustomStringConvertible {
    let _value: MLFeatureValue
    public init(_ value: MLFeatureValue) { _value = value }
    public init(_ value: Int) { _value = MLFeatureValue(int64: Int64(value)) }
    public init(_ value: Double) { _value = MLFeatureValue(double: value) }
    public init(_ value: Float) { _value = MLFeatureValue(double: Double(value)) }
    public init(_ value: String) { _value = MLFeatureValue(string: value) }
    public init(_ value: [String]) { _value = MLFeatureValue(sequence: MLSequence(strings: value)) }
    public init(_ value: [String: Double]) { _value = (try? MLFeatureValue(dictionary: value.mapValues { NSNumber(value: $0) })) ?? MLFeatureValue(undefined: .dictionary) }
    public init(_ value: [Int: Double]) { _value = (try? MLFeatureValue(dictionary: Dictionary(uniqueKeysWithValues: value.map { (AnyHashable(Int64($0.key)), NSNumber(value: $0.value)) }))) ?? MLFeatureValue(undefined: .dictionary) }
    public init<Scalar: MLShapedArrayScalar>(_ value: MLShapedArray<Scalar>) { _value = MLFeatureValue(shapedArray: value) }
    public init(undefined type: MLFeatureType) { _value = MLFeatureValue(undefined: type) }
    public var type: MLFeatureType { _value.type }
    public var isUndefined: Bool { _value.isUndefined }
    public var isScalar: Bool { [.int64, .double, .string].contains(_value.type) }
    public var isShapedArray: Bool { _value.type == .multiArray }
    public var integerValue: Int? { _value.type == .int64 ? Int(_value.int64Value) : nil }
    public var doubleValue: Double? { _value.type == .double || _value.type == .int64 ? _value.doubleValue : nil }
    public var floatValue: Float? { doubleValue.map { Float($0) } }
    public var float16Value: Float16? { doubleValue.map { Float16($0) } }
    public var stringValue: String? { _value.type == .string ? _value.stringValue : nil }
    public var stringArrayValue: [String]? { _value.type == .sequence ? _value.sequenceValue?.stringValues : nil }
    public var stringDictionaryValue: [String: Double]? {
        guard _value.type == .dictionary else { return nil }
        var out: [String: Double] = [:]
        for (k, v) in _value.dictionaryValue { guard let s = k.base as? String else { return nil }; out[s] = v.doubleValue }
        return out
    }
    public var integerDictionaryValue: [Int: Double]? {
        guard _value.type == .dictionary else { return nil }
        var out: [Int: Double] = [:]
        for (k, v) in _value.dictionaryValue {
            if let i = k.base as? Int64 { out[Int(i)] = v.doubleValue } else if let i = k.base as? Int { out[i] = v.doubleValue } else { return nil }
        }
        return out
    }
    public func shapedArrayValue<Scalar: MLShapedArrayScalar>(of type: Scalar.Type) -> MLShapedArray<Scalar>? { _value.shapedArrayValue(of: type) }
    public var description: String { _value.description }
}

extension MLFeatureValue {
    public convenience init(_ value: MLSendableFeatureValue) {
        let v = value._value
        self.init(type: v.type, int64: v.int64Value, double: v.doubleValue, string: v.stringValue, array: v.multiArrayValue,
                  dict: v.dictionaryValue, image: v.imageBufferValue, sequence: v.sequenceValue)
    }
}
