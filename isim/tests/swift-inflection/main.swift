// Automatic grammar agreement on isim (issue #351): ^[…](inflect: true) in Markdown and localized strings, number and
// gender agreement in English, Spanish, French, Italian and Portuguese, explicit morphology, terms of address,
// InflectionRule, Morphology, TermOfAddress, and the Objective-C classes (NSMorphology, NSInflectionRule, inflecting()).
import Foundation

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}
func inflect(_ markdown: String, _ lang: String, user: TermOfAddress? = nil) -> String {
    let a = (try? AttributedString(markdown: markdown, options: .init(allowsExtendedAttributes: true))) ?? AttributedString(markdown)
    return String(a.inflected(locale: Locale(identifier: lang), userTermOfAddress: user, inflectionConcepts: []).characters)
}

@main struct Main {
    static func main() {
        // the attributes from Markdown
        let parsed = try! AttributedString(markdown: "Add ^[2 apple](inflect: true) now", options: .init(allowsExtendedAttributes: true))
        let rule = parsed.runs.compactMap { $0.inflect }.first
        check(rule == .automatic, "^[…](inflect: true) sets InflectionRule.automatic")
        let explicit = try! AttributedString(markdown: "^[gato](inflect: { number: \"plural\" }, morphology: { grammaticalGender: \"masculine\" })",
                                             options: .init(allowsExtendedAttributes: true))
        if case .explicit(let m)? = explicit.runs.first?.inflect {
            check(m.number == .plural && explicit.runs.first?.morphology?.grammaticalGender == .masculine, "an explicit rule and a morphology from Markdown")
        } else { check(false, "inflect: { number: \"plural\" } is an explicit rule") }

        // number agreement
        check(inflect("Add ^[3 apple](inflect: true) to your order", "en") == "Add 3 apples to your order", "en: 3 apples")
        check(inflect("^[1 apples](inflect: true)", "en") == "1 apple", "en: 1 apple")
        check(inflect("^[2 large salad](inflect: true)", "en") == "2 large salads" && inflect("^[4 box](inflect: true)", "en") == "4 boxes" &&
              inflect("^[2 berry](inflect: true)", "en") == "2 berries" && inflect("^[3 child](inflect: true)", "en") == "3 children",
              "en: only the head noun; -es, -ies, irregular plurals")
        check(inflect("^[2 ensalada grande](inflect: true)", "es") == "2 ensaladas grandes", "es: nouns and adjectives agree (\(inflect("^[2 ensalada grande](inflect: true)", "es")))")
        check(inflect("^[2 taza de café](inflect: true)", "es") == "2 tazas de café", "es: agreement stops at a preposition")
        check(inflect("^[3 canción](inflect: true)", "es") == "3 canciones" && inflect("^[2 lápiz](inflect: true)", "es") == "2 lápices", "es: -ón, -z plurals")
        check(inflect("^[2 cheval blanc](inflect: true)", "fr") == "2 chevaux blancs" && inflect("^[1,5 kilo](inflect: true)", "fr") == "1,5 kilo",
              "fr: -al, and 1.5 is singular in French")
        check(inflect("^[2 pizza piccola](inflect: true)", "it") == "2 pizze piccole" && inflect("^[3 libro rosso](inflect: true)", "it") == "3 libri rossi", "it plurals")
        check(inflect("^[2 limão verde](inflect: true)", "pt") == "2 limões verdes" && inflect("^[2 animal](inflect: true)", "pt") == "2 animais", "pt plurals")
        check(inflect("^[apple](inflect: { number: \"plural\" })", "en") == "apples", "an explicit plural")

        // gender: the user's term of address, or an explicit morphology
        check(inflect("^[Bienvenido](inflect: true)", "es", user: .feminine) == "Bienvenida", "es: Bienvenida for a feminine term of address")
        check(inflect("^[Bienvenido](inflect: true)", "es", user: .neutral) == "Bienvenido" && inflect("^[Bienvenido](inflect: true)", "es") == "Bienvenido",
              "neutral or no term of address: unchanged")
        check(inflect("^[Bienvenu](inflect: true)", "fr", user: .feminine) == "Bienvenue", "fr: Bienvenue")
        check(inflect("^[Benvenuto](inflect: { grammaticalGender: \"feminine\" })", "it") == "Benvenuta", "it: explicit feminine")
        check(inflect("^[2 amigo](inflect: true)", "pt", user: .feminine) == "2 amigas", "pt: gender and number together")
        check(inflect("^[2 apple](inflect: true)", "de") == "2 apple" && !InflectionRule.canInflect(language: "de") && InflectionRule.canInflect(language: "es-MX"),
              "languages isim does not inflect are unchanged; canInflect(language:)")

        // localized strings and LocalizationOptions
        let localized = AttributedString(localized: "You have ^[\(5) new message](inflect: true)")
        check(String(localized.characters) == "You have 5 new messages", "AttributedString(localized:) inflects (\(String(localized.characters)))")
        let off = AttributedString(localized: "^[\(5) message](inflect: true)", options: { var o = AttributedString.LocalizationOptions(); o.inflect = false; return o }())
        check(String(off.characters) == "5 message", "LocalizationOptions.inflect = false")
        let concept = AttributedString(localized: "^[Bienvenido](inflect: true)", options: .termsOfAddressConcept([.feminine]), locale: Locale(identifier: "es"))
        check(String(concept.characters) == "Bienvenida", "termsOfAddressConcept: agreement with the given term of address")

        // the types
        var m = Morphology()
        check(m.isUnspecified, "Morphology() is unspecified")
        m.number = .plural; m.partOfSpeech = .noun
        check(!m.isUnspecified && InflectionRule(morphology: m) == .explicit(m) && Morphology.GrammaticalCase.translative.rawValue == 14, "Morphology, InflectionRule(morphology:)")
        let pronoun = Morphology.Pronoun(pronoun: "elle", morphology: { var f = Morphology(); f.grammaticalGender = .feminine; return f }())
        let custom = TermOfAddress.localized(language: Locale.Language(identifier: "fr"), pronouns: [pronoun])
        check(custom.language?.minimalIdentifier == "fr" && custom.pronouns == [pronoun] && TermOfAddress.feminine != .masculine, "TermOfAddress.localized(language:pronouns:)")
        let data = try? JSONEncoder().encode(custom)
        check(data.flatMap { try? JSONDecoder().decode(TermOfAddress.self, from: $0) } == custom, "TermOfAddress is Codable")
        check(inflect("^[Bienvenu](inflect: true)", "fr", user: custom) == "Bienvenue", "a custom term of address agrees with its pronoun's gender")

        // Objective-C: NSMorphology, NSInflectionRule, -[NSAttributedString attributedStringByInflectingString]
        let ns = NSMutableAttributedString(string: "3 cat")
        ns.addAttribute(.inflectionRule, value: NSInflectionRule.automatic, range: NSRange(location: 0, length: 5))
        let inflectedNS = ns.inflecting()
        check(inflectedNS.string == "3 cats" && inflectedNS.attribute(.inflectionRule, at: 0, effectiveRange: nil) == nil, "NSAttributedString.inflecting() (\(inflectedNS.string))")
        let nm = NSMorphology()
        nm.number = .plural
        let explicitNS = NSMutableAttributedString(string: "dog")
        explicitNS.addAttribute(.inflectionRule, value: NSInflectionRuleExplicit(morphology: nm), range: NSRange(location: 0, length: 3))
        check(explicitNS.inflecting().string == "dogs" && NSInflectionRule.canInflectLanguage("it") && !nm.isUnspecified, "NSInflectionRuleExplicit")
        let bridged = NSAttributedString(AttributedString(localized: "plain"))
        check(bridged.string == "plain", "a localized string without markup")
        let round = NSAttributedString(parsed)
        check(round.attribute(.inflectionRule, at: 4, effectiveRange: nil) is NSInflectionRule, "the inflect attribute bridges to NSInflectionRule")

        print("inflection test: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
