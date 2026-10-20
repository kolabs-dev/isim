// Sample: Foundation Models on isim (iOS 26) — the system model's availability (the device's eligibility, no model
// configured), @Generable / @Guide types and their schema, generated content (JSON, partial JSON, properties),
// sessions with instructions and tools, the transcript, prompt and instructions builders, generation options and
// dynamic schemas. Every check logs a line the test reads.
import UIKit
import FoundationModels

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

        if model.isAvailable { await live() }

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
