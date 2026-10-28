"""The system frameworks ad, login and VoIP SDKs use from Objective-C (HelloServicesObjC, issue #231), under `isim boot`:
PushKit (the VoIP token; a VoIP push to the app reports an incoming call), CallKit (CXProvider with its delegate on a
dispatch queue: answering from the incoming call screen, an outgoing call through CXCallController, ending them,
CXCallObserver, a refused request with CXErrorDomainRequestTransaction), BackgroundTasks (registering and submitting
from Objective-C; `bgtask` runs the task on its dispatch queue; an identifier missing from Info.plist is refused),
CoreSpotlight (indexing), SafariServices (SFSafariViewController with a configuration and delegate; the Reading List)
MultipeerConnectivity (an advertiser and a browser in the app connect and exchange data) and Messages (issue #406: an
MSMessagesAppViewController subclass, a message in a session copied and archived, a refused sticker)."""
import os

import pytest

from isimtest import ROOT

APP = "dev.isim.samples.HelloServicesObjC"
CALL = "7A2B3C4D-1E2F-4A5B-8C9D-0E1F2A3B4C5D"

pytestmark = pytest.mark.os_matrix          # the call UI and Safari's chrome are system UI


def keep(img, name):
    """screenshots also go to ISIM_SHOTS_DIR when it is set"""
    d = os.environ.get("ISIM_SHOTS_DIR")
    if d:
        os.makedirs(d, exist_ok=True)
        img.save(os.path.join(d, f"{name}.png"))


def test_services_objc(launch):
    dev = launch(None, install=["HelloServicesObjC"])
    dev.send(f"launch {APP}")
    dev.wait_log(r"^sy voip token 32 bytes type=PKPushTypeVoIP same=1$")
    dev.wait_log(r"^sy provider began queue=1$")
    dev.wait_log(r"^sy bg registered=1 other=0 submitted=1 error=nil refused=1 error=BGTaskSchedulerErrorDomain/3$")
    dev.wait_log(r"^sy bg pending 1 first=dev\.isim\.samples\.HelloServicesObjC\.refresh date=1$")
    dev.wait_log(r"^sy spotlight available=1 expires=1$")
    dev.wait_log(r"^sy spotlight indexed note-1 error=nil activity=com\.apple\.corespotlightitem$")
    dev.wait_log(r"^sy reading list ok=1 refused=1 error=SSReadingListErrorDomain/1 supports=1$")
    dev.wait_log(r"^sy content blocker state=0 error=SFErrorDomain/1 reload=SFErrorDomain/1 missing=1$")
    dev.wait_log(r"^sy messages caption=Your move copy=Your move session=1 archived=board=X-------- sameSession=1 pending=1 "
                 r"sticker=0 error=format style=0 active=0$")               # Messages (issue #406)
    dev.wait_log(r"^sy unknown call error=com\.apple\.CallKit\.error\.requesttransaction/4$")

    # MultipeerConnectivity: Ann browses, finds Ben, invites him; data both ways
    dev.wait_log(r"^sy mc started service=isim-svcobjc delegate=1$")
    dev.wait_log(r"^sy mc found Ben room=objc$")
    dev.wait_log(r"^sy mc invitation from Ann context=hello$")
    dev.wait_log(r"^sy mc Ann connected to Ben$")
    dev.wait_log(r"^sy mc sent ok=1 error=nil$")
    dev.wait_log(r"^sy mc Ben received ping from Ann$")
    dev.wait_log(r"^sy mc Ann received pong from Ben$")

    # BackgroundTasks: the task runs on the queue it was registered with
    dev.send(f"bgtask {APP} {APP}.refresh")
    dev.wait_log(r"^sy bg task dev\.isim\.samples\.HelloServicesObjC\.refresh refresh=1 queue=1$")

    # PushKit -> CallKit: a VoIP push reports an incoming call, answered from the call screen
    dev.send(f"push {APP} {ROOT / 'samples/HelloServicesObjC/payloads/incoming.apns'}")
    dev.wait_log(r"^sy push PKPushTypeVoIP caller=Bea Objc main=1$")
    dev.wait_log(r"^sy reported incoming error=nil$")
    dev.wait_log(r"isim: PushKit: VoIP push \S+ handled")
    dev.wait_log(rf"^sy observer {CALL[:8]} outgoing=0 connected=0 ended=0 main=1$")
    dev.wait_dump(r"id=call-banner text=Bea Objc")
    dev.tap_id("call-banner")
    dev.wait_dump(r"id=call-accept")
    keep(dev.wait_shot_still(), "services-objc-incoming")
    dev.tap_id("call-accept")
    dev.wait_log(rf"^sy perform answer {CALL} queue=1$")
    dev.wait_log(r"^sy audio session activated$")
    dev.wait_log(rf"^sy observer {CALL[:8]} outgoing=0 connected=1 ended=0 main=1$")
    dev.tap_id("call-mute")
    dev.wait_log(r"^sy perform mute 1$")
    dev.tap_id("call-end")
    dev.wait_log(rf"^sy perform end {CALL} queue=1$")
    dev.wait_log(rf"^sy observer {CALL[:8]} outgoing=0 connected=1 ended=1 main=1$")

    # an outgoing call through CXCallController; the app ends it when it connects
    dev.wait_tap_id("call-start")
    dev.wait_log(r"^sy start requested error=nil main=1$")
    dev.wait_log(r"^sy perform start \S+ handle=Cy queue=1$")
    dev.wait_log(r"^sy observer \S+ outgoing=1 connected=1 ended=0 main=1$")
    dev.wait_log(r"^sy end requested 1 error=nil$")
    dev.wait_log(r"^sy observer \S+ outgoing=1 connected=1 ended=1 main=1$")

    # SafariServices: the in-app browser with the Close button, its delegate told when it is dismissed
    dev.wait_tap_id("safari")
    dev.wait_log(r"^sy safari present collapsing=0 delegate=1$")
    dev.wait_dump(r"id=safari-done text=Close")
    dev.wait_log(r"^sy safari initial load [01]$", timeout=30)
    keep(dev.wait_shot_still(), "services-objc-safari")
    dev.tap_id("safari-done")
    dev.wait_log(r"^sy safari finished$")
