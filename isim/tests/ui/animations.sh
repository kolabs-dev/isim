#!/usr/bin/env bash
# UI test: UIKit animation (HelloAnimations sample) — keyframes (segments in order), layer property animation
# (corner radius, border), UIViewPropertyAnimator (pause, scrub to 50%, reverse back to the start, run to the
# end, stop + finish at the current position, spring, runningPropertyAnimator), transition(with:) flip and
# transition(from:to:) cross dissolve. Mid-animation values come from layer.presentation().
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloAnimations; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/animations; rm -rf "$ISIM_DATA"
script="wait 1; tapid btn-Keyframes; wait 0.3; tapid btn-Report; wait 0.6; tapid btn-Report; wait 0.8;
 tapid btn-Round; wait 0.5; tapid btn-Report; shot $shots/round.png; wait 0.8;
 tapid btn-Animator; wait 0.5; tapid btn-Pause; tapid btn-Scrub; wait 0.2; shot $shots/scrubbed.png; tapid btn-Reverse; wait 1.5;
 tapid btn-Animator; wait 2.4; tapid btn-Animator; wait 0.8; tapid btn-Stop; wait 0.3;
 tapid btn-Flip; wait 0.2; tapid btn-Report; shot $shots/flip.png; wait 1; tapid btn-Swap; wait 0.3; shot $shots/swap.png; wait 0.6;
 tapid btn-Spring; tapid btn-Cubic; wait 1.5; quit"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$script" timeout 60 out/bin/isim run out/apps/HelloAnimations.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
reports=$(grep "^presentation" <<<"$log")
nth() { sed -n "${1}p" <<<"$reports" | grep -o "$2=[0-9-]*" | cut -d= -f2; }
check "keyframe 1 (x) runs before keyframe 2 (y)"   'x=$(nth 1 x); y=$(nth 1 y); [ "$x" -gt 45 ] && [ "$x" -lt 135 ] && [ "$y" = 130 ]'
check "keyframe 2 (y) after keyframe 1 finished"    'x=$(nth 2 x); y=$(nth 2 y); [ "$x" = 140 ] && [ "$y" -gt 135 ] && [ "$y" -lt 325 ]'
check "keyframes complete"                          'grep -q "keyframes done true x=140 y=330" <<<"$log"'
check "layer corner radius/border animate"          'rd=$(nth 3 radius); b=$(nth 3 border); [ "$rd" -gt 12 ] && [ "$rd" -lt 28 ] && [ "$b" -ge 2 ] && [ "$b" -le 6 ] && grep -q "round done radius=40 border=8" <<<"$log"'
check "property animator pauses"                    'grep -q "paused: state active, running false, fraction>0 true" <<<"$log"'
check "fractionComplete scrubs (linear, 50%)"       'grep -q "presentation x=190 y=330 radius=45" <<<"$log"'
check "reversed animator finishes at the start"     'grep -q "animator finished at start, model x=140 radius=40" <<<"$log"'
check "animator runs to the end"                    'grep -q "animator finished at end, model x=240 radius=50" <<<"$log"'
check "stop + finish at the current position"       'grep -q "stopped: state stopped, model x between true" <<<"$log" && grep -q "animator finished at current" <<<"$log"'
check "transition(with:) flip"                      'w=$(nth 5 "card width"); grep -q "flip done: Back" <<<"$log" && [ -n "$w" ]'
check "flip squashes mid-way"                       'sed -n 5p <<<"$reports" | grep -Eq "card width=([0-9]|[0-9][0-9]|1[0-2][0-9])$"'
check "transition(from:to:) cross dissolve"         'grep -q "swap done: A hidden true, B hidden false, alphas 1.0 1.0" <<<"$log"'
check "spring timing parameters"                    'grep -q "spring done y=130" <<<"$log"'
check "runningPropertyAnimator"                     'grep -q "running animator done alpha=0.5 at end" <<<"$log"'
check "exits cleanly"                               '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
