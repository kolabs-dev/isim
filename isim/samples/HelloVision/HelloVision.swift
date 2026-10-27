// Sample: on-device intelligence APIs on isim — Vision (VNDetectBarcodesRequest with region of interest and
// orientation, VNRecognizeTextRequest, faces and landmarks, rectangles, text rectangles, contours, the horizon and
// saliency on pictures the app draws; tracking, registration and optical flow on drawn frames), Core ML (MLModel.compileModel, model
// descriptions, MLMultiArray, GLM regressor/classifier predictions, models isim cannot run), NaturalLanguage
// (NLTokenizer, NLLanguageRecognizer, NLTagger), Speech (authorization alert, recognition) and VisionKit
// (DataScannerViewController support check). Pictures and model specs are made by the build (buildlib/apps.py).
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
    let detected = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Vision"; title.font = .systemFont(ofSize: 34, weight: .bold)
        title.frame = CGRect(x: 20, y: 64, width: 300, height: 41); view.addSubview(title)
        picture.frame = CGRect(x: 51, y: 130, width: 300, height: 150); picture.accessibilityIdentifier = "codes"
        view.addSubview(picture)
        speechLabel.frame = CGRect(x: 20, y: 300, width: 362, height: 22); speechLabel.accessibilityIdentifier = "speech"
        view.addSubview(speechLabel)
        detected.frame = CGRect(x: 51, y: 330, width: 300, height: 225); detected.accessibilityIdentifier = "detected"
        view.addSubview(detected)
        barcodes()
        text()
        faces()
        detectors()
        tracking()
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
    /// faces and landmarks in NASA's astronaut portrait (face.jpg, also HelloCoreImage's)
    func faces() {
        guard let img = UIImage(contentsOfFile: res.appendingPathComponent("face.jpg").path)?.cgImage else { log("faces: no test picture"); return }
        let req = VNDetectFaceRectanglesRequest { req, err in log("face completion error=\(err.map(message) ?? "none")") }
        let marks = VNDetectFaceLandmarksRequest()
        do {
            try VNImageRequestHandler(cgImage: img).perform([req, marks])
            let found = req.results as? [VNFaceObservation] ?? []
            log("faces \(found.count) box=\(found.first.map { rect($0.boundingBox) } ?? "-") roll=\(found.first?.roll.map { f2($0.doubleValue) } ?? "nil")")
            if let lm = (marks.results as? [VNFaceObservation])?.first?.landmarks, let le = lm.leftPupil?.normalizedPoints.first,
               let re = lm.rightPupil?.normalizedPoints.first, let lips = lm.outerLips?.normalizedPoints {
                let mouthY = lips.map(\.y).reduce(0, +) / CGFloat(lips.count)
                log("landmarks pupils \(f2(le.x)),\(f2(le.y)) \(f2(re.x)),\(f2(re.y)) mouth below eyes \(mouthY < min(le.y, re.y)) " +
                    "contour \(lm.faceContour?.pointCount ?? 0) all \(lm.allPoints?.pointCount ?? 0) closed \(lm.leftEye?.pointsClassification == .closedPath)")
            }
            /* landmarks for a face given by the app (inputFaceObservations), here the detected one */
            let given = VNDetectFaceLandmarksRequest()
            given.inputFaceObservations = found
            try VNImageRequestHandler(cgImage: img).perform([given])
            log("given faces landmarks \((given.results as? [VNFaceObservation] ?? []).filter { $0.landmarks != nil }.count)")
        } catch { log("faces error \((error as NSError).domain) \((error as NSError).code)") }
    }

    /// a picture drawn with UIKit (top-left origin, 1 pixel per point)
    func render(_ w: CGFloat, _ h: CGFloat, _ draw: (CGContext) -> Void) -> CGImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { draw($0.cgContext) }.cgImage!
    }
    /// tracking, registration and optical flow on drawn frames with known motion (issue #373)
    func tracking() {
        /* a 200 x 150 frame: grey blobs (moved by `shift`, UIKit points, y down) and a 30 pt black square with a white
           corner (at `object`) */
        func frame(shift: CGPoint = .zero, scale: CGFloat = 1, object: CGPoint? = nil) -> CGImage {
            render(200, 150) { c in
                c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 0, y: 0, width: 200, height: 150))
                c.saveGState()
                c.translateBy(x: 100 + shift.x, y: 75 + shift.y); c.scaleBy(x: scale, y: scale); c.translateBy(x: -100, y: -75)
                for i in 0..<70 {
                    let x = CGFloat((i * 37) % 240) - 20, y = CGFloat((i * 53) % 190) - 20, r = CGFloat(5 + i % 6)
                    c.setFillColor(UIColor(white: CGFloat(i % 4) * 0.2, alpha: 1).cgColor)
                    c.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
                }
                c.restoreGState()
                if let o = object {
                    c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: o.x - 6, y: o.y - 6, width: 42, height: 42))
                    c.setFillColor(UIColor.black.cgColor); c.fill(CGRect(x: o.x, y: o.y, width: 30, height: 30))
                    c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: o.x + 4, y: o.y + 4, width: 10, height: 10))
                }
            }
        }
        do {
            /* VNTrackObjectRequest / VNTrackRectangleRequest over three frames: the square moves 12 right, 6 down each */
            let box = CGRect(x: 40.0 / 200, y: 1 - 80.0 / 150, width: 30.0 / 200, height: 30.0 / 150)
            let start = VNDetectedObjectObservation(boundingBox: box)
            let object = VNTrackObjectRequest(detectedObjectObservation: start)
            let rectangle = VNTrackRectangleRequest(rectangleObservation: VNRectangleObservation(boundingBox: box))
            rectangle.trackingLevel = .fast
            let sequence = VNSequenceRequestHandler()
            var last: VNDetectedObjectObservation?
            for k in 0..<3 {
                let f = frame(object: CGPoint(x: 40 + 12 * k, y: 50 + 6 * k))
                rectangle.isLastFrame = k == 2
                try sequence.perform([object, rectangle], on: f)
                last = object.results?.first as? VNDetectedObjectObservation
                if let last { object.inputObservation = last }
            }
            let corner = (rectangle.results?.first as? VNRectangleObservation)?.topLeft ?? .zero
            log("track object \(last.map { rect($0.boundingBox) } ?? "none") same uuid \(last?.uuid == start.uuid) confidence \(last.map { $0.confidence > 0.9 } ?? false) " +
                "rectangle topLeft \(f2(corner.x)),\(f2(corner.y)) trackers \(object.supportedNumber(ofTrackersAndReturnError: nil))")

            /* registration: the floating image is the reference moved 10 right and 6 down */
            let reference = frame(), floating = frame(shift: CGPoint(x: 10, y: 6))
            let translation = VNTranslationalImageRegistrationRequest(targetedCGImage: floating)
            let homography = VNHomographicImageRegistrationRequest(targetedCGImage: frame(shift: CGPoint(x: 4, y: -3), scale: 1.05))
            try VNImageRequestHandler(cgImage: reference).perform([translation, homography])
            let t = (translation.results?.first as? VNImageTranslationAlignmentObservation)?.alignmentTransform ?? .identity
            log("registration translation \(String(format: "%.1f %.1f", t.tx, t.ty))")
            if let w = (homography.results?.first as? VNImageHomographicAlignmentObservation)?.warpTransform {
                /* a reference point p (y down) is at A p in the floating image; the warp brings it back (y up) */
                var worst = 0.0
                for p in [CGPoint(x: 40, y: 30), CGPoint(x: 160, y: 30), CGPoint(x: 40, y: 120), CGPoint(x: 160, y: 120)] {
                    let q = CGPoint(x: 100 + 4 + (p.x - 100) * 1.05, y: 75 - 3 + (p.y - 75) * 1.05)
                    let r = w * SIMD3<Float>(Float(q.x), Float(150 - q.y), 1)
                    worst = max(worst, hypot(Double(r.x / r.z) - p.x, Double(r.y / r.z) - (150 - p.y)))
                }
                log("registration homography error below 1.5 \(worst < 1.5) scale \(String(format: "%.2f", w.columns.0.x))")
            }
            /* the same between frames of a sequence */
            let trackShift = VNTrackTranslationalImageRegistrationRequest()
            let sequence2 = VNSequenceRequestHandler()
            try sequence2.perform([trackShift], on: floating)
            let first = trackShift.results?.count ?? -1
            try sequence2.perform([trackShift], on: reference)
            let t2 = (trackShift.results?.first as? VNImageTranslationAlignmentObservation)?.alignmentTransform ?? .identity
            log("track registration first \(first) then \(String(format: "%.1f %.1f", t2.tx, t2.ty))")

            /* optical flow: the square moves 6 right and 4 down over still blobs */
            let flow = VNGenerateOpticalFlowRequest(targetedCGImage: frame(object: CGPoint(x: 80, y: 60)))
            try VNImageRequestHandler(cgImage: frame(object: CGPoint(x: 86, y: 64))).perform([flow])
            if let pb = (flow.results?.first as? VNPixelBufferObservation)?.pixelBuffer {
                CVPixelBufferLockBaseAddress(pb, .readOnly)
                let base = CVPixelBufferGetBaseAddress(pb)!, bpr = CVPixelBufferGetBytesPerRow(pb)
                /* the median motion over the square's place in the second frame, and over the whole field */
                func median(_ xs: Range<Int>, _ ys: Range<Int>) -> (Float, Float) {
                    var us: [Float] = [], vs: [Float] = []
                    for y in ys { for x in xs {
                        us.append(base.load(fromByteOffset: y * bpr + x * 8, as: Float.self))
                        vs.append(base.load(fromByteOffset: y * bpr + x * 8 + 4, as: Float.self))
                    } }
                    return (us.sorted()[us.count / 2], vs.sorted()[vs.count / 2])
                }
                let c = median(86..<116, 64..<94), all = median(0..<CVPixelBufferGetWidth(pb), 0..<CVPixelBufferGetHeight(pb))
                CVPixelBufferUnlockBaseAddress(pb, .readOnly)
                log("optical flow \(CVPixelBufferGetWidth(pb))x\(CVPixelBufferGetHeight(pb)) two floats \(CVPixelBufferGetPixelFormatType(pb) == kCVPixelFormatType_TwoComponent32Float) " +
                    "object \(String(format: "%.1f,%.1f elsewhere %.1f,%.1f", c.0, c.1, all.0, all.1))")
            }
        } catch { log("tracking error \(message(error))") }
    }
    /// rectangles, text rectangles, contours, the horizon and saliency, on pictures with known answers (issue #276)
    func detectors() {
        /* shapes: a 160x100 rectangle, an 80 pt square turned 20 degrees, and a ring around a dot */
        let shapes = render(400, 300) { c in
            c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
            c.setFillColor(UIColor.black.cgColor); c.fill(CGRect(x: 40, y: 40, width: 160, height: 100))
            c.saveGState(); c.translateBy(x: 300, y: 200); c.rotate(by: 20 * .pi / 180); c.fill(CGRect(x: -40, y: -40, width: 80, height: 80)); c.restoreGState()
            c.fillEllipse(in: CGRect(x: 55, y: 185, width: 90, height: 90))
            c.setFillColor(UIColor.white.cgColor); c.fillEllipse(in: CGRect(x: 75, y: 205, width: 50, height: 50))
            c.setFillColor(UIColor.black.cgColor); c.fillEllipse(in: CGRect(x: 92, y: 222, width: 16, height: 16))
        }
        let rects = VNDetectRectanglesRequest()
        rects.maximumObservations = 0; rects.minimumAspectRatio = 0.3; rects.minimumSize = 0.1
        let contours = VNDetectContoursRequest()
        do {
            try VNImageRequestHandler(cgImage: shapes).perform([rects, contours])
            let found = rects.results as? [VNRectangleObservation] ?? []
            log("rectangles \(found.count): " + found.map { rect($0.boundingBox) }.joined(separator: "; ") +
                (found.first.map { " first topLeft \(f2($0.topLeft.x)),\(f2($0.topLeft.y)) bottomRight \(f2($0.bottomRight.x)),\(f2($0.bottomRight.y))" } ?? ""))
            if let obs = contours.results?.first as? VNContoursObservation {
                let ring = try obs.contour(at: IndexPath(indexes: [2]))
                let dot = try obs.contour(at: IndexPath(indexes: [2, 0, 0]))
                let box = try obs.contour(at: IndexPath(index: 0)).polygonApproximation(epsilon: 0.01)
                log("contours \(obs.contourCount) top \(obs.topLevelContourCount) ring children \(ring.childContourCount) " +
                    "dot path \(dot.indexPath.map(String.init).joined(separator: ".")) box corners \(box.pointCount) aspect \(f2(Double(box.aspectRatio)))")
                detected.image = UIImage(cgImage: render(400, 300) { c in
                    UIImage(cgImage: shapes).draw(in: CGRect(x: 0, y: 0, width: 400, height: 300))   // UIKit: upright
                    c.translateBy(x: 0, y: 300); c.scaleBy(x: 400, y: -300)           // Vision's normalized, y-up space
                    c.addPath(obs.normalizedPath); c.setStrokeColor(UIColor.systemRed.cgColor); c.setLineWidth(3 / 400); c.strokePath()
                    c.setStrokeColor(UIColor.systemGreen.cgColor); c.setLineWidth(6 / 400)
                    for r in found { c.addLines(between: [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft, r.topLeft]) }
                    c.strokePath()
                })
            }
        } catch { log("shapes error \(message(error))") }

        /* text rectangles: two words, without OCR */
        let words = render(480, 120) { c in
            c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 0, y: 0, width: 480, height: 120))
            ("HELLO ISIM" as NSString).draw(at: CGPoint(x: 40, y: 30), withAttributes: [.font: UIFont.systemFont(ofSize: 48, weight: .bold), .foregroundColor: UIColor.black])
        }
        let textRects = VNDetectTextRectanglesRequest(); textRects.reportCharacterBoxes = true
        try? VNImageRequestHandler(cgImage: words).perform([textRects])
        let tr = textRects.results as? [VNTextObservation] ?? []
        log("text rectangles \(tr.count) chars \(tr.map { $0.characterBoxes?.count ?? 0 })")

        /* the horizon: sky over ground, the line turned 10 degrees counterclockwise */
        let tilted = render(320, 240) { c in
            c.setFillColor(UIColor(red: 0.6, green: 0.8, blue: 1, alpha: 1).cgColor); c.fill(CGRect(x: 0, y: 0, width: 320, height: 240))
            let t = tan(10 * Double.pi / 180)
            c.setFillColor(UIColor(red: 0.1, green: 0.35, blue: 0.1, alpha: 1).cgColor)
            c.addLines(between: [CGPoint(x: 0, y: 120 + 160 * t), CGPoint(x: 320, y: 120 - 160 * t), CGPoint(x: 320, y: 240), CGPoint(x: 0, y: 240)])
            c.fillPath()
        }
        let horizon = VNDetectHorizonRequest()
        try? VNImageRequestHandler(cgImage: tilted).perform([horizon])
        if let h = horizon.results?.first as? VNHorizonObservation {
            log("horizon \(String(format: "%.1f", h.angle * 180 / .pi)) levels \(f2(atan2(h.transform.b, h.transform.a) * 180 / .pi))")
        } else { log("horizon none") }

        /* saliency: a red disk off-centre on grey */
        let disk = render(300, 300) { c in
            c.setFillColor(UIColor(white: 0.5, alpha: 1).cgColor); c.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
            c.setFillColor(UIColor.red.cgColor); c.fillEllipse(in: CGRect(x: 175, y: 55, width: 70, height: 70))
        }
        let saliency = VNGenerateAttentionBasedSaliencyImageRequest()
        try? VNImageRequestHandler(cgImage: disk).perform([saliency])
        if let s = saliency.results?.first as? VNSaliencyImageObservation, let o = s.salientObjects?.first {
            let pb = s.pixelBuffer
            log("saliency \(CVPixelBufferGetWidth(pb))x\(CVPixelBufferGetHeight(pb)) float \(CVPixelBufferGetPixelFormatType(pb) == kCVPixelFormatType_OneComponent32Float) " +
                "objects \(s.salientObjects?.count ?? 0) first center \(f2(o.boundingBox.midX)),\(f2(o.boundingBox.midY))")
        } else { log("saliency none") }
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
