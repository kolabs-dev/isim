#!/usr/bin/env bash
# UI test: one app on every iOS version isim emulates (HelloOSVersions sample, `--os 17|18|26|27`, headless, isolated
# device data). Per version: UIDevice/ProcessInfo versions, Swift `#available` and Objective-C `@available`, a stdlib
# API behind its availability check, version-gated UIKit/SwiftUI APIs (glass button, UIGlassEffect, glassEffect,
# Tab(role:)), and the look by pixels (floating glass tab bar vs opaque bar, glass alert, Lock Screen clock, Control
# Center). Plus Xcode-like device pairing, the remembered version and `isim version` / `isim devices`.
# Devices: iPhone 17 for 26/27, iPhone 16 Pro for 18 and iPhone 15 for 17 (iPhone 17 models need iOS 26).
# OSV_VERSIONS="26" limits the versions.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloOSVersions; mkdir -p "$shots"; rm -f "$shots"/*.png
base=$PWD/out/test-data/osversions; rm -rf "$base"; mkdir -p "$base"
app=out/apps/HelloOSVersions.app
versions=${OSV_VERSIONS:-17 18 26 27}
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
device_for() { case $1 in 17) echo iphone15 ;; 18) echo iphone16pro ;; *) echo iphone17 ;; esac; }
tf() { [ "$1" -ge "$2" ] && echo true || echo false; }
of() { [ "$1" -ge "$2" ] && echo 1 || echo 0; }

for v in $versions; do
  d=$(device_for "$v")
  export ISIM_DATA=$base/$v
  log=$(ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1.5; shot $shots/u$v.png; dump; tapid more; wait 0.6; tapid menu-First; wait 0.4; tapid show-alert; wait 0.8; shot $shots/a$v.png; tapid alert-OK; wait 0.5; quit" \
        timeout 60 out/bin/isim run "$app" --os "$v" --device "$d" 2>&1); rc=$?
  check "iOS $v: systemVersion and ProcessInfo"            'grep -q "^hov version $v.0 process $v.0.0 string Version $v.0$" <<<"$log"'
  check "iOS $v: isOperatingSystemAtLeast"                 'grep -q "^hov atLeast 17=true 18=$(tf $v 18) 26=$(tf $v 26) 27=$(tf $v 27)$" <<<"$log"'
  check "iOS $v: Swift #available (18, 26, 27)"            'grep -q "^hov swift available 18=$(tf $v 18) 26=$(tf $v 26) 27=$(tf $v 27)$" <<<"$log"'
  check "iOS $v: Swift #unavailable"                       'grep -q "^hov swift unavailable 26=$([ $v -lt 26 ] && echo true || echo false)$" <<<"$log"'
  check "iOS $v: Objective-C @available (18, 26, 27)"      'grep -q "^hov objc available 18=$(of $v 18) 26=$(of $v 26) 27=$(of $v 27)$" <<<"$log"'
  if [ "$v" -ge 18 ]; then check "iOS $v: SwiftStdlib 6.0 API (Int128) behind #available" 'grep -q "^hov stdlib18 Int128 36893488147419103231$" <<<"$log"'
  else check "iOS $v: the stdlib 6.0 branch is skipped (back-deployment path)" 'grep -q "^hov stdlib18 fallback 4611686018427387903$" <<<"$log"'; fi
  check "iOS $v: stdlib strings/collections unchanged"     'grep -q "^hov stdlib strings 14 15 25 café 🇧🇷 naïve ﬁ ﬁ evïan 🇧🇷 éfaC$" <<<"$log" && grep -q "^hov stdlib collections 55 \[1, 2, 3\] ab$" <<<"$log"'
  if [ "$v" -ge 26 ]; then
    check "iOS $v: UIButton glass configuration + UIGlassEffect" 'grep -q "^hov api button glass$" <<<"$log" && grep -q "^hov api UIGlassEffect yes$" <<<"$log" && grep -q "id=glass-platter" <<<"$log"'
    check "iOS $v: iOS 26 switch (63 x 28)"                'grep -q "^hov switch size 63x28$" <<<"$log"'
    check "iOS $v: glass back/bar button item (44 pt circle)" 'grep -Eq "__IsimBarButton \([0-9.]+ [0-9.]+; 44 x 44\) id=more" <<<"$log"'
  else
    check "iOS $v: no glass APIs (filled button)"           'grep -q "^hov api button filled$" <<<"$log" && grep -q "^hov api UIGlassEffect no$" <<<"$log"'
    check "iOS $v: classic switch (51 x 31)"               'grep -q "^hov switch size 51x31$" <<<"$log"'
  fi
  check "iOS $v: menu and alert work"                      'grep -q "^hov menu first$" <<<"$log" && grep -q "^hov alert ok$" <<<"$log"'
  check "iOS $v: exits cleanly"                             '[ $rc = 0 ]'
  [ $fail = 0 ] || { echo "--- app log (iOS $v)"; echo "$log" | grep -v "^ " | tail -20; }
  # SwiftUI: TabView with Tab(role: .search) on 18+, glass APIs on 26+
  slog=$(ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1.5; shot $shots/s$v.png; dump; tapid glass-button; wait 0.3; quit" \
         timeout 60 out/bin/isim run "$app" --os "$v" --device "$d" swiftui 2>&1)
  check "iOS $v: SwiftUI Tab API $( [ $v -ge 18 ] && echo available || echo unavailable )" 'grep -q "^hov swiftui Tab api $([ $v -ge 18 ] && echo yes || echo no)$" <<<"$slog"'
  if [ "$v" -ge 26 ]; then
    check "iOS $v: SwiftUI glassEffect + .buttonStyle(.glass)" 'grep -q "^hov swiftui glass api yes$" <<<"$slog" && grep -q "id=glass-text" <<<"$slog" && grep -q "^hov swiftui glass button$" <<<"$slog"'
    check "iOS $v: search role tab on its own glass circle"  'grep -Eq "_SUITabButton \([0-9.]+ [0-9.]+; 54 x 54\) id=tab-Search" <<<"$slog"'
  else
    check "iOS $v: SwiftUI without glass"                   'grep -q "^hov swiftui glass api no$" <<<"$slog"'
  fi
  # the system: home screen, Lock Screen, Control Center
  blog=$(ISIM_LOCK_TIME=9:41 ISIM_SHOT_SCALE=1 timeout 60 out/bin/isim boot --os "$v" --device "$d" --headless \
         --script "wait 1.5; shot $shots/h$v.png; lock; wait 0.5; shot $shots/l$v.png; unlock; wait 0.3; controlcenter; wait 0.6; shot $shots/c$v.png; dump; tapid cc-background; wait 0.4; launch dev.isim.settings; wait 1.2; tapid settings-general; wait 0.8; taptext About; wait 0.8; dump; quit" 2>&1)
  check "iOS $v: home screen look"                          'grep -q "SpringBoard: iOS $v look$( [ $v -ge 26 ] && echo " (Liquid Glass)")" <<<"$blog"'
  check "iOS $v: Lock Screen and Control Center"           'grep -q "isim shell: locked (iOS $v look)" <<<"$blog" && grep -q "isim shell: Control Center (iOS $v look)" <<<"$blog"'
  if [ "$v" -ge 18 ]; then check "iOS $v: Control Center edit and power buttons (iOS 18 redesign)" 'grep -q "id=cc-power" <<<"$blog" && grep -q "id=cc-edit" <<<"$blog"'
  else check "iOS $v: Control Center without the iOS 18 buttons" '! grep -q "id=cc-power" <<<"$blog"'; fi
  check "iOS $v: Settings > General > About"                'grep -q "text=$v.0 (isim)" <<<"$blog"'
done
python3 tests/ui/osversions_check.py "$shots" $versions || fail=1

# device pairing (like Xcode: a device never runs an iOS older than the one it shipped with)
export ISIM_DATA=$base/pairing
plog=$(ISIM_HEADLESS=1 ISIM_SCRIPT="quit" timeout 30 out/bin/isim run "$app" --os 18 --device iphone17 2>&1); prc=$?
check "explicit iOS 18 on iPhone 17 is rejected"           '[ $prc = 2 ] && grep -q "iPhone 17 requires iOS 26.0 or later" <<<"$plog"'
plog=$(ISIM_HEADLESS=1 ISIM_SCRIPT="quit" timeout 30 out/bin/isim run "$app" --os 19 2>&1); prc=$?
check "unsupported versions are rejected"                  '[ $prc = 2 ] && grep -q "iOS 19 is not supported" <<<"$plog"'
plog=$(ISIM_HEADLESS=1 ISIM_SCRIPT="wait 0.5; quit" timeout 30 out/bin/isim run "$app" --device iphone17 2>&1)
check "no --os on iPhone 17: nearest valid version, logged" 'grep -q "using iOS 26.0 instead of the default iOS 18.0" <<<"$plog" && grep -q "^hov version 26.0 " <<<"$plog"'
plog=$(ISIM_HEADLESS=1 ISIM_SCRIPT="wait 0.5; quit" timeout 30 out/bin/isim run "$app" --os 17.5 --device ipadpro11 2>&1)
check "point releases (17.5 on iPad Pro 11-inch)"          'grep -q "^hov version 17.5 process 17.5.0" <<<"$plog"'
plog=$(ISIM_HEADLESS=1 ISIM_SCRIPT="quit" timeout 30 out/bin/isim run "$app" --os 17 --device ipadpro11 2>&1); prc=$?
check "iOS 17.0 on an iPad first sold with 17.5 is rejected" '[ $prc = 2 ] && grep -q "requires iOS 17.5 or later" <<<"$plog"'
# the device data remembers --os
export ISIM_DATA=$base/remember
timeout 30 out/bin/isim boot --os 27 --device iphone17 --headless --script "wait 0.5; quit" >/dev/null 2>&1
plog=$(ISIM_HEADLESS=1 ISIM_SCRIPT="wait 0.5; quit" timeout 30 out/bin/isim run "$app" --device iphone17 2>&1)
check "a booted device remembers its iOS version"          'grep -q "^hov version 27.0 " <<<"$plog" && [ "$(cat "$ISIM_DATA/Library/isim/os-version")" = 27.0 ]'
plog=$(ISIM_OS_VERSION=26 ISIM_HEADLESS=1 ISIM_SCRIPT="wait 0.5; quit" timeout 30 out/bin/isim run "$app" --device iphone17 2>&1)
check "ISIM_OS_VERSION selects the version too"            'grep -q "^hov version 26.0 " <<<"$plog"'
vout=$(out/bin/isim version); dout=$(out/bin/isim devices)
check "isim version lists the iOS versions"                'grep -q "iOS versions: 17, 18 (default), 26, 27" <<<"$vout" && grep -q "iOS 26.0" <<<"$vout"'
check "isim devices shows the versions per device"      'grep -Eq "^iphone17 +iPhone 17 +26.0 27.0$" <<<"$dout" && grep -Eq "^iphone15 +iPhone 15 +17.0 18.0 26.0 27.0$" <<<"$dout" && grep -Eq "^ipadpro11 .* 17.5 18.0 26.0 27.0$" <<<"$dout"'
exit $fail
