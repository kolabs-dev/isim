"""WidgetKit beyond the home screen (HelloWidgets): Lock Screen accessory widgets added in the Lock Screen editor
(rendered vibrant: widgetRenderingMode, AccessoryWidgetBackground; the inline one next to the date, circular and
rectangular under the clock; a tap opens the app), configurable widgets (Edit Widget: the WidgetConfigurationIntent's
parameters, the timeline reloads with them), the redacted placeholder while the first timeline loads, gallery
snapshots (isPreview), widgetURL / Link taps, WidgetCenter.currentConfigurations, and StandBy (`standby on`: two
widgets side by side, landscape, without their container backgrounds). Also: a widget configured by a SiriKit intent
(IntentConfiguration: Edit Widget from its .intentdefinition, recommendations), images in their accented rendering
modes on the tinted Home Screen, a Live Activity drawn at the small size (ActivityFamily), and widget pushes
(WidgetPushHandler, iOS 26)."""
import re

import pytest

from isimtest import mean_rgb, screen_frames

APP = "dev.isim.samples.HelloWidgets"
FRAME = r"\((\S+) (\S+); (\S+) x (\S+)\) id=(%s)"


def frames(dump, ids):
    """{id: (x, y, w, h)} of the views / system parts in a `dump` whose id matches the regex `ids` (the last wins)."""
    return {g[4]: tuple(float(v) for v in g[:4]) for g in re.findall(FRAME % ids, dump)}


def open_gallery(dev):
    """The widget gallery from edit mode: Edit > Add Widget (iOS 18+), or + (iOS 17)."""
    tree = dev.wait_view(r"id=home-(edit|add-widget)\b")
    if "id=home-edit" in tree:
        dev.tap_id("home-edit")
        dev.wait_view(r"id=menu-Customize")
        dev.wait_still()
        x, y, w, h = screen_frames(dev.view_dump())["menu-Customize"]
        dev.tap(x + w / 2, y - h / 2)                                   # Add Widget, the row above
    else:
        dev.tap_id("home-add-widget")


def boot(launch, **kw):
    dev = launch(None, install=["HelloWidgets"], env={"ISIM_LOCK_TIME": "9:41", "ISIM_SUSPEND": "0"}, **kw)
    dev.wait_log(r"isim WidgetKit: \d+ widget kind")
    dev.wait_view(rf"id=app-{re.escape(APP)}")
    dev.wait_still()
    return dev


def add_home_widget(dev, kind, family):
    dev.send(f"holdid app-{APP} 0.8")
    dev.wait_tap_id("menu-edit")
    open_gallery(dev)
    dev.wait_tap_id(f"widget-add-{kind}-{family}")
    dev.wait_log(rf"added widget {kind} \({family}\)")
    dev.wait_view(r"id=widget-add-", gone=True)
    dev.wait_still()
    dev.wait_tap_id("home-done")
    dev.wait_view(rf"id=widget-{kind}-{family}")
    dev.wait_still()


@pytest.mark.os_matrix
def test_lock_screen_widgets(launch, ios):
    dev = boot(launch)
    dev.send("lock")
    dev.wait_log(r"isim shell: locked")
    dev.send("lockscreen customize")
    dev.wait_log(r"SpringBoard: Lock Screen editor")
    dev.wait_view(r"id=lock-edit-widgets")
    dev.wait_tap_id("lock-edit-widgets")
    dev.wait_view(r"id=lock-add-Counter-accessoryCircular")
    dev.wait_log(r"isim WidgetKit: snapshots \(accessoryCircular")
    dev.wait_still()
    gallery = dev.screenshot("lock-gallery")
    dev.tap_id("lock-add-Counter-accessoryCircular")
    dev.wait_log(r"Lock Screen editor: added Counter \(accessoryCircular\)")
    dev.wait_tap_id("lock-add-Weather-accessoryRectangular")
    dev.wait_log(r"Lock Screen editor: added Weather \(accessoryRectangular\)")
    dev.wait_tap_id("lock-add-Counter-accessoryCircular")                  # 4 units: one circle more fits
    dev.wait_log(r"Lock Screen editor: added Counter \(accessoryCircular\)", count=2)
    dev.wait_tap_id("lock-add-Counter-accessoryCircular")                  # a fifth unit does not
    dev.wait_log(r"Lock Screen editor: no room for Counter")
    dev.wait_tap_id("lock-gallery-close")
    dev.wait_tap_id("lock-edit-remove-3")
    dev.wait_log(r"Lock Screen editor: removed Counter")
    dev.wait_tap_id("lock-edit-inline")
    dev.wait_tap_id("lock-add-Weather-accessoryInline")
    dev.wait_log(r"Lock Screen editor: inline widget Weather")
    dev.wait_view(r"id=lock-edit-remove-inline")
    dev.wait_still()
    editor = dev.screenshot("lock-editor")
    dev.tap_id("lock-edit-done")
    dev.wait_log(r"Lock Screen widgets saved: Weather \(accessoryInline\), Counter \(accessoryCircular\), Weather \(accessoryRectangular\)")
    dev.wait_log(r"isim shell: Lock Screen customization done")
    dev.wait_log(r"rendered Counter \(accessoryCircular, vibrant\)")
    dev.wait_log(r"rendered Weather \(accessoryRectangular, vibrant\)")
    dev.wait_log(r"rendered Weather \(accessoryInline, vibrant\)")
    # one dump with the inline widget's image in (width > 0) and the row
    dump = dev.wait_dump(r"\(\S+ \S+; [1-9][\d.]* x 26\) id=lock-widget-inline[^\n]*\n[\s\S]*?id=lock-widget-2 text=Weather")[0]
    fr = frames(dump, r"lock-widget-\S+")
    cx, cy, cw, ch = fr["lock-widget-1"]
    rx, ry, rw, rh = fr["lock-widget-2"]
    ix, iy, iw, ih = fr["lock-widget-inline"]

    def vibrant(s):                       # the circle: white text on a disc lighter than the wallpaper beside it
        box = s.crop((int(cx), int(cy), int(cx + cw), int(cy + ch)))
        px = box.tobytes()
        white = sum(1 for i in range(0, len(px), 3) if min(px[i:i + 3]) > 225)
        disc, wall = mean_rgb(s, (cx + 6, cy + ch / 2 - 4, 8, 8)), mean_rgb(s, (cx - 30, cy + ch / 2 - 4, 8, 8))
        return white > 40 and sum(disc) > sum(wall) + 30
    lock = dev.wait_shot(vibrant, "vibrant Lock Screen circle")
    dev.send("unlock")
    dev.wait_log(r"isim shell: unlocked")
    dev.send(f"launch {APP}")
    dev.wait_tap_id("widgetsInUse")
    dev.wait_log(r"HelloWidgets: widgets in use: ")
    dev.send("home")
    dev.wait_dump(r"id=home-dock")
    dev.send("lock")
    dev.wait_log(r"isim shell: locked", count=2)
    dev.wait_dump(r"id=lock-widget-1")
    dev.tap(cx + cw / 2, cy + ch / 2)                                       # a tap opens the app
    dev.wait_log(r"SpringBoard: Lock Screen widget Counter opens Widgets")
    assert dev.quit() == 0
    log = dev.log
    assert gallery.size[0] < gallery.size[1] and editor.size == gallery.size
    assert "Lock Screen widgets: 3" in log, "the shell shows three Lock Screen widgets"
    assert re.search(r"counter view \(accessoryCircular\), rendering mode vibrant", log), "widgetRenderingMode is vibrant"
    assert re.search(r"weather view \(accessoryRectangular\), background removed", log), \
        "showsWidgetContainerBackground is false on the Lock Screen"
    assert cw == 72 and ch == 72 and rw == 160 and rh == 72 and abs(cy - ry) < 1 and rx - (cx + cw) == 16, \
        f"circle 72 pt and rectangle 160 x 72 side by side, 16 pt apart: {fr}"
    assert iy < cy and ih == 26 and iw > 20, f"the inline widget is above the clock, next to the date: {fr}"
    assert vibrant(lock)
    assert re.search(r"widgets in use: Counter accessoryCircular, Weather accessoryInline, Weather accessoryRectangular", log), \
        "WidgetCenter.currentConfigurations lists the Lock Screen's widgets"
    assert "isim shell: Lock Screen widget Counter opens its app" in log


def test_widget_editing_placeholder_urls(launch):
    dev = boot(launch)
    dev.send(f"holdid app-{APP} 0.8")
    dev.wait_tap_id("menu-edit")
    open_gallery(dev)
    dev.wait_view(r"id=widget-preview-Weather")
    dev.wait_log(r"weather snapshot \(systemSmall\), preview yes")
    dev.wait_log(r"SpringBoard: gallery previews from snapshots \([1-9]")
    dev.wait_still()
    gallery = dev.screenshot("gallery")
    dev.tap_id("widget-add-Weather-systemSmall")
    dev.wait_log(r"widget Weather shows its placeholder")                  # the timeline takes 1.5 s
    dev.wait_view(r"id=widget-add-", gone=True)
    dev.wait_still()
    dev.wait_tap_id("home-done")
    m = dev.wait_log(r"widget Weather shows Weather-systemSmall-0.png")
    assert "widget Weather shows its placeholder" in dev.log[:m.start()], "the placeholder shows before the first timeline"
    dev.wait_dump(r"id=widget-Weather-systemSmall text=Weather-systemSmall-0.png")
    dev.wait_still()
    # Edit Widget: the intent's parameters
    dev.send("holdid widget-Weather-systemSmall 0.8")
    dev.wait_tap_id("menu-widget-edit")
    dev.wait_log(r"isim WidgetKit: Weather has 2 parameter\(s\): city, feelsLike")
    dev.wait_view(r"id=widget-param-city")
    dev.wait_still()
    sheet = dev.screenshot("edit-widget")
    dev.tap_id("widget-param-city")
    dev.wait_tap_id("widget-choice-paris")
    dev.wait_log(r"widget parameter city = paris")
    dev.wait_tap_id("widget-param-feelsLike")
    dev.wait_log(r"widget parameter feelsLike = true")
    dev.wait_still()
    dev.tap_id("widget-config-done")
    dev.wait_log(r"widget Weather configured: city=paris, feelsLike=true")
    dev.wait_log(r"weather timeline \(systemSmall\), Paris, feels like on")
    dev.wait_log(r"widget Weather shows Weather-systemSmall-0.png", count=2)
    dev.wait_still()
    edited = dev.screenshot("edited")
    # a tap outside any control: the app opens with the widget's URL
    x, y, w, h = screen_frames(dev.view_dump())["widget-Weather-systemSmall"]
    dev.tap(x + w / 2, y + h / 3)
    dev.wait_log(r"SpringBoard: widget Weather opens Widgets with hellowidgets://weather/paris")
    dev.wait_log(r"HelloWidgets: opened hellowidgets://weather/paris")
    # the configuration is kept: the app sees it in use; Remove Widget takes it away
    dev.send("home")
    dev.wait_dump(r"id=widget-Weather-systemSmall")
    dev.wait_still()
    dev.send("holdid widget-Weather-systemSmall 0.8")
    dev.wait_tap_id("menu-widget-remove")
    dev.wait_log(r"removed widget Weather \(systemSmall\)")
    dev.wait_view(r"id=widget-Weather-systemSmall", gone=True)
    # a Link inside a widget: the app opens with the Link's URL
    open_gallery_from_home(dev)
    dev.wait_tap_id("widget-add-Ticker-systemMedium")
    dev.wait_view(r"id=widget-add-", gone=True)
    dev.wait_still()
    dev.wait_tap_id("home-done")
    dev.wait_dump(r"id=widget-Ticker-systemMedium text=Ticker-systemMedium-\d.png")
    dev.wait_still()
    x, y, w, h = screen_frames(dev.view_dump())["widget-Ticker-systemMedium"]
    dev.tap(x + w - 50, y + (h - 22) / 2)                                    # "Details" on the right
    dev.wait_log(r"tap on Ticker opens the Link hellowidgets://ticker/details")
    dev.wait_log(r"HelloWidgets: opened hellowidgets://ticker/details")
    assert dev.quit() == 0
    log = dev.log
    assert "isim WidgetKit: placeholder of Weather (systemSmall)" in log, "placeholder(in:) rendered (redacted)"
    assert gallery.size == sheet.size == edited.size


def open_gallery_from_home(dev):
    dev.send(f"holdid app-{APP} 0.8")
    dev.wait_tap_id("menu-edit")
    open_gallery(dev)


def test_standby(launch):
    dev = boot(launch)
    add_home_widget(dev, "Counter", "systemSmall")
    dev.wait_log(r"rendered Counter \(systemSmall\)")
    dev.send("standby on")
    dev.wait_log(r"isim shell: StandBy on")
    dev.wait_log(r"SpringBoard: StandBy with 1 widget\(s\)")
    dev.wait_log(r"rendered Counter \(systemSmall, no background\)")
    dev.wait_log(r"isim shell: StandBy widgets: 1")
    dump = dev.wait_dump(r"id=standby-widget-right text=Clock").string
    m = re.search(r"\((\S+) (\S+); (\S+) x (\S+)\) id=standby-widget-left text=Counter", dump)
    assert m, dump
    x, y, w, h = (float(v) for v in m.groups())

    def ok(s):                                    # the counter without its blue background: black, white text
        c = mean_rgb(s, (x + 10, y + 10, 30, 30))
        return s.size[0] > s.size[1] and sum(c) < 60
    shot = dev.wait_shot(ok, "StandBy: landscape, the widget without its container background")
    dev.send("standby off")
    dev.wait_log(r"isim shell: StandBy off")
    dev.send("unlock")
    dev.wait_log(r"isim shell: unlocked")
    assert dev.quit() == 0
    log = dev.log
    assert w == h and w > 300, f"StandBy widgets are large squares ({w} x {h})"
    assert re.search(r"counter view \(systemSmall\), rendering mode fullColor", log)
    assert ok(shot)


def test_tinted_home_screen_widgets(launch, ios):
    """iOS 18+ tinted Home Screen: widgets render accented (widgetRenderingMode .accented), the widgetAccentable count
    in the tint and the rest white, on a dark tinted background."""
    if ios[0] and int(ios[0]) < 18:
        pytest.skip("tinted icons are iOS 18+")
    dev = boot(launch)
    add_home_widget(dev, "Counter", "systemSmall")
    dev.wait_log(r"widget Counter shows Counter-systemSmall-0.png")
    dev.send("iconstyle tinted #ff3b30")
    dev.wait_log(r"SpringBoard: widget Counter renders accented")
    dev.wait_log(r"rendered Counter \(systemSmall, accented\)")
    dev.wait_log(r"widget Counter shows Counter-systemSmall-0.png", count=2)
    dev.wait_still()
    x, y, w, h = screen_frames(dev.view_dump())["widget-Counter-systemSmall"]

    def red_count(s):                    # the count's pixels in the tint (red), the widget not blue any more
        box = s.crop((int(x + w * 0.3), int(y + h * 0.25), int(x + w * 0.7), int(y + h * 0.55)))
        px = box.tobytes()
        red = sum(1 for i in range(0, len(px), 3) if px[i] > 150 and px[i + 1] < 90 and px[i + 2] < 90)
        bg = mean_rgb(s, (x + 6, y + h - 40, 10, 10))
        return red > 30 and bg[2] < 120
    shot = dev.wait_shot(red_count, "the accented widget")
    dev.send("iconstyle light")                                             # back to full colour
    dev.wait_log(r"SpringBoard: widget Counter renders in full colour")
    assert dev.quit() == 0
    assert re.search(r"counter view \(systemSmall\), rendering mode accented", dev.log)
    assert red_count(shot)


def test_lock_screen_widget_sizes(launch):
    """6.7" class (iPhone 16 Pro Max, 440 pt): Apple's larger accessory sizes (76 pt circles); a single widget is centred
    under the clock, and a widget whose render is on its way already holds its place (a placeholder)."""
    dev = launch(None, install=["HelloWidgets"], device="iphone16promax", env={"ISIM_LOCK_TIME": "9:41", "ISIM_SUSPEND": "0"})
    dev.wait_log(r"isim WidgetKit: \d+ widget kind")
    dev.wait_view(rf"id=app-{re.escape(APP)}")
    dev.wait_still()
    dev.send("lock")
    dev.wait_log(r"isim shell: locked")
    dev.send("lockscreen customize")
    dev.wait_tap_id("lock-edit-widgets")
    dev.wait_tap_id("lock-add-Counter-accessoryCircular")
    dev.wait_log(r"Lock Screen editor: added Counter \(accessoryCircular\)")
    dev.send("lockscreen done")                                          # the editor's Done (also closes the gallery)
    dev.wait_log(r"isim shell: Lock Screen customization done")
    dev.wait_log(r"rendered Counter \(accessoryCircular, vibrant\)")
    dump = dev.wait_dump(r"\(\S+ \S+; \S+ x \S+\) id=lock-widget-1 text=Counter")[0]
    x, y, w, h = frames(dump, r"lock-widget-1")["lock-widget-1"]
    assert (w, h) == (76, 76), f"76 pt circle on the 6.7\" class ({w} x {h})"
    assert abs(x + w / 2 - 220) <= 1, f"a single widget is centred ({x})"
    dev.screenshot("lock-promax")
    png = next(p for p in (dev.data / "Library/SpringBoard/Widgets" / APP / "lock").glob("Counter-accessoryCircular-*.png"))
    from PIL import Image
    assert Image.open(png).size[0] in (76, 152, 228), f"the extension renders at the 76 pt size ({Image.open(png).size})"
    assert dev.quit() == 0


@pytest.mark.os_matrix
def test_intent_configured_widget(launch):
    """IntentConfiguration: the SiriKit intent's parameters (from Theme.intentdefinition) in Edit Widget, the values on
    the intent the IntentTimelineProvider gets; its recommendations are listed"""
    dev = boot(launch)
    add_home_widget(dev, "Theme", "systemSmall")
    dev.wait_log(r"theme timeline \(systemSmall\), color 3, title My Theme, date hidden")
    dev.wait_log(r"widget Theme shows Theme-systemSmall-0.png")
    dev.send("holdid widget-Theme-systemSmall 0.8")
    dev.wait_tap_id("menu-widget-edit")
    dev.wait_log(r"isim WidgetKit: Theme has 3 parameter\(s\): color, title, showsDate")
    dev.wait_tap_id("widget-param-color")
    dev.wait_tap_id("widget-choice-1")                                  # Sunrise (the enum's index)
    dev.wait_log(r"widget parameter color = 1")
    dev.wait_tap_id("widget-param-showsDate")
    dev.wait_log(r"widget parameter showsDate = true")
    dev.wait_tap_id("widget-param-title")
    dev.type("Breakfast")
    dev.send("key return")                                              # the keyboard goes
    dev.wait_for(type="keyboard", gone=True)
    dev.wait_still()
    dev.screenshot("edit-intent-widget")
    dev.tap(200, 120)                                                   # outside the card: Done (its centre is a field)
    dev.wait_log(r"widget Theme configured: color=1, showsDate=true, title=Breakfast")
    dev.wait_log(r"theme timeline \(systemSmall\), color 1, title Breakfast, date shown")
    dev.wait_log(r"widget Theme shows Theme-systemSmall-0.png", count=2)
    assert dev.quit() == 0
    assert re.search(r"isim WidgetKit: Theme recommends “Forest”", dev.log), "IntentRecommendation"


def test_accented_image_modes(launch):
    """iOS 18 tinted Home Screen: Image.widgetAccentedRenderingMode: the .fullColor star stays yellow, the .desaturated
    leaf turns grey, the rest of the widget is white and in the tint"""
    dev = boot(launch, os_version="18.0")
    add_home_widget(dev, "Theme", "systemSmall")
    dev.wait_log(r"widget Theme shows Theme-systemSmall-0.png")
    dev.send("iconstyle tinted #ff3b30")
    dev.wait_log(r"rendered Theme \(systemSmall, accented\)")
    dev.wait_log(r"widget Theme shows Theme-systemSmall-0.png", count=2)
    dev.wait_still()
    x, y, w, h = screen_frames(dev.view_dump())["widget-Theme-systemSmall"]

    def colours(s):
        """(yellow pixels in the star's corner, green pixels in the leaf's, grey ones there)"""
        star = s.crop((int(x + 16), int(y + h - 22 - 52), int(x + 56), int(y + h - 22 - 14))).tobytes()
        leaf = s.crop((int(x + 60), int(y + h - 22 - 52), int(x + 100), int(y + h - 22 - 14))).tobytes()
        yellow = sum(1 for i in range(0, len(star), 3) if star[i] > 180 and star[i + 1] > 150 and star[i + 2] < 90)
        green = sum(1 for i in range(0, len(leaf), 3) if leaf[i + 1] > leaf[i] + 60 and leaf[i + 1] > leaf[i + 2] + 60)
        grey = sum(1 for i in range(0, len(leaf), 3) if leaf[i] > 60 and abs(leaf[i] - leaf[i + 1]) < 12 and abs(leaf[i + 1] - leaf[i + 2]) < 12)
        return yellow, green, grey
    shot = dev.wait_shot(lambda s: colours(s)[0] > 40 and colours(s)[1] == 0 and colours(s)[2] > 40, "the star in colour, the leaf grey")
    dev.screenshot("accented-image-modes")
    assert dev.quit() == 0
    assert colours(shot)[0] > 40


def test_small_live_activity(launch):
    """iOS 18: a Live Activity with supplementalActivityFamilies([.small]) is drawn .medium on the Lock Screen and at the
    small size (activityFamily .small) too"""
    dev = boot(launch, os_version="18.0")
    dev.send(f"launch {APP}")
    dev.wait_tap_id("startTimer")
    dev.wait_log(r"HelloWidgets: started timer")
    dev.wait_log(r"isim WidgetKit: rendered Live Activity TimerAttributes \(lock screen, Dynamic Island, small\)")
    assert dev.quit() == 0
    log = dev.log
    assert "HelloWidgets extension: timer view (small)" in log and "HelloWidgets extension: timer view (medium)" in log
    small = list((dev.data / "Library/SpringBoard/Widgets" / APP).rglob("small.png"))
    assert small, "the small presentation is saved"
    from PIL import Image
    assert Image.open(small[0]).size == (172 * 3, 76 * 3), Image.open(small[0]).size


def test_widget_push(launch, tmp_path):
    """iOS 26: the extension's WidgetPushHandler gets the push token for its widgets; a widgets push reloads them"""
    dev = boot(launch, os_version="26.0", device="iphone17")
    add_home_widget(dev, "Headlines", "systemSmall")
    dev.wait_log(r"headlines timeline 1")
    m = dev.wait_log(r"isim WidgetKit: push token ([0-9a-f]{64}) for Headlines")
    dev.wait_log(rf"HelloWidgets extension: widget push token {m.group(1)} for Headlines systemSmall")
    payload = tmp_path / "widgets.apns"
    payload.write_text('{"apns-push-type": "widgets", "aps": {"content-changed": true}}')
    dev.send(f"push {APP} {payload}")
    dev.wait_log(r"SpringBoard: widgets push for Widgets \(Headlines\): reloading 1 widget\(s\)")
    dev.wait_log(r"headlines timeline 2")
    dev.wait_log(r"widget Headlines shows Headlines-systemSmall-0.png", count=2)
    assert dev.quit() == 0
