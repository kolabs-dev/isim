// Sample: SF Symbol stand-ins on isim. UIImage(systemName:) draws isim's own substitutes (procedural glyphs and
// Adwaita icons; Apple's symbol artwork is not shipped). This app lays out a grid of common symbol names and their
// .fill / .circle / .square / .slash variants, plus SymbolConfiguration weight, scale and tint, and logs where each
// cell is so tests/ui/test_symbols.py can check the pixels.
import UIKit

/// The grid, in order. The first cell is a name no substitute exists for: the reference placeholder.
let symbolNames: [String] = [
    "isim.no.such.symbol",
    "heart", "heart.fill", "star", "star.fill", "bookmark", "bookmark.fill", "tag", "tag.fill", "flag", "flag.fill",
    "bell", "bell.fill", "paperplane", "paperplane.fill", "envelope", "envelope.fill", "phone", "phone.fill", "camera", "camera.fill",
    "photo", "photo.fill", "mic", "mic.fill", "lock", "lock.fill", "eye", "eye.fill", "trash", "trash.fill",
    "pencil", "pencil.circle.fill", "gear", "gearshape.fill", "cart", "cart.fill", "creditcard", "creditcard.fill", "house", "house.fill",
    "person", "person.fill", "person.2", "person.2.fill", "person.crop.circle", "person.crop.circle.fill", "sun.max", "sun.max.fill", "moon", "moon.fill",
    "cloud", "cloud.fill", "bolt", "bolt.fill", "flame", "flame.fill", "drop", "drop.fill", "leaf", "leaf.fill",
    "clock", "clock.fill", "calendar", "timer", "map", "map.fill", "mappin", "mappin.circle.fill", "location", "location.fill",
    "trophy", "trophy.fill", "crown", "crown.fill", "gift", "gift.fill", "gamecontroller", "gamecontroller.fill", "shield", "shield.fill",
    "hand.thumbsup", "hand.thumbsup.fill", "hand.thumbsdown", "speaker", "speaker.fill", "speaker.wave.2", "speaker.slash", "headphones", "music.note", "wifi",
    "exclamationmark", "questionmark", "checkmark", "checkmark.circle", "checkmark.circle.fill", "checkmark.square", "checkmark.square.fill", "xmark", "xmark.circle", "xmark.circle.fill",
    "plus", "plus.circle", "plus.circle.fill", "minus", "minus.circle", "minus.circle.fill", "info.circle", "info.circle.fill", "questionmark.circle", "exclamationmark.triangle.fill",
    "arrow.up", "arrow.down", "arrow.left", "arrow.right", "arrow.clockwise", "arrow.counterclockwise", "arrow.uturn.left", "arrow.uturn.right", "arrow.up.circle.fill", "arrow.triangle.2.circlepath",
    "chevron.left", "chevron.right", "chevron.up", "chevron.down", "ellipsis", "ellipsis.circle", "play", "play.fill", "pause.fill", "stop.fill",
    "forward.fill", "backward.fill", "play.circle.fill", "magnifyingglass", "line.3.horizontal", "list.bullet", "square.grid.2x2", "square.and.arrow.up", "square.and.pencil", "eye.slash",
    "battery.100", "battery.25", "sparkles", "wand.and.stars", "bell.slash", "doc", "doc.fill", "folder", "folder.fill", "book",
    "video", "video.fill", "message", "bubble.left.fill", "globe", "lock.open", "key", "power", "chart.bar.fill", "slider.horizontal.3",
    "airplane", "keyboard", "printer", "paperclip", "link", "dollarsign.circle", "a.circle", "heart.circle.fill", "star.square", "wifi.slash",
]

final class SymbolsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let cell: CGFloat = 36, cols = 10
        let x0 = (view.bounds.width - cell * CGFloat(cols)) / 2, y0: CGFloat = 70
        let config = UIImage.SymbolConfiguration(pointSize: 20)
        var report = ""
        for (i, name) in symbolNames.enumerated() {
            let frame = CGRect(x: x0 + CGFloat(i % cols) * cell, y: y0 + CGFloat(i / cols) * cell, width: cell, height: cell)
            let iv = UIImageView(image: UIImage(systemName: name, withConfiguration: config))
            iv.frame = frame; iv.contentMode = .center; iv.tintColor = .black
            view.addSubview(iv)
            report += "cell \(i) \(name) \(Int(frame.minX)) \(Int(frame.minY)) \(Int(cell))\n"
        }
        // weight, tint and scale
        let y = y0 + CGFloat((symbolNames.count + cols - 1) / cols) * cell + 16
        func place(_ image: UIImage?, _ x: CGFloat, _ tint: UIColor, _ tag: String) {
            let iv = UIImageView(image: image)
            iv.frame = CGRect(x: x, y: y, width: 48, height: 48); iv.contentMode = .center; iv.tintColor = tint
            view.addSubview(iv)
            report += "extra \(tag) \(Int(x)) \(Int(y)) 48 size \(Int(image?.size.width ?? 0))x\(Int(image?.size.height ?? 0))\n"
        }
        place(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .ultraLight)), 20, .black, "light")
        place(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .black)), 80, .black, "black")
        place(UIImage(systemName: "heart.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), 140, .systemRed, "tinted")
        place(UIImage(systemName: "star.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular, scale: .small)), 200, .black, "small")
        place(UIImage(systemName: "star.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular, scale: .large)), 260, .black, "large")
        let bold = UIImage.SymbolConfiguration(font: .systemFont(ofSize: 30, weight: .bold))
        place(UIImage(systemName: "xmark", withConfiguration: bold), 320, .black, "fontbold")
        // rendering modes: the glyph (primary layer) on its enclosure (secondary layer)
        let y2 = y + 52                                                     // (fits the iPhone 15's 852 pt)
        func mode(_ name: String, _ config: UIImage.SymbolConfiguration, _ x: CGFloat, _ tag: String) {
            let iv = UIImageView(image: UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 32).applying(config)))
            iv.frame = CGRect(x: x, y: y2, width: 44, height: 44); iv.contentMode = .center; iv.tintColor = .black
            view.addSubview(iv)
            report += "mode \(tag) \(Int(x)) \(Int(y2)) 44\n"
        }
        mode("plus.circle.fill", .preferringMonochrome(), 20, "monochrome")
        mode("plus.circle.fill", UIImage.SymbolConfiguration(hierarchicalColor: .systemBlue), 72, "hierarchical")
        mode("plus.circle.fill", UIImage.SymbolConfiguration(paletteColors: [.systemRed, .systemBlue]), 124, "palette")
        mode("plus.circle.fill", .preferringMulticolor(), 176, "multicolor")
        mode("heart.fill", .preferringMulticolor(), 228, "multicolor-heart")
        report += "symbols laid out: \(symbolNames.count)\n"
        FileHandle.standardError.write(Data(report.utf8))   // one write: the test reads it mixed with the host's log
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = SymbolsViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
