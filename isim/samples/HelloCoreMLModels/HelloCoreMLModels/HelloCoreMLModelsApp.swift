// Sample: Core ML models compiled by `isim build` (issue #213). The project's folder holds Regressor.mlmodel,
// Classifier.mlmodel and Pricing.mlpackage (written by gen_models.py before the build, as Xcode projects carry model
// files); isim build compiles each into <Name>.mlmodelc (isim's format) and generates Xcode's classes: Regressor,
// RegressorInput, RegressorOutput, ... This app uses only those generated classes. Each check logs a "cml" line.
import SwiftUI
import CoreML

func log(_ s: String) { print("cml \(s)") }

@MainActor final class Results: ObservableObject {
    @Published var lines: [String] = []
    func add(_ s: String) { log(s); lines.append(s) }

    func run() async {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuOnly
            let regressor = try Regressor(configuration: config)
            let y = try regressor.prediction(x1: 1, x2: 2).y
            add("Regressor(x1: 1, x2: 2).y = \(y)")
            let viaInput = try await regressor.prediction(input: RegressorInput(x1: 2, x2: 0))      // the async overload here
            add("Regressor input class: y = \(viaInput.y)")
            let batch = try regressor.predictions(inputs: [RegressorInput(x1: 0, x2: 0), RegressorInput(x1: 1, x2: 1)])
            add("Regressor batch: \(batch.map { $0.y })")
            add("Regressor description: inputs \(regressor.model.modelDescription.inputDescriptionsByName.keys.sorted())")

            let classifier = try await Classifier.load(configuration: config)
            let features = try MLMultiArray([3.0, 1.0])
            let out = try classifier.prediction(features: features)
            add("Classifier: \(out.label) cat=\(String(format: "%.3f", out.labelProbability["cat"] ?? -1))")

            let pricing = try Pricing(configuration: config)
            add("Pricing(rooms: 3, area: 80).price = \(try pricing.prediction(rooms: 3, area: 80).price)")
            add("bundle: \(Bundle.main.url(forResource: "Pricing", withExtension: "mlmodelc") != nil ? "Pricing.mlmodelc" : "missing")")
        } catch {
            add("error: \(error.localizedDescription)")
        }
        log("done")
    }
}

struct ContentView: View {
    @StateObject var results = Results()
    var body: some View {
        NavigationStack {
            List(results.lines, id: \.self) { Text($0).font(.callout) }
                .navigationTitle("Core ML models")
        }
        .task { await results.run() }
    }
}

@main
struct HelloCoreMLModelsApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
