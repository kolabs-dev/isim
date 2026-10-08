"""Back-to-back transitions (issue #6): a pop or a dismiss that starts before the push / presentation has finished
must end with the screen behind it on screen (HelloStoryboards: performSegue push, then back; a pushed xib
controller, then its Close button pops; a presented page sheet, then Close). No wait_still() between the steps on
purpose."""
import re


def test_pop_during_push(launch):
    app = launch("HelloStoryboards")
    app.wait_tap_id("note-1")
    app.wait_view(r"id=detail-more")
    app.wait_still()
    app.tap_id("detail-more")
    app.wait_view(r"id=more-label")
    app.tap_id("nav-back")                                    # the push is still animating
    app.wait_view(r"id=more-label", gone=True)
    dump = app.wait_still()
    assert app.quit() == 0, "apps exit cleanly"
    assert re.search(r"id=detail-title text=Ideas", dump) and "id=detail-more" in dump, \
        "the detail screen is back on screen after a pop during the push\n" + dump


def close_profile_early(app, opener):
    app.wait_tap_id("tab-Controls")
    app.wait_view(r"id=rounded-view")
    app.wait_still()
    app.tap_id(opener)
    app.wait_view(r"id=profile-close")
    app.tap_id("profile-close")                               # the push / presentation is still animating
    app.wait_log(r"profile: close")
    app.wait_view(r"id=profile-close", gone=True)
    dump = app.wait_still()
    assert app.quit() == 0, "apps exit cleanly"
    return dump


def test_pop_from_pushed_controller_during_push(launch):
    dump = close_profile_early(launch("HelloStoryboards"), "open-profile")
    assert "id=rounded-view" in dump and "id=open-profile" in dump, \
        "the controls screen is back on screen after the pushed profile pops itself during the push\n" + dump


def test_dismiss_during_present(launch):
    dump = close_profile_early(launch("HelloStoryboards"), "open-default-nib")
    assert "id=rounded-view" in dump and "id=open-profile" in dump, \
        "the presenting screen is back on screen after a dismiss during the presentation\n" + dump
