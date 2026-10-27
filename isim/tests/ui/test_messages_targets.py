"""isim build with iMessage targets and a watch app (HelloStickers, issue #341): the sticker pack is an .appex in
PlugIns/ with no executable and an isim-stickers.json from its .xcstickers catalog; the Messages extension is a normal
app extension; the watchOS app is not built (the build says why) and the iOS app has no Watch/ content."""
import json
import os
import plistlib
import subprocess

import pytest
from isimtest import APPS, ISIM

APP = APPS / "HelloStickers.app"
pytestmark = pytest.mark.skipif(not APP.is_dir(), reason="HelloStickers.app is not built")
PROJECT = os.path.join(os.path.dirname(__file__), "..", "..", "samples", "HelloStickers", "HelloStickers.xcodeproj")


def plist(path):
    with open(path, "rb") as f:
        return plistlib.load(f)


def test_sticker_pack_and_messages_extension():
    stickers = APP / "PlugIns" / "HelloStickersStickers.appex"
    info = plist(stickers / "Info.plist")
    assert info["NSExtension"]["NSExtensionPointIdentifier"] == "com.apple.message-payload-provider"
    assert info["CFBundlePackageType"] == "XPC!" and "CFBundleExecutable" not in info, "a sticker pack has no executable"
    index = json.loads((stickers / "isim-stickers.json").read_text())
    pack = index["packs"][0]
    assert pack["name"] == "Sticker Pack"
    assert [(s["name"], s["accessibilityLabel"]) for s in pack["stickers"]] == [("Star", "A yellow star"), ("Heart", "A red heart")], \
        "the stickers in the pack's order, with their accessibility labels"
    for s in pack["stickers"]:
        assert (stickers / s["file"]).is_file()
    assert (stickers / index["icon"]).is_file(), "the iMessage app icon"
    messages = APP / "PlugIns" / "HelloStickersMessages.appex"
    m = plist(messages / "Info.plist")
    assert m["NSExtension"]["NSExtensionPrincipalClass"] == "HelloStickersMessages.MessagesViewController"
    assert (messages / m["CFBundleExecutable"]).is_file(), "the Messages extension is built"
    assert not (APP / "Watch").exists(), "the watch app is not embedded"


def test_watch_app_not_built(tmp_path):
    p = subprocess.run([str(ISIM), "build", "-project", PROJECT, "-target", "HelloStickersWatch", "-o", str(tmp_path)],
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=300)
    assert "HelloStickersWatch: watchOS app not built: isim runs iOS apps, not watchOS" in p.stdout, p.stdout
    assert not (tmp_path / "HelloStickersWatch.app").exists()


def test_plugins_seen_by_the_app(launch):
    app = launch("HelloStickers")
    app.wait_log(r"stk plugins HelloStickersMessages.appex,HelloStickersStickers.appex")
    app.wait_log(r"stk HelloStickersStickers.appex point com.apple.message-payload-provider executable false")
    app.wait_log(r"stk HelloStickersMessages.appex point com.apple.message-payload-provider executable true")
    app.wait_log(r"stk watch false")
    assert app.quit() == 0, "exits cleanly"
