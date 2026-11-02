// isim Accessibility (issue #426): the Swift forms of braille translation, over the Objective-C classes
// (frameworks/Accessibility/AXBraille.m, liblouis): locales and languages as Locale values, String.Index positions.
import Foundation

@available(iOS 26.0, *)
extension AXBrailleTable {
    public var language: Locale.Language { Locale.Language(identifier: __language) }
    public var locales: Set<Locale> { Set(__locales.map { Locale(identifier: $0) }) }
    public class func tables(for locale: Locale) -> Set<AXBrailleTable> { __tables(forLocale: locale.identifier) }
    public class func defaultTable(for locale: Locale) -> AXBrailleTable? { __defaultTable(forLocale: locale.identifier) }
    public class func supportedLocales() -> Set<Locale> { Set(__supportedLocales().map { Locale(identifier: $0) }) }
}

@available(iOS 26.0, *)
extension AXBrailleTranslationResult {
    /// the index in the translated (or back-translated) input of the character at this index of `resultString`
    public func inputIndex(forResultIndex index: String.Index) -> String.Index? {
        let r = resultString, offset = r.utf16.distance(from: r.startIndex, to: index)
        let i = __inputIndex(forResultIndex: offset)
        guard i != NSNotFound, let input = perform(NSSelectorFromString("input"))?.takeUnretainedValue() as? String,
              i <= input.utf16.count else { return nil }
        return input.utf16.index(input.startIndex, offsetBy: i)
    }
}
