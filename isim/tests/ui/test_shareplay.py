"""SharePlay on isim's local bus (HelloSharePlay, GroupActivities; issue #392). Two devices (Pat and Sam) join one
simulated call (the `shareplay` script command, ISIM_SHAREPLAY_CALL): Pat starts the WatchTogether activity (the
prepareForActivation alert, "SharePlay"), both get its session and join; a chat message (reliable), a reaction
(unreliable) and an event reach Sam; a journal note with its metadata reaches both; Pat's play and pause are applied to
Sam's player at the same time (AVPlaybackCoordinator.coordinateWithSession: Pat's AVPlayer's coordinator, Sam's app
playing the commands of an AVDelegatingPlaybackCoordinator, -delegating); Pat changes the movie; Sam leaves, Pat
ends the session; Sam starts SharePlay again from GroupActivitySharingController and Pat gets the new session."""
import re


def test_shareplay(launch, tmp_path):
    pat = launch("HelloSharePlay", data=tmp_path / "pat", animations=False)
    sam = launch("HelloSharePlay", data=tmp_path / "sam", animations=False, env={"ISIM_SHAREPLAY_CALL": "movie-night"},
                 args=["-delegating"])

    pat.wait_log(r"HelloSharePlay: identifier dev\.isim\.samples\.HelloSharePlay\.WatchTogether")
    pat.wait_log(r"HelloSharePlay: eligible false")
    sam.wait_log(r"HelloSharePlay: eligible true")
    pat.send("shareplay join movie-night")
    pat.wait_log(r"HelloSharePlay: eligible true")
    pat.send("shareplay")
    pat.wait_log(r"isim GroupActivities: in the SharePlay call movie-night with 1 other participant\(s\)")

    # Pat starts the activity: the system asks first
    pat.tap_id("start")
    pat.wait_view(r"Do you want to SharePlay “Big Buck Bunny”\?")
    pat.tap_text("SharePlay")
    pat.wait_log(r"HelloSharePlay: prepare activationPreferred")
    pat.wait_log(r"HelloSharePlay: activated true")
    pat.wait_log(r"HelloSharePlay: session Big Buck Bunny local true")
    sam.wait_log(r"HelloSharePlay: session Big Buck Bunny local false")
    for d in (pat, sam):
        d.wait_log(r"HelloSharePlay: state joined")
        d.wait_log(r"HelloSharePlay: participants 2")

    # messages: reliable, unreliable, an event
    pat.tap_id("send")
    pat.wait_log(r"HelloSharePlay: sent")
    sam.wait_log(r"HelloSharePlay: chat Popcorn ready\? from other true")
    sam.wait_log(r"HelloSharePlay: reaction 🍿")
    sam.wait_log(r"isim GroupActivities: event from \w+: started chatting")

    # the journal: a note with metadata, seen by both
    pat.tap_id("attach")
    pat.wait_log(r"HelloSharePlay: attached")
    for d in (pat, sam):
        d.wait_log(r"HelloSharePlay: attachments 1")
        d.wait_log(r"HelloSharePlay: note Popcorn at 8 by host")

    # coordinated playback: Pat plays, Sam's player follows; Pat pauses, Sam pauses at the same time
    pat.tap_id("play")
    sam.wait_log(r"HelloSharePlay: command play rate 1\.0 at 0\.\d item movie")
    sam.wait_log(r"HelloSharePlay: player rate 1\.0")
    pat.wait_log(r"HelloSharePlay: player rate 1\.0")
    pat.wait_log(r"HelloSharePlay: playing at [2-9]\.\d")
    sam.wait_log(r"HelloSharePlay: playing at [2-9]\.\d")
    pat.tap_id("pause")
    sam.wait_log(r"HelloSharePlay: command pause")
    a = float(pat.wait_log(r"HelloSharePlay: player rate 0\.0 at (\d+\.\d)").group(1))
    b = float(sam.wait_log(r"HelloSharePlay: player rate 0\.0 at (\d+\.\d)").group(1))
    assert a >= 2 and abs(a - b) < 0.5, f"Sam paused at {b}, Pat at {a}"

    # the activity changes for everyone
    pat.tap_id("next")
    sam.wait_log(r"HelloSharePlay: activity Tears of Steel")

    # Sam leaves; Pat ends the session
    sam.tap_id("leave")
    sam.wait_log(r"HelloSharePlay: state invalidated")
    pat.wait_log(r"HelloSharePlay: participants 1")
    pat.tap_id("end")
    pat.wait_log(r"HelloSharePlay: state invalidated: The session ended\.")

    # Sam starts SharePlay from the sharing controller
    sam.tap_id("share")
    sam.wait_tap_id("shareplay-start")
    sam.wait_log(r"HelloSharePlay: sharing result success")
    sam.wait_log(r"HelloSharePlay: session Sintel local true")
    pat.wait_log(r"HelloSharePlay: session Sintel local false")
    pat.wait_log(r"HelloSharePlay: participants 2", count=2)

    # Pat leaves the call: no longer eligible, the session goes
    pat.send("shareplay leave")
    pat.wait_log(r"HelloSharePlay: eligible false")
    pat.wait_log(r"HelloSharePlay: state invalidated", count=2)
    for d in (pat, sam):
        assert not re.search(r"HelloSharePlay: (send|attach) failed|no session", d.log)
        assert d.quit() == 0


def test_playback_coordination_medium(launch):
    """HelloSharePlay -medium: two AVPlayers in one app follow each other through an AVPlaybackCoordinationMedium."""
    app = launch("HelloSharePlay", args=["-medium"], animations=False)
    app.wait_log(r"HelloSharePlay: medium coordinators 2 others 1")
    app.wait_log(r"HelloSharePlay: medium second rate 1\.0")
    m = app.wait_log(r"HelloSharePlay: medium paused first (\d+\.\d) second (\d+\.\d) rate 0\.0")
    a, b = float(m.group(1)), float(m.group(2))
    assert a >= 1.5 and abs(a - b) < 0.3, (a, b)
    assert app.quit() == 0
