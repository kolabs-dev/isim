"""iMessage apps and sticker packs in isim's Messages app (issue #406, HelloStickers under `isim boot`): the + menu lists
the Messages extension and the sticker pack; the extension runs compact, then expanded on request; MSSticker refuses a
text file; a game message it inserts waits in the compose field (removing it cancels it), is sent with Send and shows
as a bubble; a message it sends itself replaces the session's bubble; a send without a recent tap is refused; a
sticker from the pack and one the extension draws go into the transcript; a reply from the other participant
(`isim messages receive`) reaches the active extension; tapping the bubble opens the extension expanded with the
message selected; `isim messages list` prints the conversation. System UI: os_matrix."""
import os
import re
import subprocess

import pytest

from isimtest import ISIM

EXT = "dev.isim.samples.HelloStickers.Messages"
PACK = "dev.isim.samples.HelloStickers.Stickers"

pytestmark = pytest.mark.os_matrix


def isim(data, *args):
    r = subprocess.run([str(ISIM), *args], env=dict(os.environ, ISIM_DATA=str(data)), stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True, timeout=60)
    assert r.returncode == 0, r.stdout
    return r.stdout


def test_messages_apps(launch, device_data):
    dev = launch(None, install=["HelloStickers"])
    dev.send("launch dev.isim.messages")
    dev.wait_log(rf"isim Messages: 2 iMessage apps: {EXT}, {PACK}")

    dev.wait_tap_id("messages-plus")
    dev.wait_tap_id(f"messages-app-{EXT}")
    dev.wait_log(r"^stk messages extension loaded$")
    dev.wait_log(r"^stk sticker refused true code=7$")                   # stickerFileImproperFileFormat
    dev.wait_log(r"^stk will become active compact selected=none remote=1$")
    dev.wait_log(r"^stk did become active$")
    dev.wait_tap_id("stk-expand")                                         # requestPresentationStyle(.expanded)
    dev.wait_log(r"^stk will transition expanded$")
    dev.wait_log(r"^stk did transition expanded$")
    dev.wait_tap_id("messages-collapse")
    dev.wait_log(r"^stk did transition compact$")

    dev.wait_tap_id("stk-game")                                           # insert: into the compose field
    dev.wait_log(r"^stk insert game ok$")
    dev.wait_view(r"id=messages-staged-0")
    dev.tap_id("messages-staged-remove-0")                                # removed: cancelled
    dev.wait_log(r"^stk did cancel sending Your move board=X-------- pending=true$")
    dev.tap_id("stk-game")
    dev.wait_view(r"id=messages-staged-0")
    dev.tap_id("messages-send")
    dev.wait_log(r"^stk did start sending Your move board=X--------")
    dev.wait_log(rf"isim Messages: sent message from {EXT}: Your move \| Tic-Tac-Toe \| https://example\.com/ttt\?board=X--------")

    dev.tap_id("stk-send-now")                                            # send: at once, replacing the session's bubble
    dev.wait_log(r"^stk send move ok$")
    dev.wait_log(rf"isim Messages: sent message from {EXT}: Ana's move")
    dev.wait_view(r"id=messages-bubble-0 .*text=You: Your move")
    dev.tap_id("stk-send-late")                                           # no tap for 5 s: refused
    dev.wait_log(r"^stk late send error 10$", timeout=20)

    dev.tap_id("stk-sticker")                                             # the extension's own sticker
    dev.wait_log(r"isim Messages: inserted the sticker Smile into the compose field")
    dev.tap_id("messages-send")
    dev.wait_log(r"isim Messages: sent sticker: Smile")
    dev.wait_still()
    dev.screenshot("messages-transcript")                                 # the game's bubble, the sticker, the app compact

    isim(device_data, "messages", "receive", "--app", EXT, "--session", "last", "--url", "https://example.com/ttt?board=X---O---X",
         "--caption", "Your move", "--summary", "Ana played")
    dev.wait_log(rf"isim Messages: received message from {EXT} from Ana: Your move")
    dev.wait_log(r"^stk did receive Your move board=X---O---X pending=false same session=true from remote=true$")

    dev.wait_tap_id("messages-close-app")
    dev.wait_log(r"^stk will resign active$")
    dev.wait_log(r"^stk did resign active$")
    dev.wait_tap_id("messages-plus")                                      # the sticker pack
    dev.wait_tap_id(f"messages-app-{PACK}")
    dev.wait_view(r"id=sticker-1")
    dev.tap_id("sticker-1")
    dev.wait_log(r"isim Messages: inserted the sticker A red heart into the compose field")
    dev.tap_id("messages-send")
    dev.wait_log(r"isim Messages: sent sticker: A red heart")
    dev.wait_tap_id("messages-close-app")

    isim(device_data, "messages", "receive", "Good game!")
    dev.wait_log(r"isim Messages: received text from Ana: Good game!")
    bubble = re.search(r"^\s*UIView \(.*id=(messages-bubble-\d+)", dev.view_dump(), re.M)   # the game's latest message
    dev.tap_id(bubble.group(1))                                           # its app, expanded, with the message selected
    dev.wait_log(r"^stk will become active expanded selected=Your move board=X---O---X pending=false remote=1$")
    dev.wait_still()
    dev.screenshot("messages-expanded")

    out = isim(device_data, "messages", "list")
    assert f"me: [{EXT}] Your move | Tic-Tac-Toe | https://example.com/ttt?board=X--------" in out, out
    assert "me: [sticker] Smile" in out and "me: [sticker] A red heart" in out, out
    assert "Ana: Good game!" in out, out
