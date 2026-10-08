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
