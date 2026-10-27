// Sample: an Xcode project with iMessage targets and a watch app, built by `isim build` (issue #341): a sticker pack
// (Stickers.xcstickers, embedded in PlugIns/ with no executable), a Messages extension (embedded in PlugIns/) and a
// watchOS app, which isim does not build (it runs iOS apps). The app lists what it embeds ("stk ..." lines).
import SwiftUI

@main
struct HelloStickersApp: App {
    var body: some Scene { WindowGroup { PlugInsList() } }
}

struct PlugInsList: View {
    let plugIns: [String] = {
        let dir = Bundle.main.builtInPlugInsURL
        return ((dir.flatMap { try? FileManager.default.contentsOfDirectory(atPath: $0.path) }) ?? []).sorted()
    }()
    var body: some View {
        List(plugIns, id: \.self) { Text($0) }
            .onAppear {
                print("stk plugins \(plugIns.joined(separator: ","))")
                for p in plugIns {
                    let b = Bundle(url: Bundle.main.builtInPlugInsURL!.appendingPathComponent(p))
                    let ext = b?.infoDictionary?["NSExtension"] as? [String: Any]
                    print("stk \(p) point \(ext?["NSExtensionPointIdentifier"] as? String ?? "none") executable \(b?.executableURL != nil)")
                }
                print("stk watch \(FileManager.default.fileExists(atPath: Bundle.main.bundlePath + "/Watch"))")
            }
    }
}
