"""Shell suites that are not ported to Python yet, run through pytest (temporary).

Each entry: (test id, description, shell command run from isim/, apps that must be built, os_matrix, iOS 17 ok).
Port a suite to tests/<dir>/test_<name>.py, delete its shell script and remove its entry here."""
import os
import subprocess

import pytest
from isimtest import ROOT, exclusive, need_apps

SUITES = [
    ('loader', 'loader', 'tests/loader/run.sh', [], False, True),
    ('objc-literals', 'objc constant literals (NSConstantArray & co., equality, serialization, Swift bridging)', "bash -c 'tests/objc-literals/run.sh | tail -1; exit ${PIPESTATUS[0]}'", ['ObjCLiteralsTest'], True, True),
    ('hellocounter', 'ui: HelloCounter (Objective-C)', 'tests/ui/hellocounter.sh HelloCounter', [], True, True),
    ('observation', 'ui: HelloObservation (@Observable, @Bindable, @Environment)', 'tests/ui/observation.sh', ['HelloSwiftUI', 'HelloObservation'], False, True),
    ('forms', 'ui: HelloForms (SwiftUI controls, TabView, @AppStorage)', 'tests/ui/forms.sh', ['HelloSwiftUI', 'HelloForms'], True, False),
    ('pickers', 'ui: HelloPickers (DatePicker, ColorPicker, Gauge, more controls)', 'tests/ui/pickers.sh', ['HelloSwiftUI', 'HelloPickers'], False, True),
    ('layout', 'ui: HelloLayout (Grid, Layout protocol, alignment guides, preferences, scroll targets)', 'tests/ui/layout.sh', ['HelloSwiftUI', 'HelloLayout'], False, True),
    ('lists', 'ui: HelloLists (list editing, swipes, search, refresh, split view, detents)', 'tests/ui/lists.sh', ['HelloSwiftUI', 'HelloLists'], False, True),
    ('table', 'ui: HelloTable (UITableView, diffable data source)', 'tests/ui/table.sh', ['HelloSwiftUI', 'HelloTable'], True, False),
    ('gestures', 'ui: HelloGestures (recognizers, key commands, shake)', 'tests/ui/gestures.sh', ['HelloSwiftUI', 'HelloGestures'], False, True),
    ('swiftui-gestures', 'ui: HelloSwiftUIGestures (magnify, rotate, sequenced, exclusive, @GestureState)', 'tests/ui/swiftui-gestures.sh', ['HelloSwiftUI', 'HelloSwiftUIGestures'], False, True),
    ('images', 'ui: HelloImages (image renderer, PNG/JPEG, attributed text)', 'tests/ui/images.sh', ['HelloSwiftUI', 'HelloImages'], False, True),
    ('quartz', 'ui: HelloQuartz (bitmap/PDF contexts, gradients, shadows, Core Text)', 'tests/ui/quartz.sh', ['HelloSwiftUI', 'HelloQuartz'], False, True),
    ('imaging', 'ui: HelloImaging (ImageIO, Core Image, animated/resizable images)', 'tests/ui/imaging.sh', ['HelloSwiftUI', 'HelloImaging'], False, True),
    ('constraints', 'ui: HelloConstraints (VFL, keyboard layout guide, trait registration)', 'tests/ui/constraints.sh', ['HelloSwiftUI', 'HelloConstraints'], False, True),
    ('inputs', 'ui: HelloInputs (UITextView, pickers, search, refresh, color well, appearance)', 'tests/ui/inputs.sh', ['HelloSwiftUI', 'HelloInputs'], False, True),
    ('windows', 'ui: HelloWindows (iPad multiple scenes: split view, activation/destruction requests, session restoration, UIDevice)', 'tests/ui/windows.sh', ['HelloSwiftUI', 'HelloWindows'], False, True),
    ('uitabs', 'ui: HelloUITabs (iOS 17/18/26: UITab, iPad sidebar, UIUpdateLink, bar badges, scroll edge effects, observation tracking)', 'tests/ui/uitabs.sh', ['HelloSwiftUI', 'HelloUITabs'], False, True),
    ('views', 'ui: HelloViews (context menus, button configurations, tint adjustment, content modes, input views)', 'tests/ui/views.sh', ['HelloSwiftUI', 'HelloViews'], False, True),
    ('coreanimation', 'ui: HelloCoreAnimation (CA layers/animations, 3D, masks, Dynamics, CoreHaptics)', 'tests/ui/coreanimation.sh', ['HelloSwiftUI', 'HelloCoreAnimation'], False, True),
    ('animations', 'ui: HelloAnimations (property animator, keyframes, transitions)', 'tests/ui/animations.sh', ['HelloSwiftUI', 'HelloAnimations'], False, True),
    ('transitions', 'ui: HelloTransitions (presentations, sheets, popovers, custom transitions, containers)', 'tests/ui/transitions.sh', ['HelloSwiftUI', 'HelloTransitions'], True, False),
    ('controls', 'ui: HelloControls (UIKit controls, menus)', 'tests/ui/controls.sh', ['HelloSwiftUI', 'HelloControls'], True, True),
    ('presentations', 'ui: HelloPresentations (sheets, alerts, dialogs)', 'tests/ui/presentations.sh', ['HelloSwiftUI', 'HelloPresentations'], True, False),
    ('safari', 'ui: HelloSafari (SFSafariViewController, ASWebAuthenticationSession, MessageUI, universal links)', 'tests/ui/safari.sh', ['HelloSwiftUI', 'HelloSafari'], False, True),
    ('network', 'ui: HelloNetwork (URLSession, cookies, WebSocket, NWPathMonitor; local server)', 'tests/ui/network.sh', ['HelloSwiftUI', 'HelloNetwork'], False, True),
    ('spritekit', 'ui: HelloSpriteKit (SpriteKit physics/particles, GameplayKit, GameController)', 'tests/ui/spritekit.sh', ['HelloSwiftUI', 'HelloSpriteKit'], False, True),
    ('security', 'ui: HelloSecurity (CryptoKit, keychain, SQLite, Face ID, notifications)', 'tests/ui/security.sh', ['HelloSwiftUI', 'HelloSecurity'], False, True),
    ('maps', 'ui: HelloMaps (MapKit: MKMapView, offline basemap, overlays, search, SwiftUI Map)', 'tests/ui/maps.sh', ['HelloSwiftUI', 'HelloMaps'], False, True),
    ('personal', 'ui: HelloPersonal (Contacts, ContactsUI, EventKit, EventKitUI)', 'tests/ui/personal.sh', ['HelloSwiftUI', 'HelloPersonal'], False, True),
    ('photos', 'ui: HelloPhotos (PhotosUI, Photos, image picker, camera)', 'tests/ui/photos.sh', ['HelloSwiftUI', 'HelloPhotos'], False, True),
    ('formatting', 'ui: HelloFormatting (FormatStyle, region change, Regex)', 'tests/ui/formatting.sh', ['HelloSwiftUI', 'HelloFormatting'], False, True),
    ('effects', 'ui: HelloEffects (colour filters, blend modes, blur, shadows, masks, contentShape, visualEffect, scrollTransition)', 'tests/ui/effects.sh', ['HelloSwiftUI', 'HelloEffects'], False, True),
    ('navstack', 'ui: HelloNavStack (push/pop animations, edge swipe back, zoom transition, toolbar placements, title menu, bottom and keyboard bars)', 'tests/ui/navstack.sh', ['HelloSwiftUI', 'HelloNavStack'], True, True),
    ('audio', 'ui: HelloAudio (speech, effects, recording, MediaPlayer)', 'tests/ui/audio.sh', ['HelloSwiftUI', 'HelloAudio'], False, True),
    ('media', 'ui: HelloMedia (composition, export, reader/writer, player rate/pan/meters, session events, AudioToolbox)', 'tests/ui/media.sh', ['HelloSwiftUI', 'HelloMedia'], False, True),
    ('camera', 'ui: HelloCamera (simulated camera: capture session, preview, photo, video frames, QR metadata)', 'tests/ui/camera.sh', ['HelloSwiftUI', 'HelloCamera'], False, True),
    ('signin', 'ui: HelloSignIn (Sign in with Apple, passkeys, passwords, ATT + IDFA; local simulation)', 'tests/ui/signin.sh', ['HelloSwiftUI', 'HelloSignIn'], False, True),
    ('shareddata', 'ui: HelloSharedData (plurals, LocalizedStringResource, app groups, iCloud key-value store, NotificationQueue)', 'tests/ui/shareddata.sh', ['HelloSwiftUI', 'HelloSharedData'], False, True),
    ('datetime', 'ui: Settings Date & Time (24-hour, time zone)', 'tests/ui/datetime.sh', [], False, True),
    ('system', 'ui: HelloSystem (quick actions, alternate icons, URLs, state restoration, background tasks)', 'tests/ui/system.sh', ['HelloSystem'], False, True),
    ('widgets', 'ui: HelloWidgets (WidgetKit timelines + interactive widget, ActivityKit Live Activity, App Intents)', 'tests/ui/widgets.sh', ['HelloWidgets'], False, True),
    ('scenes', 'ui: HelloScenes (SwiftUI scenes, delegate adaptor, user activities, background task, windows)', 'tests/ui/scenes.sh', ['HelloScenes'], False, True),
    ('push', 'ui: HelloPush (remote notifications, service/content extensions, actions, badges, suspension)', 'tests/ui/push.sh', ['HelloPush'], False, True),
    ('share', 'ui: HelloShare (Share and Action extensions, SLComposeServiceViewController)', 'tests/ui/share.sh', ['HelloShare', 'HelloPush'], False, True),
    ('background', 'ui: HelloBackground (suspension, background audio and location, location indicator, haptics)', 'tests/ui/background.sh', ['HelloBackground'], False, True),
    ('homepages', 'ui: home-screen pages (52 apps: paging, dots, edit across pages, Edit Pages, App Library Only)', 'tests/ui/homepages.sh', [], False, True),
    ('homescreen', 'ui: home screen (folders, rearranging, App Library, Spotlight, CoreSpotlight)', 'tests/ui/homescreen.sh', ['HelloSystem'], False, True),
    ('systemui', 'ui: system UI (lock screen, Notification Center, Control Center, app switcher)', 'tests/ui/systemui.sh', ['HelloSecurity', 'HelloSystem'], False, True),
    ('coredata', 'ui: HelloCoreData (Core Data + SwiftUI @FetchRequest, xcodeproj)', 'tests/ui/coredata.sh', ['HelloCoreData'], False, True),
    ('toolchain', 'ui: HelloToolchain (isim build toolchain, isim test: XCTest, Swift Testing, XCUITest)', 'tests/ui/toolchain.sh', ['HelloToolchain'], False, True),
    ('storyboards', 'ui: HelloStoryboards (storyboards, xibs, segues, launch screen, Settings.bundle)', 'tests/ui/storyboards.sh', ['HelloStoryboards'], False, True),
    ('osversions', 'ui: HelloOSVersions (iOS 17, 18, 26, 27: #available, Liquid Glass, Lock Screen, Control Center, device pairing)', 'tests/ui/osversions.sh', ['HelloOSVersions'], False, True),
]


MATRIX = {"17": "iphone15", "18": "iphone16pro", "26": "iphone17", "27": "iphone17"}


def pytest_generate_tests(metafunc):
    """Each suite once; with --os-matrix the matrix suites again under every iOS version."""
    params = []
    for s in SUITES:
        params.append(pytest.param(s, None, id=s[0]))
        if metafunc.config.getoption("--os-matrix") and s[4]:
            params += [pytest.param(s, v, id=f"{s[0]}-ios{v}") for v in MATRIX if v != "17" or s[5]]
    metafunc.parametrize("suite,version", params)


def test_shell_suite(suite, version, device_data):
    ident, desc, cmd, apps, matrix, ios17 = suite
    need_apps(*apps)
    env = dict(os.environ, ISIM_STANDALONE="1", ISIM_DATA=str(device_data))
    if version:
        env.update(ISIM_OS_VERSION=version, ISIM_DEVICE=MATRIX[version], ISIM_TEST_DEVICE=MATRIX[version])
    script = cmd.split()[0] if cmd.startswith("tests/") else ident
    with exclusive(os.path.basename(script)):
        p = subprocess.run(["bash", "-c", cmd], cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, errors="replace", timeout=900)
    assert p.returncode == 0, f"{desc}\n{p.stdout[-6000:]}"
