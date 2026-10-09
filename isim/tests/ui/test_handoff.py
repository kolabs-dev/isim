"""isim boot with HelloSystem: Handoff (script `handoff TYPE [URL] [TITLE]` plays the other device: the app that
declares TYPE in NSUserActivityTypes continues it, web pages go to the app that claims the universal link) and the
Safari system app (http(s) URLs no app claims, from `openurl` and Handoff, load in its WKWebView; local server only)."""
import pytest
from isimtest import ISIM, ROOT, local_server, visible

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
def test_safari(launch, tmp_path):
    with local_server(ROOT / "samples/HelloWeb/server.py", tmp_path / "requests.log") as port:
        page = f"http://127.0.0.1:{port}/page3"
        dev = launch(None, install=["HelloSystem"])
        dev.wait_view(visible(f"app-{APP}"))
        dev.send(f"openurl {page}")
        dev.wait_log(rf"SpringBoard: Safari opens {page}")              # no app claims it: Safari
        dev.wait_log(rf"Safari: loaded {page} “Server Page”", timeout=30)
        dev.wait_view(r'id=safari-address text="127\.0\.0\.1"')         # the address pill shows the host
        dev.wait_still()
        dev.screenshot("safari")
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
