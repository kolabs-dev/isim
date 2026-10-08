"""isim's local CloudKit + NSPersistentCloudKitContainer + MetricKit (HelloCloudKit). Run 1 taps through saving typed
records (asset, reference, location), paged sorted queries with a cursor, typed fetches and system-field archiving, a
serverRecordChanged conflict and its resolution, the changedKeys policy, subscriptions with in-process push delivery, a
custom zone with an atomic batch and change tokens, Core Data with a CloudKit container, the `metrickit` script command
(Debug > Simulate MetricKit Payloads), and a cascading delete. Run 2: the records persist across launches and
`isim metrickit` (from outside the app) delivers payloads again. Run 3: ISIM_ICLOUD=noAccount -> .noAccount and
CKError.notAuthenticated. Port of tests/ui/cloudkit.sh."""
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
    ("zone", [r"zones: _defaultZone,Work", r"atomic batch: CKError 22,CKError 16", r"zone changes: w1,w3",
              r"zone changes since token: changed=0 deleted=w3:Note"]),
    ("coredata", [r"coredata store: loaded=true options=iCloud\.dev\.isim\.samples\.HelloCloudKit",
                  r"coredata: items=1 isContainer=true", r"keeps its store on the device \(local, no iCloud sync\)"]),
]


def test_cloudkit(launch, device_data):
    app = launch("HelloCloudKit")
    app.wait_log(r"container: iCloud\.dev\.isim\.samples\.HelloCloudKit account=available")
    app.wait_log(r"user record: true")
    app.wait_view(r"text=account: available")                            # default container, account available
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
    app.tap_id("delete")
    app.wait_log(r"deleted n1 \(cascade\): n1=CKError 11 n2=CKError 11")  # delete cascades (.deleteSelf reference)
    app.tap_id("list")
    app.wait_log(r"records: n3,p1,u1")
    assert app.count(r"push: query") == 1, "one query subscription push"
    assert app.count(r"metrickit: metric payload") == 1, "MetricKit: one payload, from the script command"
    assert app.quit() == 0

    app = launch("HelloCloudKit")                                        # relaunch: the records persist
    app.wait_tap_id("list")
    app.wait_log(r"records: n3,p1,u1")
    mk = subprocess.run([str(ISIM), "metrickit"], env=dict(os.environ, ISIM_DATA=str(device_data)),
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True).stdout
    assert "simulated MetricKit payloads requested" in mk, mk
    app.wait_log(r"metrickit: metric payload")                           # isim metrickit reaches the running app
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
