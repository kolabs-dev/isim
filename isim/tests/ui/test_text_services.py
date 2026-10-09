"""Text services (HelloTextServices, UIKit): Password AutoFill (the QuickType bar offers saved passwords, "Save
Password?" after a sign-in, strong passwords for newPassword fields, one-time codes from a text message), dictation
(the keyboard's mic and `dictate`), Scribble on iPad (direct, declined by a delegate, indirect), inline predictions,
learning a kept word, and the data detectors of a read-only text view."""
import re

import pytest
from isimtest import rgb


def keys(app, word):
    for ch in word:
        app.wait_tap_id(f"isim-kb-{ch}")


@pytest.mark.os_matrix
def test_password_autofill(launch, ios):
    app = launch("HelloTextServices")
    app.wait_tap_id("user")
    app.wait_log(r"keyboard shown")
    app.type("alice@shop.isim.dev")
    app.wait_tap_id("password")
    app.type("hunter22pass")
    app.wait_log(r"password changed: hunter22pass")
    app.wait_tap_id("signIn")                                           # the form leaves the screen: save it?
    app.wait_log(r"AutoFill: save password prompt for alice@shop.isim.dev \(shop.isim.dev\)")
    app.wait_view(r"Save Password\?")
    app.screenshot("save-password")
    app.tap_text("Save Password")
    app.wait_log(r"AutoFill: saved the password of alice@shop.isim.dev for shop.isim.dev")

    app.wait_tap_id("nav-back")
    app.wait_view(r"id=signIn")
    app.wait_tap_id("password")                                         # the saved password is offered
    app.type("x")
    app.wait_for(id="isim-kb-autofill-0", label="alice@shop.isim.dev")
    app.wait_still()
    app.screenshot("quicktype-password")
    app.wait_tap_id("isim-kb-autofill-0")
    app.wait_log(r"AutoFill: filled 2 field\(s\) with the password of alice@shop.isim.dev \(shop.isim.dev\)")
    app.wait_log(r"password changed: hunter22pass$", count=2)
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_strong_password_and_code(launch, ios):
    app = launch("HelloTextServices")
    app.wait_tap_id("signUp")
    app.wait_tap_id("newUser")
    app.type("bob@shop.isim.dev")
    app.wait_tap_id("newPassword")
    app.wait_for(id="isim-kb-autofill-0", label="Use Strong Password")
    app.wait_tap_id("isim-kb-autofill-0")
    m = app.wait_log(r"newPassword changed: ([a-zA-Z0-9]{6}-[a-zA-Z0-9]{6}-[a-zA-Z0-9]{6})$")
    pw = m.group(1)
    assert re.search(r"[A-Z]", pw) and re.search(r"\d", pw), pw
    app.wait_log(rf"confirmPassword changed: {pw}$")
    app.wait_still()
    shot = app.screenshot("strong-password")
    f = app.find(id="newPassword")
    c = rgb(shot, f.x + f.w - 12, f.y + f.h / 2)
    assert c[0] > 200 and c[1] > 190 and c[2] < 200, f"the strong password field is yellow: {c}"
    app.wait_tap_id("create")
    app.wait_log(r"account created for bob@shop.isim.dev \(password 20 characters, confirmed true\)")
    app.wait_view(r"Save Password\?")
    app.tap_text("Not Now")
    app.wait_log(r"AutoFill: password not saved")

    app.wait_tap_id("nav-back")
    app.wait_tap_id("nav-back")
    app.wait_tap_id("verify")                                           # one-time code from Messages
    app.wait_tap_id("code")
    app.wait_log(r"keyboard shown")
    app.send("sms Your Shop code is 482913. Don't share it.")
    app.wait_log(r"message received: .*\(code 482913\)")
    app.wait_for(id="isim-kb-autofill-0", label="482913")
    app.wait_still()
    app.screenshot("one-time-code")
    app.wait_tap_id("isim-kb-autofill-0")
    app.wait_log(r"code changed: 482913$")
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_dictation_and_predictions(launch, ios):
    app = launch("HelloTextServices")
    app.wait_tap_id("dictation")
    app.wait_log(r"keyboard shown")
    app.wait_tap_id("isim-kb-dictation")                                # the mic starts listening
    app.wait_log(r"dictation started")
    app.wait_view(r"id=isim-dictation-listening")
    app.screenshot("dictation-listening")
    app.send("dictate hello there comma how are you question mark")
    app.wait_log(r"dictation result: Hello there, how are you\?$")
    app.wait_log(r"dictation recording did end")
    app.send("dictate fine thanks period")
    app.wait_log(r"dictation result:  Fine thanks\.$")
    app.send("dictate fail")
    app.wait_log(r"dictation recognition failed")
    app.wait_tap_id("isim-kb-dictation")
    app.wait_log(r"dictation stopped")

    app.wait_tap_id("notes")                                            # inline prediction: space accepts it
    keys(app, "tomor")
    app.wait_view(r"id=isim-inline-prediction .*text=row")
    app.wait_still()
    app.screenshot("inline-prediction")
    app.wait_tap_id("isim-kb-space")
    m = app.wait_log(r"inline prediction accepted \"(Tomor\w+)\"")
    word = m.group(1)
    app.wait_dump(rf"id=notes .*\"{word} \"")
    keys(app, "zorbly")                                                 # keep the typed word: it is learned
    app.wait_tap_id("isim-kb-suggestion-0")
    app.wait_log(r"learned the word \"zorbly\"")
    keys(app, "zorb")
    app.wait_for(id="isim-kb-suggestion-1", label="zorbly")
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_scribble(launch, ios):
    osv = ios[0]
    if osv and str(osv).split(".")[0] == "17":
        osv = "17.5"                                                    # the iPad Pro 11-inch (M4) needs iOS 17.5
    app = launch("HelloTextServices", device="ipadpro11", os_version=osv)
    app.wait_log(r"isPencilInputExpected: false")
    u = app.wait_for(id="user")
    app.send(f"scribble {u.x + 20} {u.y + u.h / 2} hello")
    app.wait_view(r"id=isim-scribble-ink")
    app.screenshot("scribble-ink")
    app.wait_log(r"Scribble wrote \"hello\" into UITextField \(user\)")
    app.wait_log(r"user changed: hello$")
    assert not app.has(r"keyboard shown"), "writing with the Pencil does not bring up the keyboard"
    app.send(f"scribble {u.x + u.w - 40} {u.y + u.h / 2} world")          # at the end: after a space
    app.wait_log(r"user changed: hello world$")

    lk = app.wait_for(id="locked")                                      # a UIScribbleInteraction delegate declines
    app.send(f"scribble {lk.x + 30} {lk.y + lk.h / 2} nope")
    app.wait_log(r"scribble asked at \d+,\d+: declined")
    app.wait_log(r"Scribble declined by")

    s = app.wait_for(id="searchTarget")                                 # indirect: the label becomes a search field
    app.send(f"scribble {s.x + 60} {s.y + s.h / 2} shoes")
    app.wait_log(r"will begin writing in search")
    app.wait_log(r"focus element search")
    app.wait_log(r"search: shoes$")
    app.wait_log(r"did finish writing in search")
    app.wait_tap_id("search")                                           # a finger tap brings the keyboard back
    app.wait_log(r"keyboard shown")
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_data_detectors(launch, ios):
    app = launch("HelloTextServices")
    info = app.wait_for(id="info")
    app.wait_still()
    shot = app.screenshot("data-detectors")
    lines = [info.y + 8 + 19 * i + 10 for i in range(5)]                # 16 pt text: ~19 pt lines
    def tinted(y):
        return any((lambda c: c[2] > 180 and c[0] < 120)(rgb(shot, x, y)) for x in range(int(info.x) + 60, int(info.x) + 200, 2))
    assert tinted(lines[0]) and tinted(lines[1]), "the link and the phone number are drawn as links"
    x0 = info.x + 100
    app.tap(x0, lines[1])                                               # phone: the delegate's own action
    app.wait_log(r"primary action for \+1 \(555\) 010-2030 -> tel:\+15550102030")
    app.wait_log(r"calling tel:\+15550102030")
    app.tap(info.x + 60, lines[0])                                      # link: the default action opens it
    app.wait_log(r"primary action for shop.isim.dev -> http://shop.isim.dev")
    app.wait_log(r"text item opened: http://shop.isim.dev")
    app.tap(info.x + 120, lines[2])                                     # address: Maps
    app.wait_log(r"text item opened: https://maps.apple.com/\?address=1\+Infinite\+Loop")
    app.drag(info.x + 120, lines[3], info.x + 120, lines[3], 0.05, hold=0.8)   # a long press: the item's menu
    app.wait_log(r'menu for December 24, 2026: \["Show in Calendar", "Copy"\]')
    app.wait_view(r"Share Store")
    app.screenshot("item-menu")
    app.tap_text("Share Store")
    app.wait_log(r"^share store")
    app.tap(info.x + 195, lines[4])                                     # a flight: no preview on isim, its menu
    app.wait_log(r"primary action for UA 123 -> x-apple-data-detectors://flight/UA123")
    app.wait_view(r"United Airlines flight 123")
    assert app.quit() == 0
