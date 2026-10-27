// Sample: Foundation Models on isim (iOS 26) — the system model's availability (the device's eligibility, no model
// configured), @Generable / @Guide types and their schema, generated content (JSON, partial JSON, properties),
// sessions with instructions and tools, the transcript, prompt and instructions builders, generation options and
// dynamic schemas; on iOS 27 tool calling modes, Vision's OCR and barcode tools and GeneratedContent.ParsingError.
// Every check logs a line the test reads.
import UIKit
import FoundationModels
import Vision
import CoreImage

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        let label = UILabel(frame: CGRect(x: 20, y: 80, width: 360, height: 300))
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.accessibilityIdentifier = "status"
        vc.view.addSubview(label)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        if #available(iOS 26.0, *) {
            label.text = Demo.availabilityText()
            Task { await Demo.run(); log("done") }
        } else {
            label.text = "Foundation Models needs iOS 26"
            log("foundation models need iOS 26")
        }
        return true
    }
}
func log(_ s: String) { NSLog("HelloFoundationModels: %@", s) }

@available(iOS 26.0, *)
@Generable(description: "A dish to cook")
struct Recipe {
    @Guide(description: "The dish's name")
    var name: String
    @Guide(description: "Minutes to cook", .range(1...240))
    var minutes: Int
    @Guide(description: "Three steps", GenerationGuide<[String]>.count(3))   // the element type spelled out: an attribute alone cannot infer it
    var steps: [String]
    var vegetarian: Bool
    var rating: Double?
    var difficulty: Difficulty
}
@available(iOS 26.0, *)
@Generable
enum Difficulty { case easy, medium, hard }

@available(iOS 26.0, *)
struct WeatherTool: Tool {
    let name = "getWeather"
    let description = "The weather in a city"
    @Generable
    struct Arguments {
        @Guide(description: "The city")
        var city: String
    }
    func call(arguments: Arguments) async throws -> String { "Sunny in \(arguments.city)" }
}

/// a tool that counts its calls and throws on the third: `.required` tool calling stops when a tool throws
@available(iOS 27.0, *)
struct CountingTool: Tool {
    final class Counter: @unchecked Sendable { var calls = 0 }
    struct Done: Error {}
    let name = "countUp"
    let description = "Counts up"
    let counter = Counter()
    @Generable
    struct Arguments { var step: Int }
    func call(arguments: Arguments) async throws -> String {
        counter.calls += 1
        if counter.calls >= 3 { throw Done() }
        return "count \(counter.calls)"
    }
}

@available(iOS 27.0, *)
enum Demo27 {
    /// the checks that need no model: the options' kinds, ParsingError, the Vision tools' names and parameters
    static func run() {
        let sampling = GenerationOptions.SamplingMode.random(top: 5, seed: 42)
        let options = GenerationOptions(samplingMode: sampling, toolCallingMode: .required)
        log("ios27 sampling \(sampling.kind == .randomTopK(5, seed: 42)) greedy \(GenerationOptions.SamplingMode.greedy.kind == .greedy) mode \(options.toolCallingMode?.kind == .required) default \(GenerationOptions().toolCallingMode == nil)")
        do { _ = try GeneratedContent(json: "[1, 2] x") } catch let e as GeneratedContent.ParsingError {
            log("ios27 parsing error raw '\(e.rawContent)' underlying \(e.underlyingError != nil) '\(e.debugDescription)'")
        } catch { log("ios27 parsing other \(error)") }
        let ocr = OCRTool(), codes = BarcodeReaderTool(name: "scanQRCode", description: "Scan QR codes")
        log("ios27 tools \(ocr.name) \(codes.name) '\(codes.description)' image parameter \(ocr.parameters.debugDescription.contains("\"image\""))")
    }
    /// a white picture with a QR code (Core Image's generator) or a line of text, as a PNG in the temporary directory
    static func picture(_ name: String, qr: String? = nil, text: String? = nil) -> String? {
        let size = CGSize(width: 480, height: 240)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            if let qr, let f = CIFilter(name: "CIQRCodeGenerator") {
                f.setValue(Data(qr.utf8), forKey: "inputMessage")
                if let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 6, y: 6)),
                   let cg = CIContext().createCGImage(out, from: out.extent) {
                    ctx.cgContext.interpolationQuality = .none
                    UIImage(cgImage: cg).draw(in: CGRect(x: (size.width - out.extent.width) / 2, y: (size.height - out.extent.height) / 2,
                                                         width: out.extent.width, height: out.extent.height))
                }
            }
            if let text {
                (text as NSString).draw(at: CGPoint(x: 30, y: 90), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 48), .foregroundColor: UIColor.black])
            }
        }
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent(name)
        guard let png = image.pngData(), (try? png.write(to: URL(fileURLWithPath: path))) != nil else { return nil }
        return path
    }
    static func outputs(_ entries: some Sequence<Transcript.Entry>) -> [String] {
        entries.compactMap { if case .toolOutput(let o) = $0 { return "\(o.toolName): \(o.segments.map(\.description).joined())" }; return nil }
    }
    /// with a model: the tool calling modes, the barcode and text tools
    static func live() async {
        let counter = CountingTool()
        let session = LanguageModelSession(tools: [counter, WeatherTool()], instructions: "You use tools.")
        do {
            let r = try await session.respond(to: "What is the weather in Paris?", options: GenerationOptions(toolCallingMode: .disallowed))
            log("live27 disallowed '\(r.content)' calls \(r.transcriptEntries.filter { if case .toolCalls = $0 { return true }; return false }.count)")
        } catch { log("live27 disallowed error \(error)") }
        do {
            _ = try await session.respond(to: "Count", options: GenerationOptions(toolCallingMode: .required))
            log("live27 required answered")
        } catch let e as LanguageModelSession.ToolCallError {
            log("live27 required stops at \(e.tool.name) after \(counter.counter.calls) calls, outputs \(outputs(session.transcript).count)")
        } catch { log("live27 required error \(error)") }

        let tools = LanguageModelSession(tools: [BarcodeReaderTool(), OCRTool()], instructions: "You read pictures.")
        if let qr = picture("fm-qr.png", qr: "isim tools") {
            do {
                let r = try await tools.respond(to: "Read the codes in \(qr)")
                log("live27 barcodes \(outputs(r.transcriptEntries))")
            } catch let e as LanguageModelSession.ToolCallError { log("live27 barcodes unavailable: \(e.tool.name) \(e.underlyingError.localizedDescription)") }
            catch { log("live27 barcodes error \(error)") }
        }
        if let text = picture("fm-text.png", text: "HELLO ISIM") {
            do {
                let r = try await tools.respond(to: "Read the text in \(text)")
                log("live27 text \(outputs(r.transcriptEntries))")
            } catch let e as LanguageModelSession.ToolCallError { log("live27 text unavailable: \(e.tool.name) \(e.underlyingError.localizedDescription)") }
            catch { log("live27 text error \(error)") }
        }
    }
}

@available(iOS 26.0, *)
enum Demo {
    static func availabilityText() -> String {
        switch SystemLanguageModel.default.availability {
        case .available: return "available"
        case .unavailable(let why): return "unavailable(\(why))"
        }
    }
    /// with a model configured (ISIM_LLM_URL / ISIM_LLM_MODEL): text, a Generable response, a stream, a tool call
    static func live() async {
        do {
            let session = LanguageModelSession(tools: [WeatherTool()], instructions: "You are a cook.")
            let hello = try await session.respond(to: "Say hello", options: GenerationOptions(temperature: 0.2))
            log("live text '\(hello.content)'")
            let recipe = try await session.respond(to: "A recipe, please", generating: Recipe.self)
            log("live recipe \(recipe.content.name) \(recipe.content.minutes) \(recipe.content.steps.count) steps \(recipe.content.difficulty)")
            var snapshots = 0, names: [String] = []
            for try await snapshot in session.streamResponse(to: "Stream a recipe", generating: Recipe.self) {
                snapshots += 1
                if let n = snapshot.content.name, names.last != n { names.append(n) }
            }
            log("live stream snapshots>1 \(snapshots > 1) names \(names)")
            let weather = try await session.respond(to: "What is the weather in Paris?")
            let kinds = weather.transcriptEntries.map { e -> String in
                switch e {
                case .prompt: return "prompt"
                case .toolCalls(let c): return "calls(\(c.map(\.toolName).joined()))"
                case .toolOutput(let o): return "output(\(o.segments.map(\.description).joined()))"
                case .response: return "response"
                case .instructions: return "instructions"
                @unknown default: return "?"
                }
            }
            log("live tool '\(weather.content)' entries \(kinds)")
            log("live transcript \(session.transcript.count) responding \(session.isResponding)")
        } catch { log("live error \(error)") }
    }
    static func run() async {
        let model = SystemLanguageModel.default
        log("availability \(availabilityText()) isAvailable \(model.isAvailable) english \(model.supportsLocale(Locale(identifier: "en_US")))")

        /* the schema @Generable made */
        let schema = Recipe.generationSchema.debugDescription
        log("schema " + ["\"minimum\":1", "\"maximum\":240", "\"minItems\":3", "\"maxItems\":3", "\"easy\",\"medium\",\"hard\"",
                         "\"description\":\"The dish's name\"", "\"description\":\"A dish to cook\""].map { "\(schema.contains($0) ? 1 : 0)" }.joined()
            + " required \(schema.contains("\"required\":[\"name\",\"minutes\",\"steps\",\"vegetarian\",\"difficulty\"]"))")

        /* generated content to a Generable value and back */
        do {
            let json = #"{"name": "Pancakes", "minutes": 20, "steps": ["mix", "rest", "fry"], "vegetarian": true, "difficulty": "easy"}"#
            let content = try GeneratedContent(json: json)
            let r = try Recipe(content)
            log("recipe \(r.name) \(r.minutes) \(r.steps.joined(separator: ",")) veg \(r.vegetarian) rating \(r.rating.map { "\($0)" } ?? "nil") \(r.difficulty)")
            log("roundtrip \(r.generatedContent.jsonString)")
            log("property \(try content.value(String.self, forProperty: "name")) steps \(try content.value([String].self, forProperty: "steps").count) complete \(content.isComplete)")
            let partial = try GeneratedContent(json: #"{"name": "Pan"#)
            let p = try Recipe.PartiallyGenerated(partial)
            log("partial complete \(partial.isComplete) name \(p.name ?? "nil") minutes \(p.minutes.map(String.init) ?? "nil")")
            _ = try? Recipe(try GeneratedContent(json: #"{"name": "x"}"#))
            do { _ = try Recipe(try GeneratedContent(json: #"{"name": "x"}"#)) } catch let e as LanguageModelSession.GenerationError {
                if case .decodingFailure = e { log("missing property decodingFailure") }
            }
            let made = GeneratedContent(properties: ["a": 1, "b": "two", "c": [true, false]])
            log("properties \(made.jsonString)")
        } catch { log("content error \(error)") }

        if #available(iOS 27.0, *) { Demo27.run() }
        if model.isAvailable {
            await live()
            if #available(iOS 27.0, *) { await Demo27.live() }
        }

        /* a session: instructions, a tool, a request (without a model: it fails, and the transcript keeps it) */
        guard !model.isAvailable else { return }
        let session = LanguageModelSession(tools: [WeatherTool()]) {
            "You are a cook."
            "Answer briefly."
        }
        do {
            _ = try await session.respond(to: "What should I cook?")
            log("respond succeeded")
        } catch let e as LanguageModelSession.GenerationError {
            if case .assetsUnavailable = e { log("respond assetsUnavailable: \(e.localizedDescription)") } else { log("respond error \(e)") }
        } catch { log("respond other error \(error)") }
        do {
            _ = try await session.respond(to: "A recipe", generating: Recipe.self)
        } catch { log("generating fails too \(error is LanguageModelSession.GenerationError)") }
        var streamed = 0
        do { for try await _ in session.streamResponse(to: "Hello") { streamed += 1 } } catch { log("stream fails, snapshots \(streamed)") }
        let t = session.transcript
        var tools = 0, prompts = 0, instructions = ""
        for e in t {
            switch e {
            case .instructions(let i): tools = i.toolDefinitions.count; instructions = i.segments.map(\.description).joined()
            case .prompt: prompts += 1
            default: break
            }
        }
        log("transcript \(t.count) entries, \(prompts) prompts, tools \(tools), instructions '\(instructions.replacingOccurrences(of: "\n", with: " | "))' responding \(session.isResponding)")
        log("tool \(WeatherTool().name) parameters \(WeatherTool().parameters.debugDescription.contains("\"city\"")) output \(try! await WeatherTool().call(arguments: .init(city: "Paris")))")

        /* builders, options */
        let wantsSteps = true
        let prompt = Prompt {
            "Suggest a dish."
            if wantsSteps { "List the steps." }
        }
        _ = try? await session.respond(to: prompt)
        if case .prompt(let p)? = session.transcript.last {
            log("prompt '\(p.segments.map(\.description).joined().replacingOccurrences(of: "\n", with: " | "))'")
        }
        let options = GenerationOptions(sampling: .random(top: 5, seed: 42), temperature: 0.7, maximumResponseTokens: 100)
        log("options temperature \(options.temperature ?? -1) tokens \(options.maximumResponseTokens ?? -1) greedy \(options.sampling == .greedy)")

        /* a schema built at run time */
        let person = DynamicGenerationSchema(name: "Person", properties: [
            .init(name: "name", schema: .init(type: String.self)),
            .init(name: "pet", schema: .init(referenceTo: "Pet"), isOptional: true),
        ])
        let pet = DynamicGenerationSchema(name: "Pet", anyOf: ["cat", "dog"])
        do {
            let s = try GenerationSchema(root: person, dependencies: [pet])
            log("dynamic \(s.debugDescription.contains("\"cat\",\"dog\"")) required \(s.debugDescription.contains("\"required\":[\"name\"]"))")
        } catch { log("dynamic error \(error)") }
        do { _ = try GenerationSchema(root: person, dependencies: []) } catch let e as GenerationSchema.SchemaError {
            if case .undefinedReferences(_, let refs, _) = e { log("undefined references \(refs)") }
        } catch { log("dynamic other \(error)") }
    }
}
