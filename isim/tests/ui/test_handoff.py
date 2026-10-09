"""isim boot with HelloSystem: Handoff (script `handoff TYPE [URL] [TITLE]` plays the other device: the app that
declares TYPE in NSUserActivityTypes continues it, web pages go to the app that claims the universal link) and the
Safari system app (http(s) URLs no app claims, from `openurl` and Handoff, load in its WKWebView; local server only)."""
import pytest
from isimtest import ISIM, ROOT, local_server, rgb, visible

APP = "dev.isim.samples.HelloSystem"


def test_handoff(launch):
    dev = launch(None, install=["HelloSystem"])
    dev.wait_view(visible(f"app-{APP}"))
    dev.send(f"handoff {APP}.recipe Pancake recipe")
    dev.wait_log(rf"SpringBoard: Handoff continues {APP}\.recipe in System")
    dev.wait_view(rf"text=Launched to continue {APP}\.recipe")           # cold launch: connectionOptions.userActivities
    dev.send(f"handoff {APP}.recipe Pancake recipe")
    dev.wait_log(rf"continue {APP}\.recipe Pancake recipe")              # running: scene(_:continue:)
    dev.wait_view(r"text=Continued Pancake recipe")
    dev.send("handoff NSUserActivityTypeBrowsingWeb https://hello.isim.dev/items/9")
    dev.wait_log(r"continue NSUserActivityTypeBrowsingWeb https://hello\.isim\.dev/items/9")   # its universal link
    dev.send("handoff com.example.nobody")
    dev.wait_log(r"SpringBoard: Handoff: no app continues com\.example\.nobody")
    assert dev.quit() == 0


WEB = pytest.mark.skipif(not (ISIM.parent / "isim-webkit").exists(),
                         reason="no web engine helper (needs WebKitGTK 6.0 and gtk4-broadwayd on the host)")


@WEB
@pytest.mark.os_matrix
def test_safari(launch, ios, tmp_path):
    """iPhone Safari: iOS 17/18 an opaque bar (address pill above back/forward/share/reload) with the page above it;
    iOS 26+ a floating Liquid Glass bar (back, address capsule, "…") with the page running under it."""
    glass = int(float(ios[0] or 18)) >= 26
    with local_server(ROOT / "samples/HelloWeb/server.py", tmp_path / "requests.log") as port:
        page = f"http://127.0.0.1:{port}/page3"
        dev = launch(None, install=["HelloSystem"])
        dev.wait_view(visible(f"app-{APP}"))
        dev.send(f"openurl {page}")
        dev.wait_log(rf"SpringBoard: Safari opens {page}")              # no app claims it: Safari
        dev.wait_log(rf"Safari: loaded {page} “Server Page”", timeout=30)
        dev.wait_view(r'id=safari-address text="127\.0\.0\.1"')         # the address pill shows the host
        dev.wait_still()
        shot = dev.screenshot("safari")
        address, web, back = (dev.wait_for(id=i) for i in ("safari-address", "safari-web", "safari-back"))
        H, is_page = shot.height, lambda c: min(c) > 250                  # the page is white; the iOS 18 bar light grey
        if glass:
            more, capsule = dev.wait_for(id="safari-more"), dev.wait_for(id="safari-capsule")
            assert web.y + web.h >= H - 1, (web, H)                      # the page runs under the bar
            assert back.x < capsule.x < capsule.x + capsule.w < more.x and \
                abs(back.y - capsule.y) < 2 and abs(more.y - capsule.y) < 2, (back, capsule, more)   # one row
            assert capsule.y + capsule.h > H - 60 and capsule.h >= 44, (capsule, H)                  # at the bottom
            assert dev.find(id="safari-forward") is None and dev.find(id="safari-share") is None    # in the … menu
            assert is_page(rgb(shot, shot.width / 4, H - 12)) and is_page(rgb(shot, capsule.x + capsule.w / 2, capsule.y - 16)), \
                "the white page shows around the floating bar (no opaque bar)"
        else:
            assert web.y + web.h <= address.y and address.y > H / 2, (web, address)   # the page ends above the bar
            assert dev.find(id="safari-more") is None and dev.find(id="safari-forward") is not None
            assert not is_page(rgb(shot, shot.width / 4, H - 12)), "iOS 17/18: an opaque bar at the bottom"
        dev.send("home")
        dev.wait_log(r"isim shell: home")
        dev.send(f"handoff NSUserActivityTypeBrowsingWeb {page}")
        dev.wait_log(rf"SpringBoard: Handoff of {page} to Safari")
        dev.wait_log(rf"Safari: opening {page}")
        dev.send(f"launch {APP}")
        dev.wait_tap_id("openWeb")                                      # UIApplication.open of a page no app claims
        dev.wait_log(r"open web page -> true")
        dev.wait_log(r"Safari: opening https://web\.isim\.invalid/page")
        assert dev.quit() == 0


@WEB
def test_safari_ipad(launch, tmp_path):
    """iPad Safari: one bar at the top (back, forward | address field | share, reload), the page below it."""
    with local_server(ROOT / "samples/HelloWeb/server.py", tmp_path / "requests.log") as port:
        page = f"http://127.0.0.1:{port}/page3"
        dev = launch(None, device="ipadpro11", os_version="18.0")
        dev.wait_log(r"SpringBoard: \d+ app\(s\)")
        dev.send(f"openurl {page}")
        dev.wait_log(rf"Safari: loaded {page} “Server Page”", timeout=30)
        address = dev.wait_for(id="safari-address")
        web = dev.wait_for(id="safari-web")
        assert address.y < 80 and web.y >= address.y + address.h, (address, web)   # the bar is at the top
        dev.wait_still()
        dev.screenshot("safari-ipad")
        assert dev.quit() == 0
