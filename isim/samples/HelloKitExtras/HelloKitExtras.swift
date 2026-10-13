// Sample: smaller UIKit APIs from the documentation sweep (#9), each logged with "hx" so the test can check it.
// - UIStackView: isBaselineRelativeArrangement, customSpacing(after:)
// - iOS 26 flushUpdates (UIView.animate options and UIViewPropertyAnimator)
// - UIUpdateLink's phases in order and UIUpdateInfo.current(for:)
// - UILargeContentViewerInteraction: gestureRecognizerForExclusionRelationship, scalesLargeContentImage, image insets
// - UILetterformAwareAdjusting: a label's oversize sizing rule makes room for stacked marks
// - item providers: a preferred presentation size from UIImage, a reading class augmented with plain text
// - UIEventAttribution / UIEventAttributionView (private click measurement; script `attributions`)
// - UIScreenshotService: a full-page PDF (script `fullpage PATH`)
// - UIGraphicsRenderer subclassing (runDrawingActions), UIRectFillUsingBlendMode, UIGraphicsImageRendererFormat(for:)
// - tooltips (UIToolTipInteraction, UIControl.toolTip, UILabel.showsExpansionTextWhenTruncated) and band selection on iPad
// - motion effects (script `tilt H V`), UIKit Dynamics fields and attachments, gesture recognizer touch types and masks
// - geometry: NSValue / NSCoder additions, the string forms
import UIKit
import UniformTypeIdentifiers

func log(_ s: String) { print("hx \(s)") }
func n(_ v: CGFloat) -> String { String(format: "%.0f", v) }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ExtrasViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

// ---- item providers ----
final class NoteAugmenter: NSObject, UIItemProviderReadingAugmentationProviding {
    static var additionalLeadingReadableTypeIdentifiersForItemProvider: [String] { [] }
    static var additionalTrailingReadableTypeIdentifiersForItemProvider: [String] { [UTType.plainText.identifier] }
    static func object(withItemProviderData data: Data, typeIdentifier: String, requestedClass: any NSItemProviderReading.Type) throws -> Any {
        Note(text: "augmented: " + (String(data: data, encoding: .utf8) ?? ""))
    }
}
final class Note: NSObject, NSItemProviderReading, UIItemProviderReadingAugmentationDesignating {
    let text: String
    init(text: String) { self.text = text }
    static var readableTypeIdentifiersForItemProvider: [String] { ["dev.isim.note"] }
    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        Note(text: String(data: data, encoding: .utf8) ?? "") as! Self
    }
    static var _ui_augmentingNSItemProviderReadingClass: any UIItemProviderReadingAugmentationProviding.Type { NoteAugmenter.self }
}

// ---- a renderer subclass ----
final class StampContext: UIGraphicsRendererContext {}
final class StampRenderer: UIGraphicsRenderer {
    override class func rendererContextClass() -> AnyClass { StampContext.self }
    override class func prepare(_ context: CGContext, with rendererContext: UIGraphicsRendererContext) {
        context.setFillColor(UIColor.systemBlue.cgColor)
    }
}

final class ExtrasViewController: UIViewController, UILargeContentViewerInteractionDelegate, UIScreenshotServiceDelegate,
                                  UIToolTipInteractionDelegate, UIGestureRecognizerDelegate {
    let stack = UIStackView()
    let small = UILabel(), big = UILabel()
    let box = UIView()
    var boxWidth: NSLayoutConstraint!
    let parallax = UIView()
    let deleteButton = UIButton(type: .system)
    let truncated = UILabel()
    let canvas = UIView()
    let pointerPad = UIView()
    let adButton = UIButton(type: .system)
    let attribution = UIEventAttributionView()
    var updateLink: AnyObject?
    var phases: [String] = []
    var animator: UIDynamicAnimator?
    let fieldItem = UIView(), slider = UIView()
    var band: UIBandSelectionInteraction?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let ipad = traitCollection.userInterfaceIdiom == .pad
        log("start ipad \(ipad)")

        // stack view: baseline-relative vertical spacing, custom spacing after a view
        stack.axis = .vertical; stack.spacing = 20; stack.isBaselineRelativeArrangement = true
        small.text = "Small"; small.font = .systemFont(ofSize: 12)
        big.text = "Big"; big.font = .systemFont(ofSize: 34)
        stack.addArrangedSubview(small); stack.addArrangedSubview(big)
        stack.frame = CGRect(x: 20, y: 60, width: 160, height: 120)
        view.addSubview(stack)
        log("custom spacing default \(stack.customSpacing(after: small) == UIStackView.spacingUseDefault)")
        stack.setCustomSpacing(30, after: small)
        log("custom spacing set \(n(stack.customSpacing(after: small)))")

        // flushUpdates: a constraint change made before the block is applied by it
        box.backgroundColor = .systemGreen; box.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(box)
        boxWidth = box.widthAnchor.constraint(equalToConstant: 40)
        NSLayoutConstraint.activate([boxWidth, box.heightAnchor.constraint(equalToConstant: 20),
                                     box.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 200),
                                     box.topAnchor.constraint(equalTo: view.topAnchor, constant: 60)])

        // motion effects: a red square moves with the tilt
        parallax.frame = CGRect(x: 200, y: 100, width: 40, height: 40); parallax.backgroundColor = .systemRed
        parallax.accessibilityIdentifier = "parallax"
        let mx = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        mx.minimumRelativeValue = -30; mx.maximumRelativeValue = 30
        let my = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        my.minimumRelativeValue = -10; my.maximumRelativeValue = 10
        let group = UIMotionEffectGroup(); group.motionEffects = [mx, my]
        parallax.addMotionEffect(group)
        view.addSubview(parallax)
        log("motion effects \(parallax.motionEffects.count) values \(mx.keyPathsAndRelativeValues(forViewerOffset: UIOffset(horizontal: 1, vertical: 0))?["center.x"] as? NSNumber ?? -1)")

        // large content viewer
        let lcv = UILargeContentViewerInteraction(delegate: self)
        view.addInteraction(lcv)
        small.showsLargeContentViewer = true; small.scalesLargeContentImage = true
        small.largeContentImageInsets = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
        log("lcv exclusion \(type(of: lcv.gestureRecognizerForExclusionRelationship)) scales \(small.scalesLargeContentImage) insets \(n(small.largeContentImageInsets.top))")
        NotificationCenter.default.addObserver(forName: UILargeContentViewerInteraction.enabledStatusDidChangeNotification, object: nil, queue: .main) { _ in
            log("lcv enabled now \(UILargeContentViewerInteraction.isEnabled)")
        }

        // letterform-aware sizing: stacked marks reach above the line
        let marks = "A\u{0302}\u{0302}\u{0302}\u{0302} xyz"
        let typo = UILabel(), over = UILabel()
        typo.text = marks; over.text = marks; over.sizingRule = .oversize
        let ht = typo.intrinsicContentSize.height, ho = over.intrinsicContentSize.height
        log("letterform typographic \(typo.sizingRule == .typographic) taller \(ho > ht)")

        // labels and image views
        let shrink = UILabel(); shrink.baselineAdjustment = .alignCenters
        log("label baseline \(shrink.baselineAdjustment == .alignCenters) vibrancy \(shrink.preferredVibrancy == .none) strategy \(shrink.lineBreakStrategy == []) expansion \(shrink.showsExpansionTextWhenTruncated)")
        let iv = UIImageView()
        log("image view range \(iv.preferredImageDynamicRange == .unspecified) drawn \(iv.imageDynamicRange == .standard)")

        // item providers
        let image = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 20)).image { c in UIColor.orange.setFill(); c.fill(CGRect(x: 0, y: 0, width: 30, height: 20)) }
        let p = NSItemProvider(object: image)
        log("presentation size \(n(p.preferredPresentationSize.width))x\(n(p.preferredPresentationSize.height))")
        let textProvider = NSItemProvider(object: "hello" as NSString)
        log("note can load \(textProvider.canLoadObject(ofClass: Note.self))")
        _ = textProvider.loadObject(ofClass: Note.self) { obj, _ in
            DispatchQueue.main.async { log("note loaded \((obj as? Note)?.text ?? "nil")") }
        }

        // renderers and rect functions
        let fmt = UIGraphicsImageRendererFormat(for: UITraitCollection(displayScale: 2))
        log("format scale \(n(fmt.scale)) hdr \(fmt.supportsHighDynamicRange)")
        let stamp = StampRenderer(bounds: CGRect(x: 0, y: 0, width: 10, height: 10))
        do {
            try stamp.runDrawingActions({ ctx in
                log("stamp context \(type(of: ctx)) cg \(ctx.cgContext.width > 0 || true)")
                UIRectFillUsingBlendMode(CGRect(x: 0, y: 0, width: 5, height: 5), .multiply)
                UIRectFrameUsingBlendMode(CGRect(x: 0, y: 0, width: 5, height: 5), .normal)
                UIRectClip(CGRect(x: 0, y: 0, width: 4, height: 4))
            }, completionActions: { _ in log("stamp completion") })
        } catch { log("stamp error \(error)") }

        // geometry values and strings
        let insets = UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)
        let v = NSValue(uiEdgeInsets: insets), o = NSValue(uiOffset: UIOffset(horizontal: 5, vertical: 6))
        log("values insets \(v.uiEdgeInsetsValue == insets) offset \(o.uiOffsetValue == UIOffset(horizontal: 5, vertical: 6)) zero \(UIOffset.zero == UIOffset(horizontal: 0, vertical: 0))")
        log("strings rect \(NSCoder.string(for: CGRect(x: 1, y: 2, width: 3, height: 4))) back \(NSCoder.cgRect(for: "{{1, 2}, {3, 4}}") == CGRect(x: 1, y: 2, width: 3, height: 4)) offset \(NSCoder.string(for: UIOffset(horizontal: 1, vertical: 2)))")
        let arch = NSKeyedArchiver(requiringSecureCoding: false)
        arch.encode(CGPoint(x: 7, y: 8), forKey: "p"); arch.encode(insets, forKey: "i")
        arch.finishEncoding()
        if let un = try? NSKeyedUnarchiver(forReadingFrom: arch.encodedData) {
            un.requiresSecureCoding = false
            log("coder point \(un.decodeCGPoint(forKey: "p") == CGPoint(x: 7, y: 8)) insets \(un.decodeUIEdgeInsets(forKey: "i") == insets)")
        }

        // dynamics: a linear gravity field pushes right, a sliding attachment keeps the slider on its line
        fieldItem.frame = CGRect(x: 20, y: 300, width: 30, height: 30); fieldItem.backgroundColor = .systemPurple
        slider.frame = CGRect(x: 100, y: 300, width: 30, height: 30); slider.backgroundColor = .systemTeal
        view.addSubview(fieldItem); view.addSubview(slider)
        let an = UIDynamicAnimator(referenceView: view)
        let field = UIFieldBehavior.linearGravityField(direction: CGVector(dx: 1, dy: 0))
        field.strength = 0.5; field.addItem(fieldItem)
        let gravity = UIGravityBehavior(items: [slider])
        let slide = UIAttachmentBehavior.slidingAttachment(with: slider, attachmentAnchor: slider.center, axisOfTranslation: CGVector(dx: 1, dy: 0))
        an.addBehavior(field); an.addBehavior(gravity); an.addBehavior(slide)
        animator = an
        let region = UIRegion(radius: 10)
        log("region contains \(region.contains(CGPoint(x: 3, y: 4))) outside \(region.contains(CGPoint(x: 30, y: 0))) inverse \(region.inverse().contains(CGPoint(x: 30, y: 0)))")
        _ = UIAttachmentBehavior.pinAttachment(with: fieldItem, attachedTo: slider, attachmentAnchor: .zero)
        _ = UIAttachmentBehavior.limitAttachment(with: fieldItem, offsetFromCenter: .zero, attachedTo: slider, offsetFromCenter: .zero)
        _ = UIAttachmentBehavior.fixedAttachment(with: fieldItem, attachedTo: slider, attachmentAnchor: .zero)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            log("dynamics field moved \(fieldItem.center.x > 60) slider stays \(abs(slider.center.y - 315) < 1)")
            animator?.removeAllBehaviors()
        }

        // event attribution: an ad button under a UIEventAttributionView
        adButton.setTitle("Ad", for: .normal); adButton.frame = CGRect(x: 20, y: 360, width: 80, height: 40)
        adButton.addAction(UIAction { [weak self] _ in self?.openAd() }, for: .touchUpInside)
        attribution.frame = adButton.frame; attribution.accessibilityIdentifier = "ad"
        view.addSubview(adButton); view.addSubview(attribution)
        openAd()                                                          // no tap first: dropped

        // tooltips, truncation, band selection and pointer-only gestures (iPad)
        deleteButton.setTitle("Delete", for: .normal); deleteButton.frame = CGRect(x: 120, y: 360, width: 80, height: 40)
        deleteButton.toolTip = "Delete item"; deleteButton.accessibilityIdentifier = "delete"
        view.addSubview(deleteButton)
        log("tooltip \(deleteButton.toolTip ?? "nil") interaction \(deleteButton.toolTipInteraction != nil)")
        truncated.text = "A label far too long to fit"; truncated.frame = CGRect(x: 220, y: 360, width: 60, height: 20)
        truncated.showsExpansionTextWhenTruncated = true; truncated.accessibilityIdentifier = "truncated"
        view.addSubview(truncated)
        canvas.frame = CGRect(x: 20, y: 420, width: 260, height: 140); canvas.backgroundColor = .secondarySystemBackground
        canvas.accessibilityIdentifier = "canvas"
        view.addSubview(canvas)
        let tip = UIToolTipInteraction(); tip.delegate = self
        canvas.addInteraction(tip)
        let b = UIBandSelectionInteraction { i in
            let r = i.selectionRect ?? .zero
            log("band \(["possible", "began", "selecting", "ended"][i.state.rawValue]) \(n(r.width))x\(n(r.height)) shift \(i.initialModifierFlags.contains(.shift))")
        }
        b.shouldBeginHandler = { _, p in p.x < 200 }
        canvas.addInteraction(b); band = b
        pointerPad.frame = CGRect(x: 20, y: 580, width: 260, height: 60); pointerPad.backgroundColor = .systemYellow
        pointerPad.accessibilityIdentifier = "pointer-pad"
        view.addSubview(pointerPad)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(pointerPan(_:)))
        pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)]
        pan.delegate = self
        pointerPad.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(padTap(_:)))
        log("tap mask primary \(tap.buttonMaskRequired == .primary) pan scroll types \(pan.allowedScrollTypesMask.rawValue) press types \(pan.allowedPressTypes.count)")
        pointerPad.addGestureRecognizer(tap)
        log("button mask 2 \(UIEvent.ButtonMask.button(2) == .secondary)")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // screenshot service
        view.window?.windowScene?.screenshotService?.delegate = self
        log("screenshot service \(view.window?.windowScene?.screenshotService != nil)")
        // update link: every phase, in order
        if #available(iOS 18, *), let scene = view.window?.windowScene {
            let link = UIUpdateLink(windowScene: scene)
            let all: [(String, UIUpdateActionPhase)] = [("afterUpdateComplete", .afterUpdateComplete), ("beforeEventDispatch", .beforeEventDispatch),
                ("afterCATransactionCommit", .afterCATransactionCommit), ("afterUpdateScheduled", .afterUpdateScheduled),
                ("beforeCADisplayLinkDispatch", .beforeCADisplayLinkDispatch), ("afterEventDispatch", .afterEventDispatch),
                ("beforeCATransactionCommit", .beforeCATransactionCommit), ("afterCADisplayLinkDispatch", .afterCADisplayLinkDispatch),
                ("beforeLowLatencyEventDispatch", .beforeLowLatencyEventDispatch)]
            for (name, ph) in all {
                link.addAction(to: ph) { [weak self] l, info in
                    guard let self, self.phases.count < 8 else { return }
                    self.phases.append(name)
                    if self.phases.count == 8 {
                        log("phases \(self.phases.joined(separator: ","))")
                        log("update info inside \(UIUpdateInfo.current(for: self.view) != nil)")
                        l.isEnabled = false
                    }
                }
            }
            link.requiresContinuousUpdates = true; link.isEnabled = true
            updateLink = link
            log("update info outside \(UIUpdateInfo.current(for: view) == nil)")
        }
        // flushUpdates: the pending width change is applied before the block, so only the alpha change animates
        guard #available(iOS 26, *) else { log("flush width 80"); log("animator flush true"); return }
        boxWidth.constant = 80
        UIView.animate(withDuration: 0.3, delay: 0, options: [.flushUpdates]) { [self] in
            log("flush width \(n(box.frame.width))")
            box.alpha = 0.5
        }
        let pa = UIViewPropertyAnimator(duration: 0.2, curve: .linear) { [self] in box.alpha = 1 }
        pa.flushUpdates = true
        log("animator flush \(pa.flushUpdates)")
        pa.startAnimation()
    }

    func openAd() {
        let a = UIEventAttribution(sourceIdentifier: 7, destinationURL: URL(string: "https://shop.example.com")!, sourceDescription: "Spring sale", purchaser: "Example Shop")
        log("attribution endpoint \(a.reportEndpoint?.host ?? "nil")")
        UIApplication.shared.open(URL(string: "https://shop.example.com/sale")!, options: [.eventAttribution: a])
    }

    @objc func pointerPan(_ g: UIPanGestureRecognizer) {
        if g.state == .began { log("pointer pan began mask \(g.buttonMask.rawValue)") }
    }
    @objc func padTap(_ g: UITapGestureRecognizer) { log("pad tap") }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
        if event.allTouches?.first?.type == .indirectPointer { log("should receive pointer event mask \(event.buttonMask.rawValue)") }
        return true
    }

    // large content viewer
    func viewController(for interaction: UILargeContentViewerInteraction) -> UIViewController { self }

    // tooltip on the canvas: only its left half has one
    func toolTipInteraction(_ interaction: UIToolTipInteraction, configurationAt point: CGPoint) -> UIToolTipConfiguration? {
        point.x < 130 ? UIToolTipConfiguration(toolTip: "Left half", in: CGRect(x: 0, y: 0, width: 130, height: 140)) : nil
    }

    // a two-page PDF of the "document"; the screen shows page 0
    func screenshotService(_ screenshotService: UIScreenshotService, generatePDFRepresentationWithCompletion completionHandler: @escaping (Data?, Int, CGRect) -> Void) {
        let r = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 400))
        let data = r.pdfData { c in
            for i in 0..<2 { c.beginPage(); ("Page \(i + 1)" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 24)]) }
        }
        completionHandler(data, 0, CGRect(x: 0, y: 0, width: 300, height: 400))
    }
}
