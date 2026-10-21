"""isim's local CloudKit + NSPersistentCloudKitContainer + MetricKit (HelloCloudKit). Run 1 taps through saving typed
records (asset, reference, location), paged sorted queries with a cursor, typed fetches and system-field archiving, a
serverRecordChanged conflict and its resolution, the changedKeys policy, subscriptions with in-process push delivery, a
custom zone with an atomic batch and change tokens, Core Data with a CloudKit container, the `metrickit` script command
(Debug > Simulate MetricKit Payloads), and a cascading delete. Run 2: the records persist across launches and
`isim metrickit` (from outside the app) delivers payloads again. Then the share's link is opened as other Apple
Accounts (an invited participant, a public user) to read its metadata and accept it, and the owner stops sharing in the
sharing sheet (CKSystemSharingUIObserver). Run 3: ISIM_ICLOUD=noAccount -> .noAccount and
CKError.notAuthenticated. Port of tests/ui/cloudkit.sh."""
import json
import os
import subprocess

from isimtest import ISIM

STEPS = [   # (button, log lines it leads to)
    ("save", [r"saved 3 notes; changeTag=true changedKeys\(before\)=8"]),
    ("query", [r"query page 1: Third cursor=true", r"query page 2: Second more=false", r"query or/contains: First,Third",
               r"query unknown type: CKError 11"]),
    ("fetch", [r"fetched: title=First count=1 rating=1\.5 tags=isim\+note1 created=1700000001\.0 blob=4 lat=38\.33 "
               r"asset=asset bytes type=Note dates=true", r"system fields: n1 tag=true keys=0",
               r"fetch missing: unknownItem"]),
    ("conflict", [r"conflict: serverRecordChanged server=Second \(phone\) client=Second \(stale\)",
                  r"conflict resolved: Second \(merged\)", r"changedKeys save: title=Second \(merged\) count=20"]),
    ("subscribe", [r"subscriptions: everything,urgent-notes",
                   r"push: query subscription=urgent-notes reason=created record=u1 title=Urgent: call back "
                   r"alert=An urgent note changed", r"push: database subscription=everything"]),
    ("zone", [r"zones: _defaultZone,Work", r"atomic batch: CKError 22,CKError 16", r"database changes: Work,_defaultZone more=false", r"zone changes: w1,w3",
              r"zone changes since token: changed=0 deleted=w3:Note"]),
    ("share", [r"sharing: saved=true participants=2 permission=2 discovered=true sheet=true", r"share url: true, allowed=true",
               r"operations: zones=Work,_defaultZone subscriptions=2 group=Inspect"]),
    ("accept", [r"share metadata: role=owner permission=3 status=accepted root=.+ owner=Taylor", r"accepted: me=accepted participants=2"]),
    ("sync", [r"sync engine: saved=1 failed=0 pending=0",
              r"sync engine A events: accountChange\(signIn\), willSendChanges, sentRecordZoneChanges\(1 saved, 0 deleted, 0 failed\), "
              r"stateUpdate, didSendChanges",
              r"sync engine B fetched sync1=true, A fetched its own=false, state saved=true",
              r"sync engine B: sync1 failed, serverRecordChanged=true",
              r"sync engine C: zones saved=\[\"Synced\"\]", r"sync engine: saved=1 failed=0 pending=0"]),
    ("swiftdata", [r"swiftdata: models=1 title=Local model changes=false"]),
    ("coredata", [r"coredata event: setup succeeded=true", r"coredata store: loaded=true options=iCloud\.dev\.isim\.samples\.HelloCloudKit",
                  r"coredata event: export succeeded=true",
                  r"coredata: items=1 isContainer=true", r"keeps its store on the device \(local, no iCloud sync\)"]),
]


def test_cloudkit(launch, device_data):
    app = launch("HelloCloudKit")
    app.wait_log(r"container: iCloud\.dev\.isim\.samples\.HelloCloudKit account=available")
    app.wait_log(r"user record: true")
    app.wait_view(r"text=account: available")                            # default container, account available
    app.screenshot("data-persistence")                                  # PR visual evidence: the added sharing/sync/SwiftData controls
    app.wait_log(r"metrickit: subscribed, past payloads 0")              # MetricKit: nothing by itself
    for button, lines in STEPS:
        app.wait_tap_id(button)
        for line in lines:
            app.wait_log(line)
    store = device_data / "Library/isim/CloudKit/iCloud.dev.isim.samples.HelloCloudKit"
    assert (store / "private.json").is_file() and any((store / "Assets").iterdir()), "save typed records (local store)"
    app.send("metrickit")
    app.wait_log(r"metrickit: metric payload app=1\.0 cpu=100\.0 s peakMemory=200000\.0 launchBuckets=3 exits=1 json=true")
    app.wait_log(r"metrickit: diagnostic payload crashes=1 signal=11 hangs=1 callStack=true json=true")
    app.tap_id("sheet")                                                  # the sharing sheet saves: CKSystemSharingUIObserver
    app.wait_view(r"text=Stop Sharing")
    app.wait_view(r"id=cloudSharing-title text=Notes")                   # iOS's sheet: the item, People, Share Options
    app.wait_view(r"text=Taylor \w+ \(Me\)")                            # the owner: the device's account
    app.wait_view(r"text=Invited · Can make changes")
    app.wait_view(r"text=Anyone with the link")
    app.wait_still()
    app.screenshot("sharing-sheet")                                      # PR visual evidence: the sharing sheet
    app.wait_tap_id("cloudSharing-options")                              # the link's permission: view only -> can make changes
    app.wait_tap_id("cloudSharing-permission-readWrite")
    app.wait_log(r"sharing sheet options: Anyone with the link, Can make changes")
    app.wait_still()
    app.screenshot("sharing-options")
    app.wait_tap_id("nav-back")
    app.wait_view(r"text=Anyone with the link can make changes\.")
    app.wait_tap_id("cloudSharing-done")                                 # Done saves the share (checked below, as Jordan)
    app.wait_log(r"sharing sheet: did save")
    app.wait_log(r"sharing ui saved n3 ok=true")
    app.tap_id("delete")
    app.wait_log(r"deleted n1 \(cascade\): n1=CKError 11 n2=CKError 11")  # delete cascades (.deleteSelf reference)
    app.tap_id("list")
    app.wait_log(r"records: n3,p1,sync1,u1")
    assert app.count(r"push: query") == 1, "one query subscription push"
    assert app.count(r"metrickit: metric payload") == 1, "MetricKit: one payload, from the script command"
    assert app.quit() == 0

    app = launch("HelloCloudKit")                                        # relaunch: the records persist
    app.wait_tap_id("list")
    app.wait_log(r"records: n3,p1,sync1,u1")
    mk = subprocess.run([str(ISIM), "metrickit"], env=dict(os.environ, ISIM_DATA=str(device_data)),
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True).stdout
    assert "simulated MetricKit payloads requested" in mk, mk
    app.wait_log(r"metrickit: metric payload")                           # isim metrickit reaches the running app
    assert app.quit() == 0

    account = device_data / "Library/isim/AppleAccount/account.json"     # the device's Apple Account plays the participants
    def sign_in(first, email):
        account.parent.mkdir(parents=True, exist_ok=True)
        account.write_text(json.dumps({"firstName": first, "lastName": "Example", "email": email, "signedIn": True}))
    sign_in("Casey", "casey@example.com")                                # invited (read-write, pending)
    app = launch("HelloCloudKit")
    app.wait_tap_id("accept")
    app.wait_log(r"share metadata: role=privateUser permission=3 status=pending root=.+ owner=Taylor")
    app.wait_log(r"accepted: me=accepted participants=2")
    assert app.quit() == 0
    sign_in("Jordan", "jordan@example.com")                              # not invited: the link's permission, set in the sheet
    app = launch("HelloCloudKit")
    app.wait_tap_id("accept")
    app.wait_log(r"share metadata: role=publicUser permission=3 status=unknown root=.+ owner=Taylor")
    app.wait_log(r"accepted: me=accepted participants=3")
    assert app.quit() == 0
    sign_in("Taylor", "taylor@example.com")                              # the owner stops sharing in the sheet
    app = launch("HelloCloudKit")
    app.wait_tap_id("sheet")
    app.wait_tap_id("cloudSharing-stop")
    app.wait_log(r"sharing sheet: did stop")
    app.wait_log(r"sharing ui stopped n3 share deleted=true")
    assert app.quit() == 0


def test_no_account(launch):
    app = launch("HelloCloudKit", env={"ISIM_ICLOUD": "noAccount"})
    app.wait_log(r"account=noAccount")
    app.wait_log(r"user record error: CKError 9")
    app.wait_tap_id("list")
    app.wait_log(r"list error: CKError 9")
    app.tap_id("save")
    app.wait_log(r"save error: CKError 9")                               # notAuthenticated
    assert app.quit() == 0
