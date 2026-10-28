// HelloImagePlayground ("Sticker Shop"): Image Playground and Visual Intelligence. Image Playground's availability
// (ImagePlaygroundViewController.isAvailable, supportsImagePlayground), ImageCreator (it throws: no image model on
// isim), concepts, styles and options; the SwiftUI sheet and the view controller, which say Image Playground is
// unavailable and end as a cancellation; and on iOS 26 a Visual Intelligence query (IntentValueQuery over
// SemanticContentDescriptor) that finds stickers by the labels the `visualintelligence` script command gives. Each
// step logs a "HelloImagePlayground:" line.
import SwiftUI
import UIKit
import AppIntents
import ImagePlayground
import VisualIntelligence

func log(_ s: String) { NSLog("HelloImagePlayground: %@", s) }

@main
struct HelloImagePlaygroundApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

struct Sticker: Identifiable { let id: String, name: String, tags: [String] }
let stickers = [Sticker(id: "cat", name: "Sleepy Cat", tags: ["cat", "animal", "pet"]),
                Sticker(id: "dog", name: "Happy Dog", tags: ["dog", "animal", "pet"]),
                Sticker(id: "tree", name: "Pine Tree", tags: ["tree", "plant", "forest"])]

/// supportsImagePlayground (iOS 18.1)
@available(iOS 18.1, *)
struct SupportLabel: View {
    @Environment(\.supportsImagePlayground) private var supports
    var body: some View {
        Text(supports ? "Available" : "Unavailable").accessibilityIdentifier("support")
            .onAppear { log("supports \(supports)") }
    }
}

struct ContentView: View {
    @State private var showSheet = false
    var body: some View {
        NavigationStack {
            List {
                Section("Image Playground") {
                    if #available(iOS 18.1, *) { SupportLabel() }
                    Button("Create a Sticker") { showSheet = true }
                        .accessibilityIdentifier("sheet")
                        .modifier(PlaygroundSheet(isPresented: $showSheet))
                    Button("Open Image Playground") { Checks.presentController() }.accessibilityIdentifier("controller")
                }
                Section("Stickers") {
                    ForEach(stickers) { Text($0.name) }
                }
            }
            .navigationTitle("Sticker Shop")
        }
        .task {
            if #available(iOS 18.1, *) { await Checks.run() } else { log("image playground needs iOS 18.1") }
            log("done")
        }
    }
}

/// imagePlaygroundSheet (iOS 18.1)
struct PlaygroundSheet: ViewModifier {
    let isPresented: Binding<Bool>
    func body(content: Content) -> some View {
        if #available(iOS 18.1, *) {
            content.imagePlaygroundSheet(isPresented: isPresented, concept: "a cat wearing a hat",
                                         onCompletion: { url in log("sheet created \(url.lastPathComponent)") },
                                         onCancellation: { log("sheet cancelled") })
        } else {
            content
        }
    }
}

@available(iOS 18.1, *)
final class ControllerDelegate: NSObject, ImagePlaygroundViewController.Delegate {
    func imagePlaygroundViewController(_ c: ImagePlaygroundViewController, didCreateImageAt imageURL: URL) { log("controller created \(imageURL.lastPathComponent)") }
    func imagePlaygroundViewControllerDidCancel(_ c: ImagePlaygroundViewController) { log("controller cancelled") }
}

enum Checks {
    nonisolated(unsafe) static var delegate: AnyObject?
    @MainActor static func presentController() {
        guard #available(iOS 18.1, *) else { return }
        let c = ImagePlaygroundViewController()
        let d = ControllerDelegate()
        delegate = d
        c.delegate = d
        c.concepts = [.text("a dog on a skateboard")]
        c.selectedGenerationStyle = .sketch
        let root = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first
        root?.present(c, animated: true)
    }
    @available(iOS 18.1, *)
    @MainActor static func run() async {
        log("available \(ImagePlaygroundViewController.isAvailable)")
        let concepts: [ImagePlaygroundConcept] = [.text("a cat"), .extracted(from: "A long story about a cat in a hat.", title: "Story")]
        log("concepts \(concepts.count) styles \(ImagePlaygroundStyle.animation.id),\(ImagePlaygroundStyle.illustration.id),\(ImagePlaygroundStyle.sketch.id)")
        if #available(iOS 18.4, *) {
            log("all styles \(ImagePlaygroundStyle.all.map(\.id)) emoji \(ImagePlaygroundStyle.emoji.id)")
            do {
                let creator = try await ImageCreator()
                log("creator styles \(creator.availableStyles.count)")
            } catch let e as ImageCreator.Error {
                log("creator error \(e) \(e.localizedDescription)")
            } catch { log("creator other \(error)") }
            let glyph = NSAdaptiveImageGlyph(imageContent: Data([1, 2, 3]))
            log("glyph \(glyph.contentIdentifier.count == 16) type \(NSAdaptiveImageGlyph.contentType.identifier)")
        }
        if #available(iOS 26.4, *) {
            var o = ImagePlaygroundOptions()
            o.creationVariety = .high
            o.sizeSpecification = .closest(to: CGSize(width: 512, height: 512))
            log("options variety high \(o.creationVariety == .high)")
        }
    }
}

// MARK: - Visual Intelligence (iOS 26)

struct StickerEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Sticker" }
    static var defaultQuery: StickerQuery { StickerQuery() }
    let id: String
    let name: String
    let tags: [String]
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)", subtitle: "\(tags.joined(separator: ", "))") }
    init(_ s: Sticker) { id = s.id; name = s.name; tags = s.tags }
}
struct StickerQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [StickerEntity] {
        stickers.filter { identifiers.contains($0.id) }.map(StickerEntity.init)
    }
    func suggestedEntities() async throws -> [StickerEntity] { stickers.map(StickerEntity.init) }
}
/// opens a sticker: what Visual Intelligence runs when its result is chosen
struct OpenStickerIntent: OpenIntent {
    static var title: LocalizedStringResource { "Open Sticker" }
    @Parameter(title: "Sticker") var target: StickerEntity
    func perform() async throws -> some IntentResult {
        log("open sticker \(target.name)")
        return .result()
    }
}
/// the stickers whose tags match what Visual Intelligence saw
@available(iOS 26.0, *)
struct StickerVisualSearch: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws -> [StickerEntity] {
        log("visual search \(input.labels)")
        let wanted = Set(input.labels.map { $0.lowercased() })
        return stickers.filter { !wanted.isDisjoint(with: $0.tags) }.map(StickerEntity.init)
    }
}
