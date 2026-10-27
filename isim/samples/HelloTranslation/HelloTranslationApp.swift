// HelloTranslation ("Phrasebook"): Translation. LanguageAvailability (the supported languages, a pair's status, the
// status of a text's detected language); a view's translationTask translating a batch of phrases into Spanish
// (translations(from:), translate(batch:), an attributed string) and running again after the configuration's
// invalidate(); the errors (nothing to translate, an unsupported pair or source language); on iOS 26 a session for
// installed languages (isReady, canRequestDownloads, cancel); and translationPresentation, the system's translation
// sheet, replacing a Spanish phrase with its translation. Each step logs a "HelloTranslation:" line.
import SwiftUI
import Translation

func log(_ s: String) { NSLog("HelloTranslation: %@", s) }

@main
struct HelloTranslationApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

let phrases = ["Hello, how are you?", "Good morning", "Thank you"]

struct ContentView: View {
    @State private var phrase = "Hola, ¿cómo estás?"
    @State private var showTranslation = false
    var body: some View {
        NavigationStack {
            List {
                Section("Phrase") {
                    Text(phrase).accessibilityIdentifier("phrase")
                    Button("Translate") { showTranslation = true }
                        .accessibilityIdentifier("present")
                        .modifier(PresentTranslation(isPresented: $showTranslation, text: phrase) { translated in
                            phrase = translated
                            log("replaced with '\(translated)'")
                        })
                }
                if #available(iOS 18.0, *) { SpanishPhrases() }
            }
            .navigationTitle("Phrasebook")
        }
        .task {
            if #available(iOS 18.0, *) { await Checks.run() } else { log("translation sessions need iOS 18") }
            log("done")
        }
    }
}

/// translationPresentation (iOS 17.4)
struct PresentTranslation: ViewModifier {
    let isPresented: Binding<Bool>
    let text: String
    let replace: (String) -> Void
    func body(content: Content) -> some View {
        if #available(iOS 17.4, *) {
            content.translationPresentation(isPresented: isPresented, text: text, replacementAction: replace)
        } else {
            content
        }
    }
}

/// the phrases, translated into Spanish by the view's translation task
@available(iOS 18.0, *)
struct SpanishPhrases: View {
    @State private var configuration = TranslationSession.Configuration(source: Locale.Language(identifier: "en"), target: Locale.Language(identifier: "es"))
    @State private var spanish: [String] = []
    @State private var runs = 0
    var body: some View {
        Section("Spanish") {
            ForEach(Array(spanish.enumerated()), id: \.offset) { i, s in Text(s).accessibilityIdentifier("spanish-\(i)") }
            Button("Translate Again") { configuration.invalidate() }.accessibilityIdentifier("again")
        }
        .translationTask(configuration) { session in
            runs += 1
            do {
                let requests = phrases.enumerated().map { TranslationSession.Request(sourceText: $1, clientIdentifier: "p\($0)") }
                let responses = try await session.translations(from: requests)
                spanish = responses.map(\.targetText)
                log("task run \(runs) version \(configuration.version): \(responses.map(\.targetText)) ids \(responses.compactMap(\.clientIdentifier)) " +
                    "\(responses.first.map { "\($0.sourceLanguage.minimalIdentifier)->\($0.targetLanguage.minimalIdentifier)" } ?? "")")
                var streamed: [String] = []
                for try await r in session.translate(batch: requests) { streamed.append(r.targetText) }
                log("batch \(streamed.count) in order \(streamed == spanish)")
                let attributed = try await session.translate(AttributedString("Thank you"))
                log("attributed '\(attributed.targetText)' source attributed \(attributed.attributedSourceText != nil) target \(attributed.attributedTargetText.map { String($0.characters) } ?? "nil")")
                if #available(iOS 26.0, *) { log("task session canRequestDownloads \(session.canRequestDownloads) ready \(session.isReady)") }
            } catch {
                log("task run \(runs) error \(error)")
            }
        }
    }
}

@available(iOS 18.0, *)
enum Checks {
    static func name(_ e: Error) -> String { (e as? TranslationError).map { "\($0)".components(separatedBy: ":").first! } ?? "\(e)" }
    static func run() async {
        let availability = LanguageAvailability()
        let en = Locale.Language(identifier: "en"), es = Locale.Language(identifier: "es"), de = Locale.Language(identifier: "de")
        let it = Locale.Language(identifier: "it")
        log("supported \(availability.supportedLanguages.map(\.minimalIdentifier))")
        log("status en->es \(await availability.status(from: en, to: es)) en->de \(await availability.status(from: en, to: de)) " +
            "es->en \(await availability.status(from: es, to: en)) en->en \(await availability.status(from: en, to: en))")
        do { log("detected status \(try await availability.status(for: "Hola amigos", to: en))") } catch { log("detected status error \(name(error))") }

        /* iOS 26: sessions outside a view (for installed languages); the errors */
        guard #available(iOS 26.0, *) else { return }
        let session = TranslationSession(installedSource: en, target: de)
        do { _ = try await session.translate("Hello") } catch { log("en->de \(name(error)): \(error.localizedDescription)") }
        do { _ = try await TranslationSession(installedSource: it, target: en).translate("Ciao") } catch { log("it->en \(name(error))") }
        do { _ = try await TranslationSession(installedSource: en, target: es).translate("   ") } catch { log("empty \(name(error))") }
        do {
            try await TranslationSession(installedSource: en, target: es).prepareTranslation()
            log("prepare en->es ok")
        } catch { log("prepare en->es \(name(error))") }
        do {
            _ = try await session.translate("Hello")
        } catch TranslationError.unsupportedLanguagePairing {
            log("matched unsupportedLanguagePairing")
        } catch { log("not matched \(error)") }

        do {
            let installed = TranslationSession(installedSource: es, target: en)
            log("installed ready \(installed.isReady) canRequestDownloads \(installed.canRequestDownloads) " +
                "de ready \(TranslationSession(installedSource: en, target: de).isReady)")
            do { log("installed '\(try await installed.translate("Gracias").targetText)'") } catch { log("installed error \(name(error))") }
            installed.cancel()
            do { _ = try await installed.translate("Gracias") } catch { log("after cancel \(name(error)) \(TranslationError.alreadyCancelled ~= error)") }
        }
    }
}
