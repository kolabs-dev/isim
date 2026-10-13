"""VoIP calls under `isim boot` (HelloCalls): PushKit (the VoIP push token, VoIP pushes to the running app and to an app
that is not running, which is launched in the background; an app that reports no call for a VoIP push is terminated)
and CallKit (the incoming call banner and the full-screen incoming call on the Lock Screen, the ringtone, answering
and declining, the call screen's mute / keypad (DTMF) / hold / speaker / app buttons, Home hiding it behind the green
call indicator, ending from the call screen, from the app and from the other side; outgoing calls placed with
CXCallController; CXCallObserver; the request checks; Call Directory status). System UI: os_matrix. Screenshots also
go to ISIM_SHOTS_DIR when it is set."""
import os

import pytest

from isimtest import ROOT, rgb

APP = "dev.isim.samples.HelloCalls"
P = ROOT / "samples" / "HelloCalls" / "payloads"
ALICE = "6F1C3A52-2B8E-4C59-9D34-1A2B3C4D5E01"

pytestmark = pytest.mark.os_matrix


def keep(img, name):
    d = os.environ.get("ISIM_SHOTS_DIR")
    if d:
        os.makedirs(d, exist_ok=True)
        img.save(os.path.join(d, f"{name}.png"))
    return img


def push(dev, payload):
    dev.send(f"push {APP} {P / payload}")


def started(launch):
    dev = launch(None, install=["HelloCalls"])
    dev.send(f"launch {APP}")
    dev.wait_log(r"HelloCalls: voip token [0-9a-f]{64} \(32 bytes\) same=true")
    return dev


def test_incoming_banner_and_call_screen(launch):
    dev = started(launch)
    push(dev, "incoming.apns")
    dev.wait_log(r"isim: PushKit: incoming VoIP push")
    dev.wait_log(rf"HelloCalls: reported incoming call {ALICE} error=nil")
    dev.wait_log(r"isim shell: incoming audio call from Alice Appleseed \(Calls\)")
    dev.wait_log(r"isim: PushKit: VoIP push \S+ handled")
    dev.wait_dump(r"IsimCallButton .* id=call-banner text=Alice Appleseed")
    s = keep(dev.wait_shot_still(), "call-banner")
    assert max(rgb(s, 240, 78)) < 40, "the banner is dark"
    dev.wait_log(r"HelloCalls: observer 6F1C3A52 outgoing=false connected=false hold=false ended=false calls=1")

    dev.tap_id("call-banner")                                     # the full-screen incoming call
    dev.wait_dump(r"id=call-decline text=Decline")
    keep(dev.wait_shot_still(), "call-incoming")
    dev.tap_id("call-accept")
    dev.wait_log(rf"HelloCalls: perform answer {ALICE}")
    dev.wait_log(r"HelloCalls: audio session activated")
    dev.wait_log(r"isim shell: call with Alice Appleseed connected")
    dev.wait_log(r"connected=true hold=false ended=false calls=1")
    dev.wait_dump(r"id=call-status text=00:0\d")
    keep(dev.wait_shot_still(), "call-screen")

    dev.tap_id("call-mute")
    dev.wait_log(r"HelloCalls: perform mute true")
    dev.tap_id("call-speaker")
    dev.wait_log(r"isim: CallKit: audio route speaker")
    dev.tap_id("call-hold")
    dev.wait_log(r"HelloCalls: perform hold true")
    dev.wait_dump(r"id=call-status text=on hold")
    dev.tap_id("call-hold")
    dev.wait_log(r"HelloCalls: perform hold false")
    dev.tap_id("call-keypad")
    dev.wait_dump(r"id=call-key-5 text=5")
    dev.tap_id("call-key-5")
    dev.wait_log(r"HelloCalls: perform dtmf 5")
    keep(dev.wait_shot_still(), "call-keypad")
    dev.tap_id("call-keypad-hide")

    dev.send("home")                                              # the call goes on behind the indicator
    dev.wait_dump(r"id=call-pill")
    dev.tap_id("call-pill")
    dev.wait_dump(r"id=call-end text=End")
    dev.tap_id("call-app")                                        # opens the app
    dev.wait_log(r"isim shell: opened Calls from the call")
    dev.wait_dump(r"id=call-pill")
    keep(dev.wait_shot_still(), "call-pill")
    dev.tap_id("end-call")                                        # the app ends it (CXCallController)
    dev.wait_log(r"HelloCalls: request end error=nil")
    dev.wait_log(rf"HelloCalls: perform end {ALICE}")
    dev.wait_log(r"HelloCalls: audio session deactivated")
    dev.wait_log(rf"isim shell: call {ALICE} with Alice Appleseed ended \(ended\)")
    dev.wait_log(r"ended=true calls=0")


def test_decline_and_remote_end(launch):
    dev = started(launch)
    push(dev, "video.apns")
    dev.wait_log(r"isim shell: incoming video call from Bob \(Calls\)")
    dev.tap_id("call-decline")
    dev.wait_log(r"HelloCalls: perform end 6F1C3A52-2B8E-4C59-9D34-1A2B3C4D5E02")
    dev.wait_log(r"isim shell: declined the call Bob")

    push(dev, "incoming.apns")                                    # answered from the banner, ended by the other side
    dev.wait_dump(r"id=call-banner")
    dev.tap_id("call-accept")
    dev.wait_log(r"isim shell: call with Alice Appleseed connected")
    dev.tap_id("call-end")
    dev.wait_log(rf"HelloCalls: perform end {ALICE}")
    push(dev, "incoming.apns")
    dev.wait_log(r"isim shell: incoming audio call", count=2)
    dev.tap_id("call-accept")
    dev.wait_log(r"isim shell: call with Alice Appleseed connected", count=2)
    dev.send("home")
    dev.tap_id("remote-end")
    dev.wait_log(rf"isim: CallKit: call {ALICE} ended \(remoteEnded\)")
    dev.wait_log(rf"isim shell: call {ALICE} with Alice Appleseed ended \(remoteEnded\)")


def test_outgoing_and_requests(launch):
    dev = started(launch)
    dev.tap_id("call-out")
    dev.wait_log(r"HelloCalls: request start error=nil")
    dev.wait_log(r"HelloCalls: perform start Bob video=false")
    dev.wait_log(r"isim shell: outgoing call to Bob \(Calls\)")
    dev.wait_log(r"isim shell: call with Bob connected")
    dev.wait_log(r"outgoing=true connected=true hold=false ended=false calls=1")
    dev.tap_id("mute")
    dev.wait_log(r"HelloCalls: perform mute true")
    dev.send("home")
    dev.wait_dump(r"id=call-pill")                                 # in the background: the green indicator
    dev.tap_id("call-pill")
    dev.wait_dump(r"IsimCallScreen")
    dev.tap_id("call-end")
    dev.wait_log(r"HelloCalls: perform end")
    dev.wait_log(r"ended=true calls=0")

    dev.send(f"launch {APP}")
    dev.tap_id("bad-requests")
    dev.wait_log(r"HelloCalls: request empty error=com.apple.CallKit.error.requesttransaction 3")
    dev.wait_log(r"HelloCalls: request unknown error=com.apple.CallKit.error.requesttransaction 4")
    dev.wait_log(r"HelloCalls: directory status=0 error=1")


def test_not_running_and_locked(launch):
    """the app is not running: the VoIP push launches it in the background; the Lock Screen shows the call full screen"""
    dev = launch(None, install=["HelloCalls"])
    dev.send("lock")
    push(dev, "incoming.apns")
    dev.wait_log(r"HelloCalls: didFinishLaunching state=background")
    dev.wait_log(r"isim: VoIP push \S+ \(launched in the background for it\)")
    dev.wait_log(r"isim shell: incoming audio call from Alice Appleseed")
    dev.wait_dump(r"id=call-accept text=slide to answer")
    keep(dev.wait_shot_still(), "call-locked")
    dev.tap_id("call-accept")
    dev.wait_log(rf"HelloCalls: perform answer {ALICE}")
    dev.wait_log(r"isim shell: call with Alice Appleseed connected")
    dev.wait_dump(r"id=call-end")
    dev.tap_id("call-end")
    dev.wait_log(r"HelloCalls: audio session deactivated")


def test_voip_push_without_a_call(launch):
    """iOS 13+: an app that reports no incoming call for a VoIP push is terminated"""
    dev = started(launch)
    push(dev, "noreport.apns")
    dev.wait_log(r"HelloCalls: not reporting a call")
    dev.wait_log(r"isim: PushKit: terminating the app: it never posted an incoming call")
