"""WidgetKit and ActivityKit under `isim boot` (HelloWidgets): the widget extension lists its widgets, the gallery
adds them (Edit Home Screen > +), timelines render and switch entries by date and reload at the end, tapping the
interactive widget's Button(intent:) runs the AppIntent in the extension and re-renders, the app's
WidgetCenter.reloadTimelines reloads it; a Live Activity in the Dynamic Island (compact, expanded) and on the lock
screen, updated and ended by the app. Port of tests/ui/widgets.sh."""
import re

from isimtest import mean_rgb

APP = "dev.isim.samples.HelloWidgets"


def test_widgets(launch):
    dev = launch(None, install=["HelloWidgets"])
    dev.wait_log(r"isim WidgetKit: \d+ widget kind")
    dev.wait_view(rf"id=app-{re.escape(APP)}")
    dev.wait_still()
    dev.send(f"holdid app-{APP} 0.8")
    dev.wait_tap_id("menu-edit")
    dev.wait_tap_id("home-add-widget")
    gallery = dev.wait_view(r"id=widget-add-Ticker-systemMedium")
    dev.wait_still()
    dev.screenshot("gallery")
    dev.tap_id("widget-add-Counter-systemSmall")
    dev.wait_log(r"rendered Counter \(systemSmall\)")
    dev.wait_view(r"id=widget-add-", gone=True)
    dev.wait_still()
    dev.wait_tap_id("home-add-widget")
    dev.wait_tap_id("widget-add-Ticker-systemMedium")
    dev.wait_log(r"added widget Ticker")
    dev.wait_view(r"id=widget-add-", gone=True)
    dev.wait_still()
    dev.wait_tap_id("home-done")
    home = dev.wait_view(r"id=widget-Counter-systemSmall text=Counter-systemSmall-0.png")
    dev.wait_still()
    widgets = dev.wait_shot(lambda s: (c := mean_rgb(s, (50, 290, 20, 20)))[2] > 0.9 * 255 and c[0] < 0.2 * 255,
                            "widget pixels: blue counter")
    dev.tap(114, 400)                                                   # the interactive Counter widget
    dev.wait_log(r"counter timeline \(systemSmall\), count 1")
    dev.screenshot("tapped")

    dev.send(f"launch {APP}")
    dev.wait_log(r"HelloWidgets: count 1")
    dev.wait_tap_id("increment")
    dev.wait_log(r"counter timeline \(systemSmall\), count 2")
    dev.tap_id("startDelivery")
    dev.wait_log(r"Live Activity from .*HelloWidgets.app shown")
    dev.send("home")
    dev.wait_dump(r"IsimDynamicIsland .*text=compact")
    dev.screenshot("island")
    dev.send("island")
    dev.wait_log(r"Dynamic Island expanded")
    expanded = dev.wait_shot(lambda s: sum(mean_rgb(s, (20, 130, 30, 20))) < 0.1 * 255,
                             "Dynamic Island: expanded (dark)")
    dev.send("island")
    dev.wait_log(r"Dynamic Island compact")
    dev.send("lock")
    dev.wait_log(r"isim shell: locked")
    dev.wait_dump(r"id=live-activity")
    lock = dev.wait_shot(lambda s: mean_rgb(s, (30, 280, 30, 20))[0] > 0.9 * 255, "lock screen shows the Live Activity")
    dev.send("unlock")
    dev.wait_log(r"isim shell: unlocked")

    dev.send(f"launch {APP}")
    dev.wait_tap_id("updateDelivery")
    dev.wait_log(r"updated Live Activity")
    dev.wait_log(r"rendered Live Activity DeliveryAttributes", count=2)
    dev.send("home")
    dev.wait_dump(r"IsimDynamicIsland")
    dev.send("island")
    dev.wait_log(r"Dynamic Island expanded", count=2)
    dev.screenshot("island-updated")
    dev.send("island")
    dev.wait_log(r"Dynamic Island compact", count=2)
    dev.send(f"launch {APP}")
    dev.wait_tap_id("endDelivery")
    dev.wait_log(r"Live Activity ended")
    dev.send("home")
    dev.wait_dump(r"id=home-dock")
    dev.wait_log(r"widget Ticker shows Ticker-systemMedium-2.png", timeout=30)
    dev.wait_log(r"timeline of Ticker ended; reloading", timeout=30)
    assert dev.quit() == 0, "exits cleanly"
    log = dev.log

    def has(p):
        return re.search(p, log, re.M)
    assert has(r"isim WidgetKit: 2 widget kind\(s\), 1 Live Activity configuration\(s\)") and \
        "id=widget-add-Counter-systemSmall" in gallery and "id=widget-add-Ticker-systemMedium" in gallery, \
        "the extension lists its widgets; the gallery offers them"
    assert has(r"added widget Counter \(systemSmall\)") and \
        has(r"rendered Counter \(systemSmall\): 1 entry, policy never") and \
        "id=widget-Counter-systemSmall text=Counter-systemSmall-0.png" in home, \
        "widgets added and rendered by the extension"
    blue, white = mean_rgb(widgets, (50, 290, 20, 20)), mean_rgb(widgets, (300, 90, 20, 20))
    assert blue[2] > 0.9 * 255 and blue[0] < 0.2 * 255 and white[0] > 0.9 * 255 and white[2] > 0.9 * 255, \
        f"widget pixels: blue counter, white ticker {blue} {white}"
    assert has(r"widget Ticker shows Ticker-systemMedium-1.png") and has(r"widget Ticker shows Ticker-systemMedium-2.png") \
        and has(r"timeline of Ticker ended; reloading"), "timeline entries switch by date; reload at the end"
    assert has(r"isim WidgetKit: tap on Counter") and has(r"isim AppIntents: Increment -> “Count is 1”") and \
        has(r"counter timeline \(systemSmall\), count 1"), "interactive widget: Button(intent:) runs the AppIntent"
    assert has(r"HelloWidgets: count 1") and has(r"SpringBoard: reloading widget Counter") and \
        has(r"counter timeline \(systemSmall\), count 2"), "the app sees the app-group count; reloadTimelines"
    assert has(r"requested Live Activity") and has(r"rendered Live Activity DeliveryAttributes") and \
        has(r"Live Activity from .*HelloWidgets.app shown"), "Live Activity rendered by the extension"
    assert has(r"IsimDynamicIsland \(74.5 11; 253 x 37\) id=dynamic-island text=compact") and \
        has(r"Dynamic Island expanded") and sum(mean_rgb(expanded, (20, 130, 30, 20))) < 0.1 * 255, \
        "Dynamic Island: compact outside the app, expanded"
    assert has(r"id=live-activity") and mean_rgb(lock, (30, 280, 30, 20))[0] > 0.9 * 255, \
        "lock screen shows the Live Activity"
    ended = log[log.index("Live Activity ended"):]
    assert has(r"updated Live Activity") and len(re.findall(r"rendered Live Activity DeliveryAttributes", log)) >= 2 \
        and "IsimDynamicIsland" not in ended, "update re-renders; end removes it"
