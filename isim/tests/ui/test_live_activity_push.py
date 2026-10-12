"""ActivityKit beyond request/update/end (HelloWidgets): push updates (pushType .token, pushTokenUpdates; `push` with
an APNs liveactivity payload: aps.event update / end / start, content-state, timestamp, stale-date, dismissal-date,
alert), push-to-start (pushToStartTokenUpdates, attributes-type / attributes; Activity.activityUpdates), alerts (the
Dynamic Island expands for a while; on the lock screen the activity lights up), stale dates (context.isStale,
activityState .stale), two activities in the island (minimal: one attached, one detached), contentUpdates /
activityStateUpdates, and dismissal policies (.immediate, .after(date): the ended activity stays on the lock screen
until then)."""
import json
import re
import time

import pytest

from isimtest import mean_rgb

APP = "dev.isim.samples.HelloWidgets"


def push(dev, tmp, name, payload):
    f = tmp / f"{name}.apns"
    f.write_text(json.dumps(payload))
    dev.send(f"push {APP} {f}")


def boot(launch):
    dev = launch(None, install=["HelloWidgets"], env={"ISIM_SUSPEND": "0", "ISIM_LOCK_TIME": "9:41"})
    dev.wait_log(r"isim WidgetKit: \d+ widget kind")
    dev.wait_view(rf"id=app-{re.escape(APP)}")
    dev.wait_still()
    return dev


@pytest.mark.os_matrix
def test_live_activity_push(launch, ios, tmp_path):
    dev = boot(launch)
    dev.send(f"launch {APP}")
    dev.wait_log(r"HelloWidgets: push-to-start token [0-9a-f]{64}")
    dev.wait_tap_id("startDelivery")
    token = dev.wait_log(r"HelloWidgets: push token 42 ([0-9a-f]{64})")[1]
    dev.wait_log(r"Live Activity from .*HelloWidgets.app shown")
    dev.send("home")
    dev.wait_dump(r"id=dynamic-island text=compact")
    now = int(time.time())
    # an update by push: the app sees it in contentUpdates
    push(dev, tmp_path, "update", {"apns-push-token": token, "aps": {"timestamp": now, "event": "update",
                                   "content-state": {"minutes": 5, "status": "Pushed"}}})
    dev.wait_log(r"SpringBoard: Live Activity push update for")
    dev.wait_log(r"HelloWidgets: content 42: 5 min, Pushed")
    dev.wait_log(r"isim shell: Live Activity \S+ updated")
    # an older timestamp is ignored
    push(dev, tmp_path, "old", {"apns-push-token": token, "aps": {"timestamp": now - 10, "event": "update",
                                "content-state": {"minutes": 99, "status": "Old"}}})
    dev.wait_log(r"Live Activity push update for \S+ ignored: timestamp")
    # an alert: the island expands for a while, then compact again
    push(dev, tmp_path, "alert", {"apns-push-token": token, "aps": {"timestamp": now + 1, "event": "update",
                                  "content-state": {"minutes": 2, "status": "Nearby"},
                                  "alert": {"title": "Delivery", "body": "Almost there"}, "sound": "default"}})
    dev.wait_log(r"Live Activity alert \S+: Dynamic Island expanded \(alert\)")
    dev.wait_dump(r"id=dynamic-island text=expanded")
    alert = dev.wait_shot(lambda s: sum(mean_rgb(s, (20, 130, 30, 20))) < 0.1 * 255, "the island expanded for the alert")
    dev.wait_log(r"isim shell: Dynamic Island compact \(alert ended\)")
    dev.wait_dump(r"id=dynamic-island text=compact")
    # a stale date: rendered again stale (grey on the lock screen), activityState .stale
    dev.send(f"launch {APP}")
    dev.wait_tap_id("staleDelivery")
    dev.wait_log(r"HelloWidgets: stale date set")
    dev.wait_log(r"SpringBoard: Live Activity \S+ is stale; rendering it again")
    dev.wait_log(r"rendered Live Activity DeliveryAttributes \(lock screen, Dynamic Island\) stale")
    dev.wait_log(r"HelloWidgets: state 42: stale")
    dev.send("lock")
    dev.wait_log(r"isim shell: locked")
    lock_frame = dev.wait_dump(r"IsimLiveActivity \((\S+) (\S+); (\S+) x (\S+)\) id=live-activity ")
    lx, ly = float(lock_frame[1]), float(lock_frame[2])

    def grey(s):
        c = mean_rgb(s, (lx + 4, ly + 70, 10, 10))           # the left padding, half way down
        return 120 < c[0] < 190 and abs(c[0] - c[2]) < 12
    stale = dev.wait_shot(grey, "the stale activity's grey tint")
    # a push alert while locked: the lock screen lights up
    push(dev, tmp_path, "alert2", {"apns-push-token": token, "aps": {"timestamp": now + 2, "event": "update",
                                   "content-state": {"minutes": 1, "status": "At the door"}, "alert": {"title": "Here", "body": "At the door"}}})
    dev.wait_log(r"Live Activity alert \S+: the lock screen lights up")
    dev.wait_log(r"HelloWidgets: state 42: active")                         # fresh content: no longer stale
    dev.send("unlock")
    dev.wait_log(r"isim shell: unlocked")
    # a second activity: both minimal, one attached to the island and one detached
    dev.send(f"launch {APP}")
    dev.wait_tap_id("startPickup")
    dev.wait_log(r"HelloWidgets: started pickup, 2 active")
    dev.wait_log(r"Live Activity from .*HelloWidgets.app shown", count=2)
    dev.send("home")
    two = dev.wait_dump(r"id=dynamic-island-detached text=minimal").string
    dev.wait_still()
    minimal = dev.screenshot("minimal")
    dev.send("island detached")
    dev.wait_log(r"isim shell: Dynamic Island expanded")
    dev.send("island")
    dev.wait_log(r"isim shell: Dynamic Island minimal")
    # end by push with a dismissal date: out of the island now, on the lock screen until then
    push(dev, tmp_path, "end", {"apns-push-token": token, "aps": {"timestamp": now + 3, "event": "end",
                                "content-state": {"minutes": 0, "status": "Delivered"}, "dismissal-date": int(time.time()) + 4}})
    dev.wait_log(r"Live Activity push end for")
    dev.wait_log(r"Live Activity ended \(\S+; stays on the lock screen\)")
    dev.wait_log(r"HelloWidgets: state 42: ended")
    dev.wait_dump(r"id=dynamic-island text=compact")                       # only the pickup is left in the island
    dev.send("lock")
    dev.wait_log(r"isim shell: locked", count=2)
    ended = dev.wait_dump(r"id=live-activity-2 ").string
    dev.wait_log(r"isim shell: Live Activity \S+ dismissed")
    dev.wait_log(r"HelloWidgets: state 42: dismissed")
    dev.send("unlock")
    dev.wait_log(r"isim shell: unlocked", count=2)
    # push-to-start: a new activity the app learns about from activityUpdates
    push(dev, tmp_path, "start", {"aps": {"timestamp": now + 4, "event": "start", "attributes-type": "DeliveryAttributes",
                                  "attributes": {"orderNumber": "99"}, "content-state": {"minutes": 20, "status": "Started"},
                                  "alert": {"title": "Order 99", "body": "On its way"}}})
    dev.wait_log(r"SpringBoard: Live Activity push start DeliveryAttributes for Widgets")
    dev.wait_log(r"HelloWidgets: new activity 99 Started")
    dev.wait_log(r"Live Activity from .*HelloWidgets.app shown", count=3)
    dev.send(f"launch {APP}")
    dev.wait_tap_id("endAll")
    dev.wait_log(r"HelloWidgets: ended all")
    assert dev.quit() == 0
    log = dev.log
    assert re.search(r"isim ActivityKit: push token for \S+: " + token, log), "pushType .token gives a push token"
    assert "content 42: 99 min" not in log, "a push older than the last one is ignored"
    assert sum(mean_rgb(alert, (20, 130, 30, 20))) < 0.1 * 255
    assert grey(stale), "isStale: the activity's view is rendered again (grey tint)"
    assert "id=dynamic-island text=minimal" in two and "id=dynamic-island-detached text=minimal" in two, \
        "two activities: minimal, attached and detached"
    a = re.search(r"\((\S+) 11; (\S+) x 37\) id=dynamic-island text=minimal", two)
    d = re.search(r"\((\S+) 11; 37 x 37\) id=dynamic-island-detached", two)
    assert a and d and float(d[1]) > float(a[1]) + float(a[2]), "the detached one is on the trailing side"
    assert minimal.size[0] < minimal.size[1]
    assert "id=live-activity-2 " in ended, "the ended activity stays on the lock screen until its dismissal date"
    assert re.search(r"HelloWidgets: state 42: ended[\s\S]*HelloWidgets: state 42: dismissed", log)


def test_live_activity_dismissal_policies(launch):
    dev = boot(launch)
    dev.send(f"launch {APP}")
    dev.wait_tap_id("startDelivery")
    dev.wait_log(r"Live Activity from .*HelloWidgets.app shown")
    dev.wait_tap_id("endDeliveryLater")                                     # .after(now + 3 s)
    dev.wait_log(r"isim ActivityKit: ended Live Activity \S+ \(after")
    dev.wait_log(r"Live Activity ended \(\S+; stays on the lock screen\)")
    dev.send("lock")
    dev.wait_log(r"isim shell: locked")
    dev.wait_dump(r"id=live-activity ")
    dev.wait_log(r"isim shell: Live Activity \S+ dismissed")
    dev.wait_log(r"HelloWidgets: state 42: dismissed")
    dev.send("unlock")
    dev.wait_log(r"isim shell: unlocked")
    dev.send(f"launch {APP}")
    dev.wait_tap_id("startDelivery")
    dev.wait_log(r"Live Activity from .*HelloWidgets.app shown", count=2)
    dev.wait_tap_id("endDelivery")                                          # .immediate
    dev.wait_log(r"Live Activity ended \(\S+; dismissed\)")
    dev.wait_log(r"HelloWidgets: state 42: dismissed", count=2)
    dev.wait_tap_id("alertDelivery")                                        # ended: the update is ignored
    dev.wait_log(r"has ended; update ignored")
    assert dev.quit() == 0
