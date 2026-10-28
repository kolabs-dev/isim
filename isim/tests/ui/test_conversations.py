"""LiveCommunicationKit on isim's CallKit engine (issue #404, HelloConversation, under `isim boot`): an incoming
conversation shows the system call UI; accepting it, mute, hold and the keypad come back as conversation actions the
app fulfills; a duplicate report is refused; an outgoing conversation is placed, connects and is ended by the app; the
other side ends the incoming one; ended conversations are in the app's recents (iOS 26: ConversationHistoryManager,
read and unread). System UI: os_matrix."""
import pytest

APP = "dev.isim.samples.HelloConversation"
IN, OUT = "7A1C3A52", "7A1C3A52"

pytestmark = pytest.mark.os_matrix


def test_conversations(launch, ios):
    dev = launch(None, install=["HelloConversation"])
    dev.send(f"launch {APP}")
    version = ios[0] or "18"
    if version.split(".") < ["17", "4"] and version.startswith("17"):   # LiveCommunicationKit is iOS 17.4
        dev.wait_log(r"^lc needs iOS 17\.4$")
        return
    dev.wait_log(r"^lc began$")

    dev.wait_tap_id("incoming")
    dev.wait_log(r"^lc reported incoming$")
    dev.wait_log(r"^lc duplicate refused 2$")                      # CXErrorCodeIncomingCallError.callUUIDAlreadyExists
    dev.wait_log(r"^lc changed 7A1C3A52 state=idle muted=false count=1$")
    dev.wait_log(r"isim shell: incoming audio call from Ana Lima \(Talk\)")
    dev.wait_dump(r"id=call-banner text=Ana Lima")
    dev.tap_id("call-banner")
    dev.wait_dump(r"id=call-accept")
    dev.tap_id("call-accept")
    dev.wait_log(r"^lc perform join$")
    dev.wait_log(r"^lc audio session activated$")
    dev.wait_log(r"^lc changed 7A1C3A52 state=joined muted=false count=1$")
    dev.wait_dump(r"id=call-status text=00:0\d")
    dev.wait_still()
    dev.screenshot("conversation-call")

    dev.tap_id("call-mute")
    dev.wait_log(r"^lc perform mute true$")
    dev.wait_log(r"^lc changed 7A1C3A52 state=joined muted=true")
    dev.tap_id("call-hold")
    dev.wait_log(r"^lc perform pause true$")
    dev.wait_log(r"^lc changed 7A1C3A52 state=paused")
    dev.tap_id("call-hold")
    dev.wait_log(r"^lc perform pause false$")
    dev.tap_id("call-keypad")
    dev.tap_id("call-key-5")
    dev.wait_log(r"^lc perform tones 5$")
    dev.tap_id("call-keypad-hide")
    dev.wait_dump(r"id=call-app")
    dev.tap_id("call-app")                                          # back to the app: the call goes on
    dev.wait_tap_id("remote-end")                                   # the other side hangs up
    dev.wait_log(r"^lc changed 7A1C3A52 state=left muted=true count=0$")
    dev.wait_log(r"isim: LiveCommunicationKit: incoming conversation in recents \(connected\)")
    dev.wait_log(r"^lc audio session deactivated$")

    dev.wait_tap_id("outgoing")                                     # an outgoing conversation
    dev.wait_log(r"^lc perform start \[\"Ana Lima\"\]$")
    dev.wait_log(r"^lc start requested$")
    dev.wait_log(r"^lc changed 7A1C3A52 state=joining")
    dev.wait_log(r"isim shell: outgoing call to \+15550100 \(Talk\)")      # the app stays in front (the call indicator)
    dev.wait_tap_id("connected")
    dev.wait_log(r"^lc changed 7A1C3A52 state=joined muted=false count=1$")
    dev.wait_tap_id("hangup")
    dev.wait_log(r"^lc perform end 7A1C3A52$")
    dev.wait_log(r"isim: LiveCommunicationKit: outgoing conversation in recents \(connected\)")

    dev.wait_tap_id("recents")
    if int(version.split(".")[0]) >= 26:
        dev.wait_log(r'^lc recents \["outgoing:connected:Ana Lima", "incoming:connected:Ana Lima"\] unread=1$')
        dev.wait_log(r"^lc unread after marking 0$")
        dev.wait_log(r"^lc cellular services 0$")
    else:
        dev.wait_log(r"^lc recents need iOS 26$")
