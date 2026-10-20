# FoundationModels

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Imaging, photos & ML](../COVERAGE.md#ml) · **Apple:** [FoundationModels](https://developer.apple.com/documentation/foundationmodels) · **Issues:** [`area:ml`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aml)

## How isim implements it

- **Approach:** isim's own Swift overlay (`isim/swift/overlays/FoundationModels`) and compiler plugin
  (`isim/swift/macro-support/FoundationModelsMacros.swift`, `@Generable` / `@Guide`). Apple's on-device model is not
  available on Linux: the system model's availability is honest. It is `.unavailable(.deviceNotEligible)` on devices
  without Apple Intelligence (before the iPhone 15 Pro; iPads without an M chip or the A17 Pro) and
  `.unavailable(.appleIntelligenceNotEnabled)` while no model is configured on the host; a session's requests then
  fail with `GenerationError.assetsUnavailable`. A local model backend is #277.
- **Objective-C / C interface:** Swift only (as on iOS).
- **Versus Apple's Simulator:** Apple's Simulator uses the Mac's model when Apple Intelligence is on; isim has none
  until one is configured. Schemas are isim's JSON Schema, not Apple's internal format.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `SystemLanguageModel` (`default`, `init(useCase:guardrails:)`, `UseCase`, `Guardrails`, `availability`, `isAvailable`, `supportedLanguages`, `supportsLocale(_:)`) | 🟡 | 26.0 | adapted: availability from the device's eligibility and whether a model is configured (none yet: unavailable); no adapters; tested (HelloFoundationModels on an iPhone 17 and an iPhone 15) |
| `LanguageModelSession` (instructions, `@InstructionsBuilder`, tools, `init(model:tools:transcript:)`, `transcript`, `isResponding`, `prewarm(promptPrefix:)`, `respond(to:…)` for text, `Generable` types and schemas, `streamResponse(to:…)`, `Response`, `ResponseStream` and `collect()`, `GenerationError`, `ToolCallError`) | 🟡 | 26.0 | adapted: the API and the transcript are complete; with no model every request fails with `GenerationError.assetsUnavailable` (the prompt stays in the transcript); concurrent requests fail with `concurrentRequests`; tested (HelloFoundationModels) |
| `Generable`, `@Generable(description:)`, `@Guide(description:_:)`, `PartiallyGenerated`, `asPartiallyGenerated()`; `String`, `Int`, `Double`, `Float`, `Decimal`, `Bool`, `Array`, `Optional`, `GeneratedContent` conformances | ✅ | 26.0 | adapted: isim's macro plugin writes the schema (stored properties with their `@Guide` descriptions and guides), `init(_:)`, `generatedContent` and a `PartiallyGenerated` struct (optional properties) for structs, and a choice of case names for enums without associated values (enums with associated values are reported as unsupported); tested (HelloFoundationModels) |
| `GeneratedContent` (`Kind`, `init(properties:)`, `init(elements:)`, `init(json:)`, `jsonString`, `value(_:)`, `value(_:forProperty:)`, `isComplete`, `id`), `GenerationID`, `ConvertibleFromGeneratedContent`, `ConvertibleToGeneratedContent` | ✅ | 26.0 | adapted: an order-keeping JSON reader that closes off unfinished JSON (`isComplete` false) for responses in progress; tested (HelloFoundationModels) |
| `GenerationSchema` (`init(type:description:properties:)`, `anyOf` strings and types, `init(root:dependencies:)`, `Property`, `SchemaError`, `debugDescription`, `Codable`), `DynamicGenerationSchema` | ✅ | 26.0 | adapted: encoded as JSON Schema (`description`, `required`, `enum`, `minimum` / `maximum`, `minItems` / `maxItems`, `anyOf`); references resolved from the dependencies, undefined ones reported; tested (HelloFoundationModels) |
| `GenerationGuide` (`range`, `minimum`, `maximum` for `Int` / `Double` / `Float` / `Decimal`; `anyOf`, `constant`, `pattern` for `String`; `count`, `minimumCount`, `maximumCount`, `element` for arrays) | 🟡 | 26.0 | adapted: guides become JSON Schema constraints; `pattern` is recorded but a Swift `Regex` has no pattern text to hand a backend; a guide whose type only the property gives (`.count(3)` on `[String]`) cannot be inferred in the attribute on isim's compiler: write `GenerationGuide<[String]>.count(3)`; tested (HelloFoundationModels: range, count) |
| `GenerationOptions` (`SamplingMode.greedy`, `random(top:seed:)`, `random(probabilityThreshold:seed:)`, `temperature`, `maximumResponseTokens`) | ✅ | 26.0 | passthrough of the values to a backend; tested (HelloFoundationModels) |
| `Prompt`, `Instructions`, `PromptBuilder`, `InstructionsBuilder`, `PromptRepresentable`, `InstructionsRepresentable` | ✅ | 26.0 | adapted: parts joined one per line; tested (HelloFoundationModels: a conditional part) |
| `Tool` (`name`, `description`, `parameters` from `Generable` arguments, `includesSchemaInInstructions`, `call(arguments:)`) | 🟡 | 26.0 | adapted: tools are recorded in the transcript's instructions; nothing calls them until a model backend does; tested (HelloFoundationModels) |
| `Transcript` (`Entry`: instructions, prompt, tool calls, tool output, response; `Segment`, `TextSegment`, `StructuredSegment`, `ToolDefinition`, `ResponseFormat`, `ToolCalls`, `ToolCall`, `ToolOutput`, `Response`) | ✅ | 26.0 | adapted; tested (HelloFoundationModels) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
