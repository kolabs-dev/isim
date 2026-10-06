#!/usr/bin/env bash
# UI test: Foundation formatting + Swift Regex (HelloFormatting sample). The same app runs twice: with the device
# region set to en_US and then to de_DE (AppleLocale in the isolated global preferences, as Settings > General >
# Language & Region writes it) — dates, numbers, currency, measurements and lists must follow the region.
# The regex search box is typed into and its match count checked.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloFormatting; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/formatting; rm -rf "$ISIM_DATA"
prefs() {   # locale languages time-zone
  mkdir -p "$ISIM_DATA/Library/Preferences"
  python3 - "$ISIM_DATA/Library/Preferences/.GlobalPreferences.plist" "$1" "$2" "$3" <<'PY'
import plistlib, sys
path, loc, langs, tz = sys.argv[1:]
plistlib.dump({"AppleLocale": loc, "AppleLanguages": langs.split(","), "TimeZone": tz}, open(path, "wb"))
PY
}
run() { ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 60 out/bin/isim run out/apps/HelloFormatting.app 2>&1; }

prefs en_US en America/New_York
us=$(run "wait 0.8; shot $shots/en_US.png; tapid pattern; wait 0.3; key backspace; key backspace; key backspace; type [0-9]{4}; wait 0.4; dump; shot $shots/regex.png; quit"); rc1=$?
prefs de_DE de America/New_York
de=$(run "wait 0.8; shot $shots/de_DE.png; dump; quit"); rc2=$?

fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
has() { sed "s/\xc2\xa0/ /g; s/\xe2\x80\xaf/ /g" <<<"$1" | grep -qF -- "$2"; }   # any no-break space matches a space
check "en_US: default date + time"            'has "$us" "fmt date-default=10/5/2026, 11:04 AM"'
check "en_US: complete date"                  'has "$us" "fmt date-complete=Monday, October 5, 2026"'
check "en_US: ISO 8601"                       'has "$us" "fmt date-iso=2026-10-05T15:04:05Z"'
check "en_US: relative (named)"               'has "$us" "fmt date-relative=2 hours ago" && has "$us" "fmt date-yesterday=yesterday"'
check "en_US: decimal, percent, currency"     'has "$us" "fmt num-decimal=1,234,567.891" && has "$us" "fmt num-percent=25.6%" && has "$us" "fmt num-currency=\$1,234.50"'
check "en_US: compact + spell-out"            'has "$us" "fmt num-compact=2.5M" && has "$us" "fmt num-spell=forty-two"'
check "en_US: US customary measurements"      'has "$us" "fmt measure-distance=3.11 mi" && has "$us" "fmt measure-temperature=69.8°F" && has "$us" "fmt measure-weight=154.32 pounds"'
check "en_US: list, duration, bytes"          'has "$us" "fmt list=Red, Green, and Blue" && has "$us" "fmt duration=1 hour, 24 minutes" && has "$us" "fmt bytes=3.5 MB"'
check "regex search box (typed pattern)"      'has "$us" "pattern [0-9]{4} -> 2 matches" && has "$us" "text=2 matches: 2026 and 1999"'
check "RegexBuilder captures"                 'has "$us" "text=Dates: 05/10/2026 and 02/01/1999"'
check "de_DE: region change reformats dates"  'has "$de" "fmt date-default=5.10.2026, 11:04" && has "$de" "fmt date-complete=Montag, 5. Oktober 2026"'
check "de_DE: numbers and currency"           'has "$de" "fmt num-decimal=1.234.567,891" && has "$de" "fmt num-percent=25,6 %" && has "$de" "fmt num-currency=1.234,50 €" && has "$de" "fmt num-usd=19,99 $"'
check "de_DE: metric measurements"            'has "$de" "fmt measure-distance=5 km" && has "$de" "fmt measure-temperature=21 °C" && has "$de" "fmt measure-weight=70 Kilogramm"'
check "de_DE: list + relative time"           'has "$de" "fmt list=Red, Green und Blue" && has "$de" "fmt date-relative=vor 2 Stunden" && has "$de" "fmt date-yesterday=gestern"'
check "de_DE: values shown on screen"         'has "$de" "text=1.234.567,891" && has "$de" "text=Red, Green und Blue"'
check "exits cleanly"                         '[ $rc1 = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- en_US log"; grep -E "^(fmt|pattern|region)" <<<"$us"; echo "--- de_DE log"; grep -E "^(fmt|region)" <<<"$de"; }
exit $fail
