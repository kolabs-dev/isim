#!/usr/bin/env bash
# Run every isim test suite. Build first with ./build.sh.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
status=0
run() { echo "=== $1"; shift; "$@" || status=1; }
run "loader (experiments/03)" ../experiments/03-loader/tests/run.sh
run "foundation self-test" bash -c 'out/bin/isim run out/apps/FoundationTest.app | tail -3; exit ${PIPESTATUS[0]}'
run "ui: HelloCounter (Objective-C)" tests/ui/hellocounter.sh HelloCounter
if [ -x out/apps/HelloCounterSwift.app/HelloCounterSwift ]; then   # Swift, systemOrange light/dark
  run "ui: HelloCounterSwift (Swift)" tests/ui/hellocounter.sh HelloCounterSwift "255 149 0" "255 159 10"
fi
if [ -x out/apps/HelloKeyboard.appex/HelloKeyboard ]; then         # Swift keyboard extension in the keyboard host
  run "ui: HelloKeyboard (keyboard extension)" tests/ui/keyboard.sh
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
echo; [ $status = 0 ] && echo "ALL SUITES PASSED" || echo "SOME SUITES FAILED"
exit $status
