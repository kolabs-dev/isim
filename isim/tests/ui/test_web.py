"""WKWebView (HelloWeb) rendered by real WebKit (the host's WebKitGTK through out/bin/isim-webkit) against a local
server (samples/HelloWeb/server.py, no Internet): page pixels, navigation delegate (async action policy incl. a
cancelled link, response policy, start/commit/finish), KVO, user scripts in the page and the client world, script
messages (plain and with reply), JavaScript alert/confirm/prompt through the UI delegate shown as alerts, typing into a
page field with the system keyboard, evaluateJavaScript (completion, async, exception, object result),
callAsyncJavaScript, a WKURLSchemeHandler page, back/forward history (including the loadHTMLString page), scrolling,
a server cookie seen by WKHTTPCookieStore, takeSnapshot. Port of tests/ui/web.sh."""
import re

import pytest
from isimtest import ROOT, count_px, local_server, rgb

TOP = 108                                   # the web view's top below the navigation bar: page y + 108


def red(c): return c[0] > 220 and c[1] < 40 and c[2] < 40
def green(c): return c[1] > 150 and c[0] < 40 and c[2] < 40
def blue(c): return c[2] > 200 and c[0] < 40 and c[1] < 160


@pytest.fixture
def web(tmp_path):
    if not (ROOT / "out/bin/isim-webkit").exists():
        pytest.skip("no web engine helper (needs WebKitGTK 6.0 and gtk4-broadwayd on the host)")
    log = tmp_path / "server.log"
    with local_server(ROOT / "samples/HelloWeb/server.py", log) as port:
        yield port, log


def test_web(launch, web):
    port, server_log = web
    home = rf"^HelloWeb: didFinish http://127\.0\.0\.1:{port}/ title=Hello Web"
    app = launch("HelloWeb", args=["-server", f"http://127.0.0.1:{port}"])
    app.wait_log(home + " back=0", timeout=30)                           # loadHTMLString: start/commit/finish
    app.wait_log(r"^HelloWeb: user script ran: http:")                    # WKUserScript at document end
    app.wait_log(r"^HelloWeb: kvo progress=1\.0")
    loaded = app.wait_until(lambda: (lambda s: s if red(rgb(s, 260, 204)) else None)(app.screenshot("loaded")),
                            what="the page is drawn")
    assert blue(rgb(loaded, 40, 292)), "page rendered by WebKit (red box, blue button)"
    banner = lambda c: c[1] > 0.4 * 255 and c[0] < 0.2 * 255 and c[2] < 0.2 * 255
    assert count_px(loaded, (16, 596, 200, 24), banner) > 100, "the user script's green banner"

    app.tap(100, 56 + TOP)
    app.wait_log(r"^HelloWeb: message native tap count=1 list=1,two,1 main=true")   # postMessage -> handler
    app.tap(100, 104 + TOP)
    app.wait_log(r"^HelloWeb: alert panel: Hello from JavaScript from 127\.0\.0\.1")
    app.wait_view(r"text=OK\b")
    app.tap_text("OK")
    app.wait_log(r"page out: alert done")                                 # alert() -> UI delegate -> UIAlertController
    app.tap(100, 152 + TOP)
    app.wait_log(r"^HelloWeb: confirm panel: Delete everything\?")
    app.wait_view(r"text=OK\b")
    app.tap_text("OK")
    app.wait_log(r"page out: confirm true")                               # confirm() (async delegate) on OK
    app.tap(100, 200 + TOP)
    app.wait_log(r"^HelloWeb: prompt panel: Your name\? default=Ada")
    app.wait_view(r"text=OK\b")
    app.tap_text("OK")
    app.wait_log(r"page out: prompt Ada")                                 # prompt() with default text
    app.tap(100, 248 + TOP)
    app.wait_log(r"^HelloWeb: calc 6 \* 7 = 42")
    app.wait_log(r"page out: reply 42")                                   # WKScriptMessageHandlerWithReply
    app.tap(140, 317 + TOP)
    app.wait_log(r"keyboard shown", count=2)                              # the field's keyboard (the first was prompt()'s)
    app.type("hello")
    app.wait_log(r"page out: typed hello")                                # focus a page field -> keyboard -> typing
    app.tap(330, 560)                                                     # blur the field: the page reports it,
    app.wait_log(r"keyboard hidden", count=2)                             # then the keyboard hides (it covers the bar)
    app.wait_tap_id("eval")
    app.wait_log(r"^HelloWeb: eval completion: 18 error=none")
    app.wait_log(r"^HelloWeb: eval async: hello")
    app.wait_log(r"^HelloWeb: eval threw WKError code=4 message=.*ReferenceError: Can.t find variable: nosuchFunction")
    app.wait_log(r"^HelloWeb: callAsyncJavaScript: 45")
    app.wait_log(r"^HelloWeb: eval object: n=1\.5 s=x a=2 ok=1")
    app.tap_id("snapshot")
    app.wait_log(r"^HelloWeb: snapshot 402x664 scale=3")                 # takeSnapshot
    app.tap(60, 396 + TOP)
    app.wait_log(r"^HelloWeb: policy linkActivated https://blocked\.example/ -> cancel")   # decidePolicyFor cancels
    app.tap(100, 361 + TOP)
    app.wait_log(r"^HelloWeb: scheme request isim-demo://pages/two")
    app.wait_log(r"^HelloWeb: didFinish isim-demo://pages/two title=Page Two back=1")       # WKURLSchemeHandler
    app.wait_until(lambda: green(rgb(app.screenshot("scheme"), 60, 170)), what="the scheme page is drawn")
    app.wait_log(r"^HelloWeb: kvo canGoBack=true")
    app.tap_id("back")
    app.wait_log(home, count=2)
    app.wait_log(r"^HelloWeb: kvo canGoBack=false")                      # back to the loadHTMLString page
    app.sleep(0.5)                                                        # the page settles before the link tap
    app.tap(80, 431 + TOP)
    app.wait_log(rf"^HelloWeb: didFinish http://127\.0\.0\.1:{port}/page3 title=Server Page back=1")
    app.wait_tap_id("cookies")
    app.wait_log(r"^HelloWeb: cookies: visited=yes@127\.0\.0\.1")        # WKHTTPCookieStore.getAllCookies
    app.tap_id("back")
    app.wait_log(home, count=3)
    # the scroll view only scrolls once it mirrors the page's full height: a drag that came first (after a fixed
    # pause) did not scroll on a slow run (issue #45)
    app.wait_view(r"_WKScrollView .* content 402 x 15[0-9][0-9]")
    app.drag(200, 600, 200, 400, 0.3)

    def scrolled():
        return re.search(r"_WKScrollView .* text=offset (1[5-9][0-9]|[2-8][0-9][0-9])(\.[0-9]+)?, content 402 x 15[0-9][0-9]",
                         app.view_dump())
    app.wait_until(scrolled, what="dragging scrolls the page (the scroll view mirrors it)")
    app.wait_until(lambda: not red(rgb(app.screenshot("scrolled"), 260, 204)), what="the page moved up")

    log = app.log
    assert re.search(r"^HelloWeb: kvo title=Hello Web", log, re.M), "KVO title"
    assert re.search(r"^HelloWeb: userAgent: Mozilla/5\.0 \(iPhone; CPU iPhone OS [0-9_]* like Mac OS X\) "
                     r"AppleWebKit/605\.1\.15 \(KHTML, like Gecko\) Mobile/15E148", log, re.M), "iOS-style user agent"
    assert re.search(r"^HelloWeb: page world sees secretWorldValue: undefined", log, re.M) and \
        re.search(r"^HelloWeb: client world value: only in the client world", log, re.M), \
        "content worlds: the client world value is hidden from the page"
    assert re.search(r"^HelloWeb: response 200 text/html canShow=true main=true", log, re.M), "response policy"
    assert "didFailProvisional" not in log, "the cancelled link does not fail a navigation"
    assert "GET /page3" in server_log.read_text(), "the server served page3"
    assert app.quit() == 0


def test_web_interact(launch, web):
    """HelloWeb -interact: the page's own interactions drawn by isim as on iOS — a long press selects a word (edit menu
    with Copy), a long press on a link opens a context menu (WKUIDelegate will-present / did-end), <select> elements
    become menus (single and multiple choice), pinch zoom follows scrollView.zoomScale, the find navigator
    (UIFindInteraction) counts matches, createPDF (whole page and a rect) and createWebArchiveData."""
    port, _ = web
    app = launch("HelloWeb", args=["-interact", "-server", f"http://127.0.0.1:{port}"])
    ios_green = lambda c: c[1] > 170 and c[0] < 90 and c[2] < 120                  # #34c759
    app.wait_until(lambda: ios_green(rgb(app.screenshot("interact"), 100, 520)), what="the interact page is drawn")

    app.send("drag 60 130 60 130 0.05 0 0.9")                             # long press on "quick"
    app.wait_log(r'^isim: WKWebView selected "quick"')
    app.wait_view(r"id=isim-menu-Copy")
    app.tap_id("isim-menu-Copy")
    app.wait_log(r'^isim: WKWebView copied "quick"')
    app.tap_id("paste")
    app.wait_log(r"^HelloWeb: pasteboard url=- string=quick zoom=1\.0")

    app.send("drag 100 210 100 210 0.05 0 0.9")                           # long press on the link
    app.wait_log(rf"^HelloWeb: context menu for http://127\.0\.0\.1:{port}/page3")
    app.wait_tap_id("menu-Copy Link")                                     # Open, Copy Link, Share…
    app.wait_log(r"^HelloWeb: context menu ended")
    app.tap_id("paste")
    app.wait_log(rf"^HelloWeb: pasteboard url=http://127\.0\.0\.1:{port}/page3")

    app.tap(100, 363)                                                     # <select> fruit
    app.wait_log(r"^isim: WKWebView <select> with [0-9]+ option\(s\)")
    app.wait_view(r"id=menu-Banana")
    app.tap_id("menu-Banana")
    app.wait_log(r"^HelloWeb: page says select banana")
    app.tap(100, 413)                                                     # <select multiple> (on its Red row: the tap only opens
                                                                          # the menu, it does not pick Red): the menu stays up
    app.wait_view(r"id=menu-Blue")
    app.tap_id("menu-Blue")
    app.wait_view(r"id=menu-Red")
    app.tap_id("menu-Red")
    app.wait_log(r"^HelloWeb: page says many red,green,blue")
    app.tap(200, 700)                                                     # dismiss the menu

    app.wait_tap_id("find")
    app.wait_log(r"keyboard shown")
    app.type("isim")
    app.wait_log(r'^isim: WKWebView find "isim": 4 result\(s\)')
    app.wait_view(r"text=1 of 4")

    app.wait_tap_id("pdf")
    app.wait_log(r"^HelloWeb: pdf [0-9]+ bytes PDF 1 page\(s\) [34][0-9][0-9]x[0-9]+")
    app.wait_log(r"^HelloWeb: pdf cropped 1 page\(s\) 200x100")
    app.tap_id("archive")
    app.wait_log(rf"^HelloWeb: archive text/html http://127\.0\.0\.1:{port}/ html=true subresources=1")

    app.send("pinch 200 500 2.0 0.6")
    app.wait_log(r"^isim: WKWebView zoom 2\.00")
    app.tap_id("paste")
    app.wait_log(r"^HelloWeb: pasteboard .* zoom=2\.0")
    assert app.quit() == 0


def test_web_webpage(launch, web):
    """SwiftUI WebView showing a WebPage (iOS 26): navigation events from load(html:baseURL:), the observable title,
    url and isLoading, callJavaScript with arguments."""
    port, _ = web
    app = launch("HelloWeb", os_version="26", args=["-webpage", "-server", f"http://127.0.0.1:{port}"])
    app.wait_log(r"^HelloWeb: navigation startedProvisionalNavigation")
    app.wait_log(r"^HelloWeb: navigation committed")
    app.wait_log(r"^HelloWeb: navigation finished")
    app.wait_log(rf"^HelloWeb: loaded title=Interact loading=false url=http://127\.0\.0\.1:{port}/")
    app.wait_view(r"id=page-title\n\s*UILabel .*text=Interact$")
    app.wait_tap_id("page-js")
    app.wait_log(r"^HelloWeb: callJavaScript Interact 5")
    assert app.quit() == 0


def test_web_objc(launch):
    """WebKit from Objective-C (HelloWebObjC, #200): Apple's class names, a WKUserContentController subclass, a category,
    delegates under Apple's selectors, script messages, KVO on Apple's key paths, JavaScript calls and a snapshot"""
    if not (ROOT / "out/bin/isim-webkit").exists():
        pytest.skip("no web engine helper (needs WebKitGTK 6.0 and gtk4-broadwayd on the host)")
    app = launch("HelloWebObjC")
    app.wait_log(r"^HelloWebObjC: classes WKWebView WKWebViewConfiguration WKUserContentController domain=WKErrorDomain")
    app.wait_log(r"^HelloWebObjC: config media=0 inline=1 persistent=0 scripts=1")
    app.wait_log(r"^HelloWebObjC: didStartProvisionalNavigation", timeout=30)
    for line in ( "didCommitNavigation", r"didFinishNavigation https://objc\.example/ loading=0",
                 "kvo loading=1", "kvo loading=0", r"kvo estimatedProgress=1\.0", "kvo title=ObjC page",
                 r"message native: kind=script href=https://objc\.example/ controller=SampleContentController",
                 "evaluateJavaScript: ObjC page / 42 error=none", "exception: domain=WKErrorDomain code=4",
                 "isolated world: typeof show = undefined", "callAsyncJavaScript: 42", r"snapshot \d+x\d+"):
        app.wait_log(r"^HelloWebObjC: " + line)
    shot = app.wait_until(lambda: (lambda s: s if red(rgb(s, 60, 120)) else None)(app.screenshot("objc")), what="the page is drawn")
    assert red(rgb(shot, 120, 160))
    app.tap(50, 210)                                                    # the page link "Blocked link"
    app.wait_log(r"^HelloWebObjC: policy https://blocked\.example/ type=0 main=1 -> cancel")
    assert app.quit() == 0
