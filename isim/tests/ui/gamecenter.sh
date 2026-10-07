#!/usr/bin/env bash
# UI test: isim's local Game Center (HelloGameCenter sample, isim-GameCenter.json). Run 1: sign-in, the
# access point (shown top trailing; tapping it opens the dashboard; hidden while Game Center UI is up),
# scores on classic / low-is-best / recurring (6 s period) leaderboards and a leaderboard set, achievement
# descriptions + points in the dashboard, loadPhoto (generated monogram), friends, the friend request
# composer, saving a game, the matchmaker (finds nobody). Then `isim gamecenter ... conflict` adds a version
# from another device; run 2 fetches saved games, gets the conflict and resolves it.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloGameCenter; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/gamecenter; rm -rf "$ISIM_DATA"
export ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1
app=dev.isim.samples.HelloGameCenter
s1="wait 2; shot $shots/access-point.png; dump; tapid scores; wait 0.5; tapid achievements; wait 1; shot $shots/banner.png; wait 2.5; tapid metadata; wait 1"
s1="$s1; tapid gc-access-point; wait 1.2; shot $shots/dashboard.png; dump; tapid gc-achievements; wait 1; shot $shots/achievements.png; dump; tapid gc-done; wait 1"
s1="$s1; tapid set; wait 1; shot $shots/set.png; dump; tapid gc-board-dev.isim.gc.fastest; wait 0.8; dump; tapid gc-done; wait 1"
s1="$s1; tapid photo; wait 0.5; tapid friend-request; wait 1; shot $shots/friend-request.png; tapid gc-friend-to; wait 0.3; type pat@example.com; wait 0.3; tapid gc-friend-send; wait 1"
s1="$s1; tapid save; wait 0.5; tapid match; wait 1; tapid gc-match-find; wait 0.3; shot $shots/matchmaker.png; dump; tapid gc-match-cancel; wait 1; quit"
log1=$(ISIM_SCRIPT="$s1" timeout 90 out/bin/isim run out/apps/HelloGameCenter.app 2>&1); rc1=$?
conflict=$(out/bin/isim gamecenter $app conflict slot1 "from the iPad" 2>&1)
log2=$(ISIM_SCRIPT="wait 2; tapid fetch; wait 1; tapid fetch; wait 1; quit" timeout 60 out/bin/isim run out/apps/HelloGameCenter.app 2>&1); rc2=$?
saves=$(out/bin/isim gamecenter $app saved-games 2>&1)

fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "signed in + access point top trailing"        'grep -q "authenticated: true" <<<"$log1" && grep -q "access point shown (top trailing)" <<<"$log1" && grep -q "^UIWindow (338 66; 48 x 48)$" <<<"$log1"'
check "achievement descriptions from config"         'grep -q "achievement description: dev.isim.gc.first_win \"First Win\" 10 points hidden=false \"Win a game.\"" <<<"$log1" && grep -q "dev.isim.gc.secret \"Secret Door\" 50 points hidden=true" <<<"$log1"'
check "leaderboard titles, types, best scores"       'grep -q "leaderboard: dev.isim.gc.high_score \"High Score\" type=classic best=1200 players=1" <<<"$log1" && grep -q "leaderboard: dev.isim.gc.fastest \"Fastest Clear\" type=classic best=42" <<<"$log1"'
# the 1200 posted ~4 s earlier is in the current 6 s occurrence or (after a reset) in the previous one
check "recurring leaderboard: 6 s occurrences"       '(grep -q "leaderboard: dev.isim.gc.daily \"Daily Run\" type=recurring best=1200 players=1 period=6s" <<<"$log1" && grep -q "previous occurrence best=-1" <<<"$log1") || (grep -q "leaderboard: dev.isim.gc.daily \"Daily Run\" type=recurring best=-1 players=0 period=6s" <<<"$log1" && grep -q "previous occurrence best=1200" <<<"$log1")'
check "leaderboard set + images"                     'grep -q "set: dev.isim.gc.set.season1 \"Season 1\" boards=dev.isim.gc.high_score,dev.isim.gc.fastest" <<<"$log1" && [ $(grep -c "leaderboard image .*: true" <<<"$log1") = 3 ]'
check "access point opens the dashboard"             'grep -q "access point opens Game Center" <<<"$log1" && grep -q "id=gc-achievements-summary text=1 of 2 Completed · 10 points" <<<"$log1"'
check "dashboard achievements: titles, descriptions" 'grep -q "text=You won your first game." <<<"$log1" && grep -q "text=Collect 100 gems." <<<"$log1" && grep -q "text=40% complete · 25 points" <<<"$log1" && ! grep -q "text=Secret Door" <<<"$log1"'
check "leaderboard set page"                         'grep -q "id=gc-board-dev.isim.gc.high_score" <<<"$log1" && grep -q "text=Season 1" <<<"$log1" && grep -q "text=Fastest Clear" <<<"$log1"'
check "dashboard closes via delegate"                'grep -q "dashboard closed" <<<"$log1"'
check "player photo + empty friends list"            'grep -q "photo: 128x128 true" <<<"$log1" && grep -q "friends: 0" <<<"$log1"'
check "friend request composer (not sent)"           'grep -q "friend request to pat@example.com not sent" <<<"$log1"'
check "saved game stored in device data"             'grep -q "saved: slot1 on iPhone true" <<<"$log1" && [ -f "$ISIM_DATA/Library/GameCenter/$app/SavedGames/slot1/versions.json" ]'
check "matchmaker finds nobody, cancels"             'grep -q "findMatch: match=false error=true" <<<"$log1" && grep -q "id=gc-match-note text=No players found" <<<"$log1" && grep -q "matchmaker cancelled" <<<"$log1"'
check "saved-game conflict detected"                 'grep -q "now has 2 versions" <<<"$conflict" && grep -q "saved games conflict: 2 versions of slot1 from Other Device,iPhone" <<<"$log2"'
check "conflict resolved"                            'grep -q "resolved: 1 saved game" <<<"$log2" && grep -q "resolved data: merged" <<<"$log2" && grep -q "fetched: slot1@iPhone$" <<<"$log2" && [ $(grep -c slot1 <<<"$saves") = 1 ]'
check "exits cleanly"                                '[ $rc1 = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- run 1"; grep -v "^ " <<<"$log1" | tail -40; echo "--- run 2"; grep -v "^ " <<<"$log2" | tail -15; echo "$saves"; }
exit $fail
