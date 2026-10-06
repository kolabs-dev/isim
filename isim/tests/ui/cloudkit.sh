#!/usr/bin/env bash
# UI test: isim's local CloudKit + NSPersistentCloudKitContainer + MetricKit (HelloCloudKit sample). Run 1 taps
# through saving typed records (asset, reference, location), paged sorted queries with a cursor, typed fetches and
# system-field archiving, a serverRecordChanged conflict and its resolution, the changedKeys policy, subscriptions
# with in-process push delivery, a custom zone with an atomic batch and change tokens, Core Data with a CloudKit
# container, the `metrickit` script command (Debug > Simulate MetricKit Payloads), and a cascading delete. Run 2:
# the records persist across launches and `isim metrickit` (from outside the app) delivers payloads again.
# Run 3: ISIM_ICLOUD=noAccount -> .noAccount and CKError.notAuthenticated.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloCloudKit; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/cloudkit; rm -rf "$ISIM_DATA"
export ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1
s1="wait 2; shot $shots/home.png; dump; tapid save; wait 1; tapid query; wait 1; tapid fetch; wait 1; tapid conflict; wait 1; tapid subscribe; wait 1.5"
s1="$s1; tapid zone; wait 1.5; tapid coredata; wait 1; metrickit; wait 1.5; tapid delete; wait 1; tapid list; wait 1; quit"
log1=$(ISIM_SCRIPT="$s1" timeout 90 out/bin/isim run out/apps/HelloCloudKit.app 2>&1); rc1=$?
ISIM_SCRIPT="wait 2; tapid list; wait 3; quit" timeout 60 out/bin/isim run out/apps/HelloCloudKit.app > "$ISIM_DATA/run2.log" 2>&1 &
pid=$!
sleep 3
mk=$(out/bin/isim metrickit 2>&1)
wait $pid; rc2=$?
log2=$(cat "$ISIM_DATA/run2.log")
log3=$(ISIM_ICLOUD=noAccount ISIM_SCRIPT="wait 2; tapid list; wait 1; tapid save; wait 1; quit" timeout 60 out/bin/isim run out/apps/HelloCloudKit.app 2>&1); rc3=$?
store=$ISIM_DATA/Library/isim/CloudKit/iCloud.dev.isim.samples.HelloCloudKit

fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "default container, account available"          'grep -q "container: iCloud.dev.isim.samples.HelloCloudKit account=available" <<<"$log1" && grep -q "user record: true" <<<"$log1" && grep -q "text=account: available" <<<"$log1"'
check "save typed records (local store)"               'grep -q "saved 3 notes; changeTag=true changedKeys(before)=8" <<<"$log1" && [ -f "$store/private.json" ] && [ -n "$(ls "$store/Assets")" ]'
check "query: predicate, sort, cursor paging"          'grep -q "query page 1: Third cursor=true" <<<"$log1" && grep -q "query page 2: Second more=false" <<<"$log1"'
check "query: OR / BEGINSWITH / CONTAINS on lists"     'grep -q "query or/contains: First,Third" <<<"$log1" && grep -q "query unknown type: CKError 11" <<<"$log1"'
check "fetch: String/Int/Double/list/Date/Data/CLLocation/CKAsset" 'grep -q "fetched: title=First count=1 rating=1.5 tags=isim+note1 created=1700000001.0 blob=4 lat=38.33 asset=asset bytes type=Note dates=true" <<<"$log1"'
check "encodeSystemFields round trip, unknownItem"     'grep -q "system fields: n1 tag=true keys=0" <<<"$log1" && grep -q "fetch missing: unknownItem" <<<"$log1"'
check "conflict: serverRecordChanged + resolution"     'grep -q "conflict: serverRecordChanged server=Second (phone) client=Second (stale)" <<<"$log1" && grep -q "conflict resolved: Second (merged)" <<<"$log1"'
check "savePolicy .changedKeys merges one key"         'grep -q "changedKeys save: title=Second (merged) count=20" <<<"$log1"'
check "subscriptions saved and listed"                 'grep -q "subscriptions: everything,urgent-notes" <<<"$log1"'
check "query subscription push (in-process)"           'grep -q "push: query subscription=urgent-notes reason=created record=u1 title=Urgent: call back alert=An urgent note changed" <<<"$log1" && [ $(grep -c "push: query" <<<"$log1") = 1 ]'
check "database subscription push"                     'grep -q "push: database subscription=everything" <<<"$log1"'
check "custom zone, atomic batch fails together"       'grep -q "zones: _defaultZone,Work" <<<"$log1" && grep -q "atomic batch: CKError 22,CKError 16" <<<"$log1"'
check "zone changes + change token + deletions"        'grep -q "zone changes: w1,w3" <<<"$log1" && grep -q "zone changes since token: changed=0 deleted=w3:Note" <<<"$log1"'
check "NSPersistentCloudKitContainer (local)"          'grep -q "coredata store: loaded=true options=iCloud.dev.isim.samples.HelloCloudKit" <<<"$log1" && grep -q "coredata: items=1 isContainer=true" <<<"$log1" && grep -q "keeps its store on the device (local, no iCloud sync)" <<<"$log1"'
check "MetricKit: nothing by itself, script command"   'grep -q "metrickit: subscribed, past payloads 0" <<<"$log1" && [ $(grep -c "metrickit: metric payload" <<<"$log1") = 1 ]'
check "MetricKit metric payload"                       'grep -q "metrickit: metric payload app=1.0 cpu=100.0 s peakMemory=200000.0 launchBuckets=3 exits=1 json=true" <<<"$log1"'
check "MetricKit diagnostic payload"                   'grep -q "metrickit: diagnostic payload crashes=1 signal=11 hangs=1 callStack=true json=true" <<<"$log1"'
check "delete cascades (.deleteSelf reference)"        'grep -q "deleted n1 (cascade): n1=CKError 11 n2=CKError 11" <<<"$log1" && grep -q "records: n3,p1,u1" <<<"$log1"'
check "relaunch: records persist"                      'grep -q "records: n3,p1,u1" <<<"$log2"'
check "isim metrickit reaches the running app"         'grep -q "simulated MetricKit payloads requested" <<<"$mk" && grep -q "metrickit: metric payload" <<<"$log2"'
check "ISIM_ICLOUD=noAccount: notAuthenticated"        'grep -q "account=noAccount" <<<"$log3" && grep -q "user record error: CKError 9" <<<"$log3" && grep -q "list error: CKError 9" <<<"$log3" && grep -q "save error: CKError 9" <<<"$log3"'
check "exits cleanly"                                  '[ $rc1 = 0 ] && [ $rc2 = 0 ] && [ $rc3 = 0 ]'
[ $fail = 0 ] || { echo "--- run 1"; grep -v "^ " <<<"$log1" | tail -50; echo "--- run 2"; grep -v "^ " <<<"$log2" | tail -10; echo "--- run 3"; grep -v "^ " <<<"$log3" | tail -10; }
exit $fail
