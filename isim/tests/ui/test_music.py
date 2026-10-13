"""The music library (HelloMusic): MPMediaLibrary authorization (the privacy alert), queries over the simulated
library (six generated songs: two albums by two artists), predicates, sections, playlists (seeded, and one the app
creates), MPMusicPlayerController playing an album (Control Center shows it on a booted device), skipping, and
MPMediaPickerController picking two songs."""
import re

import pytest

pytestmark = pytest.mark.os_matrix


def test_music(launch):
    dev = launch(None, install=["HelloMusic"])
    dev.send("launch dev.isim.samples.HelloMusic")
    alert = dev.wait_view(r"text=Allow")
    dev.screenshot("music-permission")
    dev.tap_text("Allow")
    dev.wait_log(r"HelloMusic: playing ")
    dev.wait_log(r"isim shell: Now Playing Morning Sine — The Oscillators \(Music Demo\)")
    dev.tap_id("next")
    dev.wait_log(r"HelloMusic: now playing item Square Dance")
    dev.wait_view(r"id=now-playing text=Square Dance")
    dev.tap_id("pick-songs")
    dev.wait_view(r"id=media-picker-Render-Loop")
    dev.tap_id("media-picker-Render-Loop")
    dev.tap_id("media-picker-Device-Data")
    dev.wait_still()
    dev.screenshot("media-picker")
    dev.tap_id("media-picker-done")
    dev.wait_log(r"HelloMusic: picked ")
    dev.wait_log(r"isim shell: Now Playing Device Data — isim Ensemble")
    dev.send("controlcenter")
    dev.wait_dump(r"id=cc-nowplaying text=Device Data — isim Ensemble")
    dev.screenshot("music-control-center")
    dev.tap_id("cc-np-next")                                         # the system player handles the remote command
    dev.wait_log(r"HelloMusic: now playing item Render Loop")
    assert dev.quit() == 0, "exits cleanly"
    log = dev.log

    def has(p):
        return re.search(p, log, re.M)
    assert "Would Like to Access Apple Music, Your Music and Video Activity, and Your Media Library" in alert and \
        "Plays songs from your library." in alert and has(r"authorization true"), "media library permission alert, allowed"
    assert has(r"songs 6: Device Data, Headless Lullaby, Morning Sine, Render Loop, Square Dance, Triangle Sunset"), "songs query (sorted)"
    assert has(r"albums Simulated Sessions \(3\), Sine Waves \(3\)"), "albums grouping"
    assert has(r"artists The Oscillators, isim Ensemble|artists isim Ensemble, The Oscillators"), "artists grouping"
    assert has(r"ambient Device Data, Headless Lullaby, Render Loop"), "genre predicate"
    assert has(r"contains sine 1"), "contains predicate"
    assert has(r"by id Device Data duration 9 artwork true asset true"), "persistent ID predicate, item properties"
    assert has(r"sections DHMRST"), "item sections"
    assert has(r"playlists isim Favorites \(3\)"), "seeded playlist"
    assert has(r"app playlist Demo Mix 2"), "app playlist created and filled"
    assert has(r"playing Morning Sine index 0 time true"), "system player plays the album"
    assert has(r"picked Render Loop, Device Data|picked Device Data, Render Loop"), "media picker (two songs)"
