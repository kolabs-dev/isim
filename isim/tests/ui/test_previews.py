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
