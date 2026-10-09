"""Interface Builder on isim (HelloStoryboards, built from an .xcodeproj by `isim build` + isim's ibtool).
- classic app: UIMainStoryboardFile window + initial controller (initWithCoder:, awakeFromNib, outlets, outlet
  collection, target-action), UILaunchScreen dictionary (asset color + navigation bar)
- scene app: UISceneStoryboardFile, LaunchScreen.storyboard, tab bar/navigation relationship segues, table view
  controller with storyboard prototype cells and a UINib-registered xib cell, selection show segue + prepare(for:sender:)
  + shouldPerformSegue, embed segue, performSegue(withIdentifier:), storyboard IDs, modal presentation from a bar button
  item, unwind segues (Done / Save / Cancel), bar button action
- controls scene: control actions, gesture recognizer from the storyboard, user defined runtime attributes, Auto
  Layout from IB, xib-backed view controllers, UIFontPickerViewController
- Settings.bundle: the app's page in Settings writes the app's UserDefaults domain, which the app reads
Port of tests/ui/storyboards.sh."""
import re

import pytest
from isimtest import ROOT, rgb

LAUNCH = {"ISIM_LAUNCH_SCREEN_SECS": "1.5"}


def test_classic(launch):
    app = launch("HelloStoryboardsClassic", launch_screen="visible", env=LAUNCH)
    launch_shot = app.wait_shot(lambda s: rgb(s, 200, 500) == (16, 112, 208),
                                "classic: UILaunchScreen dict (asset color)")
    launch_dump = app.view_dump()
    app.wait_log(r"isim: launch screen hidden")
    app.wait_tap_id("classic-increment")
    for n in (1, 2, 3):
        if n > 1:
            app.tap_id("classic-increment")
        app.wait_log(rf"classic: count {n}")
    app.tap_id("classic-reset")
    app.wait_log(r"classic: reset")
    app.tap_id("classic-increment")
    after = app.wait_view(r"id=classic-count text=Count 1")
    shot = app.wait_shot(lambda s: rgb(s, 30, 700) == (255, 255, 255), "classic: launch screen goes away")
    assert app.quit() == 0, "apps exit cleanly"
    log = app.log + "\n" + launch_dump + "\n" + after
    assert "classic: willFinishLaunching window=set" in log and \
        "classic: didFinishLaunching root=ClassicViewController storyboard=yes" in log, \
        "classic: UIMainStoryboardFile window before willFinishLaunching"
    assert "classic: initWithCoder title=Classic" in log and "classic: awakeFromNib" in log, \
        "classic: initWithCoder + awakeFromNib (ObjC class)"
    assert "classic: viewDidLoad label=Count 0 buttons=2" in log, "classic: outlets + outlet collection at viewDidLoad"
    assert "classic: count 3" in log and "classic: reset" in log and "id=classic-count text=Count 1" in log, \
        "classic: target-actions"
    assert "launch screen: UILaunchScreen UIColorName,UINavigationBar" in log and \
        "id=launch-navigation-bar" in launch_dump and rgb(launch_shot, 200, 500) == (16, 112, 208), \
        "classic: UILaunchScreen dict (asset color + bar)"
    assert "isim: launch screen hidden" in log and rgb(shot, 30, 700) == (255, 255, 255), \
        "classic: launch screen goes away"
    assert "UILabel (20 349; 362 x 44) id=classic-count" in after, "classic: Auto Layout from IB (centered label/button)"


def test_notes(launch):
    app = launch("HelloStoryboards", launch_screen="visible", env=LAUNCH)
    launch_shot = app.wait_shot(lambda s: rgb(s, 30, 300) == (88, 86, 214), "LaunchScreen.storyboard shown")
    app.wait_log(r"isim: launch screen hidden")
    notes = app.wait_view(r"id=badge-cell")
    app.wait_still()
    notes = app.view_dump()
    app.screenshot("notes")
    app.tap_id("note-1")
    app.wait_log(r"detail: viewDidLoad")
    detail = app.wait_view(r"id=info-label text=Embedded: Ideas")
    app.wait_still()
    app.screenshot("detail")
    app.tap_id("detail-more")
    more = app.wait_view(r"id=more-label")
    app.tap_id("nav-back")
    app.wait_view(r"id=more-label", gone=True)
    app.wait_still()
    app.wait_tap_id("detail-done")
    app.wait_log(r"notes: unwind doneUnwind")
    app.wait_view(r"id=detail-done", gone=True)
    app.wait_still()
    app.tap_id("bar-Add")
    app.wait_log(r"compose: viewDidLoad")
    app.wait_view(r"id=compose-title")
    app.wait_still()
    app.tap_id("compose-title")
    app.type("Hello IB")
    app.tap_id("bar-Save")
    app.wait_log(r"notes: saved ")
    saved = app.wait_view(r"text=Hello IB")
    app.wait_still()
    app.screenshot("saved")
    app.tap_id("bar-Add")
    app.wait_log(r"compose: viewDidLoad", count=2)
    app.wait_view(r"id=bar-Cancel")
    app.wait_still()
    app.tap_id("bar-Cancel")
    app.wait_log(r"notes: unwind cancelUnwind")
    app.wait_view(r"id=bar-Cancel", gone=True)
    app.wait_still()
    app.tap_id("bar-Reset")
    app.wait_log(r"notes: reset")
    assert app.quit() == 0, "apps exit cleanly"
    log = app.log + "\n" + "\n".join((notes, detail, more, saved))

    def has(p):
        return re.search(p, log, re.M)
    assert "launch screen: storyboard LaunchScreen" in log and rgb(launch_shot, 30, 300) == (88, 86, 214), \
        "LaunchScreen.storyboard shown while launching"
    assert "scene: window from storyboard: true, root=UITabBarController, storyboard=true" in log, \
        "UISceneStoryboardFile: window + root before willConnect"
    assert "notes: init(coder:) title=Notes" in log and "notes: awakeFromNib navigationItem=Notes" in log, \
        "init(coder:) + awakeFromNib (Swift class)"
    assert "notes: viewDidLoad tableView=UITableView dataSource=true storyboard=true nib objects=1 first=BadgeCell" in log, \
        "tableView key=view + dataSource outlet + nib loading"
    assert re.search(r"_TtC16HelloStoryboards8NoteCell \(0 [0-9]*; 402 x 64\) id=note-1", notes) and \
        "text=Storyboards on Linux" in notes, "prototype cell: custom class + outlets"
    assert "UIImageView (20 20; 24 x 24)" in notes and "UILabel (56 11; 304 x 21) text=Groceries" in notes, \
        "prototype cell constraints (margins, image 24x24)"
    assert re.search(r"BadgeCell \(0 [0-9]*; 402 x 56\) id=badge-cell", notes) and \
        "UILabel (20 12; 180 x 32) id=badge-label text=Pinned from a xib" in notes, "xib cell registered with UINib"
    assert "text=Subtitle style" in "\n".join(notes.splitlines()[
        next(i for i, line in enumerate(notes.splitlines()) if "id=basic-cell" in line):][:4]), \
        "subtitle-style prototype (built-in labels)"
    assert "id=tab-Notes" in notes and "id=tab-Controls" in notes, "tab bar items from the storyboard"
    assert has(r"notes: shouldPerformSegue showNote") and \
        has(r"notes: prepare showNote -> NoteDetailViewController sender=NoteCell"), \
        "selection segue: shouldPerform + prepare(sender: cell)"
    assert has(r"detail: viewDidLoad Ideas") and "id=detail-title text=Ideas" in detail, \
        "show segue pushes; detail outlets"
    assert has(r"detail: prepare embedInfo -> InfoViewController") and \
        has(r"info: viewDidLoad parent=NoteDetailViewController text=Embedded: Ideas") and \
        "id=info-label text=Embedded: Ideas" in detail, "embed segue (container view)"
    assert has(r"detail: prepare showMore -> MoreViewController") and has(r"more: viewDidLoad id-instantiable=true") and \
        "id=more-label text=More about Ideas" in more, "performSegue(withIdentifier:) + storyboard ID"
    assert has(r"notes: unwind doneUnwind from NoteDetailViewController"), "unwind segue from a button (Done)"
    assert has(r"notes: prepare compose -> UINavigationController sender=UIBarButtonItem") and \
        has(r"compose: viewDidLoad field=true placeholder=Title"), "bar button segue presents (modal)"
    assert has(r"compose: prepare saveUnwind -> NotesViewController") and has(r'notes: saved "Hello IB" -> 3 notes') and \
        "text=Hello IB" in saved, "unwind from a bar button (Save) with prepare"
    assert has(r"notes: unwind cancelUnwind from ComposeViewController") and has(r"notes: reset -> 1"), \
        "unwind (Cancel) + bar button action"


def test_controls(launch):
    app = launch("HelloStoryboards")
    app.wait_tap_id("tab-Controls")
    app.wait_log(r"controls: viewDidLoad")
    app.wait_view(r"id=rounded-view")
    first = app.wait_still()
    app.screenshot("controls")
    app.tap_id("controls-switch")
    app.wait_log(r"controls: switch false")
    app.tap(330, 245)
    app.wait_log(r"controls: stepper 3")
    app.tap(322, 297)
    app.wait_log(r"controls: segment 2")
    app.drag(201, 172, 330, 172, 0.4)
    app.wait_log(r"controls: slider")
    app.tap_id("controls-name")
    app.type("Ana")
    app.wait_log(r"controls: name Ana")
    app.send("key return")
    app.tap_id("apply-button")
    app.wait_log(r"controls: apply tapped")
    app.tap_id("rounded-view")
    app.wait_log(r"controls: rounded view tapped")
    controls = app.wait_still()
    app.tap_id("open-profile")
    profile = app.wait_view(r"id=profile-name text=Profile \(explicit nib\)")
    app.wait_still()
    app.screenshot("profile")
    app.tap_id("profile-close")
    app.wait_log(r"profile: close")
    app.wait_view(r"id=profile-close", gone=True)
    app.wait_still()
    app.tap_id("open-default-nib")
    default = app.wait_view(r"id=profile-name text=Profile \(default nib\)")
    app.wait_still()
    app.tap_id("profile-close")
    app.wait_log(r"profile: close", count=2)
    app.wait_view(r"id=profile-close", gone=True)
    app.wait_still()
    app.tap_id("open-fonts")
    app.wait_view(r"id=font-Georgia")
    app.wait_still()
    app.screenshot("fonts")
    app.tap_id("font-Georgia")
    app.wait_log(r"controls: font Georgia")                            # UIFontPickerViewController picks a family
    assert app.quit() == 0, "apps exit cleanly"
    log = app.log + "\n" + "\n".join((controls, profile, default))
    assert "controls: viewDidLoad slider=0.5 [0.0,1.0] switch=true stepper=2.0/10.0 segment=1/3 progress=0.25 " \
        "spinning=true labels=2" in log, "IB attributes reach the controls"
    assert "corner=12.0 tag=teal-pill codedInit=true field=Your name" in log, \
        "user defined runtime attributes; init(coder:) only"
    assert "(110.667 539; 181 x 40) id=rounded-view" in first + controls, \
        "IB constraints: 1:2 width, priority, placeholder dropped"
    assert all(s in log for s in ("controls: switch false", "controls: stepper 3", "controls: segment 2",
                                  "controls: slider")), "actions: switch / stepper / segment / slider"
    assert "controls: name Ana" in log and "controls: apply tapped (Apply)" in log, \
        "editingChanged action + button configuration"
    assert "controls: rounded view tapped" in log, "gesture recognizer from the storyboard"
    assert "profile: viewDidLoad nibName=ProfileViewController label=true button=Close" in log and \
        "id=profile-name text=Profile (explicit nib)" in profile, "init(nibName:bundle:) loads the xib"
    assert "id=profile-name text=Profile (default nib)" in default and app.count(r"profile: close") == 2, \
        "default nib named after the class"


@pytest.mark.skipif(not (ROOT / "out/sdk/Applications/Settings.app/Settings").exists(), reason="no Settings app")
def test_settings_bundle(launch, device_data):
    """Settings.bundle round trip under `isim boot`: the Settings app writes the app's domain, the app reads it."""
    dev = launch(None, install=["HelloStoryboards"])
    dev.send("launch dev.isim.settings")
    dev.wait_tap_id("settings-app-dev.isim.samples.HelloStoryboards")
    page = dev.wait_view(r"id=pref-enabled_preference")
    dev.wait_still()
    page = dev.view_dump()
    dev.screenshot("settings-page")
    dev.tap_id("pref-enabled_preference")
    dev.wait_log(r"enabled_preference = ")
    dev.tap_id("pref-name_preference")
    for _ in range(5):
        dev.send("key backspace")
    dev.type("Zoe")
    dev.send("key return")
    dev.wait_log(r"name_preference = Zoe")
    dev.tap_id("pref-theme_preference")
    dev.wait_tap_id("pref-theme_preference-dark")
    dev.wait_log(r"theme_preference = dark")
    dev.tap_id("isim-nav-back")
    dev.wait_view(r"id=pref-pane-Advanced")
    dev.drag(200, 450, 200, 250, 0.3)                                   # above the keyboard (the access section is first)
    dev.wait_still()
    dev.tap_id("pref-pane-Advanced")
    dev.wait_tap_id("pref-advanced_preference")
    dev.wait_log(r"Settings: dev.isim.samples.HelloStoryboards advanced_preference = true")
    dev.send("launch dev.isim.samples.HelloStoryboards")
    dev.wait_log(r"settings\(launch\): ")
    assert dev.quit() == 0, "shell exits cleanly"
    prefs = (device_data / "Containers/dev.isim.samples.HelloStoryboards/Library/Preferences/"
             "dev.isim.samples.HelloStoryboards.plist").read_text(errors="replace")
    assert all(s in page for s in ("text=Display Name", "text=Notifications", "text=Automatic", "text=1.0 (7)")), \
        "Settings: app page from Settings.bundle (localized)"
    assert "<string>dark</string>" in prefs and "<string>Zoe</string>" in prefs, "Settings: writes the app domain"
    assert "settings(launch): name=Zoe enabled=false theme=dark volume=0.0 advanced=true" in dev.log, \
        "app reads the Settings values"
