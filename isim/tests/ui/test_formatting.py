"""Foundation formatting + Swift Regex (HelloFormatting). The same app runs with the device region set to en_US and
then de_DE (AppleLocale in the device's global preferences, as Settings > General > Language & Region writes it):
dates, numbers, currency, measurements and lists follow the region. The regex search box is typed into and its match
count checked. Port of tests/ui/formatting.sh."""
import plistlib

import pytest


def set_region(data, locale, languages, tz):
    prefs = data / "Library" / "Preferences"
    prefs.mkdir(parents=True, exist_ok=True)
    with open(prefs / ".GlobalPreferences.plist", "wb") as f:
        plistlib.dump({"AppleLocale": locale, "AppleLanguages": languages.split(","), "TimeZone": tz}, f)


def spaces(s):
    """Any no-break space matches a space."""
    return s.replace(" ", " ").replace(" ", " ")


@pytest.fixture(scope="module")
def runs(launch_module, tmp_path_factory):
    data = tmp_path_factory.mktemp("formatting")
    set_region(data, "en_US", "en", "America/New_York")
    app = launch_module("HelloFormatting", data=data)
    app.wait_log(r"^fmt list=")
    app.screenshot("en_US")
    app.wait_tap_id("pattern")
    for _ in range(3):
        app.send("key backspace")
    app.type("[0-9]{4}")
    app.wait_log(r"pattern \[0-9\]\{4\} -> ")
    us_dump = app.wait_view(r"text=2 matches")
    app.screenshot("regex")
    us_rc = app.quit()
    us = spaces(app.log + "\n" + us_dump)

    set_region(data, "de_DE", "de", "America/New_York")
    app = launch_module("HelloFormatting", data=data)
    app.wait_log(r"^fmt list=")
    app.screenshot("de_DE")
    de_dump = app.wait_view(r"text=Red, Green und Blue")
    de_rc = app.quit()
    de = spaces(app.log + "\n" + de_dump)
    return us, us_rc, de, de_rc


def test_en_us(runs):
    us, rc, _, _ = runs
    assert rc == 0, "exits cleanly"
    assert "fmt date-default=10/5/2026, 11:04 AM" in us, "en_US: default date + time"
    assert "fmt date-complete=Monday, October 5, 2026" in us, "en_US: complete date"
    assert "fmt date-iso=2026-10-05T15:04:05Z" in us, "en_US: ISO 8601"
    assert "fmt date-relative=2 hours ago" in us and "fmt date-yesterday=yesterday" in us, "en_US: relative (named)"
    assert "fmt num-decimal=1,234,567.891" in us and "fmt num-percent=25.6%" in us and \
        "fmt num-currency=$1,234.50" in us, "en_US: decimal, percent, currency"
    assert "fmt num-compact=2.5M" in us and "fmt num-spell=forty-two" in us, "en_US: compact + spell-out"
    assert "fmt measure-distance=3.11 mi" in us and "fmt measure-temperature=69.8°F" in us and \
        "fmt measure-weight=154.32 pounds" in us, "en_US: US customary measurements"
    assert "fmt list=Red, Green, and Blue" in us and "fmt duration=1 hour, 24 minutes" in us and \
        "fmt bytes=3.5 MB" in us, "en_US: list, duration, bytes"
    assert "pattern [0-9]{4} -> 2 matches" in us and "text=2 matches: 2026 and 1999" in us, \
        "regex search box (typed pattern)"
    assert "text=Dates: 05/10/2026 and 02/01/1999" in us, "RegexBuilder captures"


def test_de_de(runs):
    _, _, de, rc = runs
    assert rc == 0, "exits cleanly"
    assert "fmt date-default=5.10.2026, 11:04" in de and "fmt date-complete=Montag, 5. Oktober 2026" in de, \
        "de_DE: region change reformats dates"
    assert "fmt num-decimal=1.234.567,891" in de and "fmt num-percent=25,6 %" in de and \
        "fmt num-currency=1.234,50 €" in de and "fmt num-usd=19,99 $" in de, "de_DE: numbers and currency"
    assert "fmt measure-distance=5 km" in de and "fmt measure-temperature=21 °C" in de and \
        "fmt measure-weight=70 Kilogramm" in de, "de_DE: metric measurements"
    assert "fmt list=Red, Green und Blue" in de and "fmt date-relative=vor 2 Stunden" in de and \
        "fmt date-yesterday=gestern" in de, "de_DE: list + relative time"
    assert "text=1.234.567,891" in de and "text=Red, Green und Blue" in de, "de_DE: values shown on screen"


def test_foundation_extras(runs):
    # issue #860: Decimal parse strategies and classification, CocoaError codes and Core Data userInfo, byte counts
    us, _, _, _ = runs
    assert "x860 decimal 1234.5678 percent 0.125 currency 19.99" in us, us[-2000:]
    assert "x860 class true true signOf -7 ordered true" in us
    assert "x860 cocoa 1550 title xpc true alias true" in us
    assert "x860 bytes 3.5 MB parsed 5." in us
    # issue #864: attributed format styles, the rest of the date symbols, formatter properties
    assert "x864 number 1|int ,|int,groupingSeparator 234|int .|decimalSeparator 5|frac" in us, "number parts and symbols"
    assert "x864 currency -|sign $|currency 19|int .|decimalSeparator 99|frac" in us, "currency: sign and currency symbol"
    assert "x864 percent 42|int %|percent" in us
    assert "x864 date Oct|month 6|day , 2026|year , 11|hour : 04|minute AM|amPM same true" in us, "date fields; same text as the plain style"
    assert "x864 verbatim 2026-10 October Q4 11h runs 10" in us, "Date.VerbatimFormatStyle with standalone and verbatim-hour symbols"
    assert "x864 measurement 12|int,value .|decimalSeparator,value 5|frac,value km|unit" in us, "Measurement.AttributedStyle"
    assert "x864 bytes 3|int,value .|decimalSeparator,value 5|frac,value MB|unit-mb" in us, "ByteCountFormatStyle.Attributed"
    assert "x864 formatter ******42 7. style 5 behavior true" in us, "NumberFormatter padding, alwaysShowsDecimalSeparator, Style"
    assert "x864 quarters 1st quarter Q4 tz America/Los_Angeles GMT" in us, "standalone quarters, TimeZone(abbreviation:), localizedName"
    x864b = "\n".join(l for l in us.splitlines() if "x864b" in l)
    assert "x864b discrete after 60 before true" in us, f"DiscreteFormatStyle: the next and previous minute: {x864b}"
    assert "x864b anchored in 3 days" in us, f"Date.AnchoredRelativeFormatStyle, allowedFields [.day]: {x864b}"
    assert "x864b relative true" in us, f"RelativeFormatStyle.allowedFields: {x864b}"
    assert "x864b regex 1234.5 true" in us, f"FloatingPointFormatStyle and ISO8601FormatStyle inside a Regex: {x864b}"
    assert "x864b components 2026-10-06T11:04:05Z back 6 valid true http Tue, 06 Oct 2026 11:04:05 GMT" in us, \
        f"DateComponents.ISO8601FormatStyle / HTTPFormatStyle, isValidDate(in:): {x864b}"
    assert "x864b calendar [6, 13, 20] [11, 12] range 1..<29 1..<32 matches true" in us, \
        f"Calendar.dates(byAdding:) / dates(byMatching:), minimumRange / maximumRange, date(_:matchesComponents:): {x864b}"
    x864c = "\n".join(l for l in us.splitlines() if "x864c" in l)
    assert "x864c index  world runs 2 utf8 9 utf16 11" in us, f"AttributedStringProtocol index(afterRun:), offsetByCharacters, utf8 / utf16: {x864c}"
    assert "x864c scoped example.com nil" in us, f"ScopedAttributeContainer (string[range].foundation): {x864c}"
    assert 'x864c transform links 0 langs ["fr", "en"]' in us, f"transformingAttributes, SingleAttributeTransformer.replace(with:value:): {x864c}"
    assert "x864c slices 2" in us, f"Runs.AttributesSlice3: {x864c}"
    assert 'x864c filter rightToLeft keys ["CoreText.LineHeight", "CoreText.TextAlignment"]' in us, \
        f"AttributeContainer.filter(runBoundaries:), AttributeScope.attributeKeys, writingDirection: {x864c}"
    assert "x864c discontiguous 1267 removed 034589" in us, f"DiscontiguousAttributedSubstring, removeSubranges: {x864c}"
    assert "x864c tracked two" in us or "x864c tracked" not in us, f"transform(updating:) keeps the range on its text (iOS 26): {x864c}"
    assert "x864c valid true heading 2 line multiple(factor: 1.5)" in us, f"Index(_:within:), AccessibilityAttributes, LineHeight: {x864c}"
