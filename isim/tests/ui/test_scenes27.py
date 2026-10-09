"""iOS 27 scenes (HelloScenes27, iPad with multiple windows): a scene accessory on the simulated external display
(`display connect` / `display shot` / `display disconnect`): the accessory's scene of role
windowExternalDisplayNonInteractive with its sceneAccessoryUserInfo, isAvailable seen in updateProperties, isEnabled
(disabled: the manifest's external display configuration takes the display), UIScreen.screens and its notifications;
UIWindowScene.closureConfirmation on `closescene` (a custom cancel action keeps the window, Close closes it); and
extendStateRestoration / completeStateRestoration keeping the launch screen up. Before iOS 27: the manifest's
external display scene, windows close without confirmation; state restoration extension is iOS 15."""
import pytest
from PIL import Image

PAD = "ipadpro11"


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


def ipad_os(ios):
    osv = ios[0]
    return "17.5" if osv and str(osv).split(".")[0] == "17" else osv     # the iPad Pro 11-inch (M4) needs iOS 17.5


@pytest.mark.os_matrix
def test_scenes27(launch, ios, tmp_path):
    v = major(ios)
    app = launch("HelloScenes27", device=PAD, os_version=ipad_os(ios), launch_screen=True)
    app.wait_log(rf"^hs27 ios27 {'yes' if v >= 27 else 'no'}$")

    # the asynchronous restore holds the launch screen until completeStateRestoration
    app.wait_log(r"isim: launch screen hidden")
    out = app.log
    kept, done = out.find("launch screen kept until state restoration completes"), out.find("hs27 restoration completed score 2")
    hidden = out.find("isim: launch screen hidden")
    assert 0 <= out.find("hs27 restoration extended") < kept < done < hidden, "the launch screen waits for completeStateRestoration"
    app.wait_view(r"id=score\b.*text=2:0")

    # an external display
    app.send("display connect 1920x1080")
    app.wait_log(r"^hs27 screen connected 1920x1080 scale 1, screens 2$")
    board = "Final (Scoreboard)" if v >= 27 else r"Display Board \(Display Board\)"
    app.wait_log(rf"^hs27 board connected {board.replace('(Scoreboard)', '[(]Scoreboard[)]')}, role external non-interactive, "
                 r"screen 1920x1080, main false$")
    app.wait_log(r"^hs27 board window 1920x1080 key true, the device keeps its key window true$")
    app.wait_log(r"^hs27 board active$")
    if v >= 27:
        app.wait_log(r"^hs27 accessory available true enabled true$")
        app.wait_view(r"text=External display: available")
    tree = app.wait_view(r"UIWindow \(0 0; 1920 x 1080\)")
    assert "UIWindow (0 0; 834 x 1194)" in tree or "UIWindow (0 0; 834 x 1210)" in tree, "the device's window is unchanged"
    app.tap_id("goal")                                                  # the board follows the app's state
    app.wait_log(r"^hs27 goal score 3$")
    app.wait_view(rf"id=board-score\b.*text={'Final' if v >= 27 else 'Display Board'} 3:0")

    shot = tmp_path / "external.png"
    app.send(f"display shot {shot}")
    app.wait_log(r"isim: external display shot .*external\.png \(1920x1080, scene isim-")
    img = Image.open(shot).convert("RGB")
    assert img.size == (1920, 1080), img.size
    r, g, b = img.getpixel((100, 100))
    assert r > 230 and 170 < g < 230 and b < 40, f"the board's yellow background on the display: {(r, g, b)}"
    assert any(sum(img.getpixel((x, 540))) < 100 for x in range(700, 1220, 4)), "the score's text in the middle of the display"

    if v >= 27:                                                         # disabled: the manifest's scene takes the display
        app.tap_id("accessory-enabled")
        app.wait_log(r"^hs27 accessory enabled false$")
        app.wait_log(r"^hs27 board connected Display Board \(Display Board\), role external non-interactive")
        app.tap_id("accessory-enabled")
        app.wait_log(r"^hs27 board connected Final \(Scoreboard\)", count=2)

    # closing a window
    app.tap_id("new-window")
    app.wait_log(r"^hs27 window 2 connected$")
    app.wait_still()
    app.send("closescene")
    if v >= 27:
        app.wait_log(r"isim: closing scene isim-\w+: confirmation shown")
        app.wait_view(r"text=Close Match 2\?")
        app.wait_still()
        app.screenshot("closure-confirmation")
        app.tap_text("Keep Playing")
        app.wait_log(r"^hs27 window 2 kept$")
        app.wait_log(r"isim: scene closure cancelled")
        app.wait_view(r"text=Close Match 2\?", gone=True)
        assert "discarded" not in app.log
        app.send("closescene")
        app.wait_log(r"confirmation shown", count=2)
        app.wait_view(r"text=Close Match 2\?")
        app.wait_still()
        app.tap_text("Close")
        app.wait_log(r"isim: scene closure confirmed")
    app.wait_log(r"^hs27 discarded 1 session\(s\)$")
    app.wait_log(r"isim: scenes: isim-\w+ \(0\.\.834\)$")

    app.send("display disconnect")
    app.wait_log(r"^hs27 board disconnected$")
    app.wait_log(r"^hs27 screen disconnected, screens 1$")
    if v >= 27:
        app.wait_log(r"^hs27 accessory available false enabled true$", count=2)
    app.wait_view(r"UIWindow \(0 0; 1920 x 1080\)", gone=True)
    assert app.quit() == 0
