// Sample: Xcode's generated asset symbols (issue #210). `isim build` generates GeneratedAssetSymbols.swift / .h from
// Assets.xcassets, as Xcode does: ColorResource.accent / .brandBlue, ImageResource.logo / .hero, and (with
// ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS) UIColor.brandBlue, UIImage.logo, Color.brandBlue,
// ShapeStyle .brandBlue. Each check logs an "asym" line; Objective-C reads the ACColorName / ACImageName constants.
import SwiftUI
import UIKit

func log(_ s: String) { print("asym \(s)") }

func rgb(_ c: UIColor, dark: Bool = false) -> String {
    let r = c.resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
    var x: CGFloat = 0, y: CGFloat = 0, z: CGFloat = 0, a: CGFloat = 0
    r.getRed(&x, green: &y, blue: &z, alpha: &a)
    return "\(Int((x * 255).rounded())),\(Int((y * 255).rounded())),\(Int((z * 255).rounded()))"
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(.logo).accessibilityIdentifier("logo")
            Image(.hero).accessibilityIdentifier("hero")
            Text("Brand blue").font(.title).foregroundStyle(.brandBlue).accessibilityIdentifier("brand-text")
            RoundedRectangle(cornerRadius: 12).fill(Color(.brandBlue)).frame(width: 200, height: 60).accessibilityIdentifier("brand-box")
            Rectangle().fill(Color.accent).frame(width: 200, height: 20).accessibilityIdentifier("accent-box")
            Image(uiImage: .logo).accessibilityIdentifier("uikit-logo")
        }
        .onAppear { report() }
    }
}

func report() {
    log("ColorResource.brandBlue light=\(rgb(UIColor(resource: .brandBlue))) dark=\(rgb(UIColor(resource: .brandBlue), dark: true))")
    log("UIColor.brandBlue=\(rgb(.brandBlue)) UIColor.accent=\(rgb(.accent))")
    log("UIImage(resource: .logo) size=\(Int(UIImage(resource: .logo).size.width))x\(Int(UIImage(resource: .logo).size.height))")
    log("UIImage.hero size=\(Int(UIImage.hero.size.width))x\(Int(UIImage.hero.size.height))")
    log("missing size=\(Int(UIImage(resource: ImageResource(name: "Nope", bundle: .main)).size.width))")
    log("objc \(HelloObjCAssetNames())")
}

@main
struct HelloAssetSymbolsApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
