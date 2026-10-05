#!/usr/bin/env bash
# Run every isim test suite. Build first with ./build.sh.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
status=0
export ISIM_STANDALONE=1     # `isim run` runs each test app alone (no home screen, nothing installed on the device)
run() { echo "=== $1"; shift; "$@" || status=1; }
run "loader" tests/loader/run.sh
run "foundation self-test" bash -c 'out/bin/isim run out/apps/FoundationTest.app | tail -3; exit ${PIPESTATUS[0]}'
run "ui: HelloCounter (Objective-C)" tests/ui/hellocounter.sh HelloCounter
if [ -x out/apps/HelloCounterSwift.app/HelloCounterSwift ]; then   # Swift, systemOrange light/dark
  run "ui: HelloCounterSwift (Swift)" tests/ui/hellocounter.sh HelloCounterSwift "255 149 0" "255 159 10"
fi
if [ -x out/apps/HelloKeyboard.appex/HelloKeyboard ]; then         # Swift keyboard extension in the keyboard host
  run "ui: HelloKeyboard (keyboard extension)" tests/ui/keyboard.sh
fi
if [ -x out/apps/HelloKeyboardApp.app/HelloKeyboardApp ]; then   # UIScrollView, UITextField, system keyboard, in-process extension
  run "ui: HelloKeyboardApp (system keyboard + embedded extension)" tests/ui/keyboard-app.sh
fi
if [ -x out/apps/HelloSwiftUI.app/HelloSwiftUI ]; then           # isim SwiftUI
  run "ui: HelloSwiftUI (SwiftUI)" tests/ui/swiftui.sh
  [ -x out/apps/HelloPresentations.app/HelloPresentations ] && run "ui: HelloPresentations (sheets, alerts, dialogs)" tests/ui/presentations.sh
fi
if [ -x out/sdk/Applications/Settings.app/Settings ]; then          # device shell: home screen + Settings
  run "ui: isim boot (home screen, Settings, multitasking)" tests/ui/boot.sh
fi
if [ -x out/apps/SwiftEmbeddedTest.app/SwiftEmbeddedTest ]; then
  run "swift (embedded) self-test" bash -c 'out/bin/isim run out/apps/SwiftEmbeddedTest.app/SwiftEmbeddedTest | tail -1; exit ${PIPESTATUS[0]}'
fi
if [ -x out/apps/SwiftFoundationTest.app/SwiftFoundationTest ]; then
  run "swift <-> Foundation interop" bash -c 'out/bin/isim run out/apps/SwiftFoundationTest.app/SwiftFoundationTest 2>/dev/null | tail -1; exit ${PIPESTATUS[0]}'
fi
if [ -x out/apps/SwiftFullTest.app/SwiftFullTest ]; then
  run "swift (full runtime) self-test" bash -c 'out/bin/isim run out/apps/SwiftFullTest.app/SwiftFullTest | tail -1; exit ${PIPESTATUS[0]}'
fi
if [ -x out/apps/SwiftConcurrencyTest.app/SwiftConcurrencyTest ]; then
  run "swift concurrency (async/await, actors, MainActor)" bash -c 'timeout 60 out/bin/isim run out/apps/SwiftConcurrencyTest.app/SwiftConcurrencyTest | tail -1; exit ${PIPESTATUS[0]}'
fi
if [ -x out/apps/SwiftLibrariesTest.app/SwiftLibrariesTest ]; then
  run "swift libraries (Dispatch, Combine, JSON/Codable, Calendar, ...)" bash -c 'timeout 60 out/bin/isim run out/apps/SwiftLibrariesTest.app/SwiftLibrariesTest | tail -1; exit ${PIPESTATUS[0]}'
fi
echo; [ $status = 0 ] && echo "ALL SUITES PASSED" || echo "SOME SUITES FAILED"
exit $status
