#!/usr/bin/env bash
# Run every isim test suite. Build first with ./build.sh.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
status=0
export ISIM_STANDALONE=1     # `isim run` runs each test app alone (no home screen, nothing installed on the device)
run() { echo "=== $1"; shift; "$@" || status=1; }
run "loader" tests/loader/run.sh
run "foundation self-test" bash -c 'out/bin/isim run out/apps/FoundationTest.app | tail -3; exit ${PIPESTATUS[0]}'
run "objc runtime (exceptions, forwarding, NSInvocation, NSProxy, uncaught exceptions)" bash -c 'tests/objc-runtime/run.sh | tail -1; exit ${PIPESTATUS[0]}'
run "ABI compatibility (released SDK symbols; an app built with isim 0.2.0)" tests/abi/run.sh
run "ui: HelloCounter (Objective-C)" tests/ui/hellocounter.sh HelloCounter
if [ -x out/apps/HelloCounterSwift.app/HelloCounterSwift ]; then   # Swift, systemOrange light/dark
  run "ui: HelloCounterSwift (Swift)" tests/ui/hellocounter.sh HelloCounterSwift "255 149 0" "255 159 10"
fi
if [ -x out/apps/HelloKeyboard.appex/HelloKeyboard ]; then         # Swift keyboard extension in the keyboard host
  run "ui: HelloKeyboard (keyboard extension)" tests/ui/keyboard.sh
fi
if [ -x out/apps/HelloKeyboardApp.app/HelloKeyboardApp ]; then   # UIScrollView, UITextField, system keyboard, in-process extension
  run "ui: HelloKeyboardApp (system keyboard + embedded extension)" tests/ui/keyboard-app.sh
fi
if [ -x out/apps/HelloSwiftUI.app/HelloSwiftUI ]; then           # isim SwiftUI
  run "ui: HelloSwiftUI (SwiftUI)" tests/ui/swiftui.sh
  [ -x out/apps/HelloSourceCompat.app/HelloSourceCompat ] && run "ui: HelloSourceCompat (Text(Image), Scene.onChange, optional gestures, Sendable Color/Bundle)" tests/ui/sourcecompat.sh
  [ -x out/apps/HelloObservation.app/HelloObservation ] && run "ui: HelloObservation (@Observable, @Bindable, @Environment)" tests/ui/observation.sh
  [ -x out/apps/HelloForms.app/HelloForms ] && run "ui: HelloForms (SwiftUI controls, TabView, @AppStorage)" tests/ui/forms.sh
  [ -x out/apps/HelloText.app/HelloText ] && run "ui: HelloText (rich Text, Markdown, dates, timers)" tests/ui/text.sh
  [ -x out/apps/HelloPickers.app/HelloPickers ] && run "ui: HelloPickers (DatePicker, ColorPicker, Gauge, more controls)" tests/ui/pickers.sh
  [ -x out/apps/HelloLayout.app/HelloLayout ] && run "ui: HelloLayout (Grid, Layout protocol, alignment guides, preferences, scroll targets)" tests/ui/layout.sh
  [ -x out/apps/HelloLists.app/HelloLists ] && run "ui: HelloLists (list editing, swipes, search, refresh, split view, detents)" tests/ui/lists.sh
  [ -x out/apps/HelloNavigation.app/HelloNavigation ] && run "ui: HelloNavigation (UINavigationController, UITabBarController)" tests/ui/navigation.sh
  [ -x out/apps/HelloTable.app/HelloTable ] && run "ui: HelloTable (UITableView, diffable data source)" tests/ui/table.sh
  [ -x out/apps/HelloCollection.app/HelloCollection ] && run "ui: HelloCollection (UICollectionView flow/compositional/list)" tests/ui/collection.sh
  [ -x out/apps/HelloGestures.app/HelloGestures ] && run "ui: HelloGestures (recognizers, key commands, shake)" tests/ui/gestures.sh
  [ -x out/apps/HelloMultiTouch.app/HelloMultiTouch ] && run "ui: HelloMultiTouch (pinch, rotation, two-finger pan, zooming, hover, pointer)" tests/ui/multitouch.sh
  [ -x out/apps/HelloTextEditing.app/HelloTextEditing ] && run "ui: HelloTextEditing (selection, edit menu, marked text, keyboards, autocorrection)" tests/ui/textediting.sh
  [ -x out/apps/HelloAccessibility.app/HelloAccessibility ] && run "ui: HelloAccessibility (VoiceOver, accessibility tree, Dynamic Type, settings)" tests/ui/accessibility.sh
  [ -x out/apps/HelloDragDrop.app/HelloDragDrop ] && run "ui: HelloDragDrop (drag and drop interactions, table reordering, SwiftUI)" tests/ui/dragdrop.sh
  [ -x out/apps/HelloSwiftUIGestures.app/HelloSwiftUIGestures ] && run "ui: HelloSwiftUIGestures (magnify, rotate, sequenced, exclusive, @GestureState)" tests/ui/swiftui-gestures.sh
  [ -x out/apps/HelloImages.app/HelloImages ] && run "ui: HelloImages (image renderer, PNG/JPEG, attributed text)" tests/ui/images.sh
  [ -x out/apps/HelloQuartz.app/HelloQuartz ] && run "ui: HelloQuartz (bitmap/PDF contexts, gradients, shadows, Core Text)" tests/ui/quartz.sh
  [ -x out/apps/HelloImaging.app/HelloImaging ] && run "ui: HelloImaging (ImageIO, Core Image, animated/resizable images)" tests/ui/imaging.sh
  [ -x out/apps/HelloRotation.app/HelloRotation ] && run "ui: HelloRotation (device rotation, orientations, size classes)" tests/ui/rotation.sh
  [ -x out/apps/HelloConstraints.app/HelloConstraints ] && run "ui: HelloConstraints (VFL, keyboard layout guide, trait registration)" tests/ui/constraints.sh
  [ -x out/apps/HelloKeys.app/HelloKeys ] && run "ui: HelloKeys (SwiftUI shortcuts, key presses, focus, inspector)" tests/ui/keys.sh
  [ -x out/apps/HelloInputs.app/HelloInputs ] && run "ui: HelloInputs (UITextView, pickers, search, refresh, color well, appearance)" tests/ui/inputs.sh
  [ -x out/apps/HelloCoreAnimation.app/HelloCoreAnimation ] && run "ui: HelloCoreAnimation (CA layers/animations, 3D, masks, Dynamics, CoreHaptics)" tests/ui/coreanimation.sh
  [ -x out/apps/HelloAnimations.app/HelloAnimations ] && run "ui: HelloAnimations (property animator, keyframes, transitions)" tests/ui/animations.sh
  [ -x out/apps/HelloTransitions.app/HelloTransitions ] && run "ui: HelloTransitions (presentations, sheets, popovers, custom transitions, containers)" tests/ui/transitions.sh
  [ -x out/apps/HelloControls.app/HelloControls ] && run "ui: HelloControls (UIKit controls, menus)" tests/ui/controls.sh
  [ -x out/apps/HelloPresentations.app/HelloPresentations ] && run "ui: HelloPresentations (sheets, alerts, dialogs)" tests/ui/presentations.sh
  [ -x out/apps/HelloWeb.app/HelloWeb ] && run "ui: HelloWeb (WKWebView on WebKitGTK: delegates, JS bridge, scheme handler, history; local server)" tests/ui/web.sh
  [ -x out/apps/HelloSafari.app/HelloSafari ] && run "ui: HelloSafari (SFSafariViewController, ASWebAuthenticationSession, MessageUI, universal links)" tests/ui/safari.sh
  [ -x out/apps/HelloConnections.app/HelloConnections ] && run "ui: HelloConnections (Network framework, Bonjour, Multipeer, URLSession auth/metrics/resume; local servers)" tests/ui/connections.sh
  [ -x out/apps/HelloNetwork.app/HelloNetwork ] && run "ui: HelloNetwork (URLSession, cookies, WebSocket, NWPathMonitor; local server)" tests/ui/network.sh
  [ -x out/apps/HelloSpriteKit.app/HelloSpriteKit ] && run "ui: HelloSpriteKit (SpriteKit physics/particles, GameplayKit, GameController)" tests/ui/spritekit.sh
  [ -x out/apps/HelloSpriteKit2.app/HelloSpriteKit2 ] && run "ui: HelloSpriteKit2 (warp/transform/video nodes, reversed actions, GameplayKit AI and spatial trees, host gamepads)" tests/ui/spritekit2.sh
  [ -x out/apps/HelloSecurity.app/HelloSecurity ] && run "ui: HelloSecurity (CryptoKit, keychain, SQLite, Face ID, notifications)" tests/ui/security.sh
  [ -x out/apps/HelloMaps.app/HelloMaps ] && run "ui: HelloMaps (MapKit: MKMapView, offline basemap, overlays, search, SwiftUI Map)" tests/ui/maps.sh
  [ -x out/apps/HelloLocation.app/HelloLocation ] && run "ui: HelloLocation (Core Location, simulated location, geocoding)" tests/ui/location.sh
  [ -x out/apps/HelloSensors.app/HelloSensors ] && run "ui: HelloSensors (Core Motion, Bluetooth, NFC, HealthKit)" tests/ui/sensors.sh
  [ -x out/apps/HelloPersonal.app/HelloPersonal ] && run "ui: HelloPersonal (Contacts, ContactsUI, EventKit, EventKitUI)" tests/ui/personal.sh
  [ -x out/apps/HelloPhotos.app/HelloPhotos ] && run "ui: HelloPhotos (PhotosUI, Photos, image picker, camera)" tests/ui/photos.sh
  [ -x out/apps/HelloFormatting.app/HelloFormatting ] && run "ui: HelloFormatting (FormatStyle, region change, Regex)" tests/ui/formatting.sh
  [ -x out/apps/HelloDrawing.app/HelloDrawing ] && run "ui: HelloDrawing (shapes, paths, gradients, Canvas, animations)" tests/ui/drawing.sh
  [ -x out/apps/HelloCharts.app/HelloCharts ] && run "ui: HelloCharts (Swift Charts marks, axes, legend)" tests/ui/charts.sh
  [ -x out/apps/HelloVideo.app/HelloVideo ] && run "ui: HelloVideo (AVPlayer, AVPlayerLayer, AVKit, VideoPlayer)" tests/ui/video.sh
  [ -x out/apps/HelloAudio.app/HelloAudio ] && run "ui: HelloAudio (speech, effects, recording, MediaPlayer)" tests/ui/audio.sh
  [ -x out/apps/HelloStore.app/HelloStore ] && run "ui: HelloStore (StoreKit testing: subscriptions, offers, refunds, StoreKit 1)" tests/ui/store.sh
  [ -x out/apps/HelloSignIn.app/HelloSignIn ] && run "ui: HelloSignIn (Sign in with Apple, passkeys, passwords, ATT + IDFA; local simulation)" tests/ui/signin.sh
  [ -x out/apps/HelloCloudKit.app/HelloCloudKit ] && run "ui: HelloCloudKit (local CloudKit, NSPersistentCloudKitContainer, MetricKit)" tests/ui/cloudkit.sh
  [ -x out/apps/HelloSharedData.app/HelloSharedData ] && run "ui: HelloSharedData (plurals, LocalizedStringResource, app groups, iCloud key-value store, NotificationQueue)" tests/ui/shareddata.sh
  [ -x out/apps/HelloGameCenter.app/HelloGameCenter ] && run "ui: HelloGameCenter (local Game Center: config, access point, saved games)" tests/ui/gamecenter.sh
fi
if [ -x out/sdk/Applications/Settings.app/Settings ]; then          # device shell: home screen + Settings
  run "ui: isim boot (home screen, Settings, multitasking)" tests/ui/boot.sh
  run "ui: Settings Date & Time (24-hour, time zone)" tests/ui/datetime.sh
  [ -x out/apps/HelloSystem.app/HelloSystem ] && run "ui: HelloSystem (quick actions, alternate icons, URLs, state restoration, background tasks)" tests/ui/system.sh
  [ -x out/apps/HelloWidgets.app/HelloWidgets ] && run "ui: HelloWidgets (WidgetKit timelines + interactive widget, ActivityKit Live Activity, App Intents)" tests/ui/widgets.sh
  [ -x out/apps/HelloScenes.app/HelloScenes ] && run "ui: HelloScenes (SwiftUI scenes, delegate adaptor, user activities, background task, windows)" tests/ui/scenes.sh
  run "ui: home-screen pages (52 apps: paging, dots, edit across pages, Edit Pages, App Library Only)" tests/ui/homepages.sh
  [ -x out/apps/HelloSystem.app/HelloSystem ] && run "ui: home screen (folders, rearranging, App Library, Spotlight, CoreSpotlight)" tests/ui/homescreen.sh
  [ -x out/apps/HelloSecurity.app/HelloSecurity ] && [ -x out/apps/HelloSystem.app/HelloSystem ] && run "ui: system UI (lock screen, Notification Center, Control Center, app switcher)" tests/ui/systemui.sh
fi
if [ -x out/apps/SwiftEmbeddedTest.app/SwiftEmbeddedTest ]; then
  run "swift (embedded) self-test" bash -c 'out/bin/isim run out/apps/SwiftEmbeddedTest.app/SwiftEmbeddedTest | tail -1; exit ${PIPESTATUS[0]}'
fi
if [ -x out/apps/SwiftFoundationTest.app/SwiftFoundationTest ]; then
  run "swift <-> Foundation interop" bash -c 'out/bin/isim run out/apps/SwiftFoundationTest.app/SwiftFoundationTest 2>/dev/null | tail -1; exit ${PIPESTATUS[0]}'
fi
if [ -x out/apps/SwiftFullTest.app/SwiftFullTest ]; then
  run "swift (full runtime) self-test" bash -c 'out/bin/isim run out/apps/SwiftFullTest.app/SwiftFullTest | tail -1; exit ${PIPESTATUS[0]}'
fi
if [ -x out/apps/SwiftConcurrencyTest.app/SwiftConcurrencyTest ]; then
  run "swift concurrency (async/await, actors, MainActor)" bash -c 'timeout 60 out/bin/isim run out/apps/SwiftConcurrencyTest.app/SwiftConcurrencyTest | tail -1; exit ${PIPESTATUS[0]}'
fi
if [ -x out/apps/SwiftLibrariesTest.app/SwiftLibrariesTest ]; then
  run "swift libraries (Dispatch, Combine, JSON/Codable, Calendar, ...)" bash -c 'timeout 60 out/bin/isim run out/apps/SwiftLibrariesTest.app/SwiftLibrariesTest | tail -1; exit ${PIPESTATUS[0]}'
fi
if [ -x out/apps/SwiftExtrasTest.app/SwiftExtrasTest ]; then      # Combine operators, Dispatch sources/IO/Data, Synchronization, Distributed
  run "swift extras (Combine operators, Dispatch sources/IO, Synchronization, Distributed)" bash -c 'timeout 90 out/bin/isim run out/apps/SwiftExtrasTest.app | tail -1; exit ${PIPESTATUS[0]}'
fi
if [ -x out/apps/SwiftCxxTest.app/SwiftCxxTest ]; then            # Swift <-> C++ interoperability
  run "swift C++ interop" bash -c 'timeout 30 out/bin/isim run out/apps/SwiftCxxTest.app | tail -1; exit ${PIPESTATUS[0]}'
fi
if [ -x out/apps/SwiftNetworkTest.app/SwiftNetworkTest ]; then   # sockets + URLSession against an in-process server (no Internet)
  run "swift networking (sockets, URLSession, cookies, cache, NWPathMonitor)" bash -c 'export ISIM_DATA=$PWD/out/test-data/swift-network; rm -rf "$ISIM_DATA"; timeout 90 out/bin/isim run out/apps/SwiftNetworkTest.app/SwiftNetworkTest | tail -1; exit ${PIPESTATUS[0]}'
fi
if [ -x out/apps/SecurityTest.app/SecurityTest ]; then          # known-answer vectors, keychain on isolated device data, log lines
  run "security (CommonCrypto, CryptoKit, SQLite3, Keychain, os.Logger)" bash -c 'tests/security/run.sh | tail -1; exit ${PIPESTATUS[0]}'
fi
if [ -x out/apps/HelloCoreData.app/HelloCoreData ]; then         # Xcode project + .xcdatamodeld, @FetchRequest, relaunch persistence
  run "ui: HelloCoreData (Core Data + SwiftUI @FetchRequest, xcodeproj)" tests/ui/coredata.sh
fi
if [ -x out/apps/HelloToolchain.app/HelloToolchain ]; then         # isim build (workspace, libs, packages, xcframework) + isim test (XCTest, Swift Testing, XCUITest)
  run "ui: HelloToolchain (isim build toolchain, isim test: XCTest, Swift Testing, XCUITest)" tests/ui/toolchain.sh
fi
if [ -x out/apps/HelloStoryboards.app/HelloStoryboards ]; then     # Xcode project with storyboards, xibs, launch screen, Settings.bundle
  run "ui: HelloStoryboards (storyboards, xibs, segues, launch screen, Settings.bundle)" tests/ui/storyboards.sh
fi
if [ -x out/apps/CoreDataTest.app/CoreDataTest ]; then       # models, SQLite/in-memory stores, contexts, fetches, FRC, migration
  run "Core Data (models, stores, contexts, fetching, FRC, migration)" bash -c 'tests/coredata/run.sh | tail -1; exit ${PIPESTATUS[0]}'
fi
echo; [ $status = 0 ] && echo "ALL SUITES PASSED" || echo "SOME SUITES FAILED"
exit $status
