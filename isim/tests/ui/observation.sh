#!/usr/bin/env bash
# UI test: Observation (HelloObservation sample) — @Observable store in @State passed with .environment(_:),
# @Environment(Store.self), @Bindable bindings (TextField, Toggle), computed properties updating views.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloObservation; mkdir -p "$shots"; rm -f "$shots"/*.png
log=$(ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 0.8; dump; tapid task-Buy_milk; wait 0.3; tapid draft; wait 0.3; type Eggs; wait 0.2; tapid add; wait 0.5; tapid task-Eggs; wait 0.3; shot $shots/tasks.png; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloObservation.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "@Environment(Store.self) renders the store"   'grep -q "text=2 remaining" <<<"$log" && grep -q "text=Walk the dog" <<<"$log"'
check "@Bindable Toggle updates an @Observable item" 'grep -q "^remaining 1" <<<"$log"'
check "@Bindable TextField + method on the store"    'grep -q "added Eggs" <<<"$log" && grep -q "text=Eggs" <<<"$log"'
check "computed property re-renders"                 'grep -q "text=1 remaining" <<<"$log" && grep -q "^remaining 2" <<<"$log"'
check "exits cleanly"                                '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
