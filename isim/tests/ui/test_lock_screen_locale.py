"""The lock screen's date and clock follow Settings > General > Language & Region (issue #179): the date in the
device's locale (AppleLocale in the global preferences), and the 24-hour clock where the region uses it. Checked in
the shell's `dump`."""
import plistlib
import re

import pytest

EN_DAYS = "Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday"
DE_DAYS = "Sonntag|Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Samstag"
DE_MONTHS = "Januar|Februar|März|April|Mai|Juni|Juli|August|September|Oktober|November|Dezember"


def set_region(data, locale, languages):
    prefs = data / "Library" / "Preferences"
    prefs.mkdir(parents=True, exist_ok=True)
    with open(prefs / ".GlobalPreferences.plist", "wb") as f:
        plistlib.dump({"AppleLocale": locale, "AppleLanguages": [languages]}, f)


CASES = [("en_US", "en", rf"(?:{EN_DAYS}), [A-Z][a-z]+ \d{{1,2}}", r"\d{1,2}:\d\d"),
         ("de_DE", "de", rf"(?:{DE_DAYS}), \d{{1,2}}\. (?:{DE_MONTHS})", r"\d\d:\d\d")]


@pytest.mark.parametrize("locale,language,date,clock", CASES, ids=[c[0] for c in CASES])
def test_lock_screen_locale(launch, tmp_path, monkeypatch, locale, language, date, clock):
    monkeypatch.delenv("ISIM_LOCK_TIME", raising=False)
    monkeypatch.delenv("ISIM_HOUR_CYCLE", raising=False)
    set_region(tmp_path, locale, language)
    dev = launch(None, data=tmp_path)
    dev.wait_log(r"SpringBoard: page 1 of")
    dev.send("lock")
    dev.wait_log(r"isim shell: locked")
    dev.wait_dump(rf"id=lock-date text={date}$")
    dev.wait_dump(rf"id=lock-clock text={clock}$")
    assert dev.quit() == 0, "exits cleanly"
