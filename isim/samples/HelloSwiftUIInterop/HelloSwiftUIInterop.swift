// Sample: SwiftUI in a UIKit app on isim. The app delegate's scene configuration names a UIHostingSceneDelegate, whose
// rootScene's first WindowGroup becomes the window; its content shows UIHostingConfiguration cells in a UIKit
// collection view (self-sizing, background, margins), an ImageRenderer's image and its PDF rendering, and
// UIGestureRecognizerRepresentables (a tap with a coordinator, a pan with translation). "Open second" activates the
// rootScene's second WindowGroup through UISceneSessionActivationRequest(hostingDelegateClass:id:) (a new window on
// iPad). It prints what the UI test checks.
import SwiftUI
import UIKit
import Combine

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        if #available(iOS 26.0, *) { config.delegateClass = HostingSceneDelegate.self } else { config.delegateClass = OldSceneDelegate.self }
        return config
    }
}

/// before iOS 26 (no UIHostingSceneDelegate): a UIKit window saying so
final class OldSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        w.rootViewController = vc
        window = w
        w.makeKeyAndVisible()
        print("interop needs iOS 26")
    }
}

@available(iOS 26.0, *)
final class HostingSceneDelegate: UIResponder, UIWindowSceneDelegate, UIHostingSceneDelegate {
    var window: UIWindow?
    static var rootScene: some Scene {
        WindowGroup(id: "main") { MainView() }
        WindowGroup(id: "second") { Text("Second window").accessibilityIdentifier("second") }
    }
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        print("interop willConnect window \(window != nil)")
    }
    func sceneDidBecomeActive(_ scene: UIScene) { print("interop scene active") }
}

// MARK: - UIHostingConfiguration cells

struct Cells: UIViewRepresentable {
    final class Coordinator: NSObject, UICollectionViewDataSource {
        let texts = ["Short", "A much longer row whose text wraps onto several lines in the cell, so the cell is taller than the others"]
        func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int { texts.count }
        func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
            let cell = cv.dequeueReusableCell(withReuseIdentifier: "cell", for: ip)
            let text = texts[ip.item]
            cell.contentConfiguration = UIHostingConfiguration {
                HStack {
                    Image(systemName: "star.fill").foregroundStyle(.orange)
                    Text(text).accessibilityIdentifier("cell-text-\(ip.item)")
                    Spacer()
                }
            }
            .background(Color.yellow.opacity(0.3))
            .margins(.horizontal, 24)
            cell.accessibilityIdentifier = "cell-\(ip.item)"
            return cell
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewCompositionalLayout.list(using: UICollectionLayoutListConfiguration(appearance: .plain))
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        cv.dataSource = context.coordinator
        cv.accessibilityIdentifier = "cells"
        return cv
    }
    func updateUIView(_ uiView: UICollectionView, context: Context) {}
}

// MARK: - UIGestureRecognizerRepresentables

@available(iOS 18.0, *)
struct TapRecognizer: UIGestureRecognizerRepresentable {
    final class Coordinator { var made = 0 }
    let onTap: (CGPoint, CGPoint) -> Void
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }
    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        context.coordinator.made += 1
        print("uigr made tap \(context.coordinator.made)")
        return UITapGestureRecognizer()
    }
    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        guard recognizer.state == .ended else { return }
        onTap(context.converter.localLocation, context.converter.location(in: .global))
    }
}
@available(iOS 18.0, *)
struct PanRecognizer: UIGestureRecognizerRepresentable {
    let onPan: (CGPoint?, Bool) -> Void
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer { UIPanGestureRecognizer() }
    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        if recognizer.state == .ended { onPan(context.converter.localTranslation, context.converter.localVelocity != nil) }
    }
}

// MARK: - the window

struct Badge: View {
    var body: some View {
        Text("Rendered").font(.system(size: 20, weight: .bold)).padding(8)
            .background(Color(red: 1, green: 0.5, blue: 0)).foregroundStyle(.white)
    }
}

@available(iOS 26.0, *)
struct MainView: View {
    @State private var taps = 0
    @State private var image: UIImage?
    @State private var bag: AnyCancellable?
    var body: some View {
        VStack(spacing: 12) {
            Cells().frame(height: 220)
            if let image { Image(uiImage: image).accessibilityIdentifier("rendered") }
            Color.blue.frame(width: 120, height: 60)
                .gesture(TapRecognizer { local, global in
                    taps += 1
                    print("uigr tap \(taps) local \(Int(local.x)) \(Int(local.y)) global-minus-local \(Int(global.x - local.x)) \(Int(global.y - local.y))")
                })
                .accessibilityIdentifier("tap-target")
            Text("taps \(taps)").accessibilityIdentifier("taps")
            Color.green.frame(width: 200, height: 60)
                .gesture(PanRecognizer { t, hasVelocity in print("uigr pan \(Int(t?.x ?? -1)) \(Int(t?.y ?? -1)) velocity \(hasVelocity)") })
                .accessibilityIdentifier("pan-target")
            Button("Open second") {
                print("interop missing request nil \(UISceneSessionActivationRequest(hostingDelegateClass: HostingSceneDelegate.self, id: "missing") == nil)")
                if let r = UISceneSessionActivationRequest(hostingDelegateClass: HostingSceneDelegate.self, id: "second") {
                    UIApplication.shared.activateSceneSession(for: r)
                }
            }.accessibilityIdentifier("open-second")
        }
        .onAppear { renderImages() }
    }
    @MainActor func renderImages() {
        let r = ImageRenderer(content: Badge())
        var changes = 0
        bag = r.objectWillChange.sink { changes += 1 }
        r.scale = 2
        guard let ui = r.uiImage, let cg = r.cgImage else { print("renderer no image"); return }
        print("renderer image \(Int(ui.size.width))x\(Int(ui.size.height)) scale \(Int(ui.scale)) cg \(cg.width)x\(cg.height) changes \(changes)")
        image = ui
        let hc = UIHostingController(rootView: Badge())                  // sizingOptions: the ideal size as preferredContentSize
        hc.sizingOptions = .preferredContentSize
        hc.view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        hc.view.layoutIfNeeded()
        print("sizing preferred \(Int(hc.preferredContentSize.width))x\(Int(hc.preferredContentSize.height))")
        let pdf = NSMutableData()
        r.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(data: pdf as CFMutableData), let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil)
            draw(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
            print("renderer render size \(Int(size.width))x\(Int(size.height)) pdf \(pdf.length > 100)")
        }
    }
}
