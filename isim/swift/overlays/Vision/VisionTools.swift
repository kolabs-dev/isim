// isim Vision (self-authored, Apple's API names): OCRTool and BarcodeReaderTool (iOS 27), Foundation Models tools a
// language model session calls to read text and machine-readable codes in an image. They run isim's
// VNRecognizeTextRequest (the host's tesseract) and VNDetectBarcodesRequest (libzbar or zxing-cpp).
// Adapted: Apple's model passes an image attached to the prompt; isim has no image attachments, so the tools' argument
// is the image's file path or URL.
import Foundation
import FoundationModels

@available(iOS 27.0, macOS 27.0, *)
public struct _VisionToolArguments: ConvertibleFromGeneratedContent {
    public let image: String
    public init(_ content: GeneratedContent) throws {
        image = try content.value(String.self, forProperty: "image")
    }
    static var schema: GenerationSchema {
        let image = DynamicGenerationSchema(name: "image", properties: [
            .init(name: "image", description: "The image's file path or file URL", schema: .init(type: String.self)),
        ])
        return (try? GenerationSchema(root: image, dependencies: [])) ?? String.generationSchema
    }
    var url: URL {
        if let u = URL(string: image), u.scheme != nil { return u }
        return URL(fileURLWithPath: image)
    }
}

@available(iOS 27.0, macOS 27.0, *)
func _visionToolPerform(_ request: VNRequest, _ arguments: _VisionToolArguments) throws -> [VNObservation] {
    guard FileManager.default.fileExists(atPath: arguments.url.path) else {
        throw _vnError(.invalidImage, "there is no image at \(arguments.image)")
    }
    try VNImageRequestHandler(url: arguments.url).perform([request])
    return request.results ?? []
}

/// A tool that recognizes text in an image: its output is the recognized text, one line per line of text.
@available(iOS 27.0, macOS 27.0, *)
public struct OCRTool: Tool, Sendable {
    public typealias Arguments = _VisionToolArguments
    public typealias Output = String
    public let name: String
    public let description: String
    public init(name: String? = nil, description: String? = nil) {
        self.name = name ?? "OCRTool"
        self.description = description ?? "Recognizes the text in an image and returns it."
    }
    public var parameters: GenerationSchema { Arguments.schema }
    public func call(arguments: Arguments) async throws -> String {
        let request = VNRecognizeTextRequest()
        return try _visionToolPerform(request, arguments).compactMap { ($0 as? VNRecognizedTextObservation)?.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}

/// A tool that scans machine-readable codes in an image: its output is an array of barcodes, each with its decoded
/// content (`payload`) and its symbology (`symbology`, Vision's `BarcodeSymbology` case name).
@available(iOS 27.0, macOS 27.0, *)
public struct BarcodeReaderTool: Tool, Sendable {
    public typealias Arguments = _VisionToolArguments
    public typealias Output = GeneratedContent
    public let name: String
    public let description: String
    public init(name: String? = nil, description: String? = nil) {
        self.name = name ?? "BarcodeReaderTool"
        self.description = description ?? "Scans the barcodes and QR codes in an image and returns their contents."
    }
    public var parameters: GenerationSchema { Arguments.schema }
    public func call(arguments: Arguments) async throws -> GeneratedContent {
        let codes = try _visionToolPerform(VNDetectBarcodesRequest(), arguments).compactMap { $0 as? VNBarcodeObservation }
        return GeneratedContent(elements: codes.map { o -> any ConvertibleToGeneratedContent in
            GeneratedContent(properties: ["payload": o.payloadStringValue ?? "", "symbology": BarcodeReaderTool._caseName(o.symbology)])
        })
    }
    /// VNBarcodeSymbologyQR -> qr, VNBarcodeSymbologyEAN13 -> ean13, VNBarcodeSymbologyDataMatrix -> dataMatrix
    static func _caseName(_ s: VNBarcodeSymbology) -> String {
        let name = Array(s.rawValue.replacingOccurrences(of: "VNBarcodeSymbology", with: ""))
        var run = 0
        while run < name.count, name[run].isUppercase { run += 1 }
        if run > 1, run < name.count, name[run].isLowercase { run -= 1 }   // MSIPlessey -> msiPlessey
        return String(name[..<run]).lowercased() + String(name[run...])
    }
}
