"""Shell suites that are not ported to Python yet, run through pytest (temporary).

Each entry: (test id, description, shell command run from isim/, apps that must be built, os_matrix, iOS 17 ok).
Port a suite to tests/<dir>/test_<name>.py, delete its shell script and remove its entry here."""
import os
import subprocess

import pytest
from isimtest import ROOT, exclusive, need_apps

SUITES = [
    ('objc-runtime', 'objc runtime (exceptions, forwarding, NSInvocation, NSProxy, uncaught exceptions)', "bash -c 'tests/objc-runtime/run.sh | tail -1; exit ${PIPESTATUS[0]}'", [], False, True),
    ('abi', 'ABI compatibility (released SDK symbols; an app built with isim 0.2.0)', 'tests/abi/run.sh', [], False, True),
    ('keyboard', 'ui: HelloKeyboard (keyboard extension)', 'tests/ui/keyboard.sh', ['HelloKeyboard'], False, True),
    ('keyboard-app', 'ui: HelloKeyboardApp (system keyboard + embedded extension)', 'tests/ui/keyboard-app.sh', ['HelloKeyboardApp'], False, True),
    ('swiftui', 'ui: HelloSwiftUI (SwiftUI)', 'tests/ui/swiftui.sh', ['HelloSwiftUI'], True, True),
    ('text', 'ui: HelloText (rich Text, Markdown, dates, timers)', 'tests/ui/text.sh', ['HelloSwiftUI', 'HelloText'], False, True),
    ('lists', 'ui: HelloLists (list editing, swipes, search, refresh, split view, detents)', 'tests/ui/lists.sh', ['HelloSwiftUI', 'HelloLists'], False, True),
    ('collection', 'ui: HelloCollection (UICollectionView flow/compositional/list)', 'tests/ui/collection.sh', ['HelloSwiftUI', 'HelloCollection'], False, True),
    ('multitouch', 'ui: HelloMultiTouch (pinch, rotation, two-finger pan, zooming, hover, pointer)', 'tests/ui/multitouch.sh', ['HelloSwiftUI', 'HelloMultiTouch'], False, True),
    ('textediting', 'ui: HelloTextEditing (selection, edit menu, marked text, keyboards, autocorrection)', 'tests/ui/textediting.sh', ['HelloSwiftUI', 'HelloTextEditing'], False, True),
    ('accessibility', 'ui: HelloAccessibility (VoiceOver, accessibility tree, Dynamic Type, settings)', 'tests/ui/accessibility.sh', ['HelloSwiftUI', 'HelloAccessibility'], False, True),
    ('dragdrop', 'ui: HelloDragDrop (drag and drop interactions, table reordering, SwiftUI)', 'tests/ui/dragdrop.sh', ['HelloSwiftUI', 'HelloDragDrop'], False, True),
    ('symbols', 'ui: HelloSymbols (SF Symbol stand-ins: variants, weight, scale, tint)', 'tests/ui/symbols.sh', ['HelloSwiftUI', 'HelloSymbols'], True, True),
    ('rotation', 'ui: HelloRotation (device rotation, orientations, size classes)', 'tests/ui/rotation.sh', ['HelloSwiftUI', 'HelloRotation'], False, True),
    ('keys', 'ui: HelloKeys (SwiftUI shortcuts, key presses, focus, inspector)', 'tests/ui/keys.sh', ['HelloSwiftUI', 'HelloKeys'], False, True),
    ('inputs', 'ui: HelloInputs (UITextView, pickers, search, refresh, color well, appearance)', 'tests/ui/inputs.sh', ['HelloSwiftUI', 'HelloInputs'], False, True),
    ('appearance', 'ui: HelloAppearance (traits, custom traits, trait overrides, dynamic colors/images, appearance proxies, live dark mode)', 'tests/ui/appearance.sh', ['HelloSwiftUI', 'HelloAppearance'], True, True),
    ('views', 'ui: HelloViews (context menus, button configurations, tint adjustment, content modes, input views)', 'tests/ui/views.sh', ['HelloSwiftUI', 'HelloViews'], False, True),
    ('symboleffects', 'ui: HelloSymbolEffects (iOS 17/18/26: SF Symbols effects on image views)', 'tests/ui/symboleffects.sh', ['HelloSwiftUI', 'HelloSymbolEffects'], False, True),
    ('transitions', 'ui: HelloTransitions (presentations, sheets, popovers, custom transitions, containers)', 'tests/ui/transitions.sh', ['HelloSwiftUI', 'HelloTransitions'], True, False),
    ('web', 'ui: HelloWeb (WKWebView on WebKitGTK: delegates, JS bridge, scheme handler, history; local server)', 'tests/ui/web.sh', ['HelloSwiftUI', 'HelloWeb'], False, True),
    ('connections', 'ui: HelloConnections (Network framework, Bonjour, Multipeer, URLSession auth/metrics/resume; local servers)', 'tests/ui/connections.sh', ['HelloSwiftUI', 'HelloConnections'], False, True),
    ('spritekit2', 'ui: HelloSpriteKit2 (warp/transform/video nodes, reversed actions, GameplayKit AI and spatial trees, host gamepads)', 'tests/ui/spritekit2.sh', ['HelloSwiftUI', 'HelloSpriteKit2'], False, True),
    ('location', 'ui: HelloLocation (Core Location, simulated location, geocoding)', 'tests/ui/location.sh', ['HelloSwiftUI', 'HelloLocation'], False, True),
    ('sensors', 'ui: HelloSensors (Core Motion, Bluetooth, NFC, HealthKit)', 'tests/ui/sensors.sh', ['HelloSwiftUI', 'HelloSensors'], False, True),
    ('drawing', 'ui: HelloDrawing (shapes, paths, gradients, Canvas, animations)', 'tests/ui/drawing.sh', ['HelloSwiftUI', 'HelloDrawing'], False, True),
    ('effects', 'ui: HelloEffects (colour filters, blend modes, blur, shadows, masks, contentShape, visualEffect, scrollTransition)', 'tests/ui/effects.sh', ['HelloSwiftUI', 'HelloEffects'], False, True),
    ('sheets', 'ui: HelloSheets (alert text fields, popovers, background interaction, interactiveDismissDisabled, presentationSizing, inspector column, zoom cover)', 'tests/ui/sheets.sh', ['HelloSwiftUI', 'HelloSheets'], False, True),
    ('splitview', 'ui: HelloSplit (NavigationSplitView: iPad columns, visibility, styles; iPhone stack)', 'tests/ui/splitview.sh', ['HelloSwiftUI', 'HelloSplit'], False, True),
    ('tabs', 'ui: HelloTabs (TabSection, iPad sidebar, iOS 26 accessory/minimize/glass/background extension, iOS 27 toolbar overflow)', 'tests/ui/tabs.sh', ['HelloSwiftUI', 'HelloTabs'], False, True),
    ('charts', 'ui: HelloCharts (Swift Charts marks, axes, legend)', 'tests/ui/charts.sh', ['HelloSwiftUI', 'HelloCharts'], False, True),
    ('video', 'ui: HelloVideo (AVPlayer, AVPlayerLayer, AVKit, VideoPlayer)', 'tests/ui/video.sh', ['HelloSwiftUI', 'HelloVideo'], False, True),
    ('vision', 'ui: HelloVision (Vision, Core ML, NaturalLanguage, Speech, VisionKit)', 'tests/ui/vision.sh', ['HelloSwiftUI', 'HelloVision'], False, True),
    ('store', 'ui: HelloStore (StoreKit testing: subscriptions, offers, refunds, StoreKit 1)', 'tests/ui/store.sh', ['HelloSwiftUI', 'HelloStore'], False, True),
    ('cloudkit', 'ui: HelloCloudKit (local CloudKit, NSPersistentCloudKitContainer, MetricKit)', 'tests/ui/cloudkit.sh', ['HelloSwiftUI', 'HelloCloudKit'], False, True),
    ('gamecenter', 'ui: HelloGameCenter (local Game Center: config, access point, saved games)', 'tests/ui/gamecenter.sh', ['HelloSwiftUI', 'HelloGameCenter'], False, True),
    ('boot', 'ui: isim boot (home screen, Settings, multitasking)', 'tests/ui/boot.sh', [], True, True),
    ('system', 'ui: HelloSystem (quick actions, alternate icons, URLs, state restoration, background tasks)', 'tests/ui/system.sh', ['HelloSystem'], False, True),
    ('background', 'ui: HelloBackground (suspension, background audio and location, location indicator, haptics)', 'tests/ui/background.sh', ['HelloBackground'], False, True),
    ('homepages', 'ui: home-screen pages (52 apps: paging, dots, edit across pages, Edit Pages, App Library Only)', 'tests/ui/homepages.sh', [], False, True),
    ('security-selftest', 'security (CommonCrypto, CryptoKit, SQLite3, Keychain, os.Logger)', "bash -c 'tests/security/run.sh | tail -1; exit ${PIPESTATUS[0]}'", ['SecurityTest'], False, True),
    ('toolchain', 'ui: HelloToolchain (isim build toolchain, isim test: XCTest, Swift Testing, XCUITest)', 'tests/ui/toolchain.sh', ['HelloToolchain'], False, True),
    ('coredata-selftest', 'Core Data (models, stores, contexts, fetching, FRC, migration)', "bash -c 'tests/coredata/run.sh | tail -1; exit ${PIPESTATUS[0]}'", ['CoreDataTest'], False, True),
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
