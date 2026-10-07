// isim NaturalLanguage (self-authored, iOS API names): NLTokenizer, NLLanguageRecognizer, NLTagger, NLLanguage, NLTag.
// Adapted: Apple's statistical models are not available, so isim uses its own rules:
//   - tokenization by Unicode character classes (words keep inner apostrophes, hyphens and dots between digits;
//     each Han/Hiragana/Katakana/Thai character is its own word); sentences end at . ! ? 。！？ (followed by space or
//     the end), with common English abbreviations kept; paragraphs at line breaks.
//   - language recognition: the writing system decides non-Latin scripts; Latin-script text is scored against
//     stop-word lists and letters of 14 languages (en, fr, de, es, it, pt, nl, sv, da, nb, fi, pl, tr, ro).
//   - tagging: tokenType, language, script; lexicalClass from a small English lexicon and suffix rules (heuristic);
//     sentimentScore from a small English word list (-1...1). nameType, lemma and NLEmbedding / NLModel / NLGazetteer
//     are not available (nameType gives nil tags; NLEmbedding/NLModel return nil / throw).
import Foundation

public struct NLLanguage: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { rawValue = value }
    public static let undetermined = NLLanguage("und")
    public static let amharic = NLLanguage("am"), arabic = NLLanguage("ar"), armenian = NLLanguage("hy"), bengali = NLLanguage("bn")
    public static let bulgarian = NLLanguage("bg"), burmese = NLLanguage("my"), catalan = NLLanguage("ca"), cherokee = NLLanguage("chr")
    public static let croatian = NLLanguage("hr"), czech = NLLanguage("cs"), danish = NLLanguage("da"), dutch = NLLanguage("nl")
    public static let english = NLLanguage("en"), finnish = NLLanguage("fi"), french = NLLanguage("fr"), georgian = NLLanguage("ka")
    public static let german = NLLanguage("de"), greek = NLLanguage("el"), gujarati = NLLanguage("gu"), hebrew = NLLanguage("he")
    public static let hindi = NLLanguage("hi"), hungarian = NLLanguage("hu"), icelandic = NLLanguage("is"), indonesian = NLLanguage("id")
    public static let italian = NLLanguage("it"), japanese = NLLanguage("ja"), kannada = NLLanguage("kn"), kazakh = NLLanguage("kk")
    public static let khmer = NLLanguage("km"), korean = NLLanguage("ko"), lao = NLLanguage("lo"), malay = NLLanguage("ms")
    public static let malayalam = NLLanguage("ml"), marathi = NLLanguage("mr"), mongolian = NLLanguage("mn"), norwegian = NLLanguage("nb")
    public static let oriya = NLLanguage("or"), persian = NLLanguage("fa"), polish = NLLanguage("pl"), portuguese = NLLanguage("pt")
    public static let punjabi = NLLanguage("pa"), romanian = NLLanguage("ro"), russian = NLLanguage("ru"), simplifiedChinese = NLLanguage("zh-Hans")
    public static let sinhalese = NLLanguage("si"), slovak = NLLanguage("sk"), spanish = NLLanguage("es"), swedish = NLLanguage("sv")
    public static let tamil = NLLanguage("ta"), telugu = NLLanguage("te"), thai = NLLanguage("th"), tibetan = NLLanguage("bo")
    public static let traditionalChinese = NLLanguage("zh-Hant"), turkish = NLLanguage("tr"), ukrainian = NLLanguage("uk"), urdu = NLLanguage("ur")
    public static let vietnamese = NLLanguage("vi"), kurdish = NLLanguage("ku"), lithuanian = NLLanguage("lt"), latvian = NLLanguage("lv")
    public static let slovenian = NLLanguage("sl"), estonian = NLLanguage("et"), serbian = NLLanguage("sr"), tagalog = NLLanguage("tl")
}

public enum NLTokenUnit: Int, Sendable { case word = 0, sentence = 1, paragraph = 2, document = 3 }

public struct NLTag: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    // token types
    public static let word = NLTag("Word"), punctuation = NLTag("Punctuation"), whitespace = NLTag("Whitespace"), other = NLTag("Other")
    // lexical classes
    public static let noun = NLTag("Noun"), verb = NLTag("Verb"), adjective = NLTag("Adjective"), adverb = NLTag("Adverb"), pronoun = NLTag("Pronoun")
    public static let determiner = NLTag("Determiner"), particle = NLTag("Particle"), preposition = NLTag("Preposition"), number = NLTag("Number")
    public static let conjunction = NLTag("Conjunction"), interjection = NLTag("Interjection"), classifier = NLTag("Classifier"), idiom = NLTag("Idiom")
    public static let otherWord = NLTag("OtherWord"), sentenceTerminator = NLTag("SentenceTerminator"), openQuote = NLTag("OpenQuote")
    public static let closeQuote = NLTag("CloseQuote"), openParenthesis = NLTag("OpenParenthesis"), closeParenthesis = NLTag("CloseParenthesis")
    public static let wordJoiner = NLTag("WordJoiner"), dash = NLTag("Dash"), otherPunctuation = NLTag("OtherPunctuation")
    public static let paragraphBreak = NLTag("ParagraphBreak"), otherWhitespace = NLTag("OtherWhitespace")
    // names
    public static let personalName = NLTag("PersonalName"), placeName = NLTag("PlaceName"), organizationName = NLTag("OrganizationName")
}
public struct NLTagScheme: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let tokenType = NLTagScheme("TokenType"), lexicalClass = NLTagScheme("LexicalClass"), nameType = NLTagScheme("NameType")
    public static let nameTypeOrLexicalClass = NLTagScheme("NameTypeOrLexicalClass"), lemma = NLTagScheme("Lemma"), language = NLTagScheme("Language")
    public static let script = NLTagScheme("Script"), sentimentScore = NLTagScheme("SentimentScore")
}

// MARK: - tokenization

enum _NL {
    enum Kind { case letter, digit, ideograph, space, newline, punct }
    static func kind(_ c: Character) -> Kind {
        guard let u = c.unicodeScalars.first else { return .punct }
        if c == "\n" || c == "\r" || c == "\r\n" || u.value == 0x2029 { return .newline }
        if c.isWhitespace { return .space }
        let v = u.value
        if (0x3040...0x30FF).contains(v) || (0x3400...0x9FFF).contains(v) || (0xF900...0xFAFF).contains(v) || (0x0E00...0x0E7F).contains(v) { return .ideograph }
        if c.isNumber { return .digit }
        if c.isLetter || u.properties.generalCategory == .nonspacingMark || u.properties.generalCategory == .spacingMark { return .letter }
        return .punct
    }
    static func words(_ s: String, _ r: Range<String.Index>) -> [Range<String.Index>] {
        var out: [Range<String.Index>] = []
        var i = r.lowerBound
        while i < r.upperBound {
            let k = kind(s[i])
            if k == .ideograph { out.append(i..<s.index(after: i)); i = s.index(after: i); continue }
            guard k == .letter || k == .digit else { i = s.index(after: i); continue }
            let start = i
            i = s.index(after: i)
            while i < r.upperBound {
                let c = s[i], kc = kind(c)
                if kc == .letter || kc == .digit { i = s.index(after: i); continue }
                // inner joiners: don't, e-mail, 3.14, 1,000
                if "'’-.,".contains(c), s.index(after: i) < r.upperBound {
                    let n = s[s.index(after: i)], kn = kind(n)
                    let prev = s[s.index(before: i)]
                    let ok = (c == "." || c == ",") ? (kind(prev) == .digit && kn == .digit) : (kn == .letter)
                    if ok { i = s.index(after: i); continue }
                }
                break
            }
            out.append(start..<i)
        }
        return out
    }
    static let abbreviations: Set<String> = ["mr", "mrs", "ms", "dr", "prof", "sr", "jr", "st", "vs", "etc", "e.g", "i.e", "inc", "ltd", "co", "no", "fig", "approx"]
    static func sentences(_ s: String, _ r: Range<String.Index>) -> [Range<String.Index>] {
        var out: [Range<String.Index>] = []
        var start = r.lowerBound
        var i = r.lowerBound
        func skipSpace(_ j: String.Index) -> String.Index { var j = j; while j < r.upperBound && s[j].isWhitespace && kind(s[j]) != .newline { j = s.index(after: j) }; return j }
        while i < r.upperBound {
            let c = s[i]
            if kind(c) == .newline {
                if s[start..<i].contains(where: { !$0.isWhitespace }) { out.append(start..<i) }
                i = s.index(after: i); start = i; continue
            }
            if ".!?。！？…".contains(c) {
                var j = s.index(after: i)
                while j < r.upperBound, ".!?。！？…\"'”’)".contains(s[j]) { j = s.index(after: j) }
                let ends = j == r.upperBound || s[j].isWhitespace || "。！？".contains(c)
                if ends && c == "." {
                    let w = words(s, start..<i).last.map { String(s[$0]).lowercased() } ?? ""
                    if abbreviations.contains(w) || (w.count == 1 && w.first!.isLetter && w.first!.isUppercase == false && false) { i = j; continue }
                }
                if ends {
                    let e = skipSpace(j)
                    out.append(start..<e)
                    start = e; i = e; continue
                }
                i = j; continue
            }
            i = s.index(after: i)
        }
        if start < r.upperBound, s[start..<r.upperBound].contains(where: { !$0.isWhitespace }) { out.append(start..<r.upperBound) }
        return out
    }
    static func paragraphs(_ s: String, _ r: Range<String.Index>) -> [Range<String.Index>] {
        var out: [Range<String.Index>] = []
        var start = r.lowerBound, i = r.lowerBound
        while i < r.upperBound {
            if kind(s[i]) == .newline {
                let e = s.index(after: i)
                if s[start..<i].contains(where: { !$0.isWhitespace }) { out.append(start..<e) }
                start = e
            }
            i = s.index(after: i)
        }
        if start < r.upperBound, s[start..<r.upperBound].contains(where: { !$0.isWhitespace }) { out.append(start..<r.upperBound) }
        return out
    }
    static func tokens(_ s: String, _ r: Range<String.Index>, _ unit: NLTokenUnit) -> [Range<String.Index>] {
        switch unit {
        case .word: return words(s, r)
        case .sentence: return sentences(s, r)
        case .paragraph: return paragraphs(s, r)
        case .document: return r.isEmpty ? [] : [r]
        }
    }

    // MARK: language
    static let stopwords: [String: Set<String>] = [
        "en": ["the", "and", "is", "are", "of", "to", "in", "that", "it", "with", "for", "this", "was", "you", "be", "on", "have", "not", "what", "where", "how", "a", "an", "i", "we", "they", "he", "she", "my", "your", "will", "can", "do", "from", "at", "by"],
        "fr": ["le", "la", "les", "et", "est", "un", "une", "des", "du", "de", "que", "qui", "dans", "pour", "pas", "sur", "avec", "ce", "il", "elle", "nous", "vous", "je", "au", "aux", "mais", "ou", "où", "sont", "bonjour", "merci", "très"],
        "de": ["der", "die", "das", "und", "ist", "nicht", "ein", "eine", "mit", "den", "dem", "zu", "von", "ich", "sie", "es", "wir", "auf", "für", "auch", "sich", "wie", "wo", "was", "heute", "sehr", "danke", "ihr"],
        "es": ["el", "la", "los", "las", "y", "es", "un", "una", "de", "que", "en", "por", "con", "para", "no", "se", "su", "del", "al", "lo", "como", "pero", "muy", "hola", "gracias", "está", "dónde", "qué", "yo", "tú"],
        "it": ["il", "lo", "la", "gli", "le", "e", "è", "un", "una", "di", "che", "in", "per", "con", "non", "si", "del", "della", "sono", "ciao", "grazie", "molto", "dove", "come", "anche", "io", "tu"],
        "pt": ["o", "a", "os", "as", "e", "é", "um", "uma", "de", "que", "em", "por", "com", "para", "não", "se", "do", "da", "dos", "das", "no", "na", "muito", "obrigado", "olá", "onde", "você", "eu", "está", "são"],
        "nl": ["de", "het", "een", "en", "is", "van", "in", "dat", "niet", "met", "op", "voor", "zijn", "je", "ik", "we", "wij", "ze", "er", "maar", "ook", "waar", "hoe", "dank", "goed", "heel"],
        "sv": ["och", "är", "en", "ett", "att", "det", "som", "på", "för", "med", "inte", "jag", "du", "vi", "de", "har", "av", "till", "var", "hur", "tack", "mycket", "hej"],
        "da": ["og", "er", "en", "et", "at", "det", "som", "på", "for", "med", "ikke", "jeg", "du", "vi", "de", "har", "af", "til", "hvor", "hvordan", "tak", "meget", "hej"],
        "nb": ["og", "er", "en", "et", "å", "det", "som", "på", "for", "med", "ikke", "jeg", "du", "vi", "de", "har", "av", "til", "hvor", "hvordan", "takk", "veldig", "hei"],
        "fi": ["ja", "on", "ei", "se", "että", "hän", "minä", "sinä", "me", "he", "olen", "kuin", "mutta", "tämä", "kiitos", "hyvää", "missä", "miten", "paljon"],
        "pl": ["i", "w", "jest", "nie", "się", "na", "że", "to", "z", "do", "jak", "ale", "czy", "dzień", "dobry", "dziękuję", "bardzo", "gdzie", "ja", "ty", "my"],
        "tr": ["ve", "bir", "bu", "da", "de", "ne", "için", "ile", "çok", "ben", "sen", "biz", "merhaba", "teşekkürler", "nerede", "nasıl", "değil", "var", "yok"],
        "ro": ["și", "este", "un", "o", "de", "la", "în", "nu", "cu", "pe", "că", "care", "mulțumesc", "bună", "foarte", "unde", "eu", "tu"],
    ]
    static let letters: [String: String] = ["fr": "àâçèéêëîïôœùûü", "de": "äöüß", "es": "ñáíóúü¿¡", "it": "àèéìòù", "pt": "ãõçáâêíóôú",
                                            "sv": "åäö", "da": "æøå", "nb": "æøå", "fi": "äö", "pl": "ąćęłńóśźż", "tr": "çğışöü", "ro": "ăâîșț", "nl": "ĳ"]
    /// probabilities per language (sums to 1), highest first
    static func hypotheses(_ text: String, constraints: [NLLanguage], hints: [NLLanguage: Double]) -> [(NLLanguage, Double)] {
        var scripts: [String: Int] = [:], latin = 0
        for u in text.unicodeScalars {
            let v = u.value
            let s: String?
            switch v {
            case 0x0041...0x024F where u.properties.isAlphabetic: latin += 1; s = nil
            case 0x0370...0x03FF: s = "el"
            case 0x0400...0x04FF: s = "ru"
            case 0x0530...0x058F: s = "hy"
            case 0x0590...0x05FF: s = "he"
            case 0x0600...0x06FF: s = "ar"
            case 0x0900...0x097F: s = "hi"
            case 0x0980...0x09FF: s = "bn"
            case 0x0B80...0x0BFF: s = "ta"
            case 0x0E00...0x0E7F: s = "th"
            case 0x10A0...0x10FF: s = "ka"
            case 0x3040...0x30FF: s = "ja"
            case 0xAC00...0xD7AF, 0x1100...0x11FF: s = "ko"
            case 0x4E00...0x9FFF, 0x3400...0x4DBF: s = "zh-Hans"
            default: s = nil
            }
            if let s { scripts[s, default: 0] += 1 }
        }
        var scores: [String: Double] = [:]
        if let (top, n) = scripts.max(by: { $0.value < $1.value }), n > latin {
            var lang = top
            if top == "zh-Hans" && (scripts["ja"] ?? 0) > 0 { lang = "ja" }          // kana present: Japanese
            if top == "ru" && text.unicodeScalars.contains(where: { "ієїґ".unicodeScalars.contains($0) }) { lang = "uk" }
            if top == "zh-Hans" && text.contains(where: { "們這個來說時為國學".contains($0) }) { lang = "zh-Hant" }
            scores[lang] = 1
        } else if latin > 0 {
            let lower = text.lowercased()
            let ws = words(lower, lower.startIndex..<lower.endIndex).map { String(lower[$0]) }
            for (lang, set) in stopwords {
                var sc = 0.0
                for w in ws where set.contains(w) { sc += 1 }
                for ch in letters[lang] ?? "" { sc += 0.6 * Double(lower.filter { $0 == ch }.count) }
                scores[lang] = sc
            }
            if lower.contains("ß") { scores["de", default: 0] += 2 }
            if scores.values.allSatisfy({ $0 == 0 }) { scores["en"] = 0.1 }
        }
        for (l, w) in hints { scores[l.rawValue, default: 0] *= (1 + w) }
        if !constraints.isEmpty { scores = scores.filter { k, _ in constraints.contains(NLLanguage(k)) } }
        let total = scores.values.reduce(0, +)
        guard total > 0 else { return [] }
        return scores.filter { $0.value > 0 }.map { (NLLanguage($0.key), $0.value / total) }.sorted { $0.1 > $1.1 }
    }
    static func script(_ text: String) -> String {
        for u in text.unicodeScalars where u.properties.isAlphabetic {
            switch u.value {
            case 0x0370...0x03FF: return "Grek"
            case 0x0400...0x04FF: return "Cyrl"
            case 0x0590...0x05FF: return "Hebr"
            case 0x0600...0x06FF: return "Arab"
            case 0x0900...0x097F: return "Deva"
            case 0x0E00...0x0E7F: return "Thai"
            case 0x3040...0x30FF: return "Jpan"
            case 0xAC00...0xD7AF: return "Kore"
            case 0x4E00...0x9FFF: return "Hani"
            default: return "Latn"
            }
        }
        return "Zyyy"
    }

    // MARK: English lexical classes (heuristic)
    static let lexicon: [String: NLTag] = {
        var d: [String: NLTag] = [:]
        for w in ["the", "a", "an", "this", "that", "these", "those", "every", "each", "some", "any", "no", "my", "your", "his", "her", "its", "our", "their"] { d[w] = .determiner }
        for w in ["i", "you", "he", "she", "it", "we", "they", "me", "him", "us", "them", "who", "whom", "what", "which", "myself", "yourself", "something", "nothing", "everyone"] { d[w] = .pronoun }
        for w in ["in", "on", "at", "by", "for", "with", "about", "against", "between", "into", "through", "during", "before", "after", "above", "below", "to", "from", "up", "down", "of", "off", "over", "under", "near", "across"] { d[w] = .preposition }
        for w in ["and", "or", "but", "nor", "so", "yet", "because", "although", "while", "if", "unless", "since", "whether"] { d[w] = .conjunction }
        for w in ["is", "am", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did", "will", "would", "shall", "should", "can", "could", "may", "might", "must",
                  "go", "goes", "went", "gone", "get", "got", "make", "made", "say", "said", "see", "saw", "seen", "know", "knew", "think", "thought", "take", "took", "come", "came",
                  "want", "use", "find", "give", "tell", "work", "call", "try", "ask", "need", "feel", "become", "leave", "put", "mean", "keep", "let", "begin", "seem", "help", "show",
                  "hear", "play", "run", "ran", "move", "live", "believe", "bring", "happen", "write", "sit", "stand", "lose", "pay", "meet", "include", "continue", "set", "learn",
                  "change", "lead", "understand", "watch", "follow", "stop", "create", "speak", "read", "spend", "grow", "open", "walk", "win", "teach", "offer", "remember", "love",
                  "consider", "appear", "buy", "wait", "serve", "die", "send", "build", "stay", "fall", "cut", "reach", "kill", "raise", "pass", "sell", "decide", "return", "explain",
                  "hope", "develop", "carry", "break", "receive", "agree", "support", "hit", "produce", "eat", "ate", "cover", "catch", "draw", "choose", "like", "jumps", "jump", "sleeps", "sleep"] { d[w] = .verb }
        for w in ["not", "very", "too", "also", "just", "only", "now", "then", "here", "there", "always", "never", "often", "sometimes", "soon", "again", "already", "still", "almost", "quite", "really", "well"] { d[w] = .adverb }
        for w in ["good", "new", "first", "last", "long", "great", "little", "own", "other", "old", "right", "big", "high", "different", "small", "large", "next", "early", "young", "important",
                  "few", "public", "bad", "same", "able", "quick", "brown", "lazy", "happy", "sad", "red", "green", "blue", "black", "white", "beautiful", "hot", "cold", "fast", "slow"] { d[w] = .adjective }
        for w in ["oh", "wow", "hey", "hello", "hi", "ouch", "oops", "yes", "please", "thanks"] { d[w] = .interjection }
        for w in ["'s", "’s"] { d[w] = .particle }
        return d
    }()
    static func lexicalClass(_ w: String) -> NLTag {
        let l = w.lowercased()
        if let t = lexicon[l] { return t }
        if l.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," }) { return .number }
        if l.hasSuffix("ly") && l.count > 4 { return .adverb }
        if l.hasSuffix("ing") && l.count > 5 || l.hasSuffix("ed") && l.count > 4 || l.hasSuffix("ize") || l.hasSuffix("ise") { return .verb }
        if l.hasSuffix("ous") || l.hasSuffix("ful") || l.hasSuffix("ive") || l.hasSuffix("able") || l.hasSuffix("ible") || l.hasSuffix("al") && l.count > 5 || l.hasSuffix("less") { return .adjective }
        return .noun
    }
    static func punctuationTag(_ c: Character) -> NLTag {
        switch c {
        case ".", "!", "?", "。", "！", "？": return .sentenceTerminator
        case "\"", "“", "«", "„": return .openQuote
        case "”", "»": return .closeQuote
        case "(", "[", "{": return .openParenthesis
        case ")", "]", "}": return .closeParenthesis
        case "-", "–", "—": return .dash
        default: return .otherPunctuation
        }
    }
    static let positive: Set<String> = ["good", "great", "excellent", "amazing", "awesome", "love", "loved", "like", "liked", "happy", "wonderful", "fantastic", "best", "nice",
                                        "beautiful", "perfect", "enjoy", "enjoyed", "glad", "pleased", "brilliant", "delightful", "superb", "fun", "recommend", "favorite", "better"]
    static let negative: Set<String> = ["bad", "terrible", "awful", "horrible", "hate", "hated", "worst", "poor", "sad", "angry", "disappointing", "disappointed", "boring",
                                        "ugly", "broken", "annoying", "useless", "slow", "wrong", "fail", "failed", "problem", "worse", "never", "dislike"]
    static func sentiment(_ s: String) -> Double {
        let lower = s.lowercased()
        let ws = words(lower, lower.startIndex..<lower.endIndex).map { String(lower[$0]) }
        var score = 0.0, n = 0.0, negate = false
        for w in ws {
            if ["not", "no", "never", "don't", "isn't", "wasn't", "didn't", "can't", "won't"].contains(w) { negate = true; continue }
            var v = positive.contains(w) ? 1.0 : negative.contains(w) ? -1.0 : 0
            if negate { v = -v; negate = v == 0 }
            if v != 0 { score += v; n += 1 }
        }
        return n == 0 ? 0 : max(-1, min(1, score / max(n, 1.5)))
    }
}

// MARK: - NLTokenizer

open class NLTokenizer: NSObject, @unchecked Sendable {
    public struct Attributes: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let numeric = Attributes(rawValue: 1), symbolic = Attributes(rawValue: 2), emoji = Attributes(rawValue: 4)
    }
    public let unit: NLTokenUnit
    open var string: String?
    public init(unit: NLTokenUnit) { self.unit = unit }
    open func setLanguage(_ language: NLLanguage) {}
    open func tokenRange(at characterIndex: String.Index) -> Range<String.Index> {
        guard let s = string else { return characterIndex..<characterIndex }
        return _NL.tokens(s, s.startIndex..<s.endIndex, unit).first { $0.contains(characterIndex) } ?? characterIndex..<characterIndex
    }
    open func tokenRange(for range: Range<String.Index>) -> Range<String.Index> {
        guard let s = string else { return range }
        let ts = _NL.tokens(s, s.startIndex..<s.endIndex, unit).filter { $0.overlaps(range) || $0.contains(range.lowerBound) }
        guard let a = ts.first, let b = ts.last else { return range }
        return a.lowerBound..<b.upperBound
    }
    open func tokens(for range: Range<String.Index>) -> [Range<String.Index>] {
        guard let s = string else { return [] }
        return _NL.tokens(s, range, unit)
    }
    open func enumerateTokens(in range: Range<String.Index>, using block: (Range<String.Index>, Attributes) -> Bool) {
        guard let s = string else { return }
        for t in _NL.tokens(s, range, unit) {
            var a: Attributes = []
            if s[t].allSatisfy({ $0.isNumber || $0 == "." || $0 == "," }) { a.insert(.numeric) }
            if s[t].unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) { a.insert(.emoji) }
            if !block(t, a) { break }
        }
    }
}

// MARK: - NLLanguageRecognizer

open class NLLanguageRecognizer: NSObject, @unchecked Sendable {
    var _text = ""
    open var languageConstraints: [NLLanguage] = []
    open var languageHints: [NLLanguage: Double] = [:]
    public override init() { super.init() }
    open class func dominantLanguage(for string: String) -> NLLanguage? { _NL.hypotheses(string, constraints: [], hints: [:]).first?.0 }
    open func processString(_ string: String) { _text += string }
    open var dominantLanguage: NLLanguage? { _NL.hypotheses(_text, constraints: languageConstraints, hints: languageHints).first?.0 }
    open func languageHypotheses(withMaximum maxHypotheses: Int) -> [NLLanguage: Double] {
        Dictionary(_NL.hypotheses(_text, constraints: languageConstraints, hints: languageHints).prefix(max(0, maxHypotheses)).map { ($0.0, $0.1) }, uniquingKeysWith: { a, _ in a })
    }
    open func reset() { _text = "" }
}

// MARK: - NLTagger

open class NLTagger: NSObject, @unchecked Sendable {
    public struct Options: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let omitWords = Options(rawValue: 1 << 0), omitPunctuation = Options(rawValue: 1 << 1), omitWhitespace = Options(rawValue: 1 << 2)
        public static let omitOther = Options(rawValue: 1 << 3), joinNames = Options(rawValue: 1 << 4), joinContractions = Options(rawValue: 1 << 5)
    }
    public let tagSchemes: [NLTagScheme]
    open var string: String?
    var _language: NLLanguage?
    public init(tagSchemes: [NLTagScheme]) { self.tagSchemes = tagSchemes }
    open class func availableTagSchemes(for unit: NLTokenUnit, language: NLLanguage) -> [NLTagScheme] {
        switch unit {
        case .word: return language == .english ? [.tokenType, .lexicalClass, .language, .script] : [.tokenType, .language, .script]
        case .sentence, .paragraph, .document: return language == .english ? [.language, .script, .sentimentScore] : [.language, .script]
        }
    }
    open var dominantLanguage: NLLanguage? { _language ?? string.flatMap { NLLanguageRecognizer.dominantLanguage(for: $0) } }
    open func setLanguage(_ language: NLLanguage, range: Range<String.Index>) { _language = language }
    open func tokenRange(at index: String.Index, unit: NLTokenUnit) -> Range<String.Index> {
        guard let s = string else { return index..<index }
        return _NL.tokens(s, s.startIndex..<s.endIndex, unit).first { $0.contains(index) } ?? index..<index
    }

    /// word-unit segments: words, punctuation and whitespace runs
    func _segments(_ s: String, _ r: Range<String.Index>) -> [(Range<String.Index>, NLTag)] {
        var out: [(Range<String.Index>, NLTag)] = []
        let ws = _NL.words(s, r)
        var i = r.lowerBound
        for w in ws {
            while i < w.lowerBound {
                let c = s[i], n = s.index(after: i)
                if c.isWhitespace {
                    var e = n; while e < w.lowerBound && s[e].isWhitespace { e = s.index(after: e) }
                    out.append((i..<e, .whitespace)); i = e
                } else { out.append((i..<n, .punctuation)); i = n }
            }
            out.append((w, .word)); i = w.upperBound
        }
        while i < r.upperBound {
            let c = s[i], n = s.index(after: i)
            if c.isWhitespace { var e = n; while e < r.upperBound && s[e].isWhitespace { e = s.index(after: e) }; out.append((i..<e, .whitespace)); i = e }
            else { out.append((i..<n, .punctuation)); i = n }
        }
        return out
    }
    func _tag(_ s: String, _ r: Range<String.Index>, _ kind: NLTag, unit: NLTokenUnit, scheme: NLTagScheme) -> NLTag? {
        switch scheme {
        case .tokenType: return unit == .word ? kind : nil
        case .language: return (_language ?? NLLanguageRecognizer.dominantLanguage(for: String(s[r]))).map { NLTag($0.rawValue) }
        case .script: return NLTag(_NL.script(String(s[r])))
        case .lexicalClass, .nameTypeOrLexicalClass:
            guard unit == .word else { return nil }
            if kind == .punctuation { return _NL.punctuationTag(s[r.lowerBound]) }
            if kind == .whitespace { return s[r].contains(where: { _NL.kind($0) == .newline }) ? .paragraphBreak : .whitespace }
            return _NL.lexicalClass(String(s[r]))
        case .sentimentScore:
            guard unit != .word else { return nil }
            return NLTag(String(format: "%.1f", _NL.sentiment(String(s[r]))))
        default: return nil        // nameType, lemma: not available on isim
        }
    }
    open func enumerateTags(in range: Range<String.Index>, unit: NLTokenUnit, scheme: NLTagScheme, options: Options = [],
                            using block: (NLTag?, Range<String.Index>) -> Bool) {
        guard let s = string, tagSchemes.contains(scheme) || scheme == .tokenType else { return }
        if unit == .word {
            for (r, kind) in _segments(s, range) {
                if options.contains(.omitWords) && kind == .word { continue }
                if options.contains(.omitPunctuation) && kind == .punctuation { continue }
                if options.contains(.omitWhitespace) && kind == .whitespace { continue }
                if !block(_tag(s, r, kind, unit: unit, scheme: scheme), r) { return }
            }
        } else {
            for r in _NL.tokens(s, range, unit) { if !block(_tag(s, r, .word, unit: unit, scheme: scheme), r) { return } }
        }
    }
    open func tag(at index: String.Index, unit: NLTokenUnit, scheme: NLTagScheme) -> (NLTag?, Range<String.Index>) {
        guard let s = string else { return (nil, index..<index) }
        var result: (NLTag?, Range<String.Index>) = (nil, index..<index)
        enumerateTags(in: s.startIndex..<s.endIndex, unit: unit, scheme: scheme) { t, r in
            if r.contains(index) { result = (t, r); return false }
            return true
        }
        return result
    }
    open func tags(in range: Range<String.Index>, unit: NLTokenUnit, scheme: NLTagScheme, options: Options = []) -> [(NLTag?, Range<String.Index>)] {
        var out: [(NLTag?, Range<String.Index>)] = []
        enumerateTags(in: range, unit: unit, scheme: scheme, options: options) { out.append(($0, $1)); return true }
        return out
    }
    open func tagHypotheses(at index: String.Index, unit: NLTokenUnit, scheme: NLTagScheme, maximumCount: Int) -> ([String: Double], Range<String.Index>) {
        let (t, r) = tag(at: index, unit: unit, scheme: scheme)
        return (t.map { [$0.rawValue: 1] } ?? [:], r)
    }
}

/// isim: no embeddings or custom models (they need Apple's model files).
open class NLEmbedding: NSObject, @unchecked Sendable {
    open class func wordEmbedding(for language: NLLanguage) -> NLEmbedding? { nil }
    open class func sentenceEmbedding(for language: NLLanguage) -> NLEmbedding? { nil }
}
open class NLModel: NSObject, @unchecked Sendable {
    public init(contentsOf url: URL) throws {
        throw NSError(domain: "NLNaturalLanguageErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "NLModel is not available on isim (it needs Apple's Core ML runtime)"])
    }
}
