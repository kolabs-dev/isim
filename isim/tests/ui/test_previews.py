"""`isim preview` (HelloSwiftUI's #Previews): lists the app's previews from their entry points (the PreviewsMacros
plugin exports one per #Preview, named after its file, line and name) and renders one to a PNG in UIKit's preview
mode: the default layout fills the device, .sizeThatFitsLayout centres the content at its size on a grey canvas."""
import os
import subprocess

from PIL import Image
from isimtest import ISIM, ROOT

APP = ROOT / "out" / "apps" / "HelloSwiftUI.app"


def run(tmp_path, *args):
    env = dict(os.environ, ISIM_DATA=str(tmp_path / "data"), ISIM_SHOT_SCALE="1")
    return subprocess.run([str(ISIM), "preview", str(APP), *args], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, timeout=120)


def test_previews(tmp_path):
    listed = run(tmp_path, "--list")
    assert listed.returncode == 0, listed.stdout
    rows = [line.split("\t") for line in listed.stdout.strip().splitlines()]
    assert rows == [["0", "(unnamed)", "HelloSwiftUI/HelloSwiftUIApp.swift:80"], ["1", "Detail", "HelloSwiftUI/HelloSwiftUIApp.swift:81"]], \
        f"the #Previews, in source order ({listed.stdout})"

    detail = run(tmp_path, "Detail", "-o", str(tmp_path / "detail.png"))
    assert detail.returncode == 0 and "isim: preview Detail (HelloSwiftUI/HelloSwiftUIApp.swift:81)" in detail.stdout, detail.stdout
    img = Image.open(tmp_path / "detail.png").convert("RGB")
    w, h = img.size
    grey = lambda c: all(220 <= v <= 236 for v in c) and max(c) - min(c) < 8
    assert grey(img.getpixel((w // 2, int(h * 0.15)))) and grey(img.getpixel((w // 2, int(h * 0.9)))), \
        ".sizeThatFitsLayout: the grey canvas above and below the content"
    assert not grey(img.getpixel((w // 2, h // 2))), "the content in the middle"

    first = run(tmp_path, "0", "-o", str(tmp_path / "content.png"))
    assert first.returncode == 0, first.stdout
    img = Image.open(tmp_path / "content.png").convert("RGB")
    assert not grey(img.getpixel((img.size[0] // 2, int(img.size[1] * 0.9)))), "the default layout fills the device"
    missing = run(tmp_path, "Nope")
    assert missing.returncode != 0 and "no preview named 'Nope'" in missing.stdout


WIDGETS = ROOT / "out" / "apps" / "HelloWidgets.app"


def run_widgets(tmp_path, *args):
    env = dict(os.environ, ISIM_DATA=str(tmp_path / "data"), ISIM_SHOT_SCALE="1")
    return subprocess.run([str(ISIM), "preview", str(WIDGETS), *args], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, timeout=120)


def test_widget_previews(tmp_path):
    """WidgetKit previews in HelloWidgets' extension: #Preview(as:widget:timeline:) renders each timeline entry like the
    home screen, #Preview(as:widget:timelineProvider:) and with `using:` an intent run the provider, and
    #Preview(as:using:widget:contentStates:) renders a Live Activity's content states (lock screen, Dynamic Island)."""
    listed = run_widgets(tmp_path, "--list")
    assert listed.returncode == 0, listed.stdout
    names = {row.split("\t")[1]: row.split("\t") for row in listed.stdout.strip().splitlines()}
    for n in ("Counter", "Counter circle", "Weather", "Delivery", "Delivery island"):
        assert n in names and names[n][-1] == "(HelloWidgetsExtension.appex)", f"{n}: listed from the extension ({listed.stdout})"

    counter = run_widgets(tmp_path, "Counter", "-o", str(tmp_path / "counter.png"))
    assert counter.returncode == 0, counter.stdout
    assert "isim WidgetKit: preview of Counter (systemSmall): 3 entries" in counter.stdout, counter.stdout
    img = Image.open(tmp_path / "counter.png").convert("RGB")
    w, h = img.size
    blue = lambda c: c[2] > 150 and c[0] < 120                  # the counter's blue container
    rows = [y for y in range(h) if blue(img.getpixel((w // 2 - 75, y)))]     # inside the small widget's left edge
    assert rows, "the widget is drawn"
    bands = 1 + sum(1 for a, b in zip(rows, rows[1:]) if b - a > 5)
    assert bands == 3, f"one widget per timeline entry, stacked: {bands}"

    weather = run_widgets(tmp_path, "Weather", "--wait", "4", "-o", str(tmp_path / "weather.png"))
    assert weather.returncode == 0 and "weather timeline (systemMedium), Paris, feels like on" in weather.stdout, weather.stdout
    assert "isim WidgetKit: preview of Weather (systemMedium): 1 entry" in weather.stdout, weather.stdout

    circle = run_widgets(tmp_path, "Counter circle", "-o", str(tmp_path / "circle.png"))
    assert circle.returncode == 0 and "preview of Counter (accessoryCircular): 1 entry" in circle.stdout, circle.stdout

    delivery = run_widgets(tmp_path, "Delivery", "-o", str(tmp_path / "delivery.png"))
    assert delivery.returncode == 0 and "preview of Live Activity DeliveryAttributes (content): 2 content state(s)" in delivery.stdout, delivery.stdout
    island = run_widgets(tmp_path, "Delivery island", "-o", str(tmp_path / "island.png"))
    assert island.returncode == 0 and "(dynamicIsland.expanded): 1 content state(s)" in island.stdout, island.stdout
    img = Image.open(tmp_path / "island.png").convert("RGB")
    w, h = img.size
    assert any(img.getpixel((w // 2, y)) == (0, 0, 0) for y in range(h)), "the expanded Dynamic Island is black"
