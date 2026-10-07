// Sample: on-device intelligence APIs on isim — Vision (VNDetectBarcodesRequest with region of interest and
// orientation, VNRecognizeTextRequest, VNDetectFaceRectanglesRequest), Core ML (MLModel.compileModel, model
// descriptions, MLMultiArray, GLM regressor/classifier predictions, models isim cannot run), NaturalLanguage
// (NLTokenizer, NLLanguageRecognizer, NLTagger), Speech (authorization alert, recognition) and VisionKit
// (DataScannerViewController support check). Pictures and model specs are made by build.sh.
import UIKit
import Vision
import CoreML
import NaturalLanguage
import Speech
import VisionKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = VisionViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

func log(_ s: String) { NSLog("HelloVision: %@", s) }
func f2(_ x: Double) -> String { String(format: "%.2f", x) }
func rect(_ r: CGRect) -> String { "\(f2(r.minX)),\(f2(r.minY)),\(f2(r.width)),\(f2(r.height))" }
let res = Bundle.main.bundleURL
func message(_ e: Error) -> String { (e as NSError).userInfo[NSLocalizedDescriptionKey] as? String ?? "\(e)" }

final class VisionViewController: UIViewController {
    let picture = UIImageView()
    let speechLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Vision"; title.font = .systemFont(ofSize: 34, weight: .bold)
        title.frame = CGRect(x: 20, y: 64, width: 300, height: 41); view.addSubview(title)
        picture.frame = CGRect(x: 51, y: 130, width: 300, height: 150); picture.accessibilityIdentifier = "codes"
        view.addSubview(picture)
        speechLabel.frame = CGRect(x: 20, y: 300, width: 362, height: 22); speechLabel.accessibilityIdentifier = "speech"
        view.addSubview(speechLabel)
        barcodes()
        text()
        faces()
        coreML()
        language()
        visionKit()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        speech()
    }

    // MARK: Vision
    func barcodes() {
        let url = res.appendingPathComponent("codes.png")
        guard let img = UIImage(contentsOfFile: url.path), let cg = img.cgImage else { log("barcodes: no test picture (needs qrencode at build time)"); return }
        picture.image = img
        log("barcode symbologies qr=\(VNDetectBarcodesRequest.supportedSymbologies.contains(.qr))")
        let all = VNDetectBarcodesRequest { req, err in
            let found = (req.results as? [VNBarcodeObservation] ?? []).sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            log("barcodes \(found.count): " + found.map { "\($0.symbology == .qr ? "qr" : $0.symbology.rawValue) '\($0.payloadStringValue ?? "")' box=\(rect($0.boundingBox))" }.joined(separator: "; "))
        }
        do { try VNImageRequestHandler(cgImage: cg, options: [:]).perform([all]) } catch { log("barcodes error \(message(error))") }
        // draw the found boxes over the picture (Vision: normalized, origin bottom-left)
        for o in (all.results as? [VNBarcodeObservation]) ?? [] {
            let b = o.boundingBox, w = picture.bounds.width, h = picture.bounds.height
            let box = UIView(frame: CGRect(x: b.minX * w, y: (1 - b.maxY) * h, width: b.width * w, height: b.height * h))
            box.layer.borderColor = UIColor.systemGreen.cgColor; box.layer.borderWidth = 4
            box.accessibilityIdentifier = "box-\(o.payloadStringValue ?? "")"
            picture.addSubview(box)
        }
        // region of interest: the right half only; then the picture rotated (orientation)
        let right = VNDetectBarcodesRequest()
        right.regionOfInterest = CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        right.symbologies = [.qr]
        try? VNImageRequestHandler(cgImage: cg).perform([right])
        log("roi barcodes \((right.results as? [VNBarcodeObservation] ?? []).compactMap(\.payloadStringValue))")
        let rotated = VNDetectBarcodesRequest()
        try? VNImageRequestHandler(cgImage: cg, orientation: .right).perform([rotated])
        log("rotated barcodes \((rotated.results as? [VNBarcodeObservation] ?? []).count)")
        let ean = VNDetectBarcodesRequest(); ean.symbologies = [.ean13]
        try? VNImageRequestHandler(cgImage: cg).perform([ean])
        log("ean13 only \(ean.results?.count ?? -1)")
    }
    func text() {
        guard let data = try? Data(contentsOf: res.appendingPathComponent("text.png")) else { log("text: no test picture"); return }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.recognitionLanguages = ["en-US"]
        do {
            try VNImageRequestHandler(data: data, options: [:]).perform([req])
            let lines = (req.results as? [VNRecognizedTextObservation] ?? []).compactMap { $0.topCandidates(1).first?.string }
            log("text recognized \(lines)")
        } catch { log("text unavailable: \(message(error))") }
    }
    func faces() {
        guard let img = UIImage(contentsOfFile: res.appendingPathComponent("text.png").path)?.cgImage else { return }
        let req = VNDetectFaceRectanglesRequest { req, err in log("face completion error=\(err.map(message) ?? "none")") }
        do { try VNImageRequestHandler(cgImage: img).perform([req]); log("faces \(req.results?.count ?? 0)") }
        catch { log("faces error \((error as NSError).domain) \((error as NSError).code)") }
    }

    // MARK: Core ML
    func coreML() {
        do {
            let m = try MLMultiArray(shape: [2, 3], dataType: .float32)
            m[[1, 2] as [NSNumber]] = 7.5
            m[0] = 1
            log("multiarray count=\(m.count) strides=\(m.strides.map(\.intValue)) [1,2]=\(m[5].doubleValue) [0]=\(m[[0, 0] as [NSNumber]].doubleValue)")

            let reg = try MLModel(contentsOf: MLModel.compileModel(at: res.appendingPathComponent("Regressor.mlmodel")))
            let d = reg.modelDescription
            log("regressor inputs=\(d.inputDescriptionsByName.keys.sorted()) output=\(d.predictedFeatureName ?? "") meta='\(d.metadata[.description] as? String ?? "")'")
            let y = try reg.prediction(from: MLDictionaryFeatureProvider(dictionary: ["x1": 1.0, "x2": 2.0]))
            log("regressor y=\(f2(y.featureValue(for: "y")?.doubleValue ?? .nan))")

            let cls = try MLModel(contentsOf: MLModel.compileModel(at: res.appendingPathComponent("Classifier.mlmodel")), configuration: MLModelConfiguration())
            let input = try MLMultiArray([3, 1])
            let out = try cls.prediction(from: MLDictionaryFeatureProvider(dictionary: ["features": input]))
            let probs = out.featureValue(for: "labelProbability")?.dictionaryValue ?? [:]
            log("classifier label=\(out.featureValue(for: "label")?.stringValue ?? "") p(dog)=\(f2(probs["dog"]?.doubleValue ?? .nan)) p(cat)=\(f2(probs["cat"]?.doubleValue ?? .nan)) labels=\(cls.modelDescription.classLabels?.count ?? 0)")
        } catch { log("coreml error \(message(error))") }
        do {
            let nn = try MLModel(contentsOf: MLModel.compileModel(at: res.appendingPathComponent("Neural.mlmodel")))
            log("neural loaded inputs=\(nn.modelDescription.inputDescriptionsByName.keys.sorted()) type=\(nn.modelDescription.inputDescriptionsByName["image"]?.type.rawValue ?? -1)")
            _ = try nn.prediction(from: MLDictionaryFeatureProvider(dictionary: [:]))
            log("neural predicted?!")
        } catch { log("neural prediction error: \(message(error))") }
        do { _ = try MLModel(contentsOf: res.appendingPathComponent("XcodeCompiled.mlmodelc")); log("xcode model loaded?!") }
        catch { log("xcode-compiled model error: \(message(error))") }
    }

    // MARK: NaturalLanguage
    func language() {
        let text = "Hello, world! Don't stop. Mr. Smith paid 3.50 dollars."
        let tok = NLTokenizer(unit: .word); tok.string = text
        log("words \(tok.tokens(for: text.startIndex..<text.endIndex).map { String(text[$0]) })")
        let sent = NLTokenizer(unit: .sentence); sent.string = text
        log("sentences \(sent.tokens(for: text.startIndex..<text.endIndex).count)")
        let samples = ["The weather is nice today and we are going to the park.", "Bonjour, je voudrais un café et un croissant, merci.",
                       "Ich habe heute keine Zeit, aber morgen gerne.", "¿Dónde está la estación de tren?", "今日はいい天気ですね。", "Привет, как дела?"]
        log("languages \(samples.map { NLLanguageRecognizer.dominantLanguage(for: $0)?.rawValue ?? "?" }.joined(separator: ","))")
        let r = NLLanguageRecognizer(); r.processString("Bonjour tout le monde")
        let h = r.languageHypotheses(withMaximum: 2)
        log("hypotheses top=\(r.dominantLanguage?.rawValue ?? "?") count=\(h.count) sum<=1 \(h.values.reduce(0, +) <= 1.0001)")
        let sentence = "The quick brown fox jumps over the lazy dog."
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .sentimentScore])
        tagger.string = sentence
        var classes: [String] = []
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, _ in
            classes.append(tag?.rawValue ?? "nil"); return true
        }
        log("lexical \(classes.joined(separator: " "))")
        for s in ["I love this, it is wonderful", "This is terrible and awful"] {
            tagger.string = s
            let (t, _) = tagger.tag(at: s.startIndex, unit: .paragraph, scheme: .sentimentScore)
            log("sentiment '\(s)' \(t?.rawValue ?? "nil")")
        }
    }

    // MARK: Speech
    func speech() {
        log("speech recognizer en-US available=\(SFSpeechRecognizer(locale: Locale(identifier: "en-US"))?.isAvailable ?? false) xx=\(SFSpeechRecognizer(locale: Locale(identifier: "xx")) == nil ? "nil" : "?")")
        SFSpeechRecognizer.requestAuthorization { status in
            log("speech authorization \(status.rawValue)")
            DispatchQueue.main.async {
                guard let rec = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else { return }
                let url = res.appendingPathComponent("speech.wav")
                _ = rec.recognitionTask(with: SFSpeechURLRecognitionRequest(url: url)) { result, error in
                    if let result { log("speech transcription '\(result.bestTranscription.formattedString)' final=\(result.isFinal)"); self.speechLabel.text = result.bestTranscription.formattedString }
                    else { log("speech error: \(error.map(message) ?? "none")"); self.speechLabel.text = "unavailable" }
                }
            }
        }
    }

    // MARK: VisionKit
    func visionKit() {
        log("datascanner supported=\(DataScannerViewController.isSupported) available=\(DataScannerViewController.isAvailable) documentCamera=\(VNDocumentCameraViewController.isSupported)")
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])])
        do { try scanner.startScanning(); log("scanning?!") } catch { log("datascanner startScanning throws \(error)") }
    }
}
