// isim Foundation Models: the iOS 26.4 / 27 schema and content additions (issue #859): explicit nil in generated
// content (isim: nil properties are left out either way), a schema's name, null schemas, content from properties
// with duplicate keys, and the options initializer without a tool-calling mode.
import Foundation

@available(iOS 26.0, macOS 26.0, *)
extension GenerationOptions {
    @_disfavoredOverload
    public init(samplingMode: SamplingMode? = nil, temperature: Double? = nil, maximumResponseTokens: Int? = nil) {
        self.init(sampling: samplingMode, temperature: temperature, maximumResponseTokens: maximumResponseTokens)
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension GeneratedContent {
    /// structured content from key–value pairs; `combine` settles a key that appears twice
    public init<S>(properties: S, id: GenerationID? = nil,
                   uniquingKeysWith combine: (GeneratedContent, GeneratedContent) throws -> some ConvertibleToGeneratedContent) rethrows
        where S: Sequence, S.Element == (String, any ConvertibleToGeneratedContent) {
        var values: [String: GeneratedContent] = [:], order: [String] = []
        for (k, v) in properties {
            let g = v.generatedContent
            if let old = values[k] { values[k] = try combine(old, g).generatedContent } else { values[k] = g; order.append(k) }
        }
        self.init(kind: .structure(properties: values, orderedKeys: order), id: id)
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension GenerationSchema {
    public init(type: any Generable.Type, description: String? = nil, representNilExplicitlyInGeneratedContent explicitNil: Bool,
                properties: [GenerationSchema.Property]) {
        self.init(type: type, description: description, properties: properties)
    }
    /// the schema's type name
    public var name: String {
        switch _node {
        case .object(let n, _), .anyOf(let n, _), .named(let n, _): return n
        default: return ""
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension DynamicGenerationSchema {
    public init(name: String, description: String? = nil, representNilExplicitlyInGeneratedContent explicitNil: Bool,
                properties: [DynamicGenerationSchema.Property]) {
        self.init(name: name, description: description, properties: properties)
    }
    /// a value that is always null
    public static var null: DynamicGenerationSchema { DynamicGenerationSchema(_isimNull: ()) }
    init(_isimNull: Void) { _kind = .node(.optional(.any)); _description = nil }
}
