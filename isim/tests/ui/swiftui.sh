#!/usr/bin/env bash
# UI test: the HelloSwiftUI sample on isim's SwiftUI — state, onChange, task, Form layout,
# text input with @FocusState, toolbar items, NavigationLink push/pop.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloSwiftUI; mkdir -p "$shots"; rm -f "$shots"/*.png
log=$(ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 0.5; tapid increment; tapid increment; tapid name-field; wait 0.1; tapid isim-kb-a; tapid isim-kb-d; tapid isim-kb-a; wait 0.1; shot $shots/editing.png; dump; tapid done; wait 0.2; taptext Details; wait 0.2; dump; tapid isim-nav-back; wait 0.2; tapid reset; wait 0.2; dump; quit" \
      timeout 40 out/bin/isim run out/apps/HelloSwiftUI.app 2>&1); rc=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "@State + onChange(old,new)"        'grep -q "count 0 -> 1" <<<"$log" && grep -q "count 1 -> 2" <<<"$log"'
check ".task runs (MainActor) and updates" 'grep -q "task finished" <<<"$log" && grep -q "text=Loaded by .task" <<<"$log"'
check "LabeledContent shows the count"    'grep -q "text=2" <<<"$log"'
check "section headers uppercased"        'grep -q "text=COUNTER" <<<"$log"'
check "TextField + system keyboard"       'grep -q "text=\"Ada\" (editing)" <<<"$log"'
check "footer follows the binding"        'grep -q "text=Hello, Ada!" <<<"$log"'
check "@FocusState + toolbar Done"        'grep -q "editing true" <<<"$log" && grep -q "editing false" <<<"$log" && grep -q "id=done" <<<"$log"'
check "NavigationLink pushes (inline)"    'grep -q "text=The counter is at 2." <<<"$log"'
check "back pops, root state kept"        'grep -q "count 2 -> 0" <<<"$log"'
check "exits cleanly"                     '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
