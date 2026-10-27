// Sample: PencilKit on isim — a PKCanvasView that the Apple Pencil (and a finger) draws on, with a PKToolPicker
// docked at the bottom (pen, monoline, marker, pencil, eraser, lasso, ruler, and a color), and a toolbar that clears the
// drawing, saves and reloads it through its data representation, and erases a band across it in code. At launch it
// builds a drawing from Swift values (PKStroke, PKStrokePath, PKInk) and prints what it checked.
import PencilKit
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: SketchViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class SketchViewController: UIViewController, PKCanvasViewDelegate, PKToolPickerObserver {
    let canvas = PKCanvasView()
    let picker = PKToolPicker()
    var saved = Data()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sketch"
        view.backgroundColor = .systemBackground
        canvas.frame = view.bounds
        canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvas.accessibilityIdentifier = "canvas"
        canvas.backgroundColor = .white
        canvas.drawingPolicy = .anyInput                      // fingers draw too
        canvas.delegate = self
        canvas.tool = PKInkingTool(.pen, color: .systemBlue, width: 6)
        view.addSubview(canvas)
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clear))
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "clear"
        let save = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(saveAndReload))
        save.accessibilityIdentifier = "save"
        let erase = UIBarButtonItem(title: "Erase band", style: .plain, target: self, action: #selector(eraseBand))
        erase.accessibilityIdentifier = "erase-band"
        navigationItem.rightBarButtonItems = [save, erase]
        swiftValues()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        picker.addObserver(canvas)                          // the canvas takes the picker's tool
        picker.addObserver(self)
        picker.setVisible(true, forFirstResponder: canvas)
        canvas.becomeFirstResponder()
    }

    /// a drawing built from Swift values, and what the overlay's value types give back
    func swiftValues() {
        let points = (0...4).map { i in
            PKStrokePoint(location: CGPoint(x: 40 + 50 * CGFloat(i), y: 300), timeOffset: 0.1 * TimeInterval(i), size: CGSize(width: 8, height: 8),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        let stroke = PKStroke(ink: PKInk(.marker, color: .systemOrange), path: path)
        var drawing = PKDrawing(strokes: [stroke])
        let along = path.interpolatedPoints(by: .distance(25)).map(\.location.x)
        print("swift: path of \(path.count) points, \(along.count) points every 25 pt, mid x \(Int(path.interpolatedLocation(at: 2).x))")
        drawing.transform(using: CGAffineTransform(translationX: 0, y: 40))
        drawing.append(PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black), path: path[1...3])]))
        let back = try? PKDrawing(data: drawing.dataRepresentation())
        print("swift: drawing of \(drawing.strokes.count) strokes, bounds y \(Int(drawing.bounds.minY)), reads back \(back == drawing),"
              + " first ink \(drawing.strokes[0].ink.inkType == .marker ? "marker" : "?")")
        let tool = PKInkingTool(.pen, color: .red, width: 500)
        print("swift: pen width clamps to \(Int(tool.width)) (range \(Int(PKInkingTool.InkType.pen.validWidthRange.upperBound))),"
              + " eraser \(Int(PKEraserTool(.vector).width))")
        if #available(iOS 17.0, *) { print("swift: latest content version \(PKContentVersion.latest.rawValue)") }
    }

    // MARK: actions
    @objc func clear() { canvas.drawing = PKDrawing() }
    @objc func saveAndReload() {
        saved = canvas.drawing.dataRepresentation()
        canvas.drawing = PKDrawing()
        canvas.drawing = (try? PKDrawing(data: saved)) ?? PKDrawing()
        print("saved \(saved.count) bytes, reloaded \(canvas.drawing.strokes.count) strokes")
    }
    /// erase a horizontal band across the middle of the canvas
    @objc func eraseBand() {
        guard #available(iOS 26.0, *) else { return print("erasing in code needs iOS 26") }
        let y = canvas.bounds.midY
        let eraser = PKStrokePath(controlPoints: [0, 1].map { i in
            PKStrokePoint(location: CGPoint(x: CGFloat(i) * canvas.bounds.width, y: y), timeOffset: TimeInterval(i), size: CGSize(width: 30, height: 30),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }, creationDate: Date())
        canvas.drawing.erasePath(eraser, mask: nil, transform: .identity)
    }

    // MARK: PKCanvasViewDelegate
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        let inks = canvasView.drawing.strokes.map { $0.ink.inkType.rawValue.replacingOccurrences(of: "com.apple.ink.", with: "") }
        print("drawing changed: \(canvasView.drawing.strokes.count) strokes [\(inks.joined(separator: " "))]")
    }
    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) { print("began using \(describe(canvasView.tool))") }
    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) { print("ended using tool") }

    // MARK: PKToolPickerObserver
    func toolPickerSelectedToolItemDidChange(_ toolPicker: PKToolPicker) {
        if #available(iOS 18.0, *) { print("picker tool: \(toolPicker.selectedToolItemIdentifier)") }
    }
    func toolPickerIsRulerActiveDidChange(_ toolPicker: PKToolPicker) { print("ruler active \(toolPicker.isRulerActive)") }
    func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
        print("picker visible \(toolPicker.isVisible), obscures \(Int(toolPicker.frameObscured(in: view).height)) pt")
    }

    func describe(_ tool: any PKTool) -> String {
        switch tool {
        case let t as PKInkingTool: return "\(t.inkType.rawValue.replacingOccurrences(of: "com.apple.ink.", with: "")) width \(Int(t.width))"
        case let t as PKEraserTool: return "eraser \(t.eraserType == .vector ? "vector" : "bitmap")"
        default: return "lasso"
        }
    }
}
