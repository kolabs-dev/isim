#!/usr/bin/env bash
# UI test (isim boot, HelloWidgets): WidgetKit — the widget extension lists its widgets, the gallery adds them
# (Edit Home Screen > +), timelines render and switch entries by date and reload at the end, tapping the
# interactive widget's Button(intent:) runs the AppIntent in the extension and re-renders, the app's
# WidgetCenter.reloadTimelines reloads it; ActivityKit — a Live Activity in the Dynamic Island (compact, expanded)
# and on the lock screen, updated and ended by the app.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloWidgets; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/widgets; rm -rf "$ISIM_DATA"
out/bin/isim install out/apps/HelloWidgets.app >/dev/null
boot() { ISIM_DEVICE=iphone17 ISIM_SHOT_SCALE=1 timeout 120 out/bin/isim boot --headless --script "$1" 2>&1; }
log=$(boot "wait 2.5; holdid app-dev.isim.samples.HelloWidgets 0.8; wait 0.4; tapid menu-edit; wait 0.4; tapid home-add-widget; wait 0.5; shot $shots/gallery.png; dump;
            tapid widget-add-Counter-systemSmall; wait 2; tapid home-add-widget; wait 0.4; tapid widget-add-Ticker-systemMedium; wait 2; tapid home-done; wait 0.6; shot $shots/widgets.png; dump;
            tap 114 400; wait 2; shot $shots/tapped.png;
            launch dev.isim.samples.HelloWidgets; wait 1.5; dump; tapid increment; wait 1; tapid startDelivery; wait 2; home; wait 1; shot $shots/island.png; dump;
            island; wait 0.5; shot $shots/island-expanded.png; island; wait 0.3; lock; wait 1; shot $shots/lock.png; dump; unlock; wait 0.5;
            launch dev.isim.samples.HelloWidgets; wait 1; tapid updateDelivery; wait 2; home; wait 0.6; island; wait 0.4; shot $shots/island-updated.png; island;
            launch dev.isim.samples.HelloWidgets; wait 1; tapid endDelivery; wait 1; home; wait 0.6; dump; quit"); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
px() { magick "$1" -crop "$2" +repage -format "%[fx:mean.r] %[fx:mean.g] %[fx:mean.b]" info: 2>/dev/null; }
check "the extension lists its widgets; the gallery offers them"   'grep -q "isim WidgetKit: 2 widget kind(s), 1 Live Activity configuration(s)" <<<"$log" && grep -q "id=widget-add-Counter-systemSmall" <<<"$log" && grep -q "id=widget-add-Ticker-systemMedium" <<<"$log"'
check "widgets added and rendered by the extension"               'grep -q "added widget Counter (systemSmall)" <<<"$log" && grep -q "rendered Counter (systemSmall): 1 entry, policy never" <<<"$log" && grep -q "id=widget-Counter-systemSmall text=Counter-systemSmall-0.png" <<<"$log"'
check "widget pixels: blue counter, white ticker"                 'read r g b <<<"$(px "$shots/widgets.png" 20x20+50+290)"; python3 -c "import sys; sys.exit(0 if $b > 0.9 and $r < 0.2 else 1)" && read r g b <<<"$(px "$shots/widgets.png" 20x20+300+90)" && python3 -c "import sys; sys.exit(0 if $r > 0.9 and $b > 0.9 else 1)"'
check "timeline entries switch by date; reload at the end"       'grep -q "widget Ticker shows Ticker-systemMedium-1.png" <<<"$log" && grep -q "widget Ticker shows Ticker-systemMedium-2.png" <<<"$log" && grep -q "timeline of Ticker ended; reloading" <<<"$log"'
check "interactive widget: Button(intent:) runs the AppIntent"    'grep -q "isim WidgetKit: tap on Counter" <<<"$log" && grep -q "isim AppIntents: Increment -> “Count is 1”" <<<"$log" && grep -q "counter timeline (systemSmall), count 1" <<<"$log"'
check "the app sees the app-group count; reloadTimelines"         'grep -q "HelloWidgets: count 1" <<<"$log" && grep -q "SpringBoard: reloading widget Counter" <<<"$log" && grep -q "counter timeline (systemSmall), count 2" <<<"$log"'
check "Live Activity rendered by the extension"                   'grep -q "requested Live Activity" <<<"$log" && grep -q "rendered Live Activity DeliveryAttributes" <<<"$log" && grep -q "Live Activity from .*HelloWidgets.app shown" <<<"$log"'
check "Dynamic Island: compact outside the app, expanded"         'grep -q "IsimDynamicIsland (74.5 11; 253 x 37) id=dynamic-island text=compact" <<<"$log" && grep -q "Dynamic Island expanded" <<<"$log" && read r g b <<<"$(px "$shots/island-expanded.png" 30x20+20+130)" && python3 -c "import sys; sys.exit(0 if $r + $g + $b < 0.1 else 1)"'
check "lock screen shows the Live Activity"                       'grep -q "id=live-activity" <<<"$log" && read r g b <<<"$(px "$shots/lock.png" 30x20+30+280)" && python3 -c "import sys; sys.exit(0 if $r > 0.9 else 1)"'
check "update re-renders; end removes it"                         'grep -q "updated Live Activity" <<<"$log" && [ "$(grep -c "rendered Live Activity DeliveryAttributes" <<<"$log")" -ge 2 ] && grep -q "Live Activity ended" <<<"$log" && ! tail -5 <<<"$log" | grep -q IsimDynamicIsland'
check "exits cleanly"                                             '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- log"; echo "$log" | grep -E "Widget|widget|Intent|Live|Island|HelloWidgets:" | grep -v "^ " | tail -40; }
exit $fail
