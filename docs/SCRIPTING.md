# Scripting and automation

`isim boot` and `isim run` accept `--headless --script "…"`: a list of commands separated by `;` (or newlines; `\;` is
a literal `;`, e.g. `type a\;b`) that drive the device like a person (or like Xcode's Simulator menus) and then quit.
Tests and CI use this.

The same commands can be sent to a running device from another terminal (or by an AI agent) with `isim send`:

```bash
isim send "tapid loginButton; shot s.png"        # to the device running on this device data (ISIM_DATA)
```

Every device reads commands from a control FIFO, one command line at a time: the one given with `--control FIFO`
(e.g. `echo "shot s.png" > FIFO`), or else a FIFO of its own in `$XDG_RUNTIME_DIR/isim/` that the device removes when
it quits. The device data records which FIFO the running device reads, so `isim send`, `isim openurl` and
`isim open` find it without options. The FIFO goes one way: commands get no reply, so read results from files
(`dump views FILE`, `shot FILE`) and from the device's output.

```bash
isim boot --headless --script "wait 2; launch dev.isim.settings; wait 1; shot s.png; quit"
isim run MyApp.app --device iphone17 --headless --script "wait 3; tapid loginButton; wait 1; dump; quit"
```

Coordinates are in points of the device screen, with the origin at the top left.

## Timing and control

| Command | What it does |
|---|---|
| `wait S` | wait S seconds (fractions allowed; `ISIM_WAIT_SCALE=2` doubles every wait, for slow machines) |
| `quit` | stop the device |
| `focus` | bring the device window to the front (what `isim open` sends to a running device; the desktop may only highlight it, Wayland compositors decide). With an argument it is the Focus mode (System UI below) |
| `home` | go to the home screen. With `isim run` (the app alone, also XCUITest's app) there is no home screen: the app goes to the background |
| `activate` | `isim run` only: bring the app back from the background (like tapping its icon after `home`) |
| `launch BUNDLE_ID` | open an installed app |
| `openurl URL` | open a URL: under `isim boot` the home screen opens it in the app that handles it (its `CFBundleURLTypes` scheme, or an https universal link of its `applinks:` domains); with `isim run` the running app gets it (custom schemes, its own universal links, other web URLs "open in Safari"). Under `isim boot`, web URLs no app claims open in isim's Safari. `isim openurl URL` does the same from another terminal |
| `handoff TYPE [URL] [TITLE]` | `isim boot` only: an `NSUserActivity` handed off from another device (isim is one device; the script plays the other). The app that lists `TYPE` in `NSUserActivityTypes` continues it (launched with it in `connectionOptions.userActivities` / launch options, or `scene(_:continue:)` / `application(_:continue:restorationHandler:)` when running); `NSUserActivityTypeBrowsingWeb` with a URL goes to the app that claims it as a universal link, else to Safari |
| `appclip URL [code\|nfc]` | `isim boot` only: an App Clip invocation, like scanning an App Clip Code or QR code (`code`, the default) or an NFC tag for URL. A local experience whose URL prefix matches (Settings › Developer › Local Experiences, or `appclip register`) or an installed App Clip's `appclips:` domain shows the App Clip card; `tapid appclip-open` launches the App Clip with an `NSUserActivity` of type `NSUserActivityTypeBrowsingWeb` for URL. With a default experience (`appclips:` domain) and the full app installed, the full app opens instead. `openurl URL` of such a URL (no app claims it as a universal link) is a link invocation: the same card, but location confirmation is not allowed. App Clips are installed with `isim install Clip.app` (iOS: cached from the App Store) and are not on the home screen |
| `appclip register PREFIX BUNDLE_ID ACTION\|TITLE\|SUBTITLE[\|IMAGE]` · `appclip unregister PREFIX\|all` · `appclip list` | local App Clip experiences, as in Settings › Developer › Local Experiences: the URL prefix, the App Clip's bundle ID, the card's call-to-action verb (`Open`, `View`, `Play`), title, subtitle and header image (an absolute path; without one the card shows the App Clip's icon) |
| `appclip expire BUNDLE_ID` | iOS removing an App Clip that was not used for a while: its container, the app group containers no installed app still uses and its App Library entry are deleted (the bundle stays, as the App Store's copy) |
| `bgtask BUNDLE_ID TASK_ID` | launch a submitted BackgroundTasks request (like Xcode's `_simulateLaunchForTaskWithIdentifier`); a closed app is started in the background (a suspended one is resumed). `TASK_ID` `--fetch` runs a background fetch (with `UIBackgroundModes` `fetch` and a minimum fetch interval other than never, like iOS) |
| `terminate BUNDLE_ID` | the system ends the app without notice (as iOS does to reclaim memory), unlike closing it in the app switcher; an app with unfinished background `URLSession` transfers is relaunched in the background to finish them |
| `push BUNDLE_ID FILE` | deliver a remote notification payload (JSON with an `aps` dictionary), like `xcrun simctl push`: the Notification Service extension runs for `mutable-content`, then the running app gets it, or the system shows it (app not running), or `content-available` launches the app in the background. With `isim run` (the app alone) the payload goes straight to the app. Outside scripts: `isim push [BUNDLE_ID] payload.apns\|-`, or drop a `.apns` file (with a `"Simulator Target Bundle"` key) on the device window. A top-level `"apns-collapse-id"` key becomes the notification's identifier; a top-level `"apns-push-type": "voip"` makes it a PushKit VoIP push (no `aps` needed; apps with `UIBackgroundModes` `voip`, launched in the background when not running); `"apns-push-type": "widgets"` (iOS 26, with `"aps": {"content-changed": true}`) is a widget push: the app's widgets that have a `WidgetPushHandler` reload |
| `appearance light\|dark` | switch the device appearance (like Settings > Display & Brightness); running apps get a trait change (`traitCollectionDidChange`, `registerForTraitChanges`) |
| `contrast on\|off` | Increase Contrast (`accessibilityContrast`): high-contrast system and asset colors |
| `boldtext on\|off` | Bold Text (`legibilityWeight`) |
| `glasstint VALUE` | the Liquid Glass setting (iOS 26: Display & Brightness › Liquid Glass, Clear `0.5` / Tinted `1`; iOS 27: Appearance › Liquid Glass, a slider from `0` clear through `0.5`, the default, to `1` tinted); every process's glass follows |
| `takescreenshot` | the user takes a screenshot (the Simulator's Device ▸ Trigger Screenshot): the app gets `UIApplication.userDidTakeScreenshotNotification` |
| `memorywarning [warn\|critical\|normal]` | simulate a memory warning (like the Simulator's Debug menu): memory-pressure dispatch sources get the level (default `warn`); `warn` and `critical` then reach the app delegate, `didReceiveMemoryWarningNotification` and every loaded view controller |

## System UI (`isim boot`)

| Command | What it does |
|---|---|
| `lock` / `unlock` | lock the device (the foreground app goes to the background; the lock screen shows the clock, notifications and Live Activities) / unlock (apps lose protected data while locked: `isProtectedDataAvailable`, the delegate calls and notifications) |
| `switcher` | the app switcher (cards of running apps; `swipeid switcher-NAME 0 -300 0.3` closes an app, `tapid switcher-NAME` switches) |
| `notifications` | Notification Center (`tapid nc-item-ID` opens a notification, `holdid nc-item-ID 0.8` expands it, `tapid nc-clear` clears). An app's notifications of one thread are a stack, `nc-group-ID` (ID: the newest; text: its title and the summary, e.g. `Ann (2 more messages from Ann)`): `tapid` expands it into `nc-item-…` items under `nc-less-ID` (Show Less) |
| `controlcenter` | Control Center (`tapid cc-wifi`, `cc-airplane`, `cc-dark`, `cc-orientation`, `cc-focus`, …; Now Playing: `cc-nowplaying` (its text is the title — artist), `cc-np-previous`, `cc-np-play`, `cc-np-next`; `tapid cc-background` closes). `cc-focus` toggles the last Focus, `cc-focus-modes` opens the Focus list (`cc-focus-dnd`, `cc-focus-personal`, `cc-focus-work`, `cc-focus-sleep`; `cc-page-background` goes back). iOS 18+: `cc-edit` is edit mode (`cc-remove-NAME`, `cc-resize-KIND` for app controls, `cc-add-control` opens the gallery: `cc-gallery-KIND` adds an app's ControlWidget, `cc-gallery-system-NAME` a system control, `cc-gallery-close`; `cc-edit-background` ends edit mode); added controls are `cc-control-KIND` (text: title and value) and run their intent when tapped. The lock screen's player has `lock-nowplaying`, `lock-np-previous`, `lock-np-play`, `lock-np-next` |
| `focus dnd\|personal\|work\|sleep\|off` | turn a Focus on (or off), like Control Center's Focus list (logs `isim shell: Focus Work on`): banners of apps the Focus does not allow (Settings › Focus › the Focus › Apps) are silenced, time-sensitive ones break through, apps' Focus filters run (`SetFocusFilterIntent.perform()`) |
| `lockcontrol left\|right CONTROL` | the Lock Screen's bottom buttons (iOS 18 lets you replace the flashlight and camera): `flashlight`, `camera`, `timer`, `dark`, `lowpower`, `focus`, `none`, or an app control's kind; on the lock screen `tapid lock-control-left` / `lock-control-right` runs it. Only Face ID iPhones have them: the iPhone SE and iPads draw none (`dump` lists `lock-hint`, "Swipe up to open" or, on the iPhone SE, "Press home to open") |
| `silent on\|off` | Silent Mode (the Ring/Silent switch): notification sounds and ringtones are not played (critical alerts still are) |
| `actionbutton [assign CONTROL]` | press the Action button (iPhone 15 Pro and later, iPhone 16 and 17 presets; default: Silent Mode), or assign it a control (`silent`, `focus`, `flashlight`, …, or an app control's kind). Devices without one log that they have none |
| `spotlight` | Spotlight on the home screen (it also lists the apps' App Shortcuts: `spotlight-shortcut-BUNDLE-N`) |
| `siri` · `siri PHRASE` · `siri intent CLASS KEY=VALUE …` · `siri dismiss` | the simulated Siri (see below): `siri` alone starts listening (like holding the side button); `siri PHRASE` is what you say, or the answer to Siri's question; `siri intent` builds a SiriKit intent directly |
| `visualintelligence LABEL[,LABEL…]` | Visual Intelligence (iOS 26) saw something with these labels: the apps with an `IntentValueQuery` over `SemanticContentDescriptor` run it in the background; their results are logged (`SpringBoard: Visual Intelligence: APP: TITLE (SUBTITLE), …`, or `no results`) and shown in a sheet: a tab per app (`tapid vi-tab-N`), its results (`tapid vi-result-N` opens one with the app's `OpenIntent`), `vi-close` |
| `island` / `island detached` | expand / collapse the Dynamic Island's Live Activity (with two activities: the attached one, or the detached one) |
| `lockscreen customize` / `lockscreen done` | the Lock Screen editor (what a long press on the Lock Screen opens; locks first): `tapid lock-edit-widgets` opens the Add Widgets sheet for the row under the clock, `tapid lock-edit-inline` the one for the inline widget next to the date; `tapid lock-add-KIND-FAMILY` adds a widget (`accessoryCircular` takes one of the four units, `accessoryRectangular` two), `tapid lock-edit-remove-N` / `lock-edit-remove-inline` removes one, `tapid lock-gallery-close` closes the sheet, `tapid lock-edit-done` / `lock-edit-cancel` (or `lockscreen done`) saves / discards |
| `standby on\|off` | StandBy (iOS 17+: the iPhone charging on its side): locks the device, turns it to landscape and shows the first two small home-screen widgets side by side without their container backgrounds (an empty side shows the clock); `dump` lists `standby-widget-left` / `standby-widget-right`. Off: the portrait Lock Screen (unlocking also ends it) |
| `homepage N` / `homepage library` | show home-screen page N (1-based) or the App Library |
| `iconstyle STYLE [#RRGGBB] [small\|large]` | Home Screen icon appearance, as chosen in edit mode › Edit › Customize: `automatic`, `light`, `dark`, `tinted` (with the tint) or, iOS 26+, `clear`; small or large icons (saved; logs `SpringBoard: icon appearance …`) |
| `swipehome left\|right` | swipe across the home screen (left: the next page) |

While one of these is shown, `dump` lists its parts (ids and text) and `tapid` / `swipeid` act on them.

**Expanded notifications** (a long press on a Notification Center / lock-screen item or a banner, `holdid … 0.8`):
`dump` lists `nx-content` (tap: open the app), `nx-action-ID` for each action of the notification's category and
`nx-background` (tap: close; categories with `.customDismissAction` send the dismiss action). A text input action
opens `nx-reply-field`: `type TEXT` then `key return` (or `tapid nx-reply-send`) sends the reply. A Notification Content
extension's view is drawn at the top of the card, `nx-extension` (with `UNNotificationExtensionUserInteractionEnabled`,
`tap X Y` inside it reaches the extension's views), with its media button `nx-media` (text `Play` / `Pause`); the
actions are the extension's `notificationActions` when it sets them, answered by its `didReceive(_:completionHandler:)`.

**Calls** (CallKit; the shell draws iOS's call UI for the apps' VoIP calls): an incoming call is a banner while the
device is in use (`call-banner`: tap for the full-screen call; `call-decline`, `call-accept`) or the full-screen call
on the Lock Screen (`call-accept`: slide to answer). The call screen has `call-caller`, `call-status` (duration, "on
hold"), `call-speaker`, `call-video`, `call-mute`, `call-hold` (calls that support holding; else `call-add`),
`call-app` (opens the app), `call-keypad` (then `call-key-0` … `call-key-9`, `call-key-star`, `call-key-hash`,
`call-keypad-hide`) and `call-end`. `home` hides it; the call then shows as `call-pill` (the green indicator, or the
Dynamic Island's phone and duration), which brings it back. `dump` lists them as `IsimCallButton`.

**Messages** (isim's Messages app, `launch dev.isim.messages`, hosts the iMessage apps and sticker packs): `messages-plus`
opens the app menu (`messages-app-EXTENSION_BUNDLE_ID`), the open app has `messages-expand` / `messages-collapse` and
`messages-close-app`; a sticker pack's stickers are `sticker-N`. The compose field is `messages-field`, content an app
inserted is `messages-staged-N` (`messages-staged-remove-N` takes it out), `messages-send` sends; the transcript's
bubbles are `messages-bubble-N` (tapping an app's message opens the app with it selected). `isim messages list` prints
the conversation, `isim messages receive TEXT` (or `--app EXTENSION --url URL --caption C --session last`) delivers a
message from the other participant.

**Files** (the document picker and browser, UIDocumentPickerViewController / UIDocumentBrowserViewController): the
Browse list's locations are `docs-location-on-my-iphone` and, for each file provider domain an app added,
`docs-location-NAME` (the domain's display name, lowercase, spaces as `-`: `docs-location-sample-notes`); a folder's
items are `docs-item-NAME` (spaces as `-`), a file provider's file that is not downloaded yet has a `docs-cloud-NAME`
badge; `docs-open`, `docs-export` and `docs-cancel` are the bar buttons, `nav-back` goes back to Browse. `holdid
docs-item-NAME 0.9` opens an item's menu, which lists the file provider's actions (`menu-TITLE`). `isim fileprovider
list` prints the device's domains (app, domain, name, replica folder) and `isim fileprovider files DOMAIN` a domain's
items, `(placeholder)` for those not downloaded.

**Alarms** (AlarmKit; the shell rings the apps' alarms and timers, also in Silent Mode): an alarm going off is a
banner while the device is in use (`alarm-banner`: tap for the full-screen alert; `alarm-secondary`, the alarm's
secondary button such as Snooze or Repeat; `alarm-stop`) or the full-screen alert on the Lock Screen and in StandBy
(`alarm-title`, `alarm-secondary`, `alarm-stop`). `home` turns the full-screen alert into the banner. `dump` lists
them under `IsimAlarmBanner` / `IsimAlarmAlert` as `IsimAlarmButton`; `isim alarms list` prints every app's alarms
(id, title, state, when it goes off).

**Siri** (adapted; isim has no speech recognition, so Siri understands text): `siri PHRASE` is matched, in this
order, against the installed apps' App Shortcut phrases (case and trailing punctuation ignored; `\(.applicationName)`
is the app's display name or `CFBundleName`; an `AppEnum` or `AppEntity` parameter in a phrase matches one of its
cases, or of the entities the app suggested (`suggestedEntities()`, refreshed by `updateAppShortcutParameters()`)),
then voice shortcuts added to Siri (`INVoiceShortcut` invocation phrases), then these English SiriKit phrasings, each
optionally ending with `using|with|in|on|via APP` (or starting with `APP,`):

| Phrasing | Intent |
|---|---|
| `send a message to NAME [saying\|that says\|with TEXT]`, `message NAME saying TEXT`, `tell NAME [that] TEXT` | `INSendMessageIntent` |
| `call NAME`, `facetime NAME`, `video call NAME` | `INStartCallIntent` |
| `show my messages [from NAME]`, `read my messages`, `search for messages from NAME` | `INSearchForMessagesIntent` |
| `edit my last message to say TEXT`, `change my message to TEXT` | `INEditMessageIntent` (the last message Siri sent with the app) |
| `unsend my last message`, `take back my message` | `INUnsendMessagesIntent` (the last message Siri sent with the app) |
| `play NAME`, `shuffle NAME` | `INPlayMediaIntent` (`mediaSearch.mediaName`) |
| `add NAME to my library`, `add NAME to my PLAYLIST playlist`, `add this song to …` | `INAddMediaIntent` (`mediaSearch`, `mediaDestination`; "this" is what's playing) |
| `search for NAME`, `find NAME`, `look up NAME` | `INSearchForMediaIntent` |
| `add TASK to [my] LIST [list]`, `remind me to TASK` | `INAddTasksIntent` |
| `create a note [saying TEXT]`, `note TEXT` | `INCreateNoteIntent` |

`siri intent CLASS KEY=VALUE …` (`CLASS`: `INSendMessageIntent` or `SendMessage`; quote values with spaces) takes
`recipients=A,B content=TEXT` (messages), `contacts=A video=1` (calls), `senders=A terms=X,Y` (message search),
`message=ID content=TEXT` (editing), `messages=ID,ID` (unsending), `media=NAME shuffle=1` (playing),
`media=NAME playlist=NAME|library=1` (adding media), `media=NAME` (media search), `tasks=A,B list=NAME`, `title=… content=… folder=…` (notes) and `app=BUNDLE_ID`. A custom intent
(from an `.intentdefinition`) is named by its class, `siri intent OrderSoupIntent soup=Tomato quantity=2 size=bowl`:
each value is converted to its parameter's type (numbers, booleans, enum cases by name, custom types by display
string, people), Siri asks for missing values with the definition's prompts (listing the handler's dynamic options,
`provide<Parameter>OptionsCollection`, as choices) and speaks the response code's dialog. Before it sends an intent,
Siri spells the names in it the app's way when they match its vocabulary (`INVocabulary`). A SiriKit
intent goes to the app that supports it (its Intents extension's `IntentsSupported`, or `INIntentsSupported` in the
app's Info.plist; Siri asks "Which app?" when several do); the app must have the `com.apple.developer.siri`
entitlement and have been allowed to use Siri (`INPreferences.requestSiriAuthorization`).

While Siri is shown, `dump` lists `IsimSiri … mode=MODE source=SOURCE` and its parts: `siri-card` (text: what Siri
says or asks), `siri-heard`, `siri-detail` (a message read back, search results), `siri-snippet` (a snippet view or
an Intents UI extension's view), `siri-option-N` (choices: tap one, or `siri TITLE`, or `siri N`), `siri-confirm` /
`siri-cancel` (or `siri yes`), `siri-field` (Type to Siri: `type TEXT; key return`, or `siri TEXT`), `siri-orb` (iOS
17) / `siri-glow` (iOS 18+), and `siri-background` (tap: dismiss). The same card, without the orb or the glow, shows
the questions and results of App Shortcuts run from the Shortcuts app (`launch dev.isim.shortcuts`: `tapid
shortcut-BUNDLE-N`, `action-TYPE`, `suggestion-ID`, `voice-PHRASE`) and from Spotlight. The output has `SpringBoard:
Siri heard “…”`, `Siri asks “…”` (with the choices), `Siri says “…”` and `Siri answer …` lines. A result stays for 8 s
(`ISIM_SIRI_RESULT_SECONDS`).

**Notification banners**: while the shell shows a banner (a notification for an app in the background or not running),
`dump` lists it before the app's view tree:
`IsimNotificationBanner … id=isim-notification-banner notification=ID text=TITLE body=BODY` (line breaks become spaces).
`tapid isim-notification-banner` opens it and `holdid isim-notification-banner 0.8` expands it.

**App Clip card** (`appclip URL`): `dump` lists `IsimAppClipCard` with `appclip-card`, `appclip-title`,
`appclip-subtitle`, `appclip-open` (the call-to-action button: launches the App Clip), `appclip-close` and
`appclip-background` (dismiss), `appclip-notifications` and `appclip-location` (the notes for ephemeral notifications and
location confirmation, when the App Clip's `NSAppClip` requests them: a tap turns them off or on again) and
`appclip-app` (the App Clip's name). Recently used App Clips are in the App Library's Recently Added
(`applibrary-recent-BUNDLE_ID`); opened from there they get their last invocation URL.

**Widgets** (WidgetKit): a long press on a home-screen widget (`holdid widget-KIND-FAMILY 0.8`) opens its menu:
`menu-widget-edit` (configurable widgets: Edit Widget), `menu-edit` (Edit Home Screen), `menu-widget-remove`. Edit Widget
shows the configuration intent's parameters: `tapid widget-param-NAME` toggles a Bool switch, opens an enum's choices
(`tapid widget-choice-RAWVALUE`) or focuses a text / number field (`type`, `key return`); `tapid widget-config-done`
(outside the card) applies them and the timeline reloads. A tap on a widget outside its buttons opens the app with its
`widgetURL` (on a `Link`: the Link's URL); the log says `SpringBoard: widget KIND opens APP with URL`. In the widget
gallery each row shows the widget's snapshot (`widget-preview-KIND`). On the Lock Screen `dump` lists
`IsimLockScreenWidget … id=lock-widget-N` (and `lock-widget-inline`); `tapid` on one unlocks and opens its app.

**Live Activities**: `dump` lists `IsimDynamicIsland … id=dynamic-island text=compact|minimal|expanded` (with two
activities also `id=dynamic-island-detached`), on the lock screen `IsimLiveActivity … id=live-activity` (then
`live-activity-2`, …; text: the activity's id; `tapid` opens the app with the activity's `widgetURL`) and, on devices
without a Dynamic Island while an alert shows, `id=live-activity-banner`. Push updates go through `push BUNDLE_ID FILE`
(or `isim push`) with a liveactivity payload: `"aps": { "event": "update" | "end" | "start", "timestamp",
"content-state", "stale-date", "dismissal-date", "relevance-score", "alert", "attributes-type", "attributes" }`; a
top-level `"apns-push-token"` (the token the app logs from `pushTokenUpdates`) picks the activity, else the app's newest
activity with a push token. `start` needs the push-to-start token the app read from `pushToStartTokenUpdates`.

**Location indicator**: while an app uses location in the background, the status bar's time sits on a blue capsule
(`dump`: `IsimLocationIndicator … id=location-indicator`); `tapid location-indicator` opens that app.

## Touch

| Command | What it does |
|---|---|
| `tap X Y` | tap a point (a tap on the status bar, e.g. `tap 200 20`, scrolls the scroll view with `scrollsToTop` to the top, as on iOS; with none, the tap reaches the app) |
| `tapid ID` | tap the view whose `accessibilityIdentifier` is ID (the rest of the command, spaces included: `tapid menu-Copy Link`); a view below the fold of a scroll view (a long list) is scrolled into view first, like XCUITest (logs `isim: scrolled 'ID' into view`) |
| `taptext TEXT` | tap the view that shows TEXT |
| `holdid ID S` | press and hold a view for S seconds |
| `drag X1 Y1 X2 Y2 [S [HOLD [PRESS]]]` | drag between two points, optionally over S seconds, then held HOLD seconds before lifting (e.g. at the screen edge to turn a home-screen page in edit mode); PRESS: pressed that many seconds at the start before moving (XCUITest's `press(forDuration:thenDragTo:)`) |
| `swipeid ID DX DY S` | drag from a view's centre by (DX, DY) over S seconds |
| `longdrag X1 Y1 X2 Y2 HOLD S [REST]` | press, hold HOLD seconds (to start drag and drop), then move over S seconds; REST: rest that long at the end before lifting (spring-loaded controls activate under a resting drag) |
| `pointerdrag X1 Y1 X2 Y2 HOLD S [REST]` | the same with the iPad pointer: the touches are `UITouch.TouchType.indirectPointer` (a trackpad or mouse click) |
| `pinch X Y SCALE S` | two-finger pinch around (X, Y) to SCALE over S seconds |
| `rotate2 X Y DEGREES S` | two-finger rotation around (X, Y) |
| `twofinger X Y DX DY S` | two fingers moving together by (DX, DY) |
| `scroll X Y DX DY [S] [wheel]` | the pointer at (X, Y) scrolls (`UIEvent.EventType.scroll`): a trackpad swipe moving the content by (DX, DY) points over S seconds (default 0.3; its momentum carries on), or with `wheel` one mouse wheel step. The innermost `UIPanGestureRecognizer` whose `allowedScrollTypesMask` takes it pans (a scroll view's takes both); logs `isim: trackpad scroll to CLASS` / `isim: wheel scroll to CLASS`. The window's mouse wheel and trackpad do the same |
| `hover X Y` / `hover` | move the pointer without pressing (iPad pointer, `UIHoverGestureRecognizer`); no arguments ends hovering |
| `pencil X1 Y1 X2 Y2 SECS [FORCE] [ALTITUDE]` | an Apple Pencil stroke: `UITouch.type` `.pencil`, `force` (0…4.17, default 1), `altitudeAngle` (radians, default 1.1), azimuth along the stroke |
| `pencil tap` · `pencil squeeze` | the Pencil's double-tap / squeeze (`UIPencilInteraction`; the preferred actions come from Settings › Apple Pencil) |
| `pencil hover X Y [Z]` | the Pencil hovering Z (0…1, default 0.5) above (X, Y): `UIHoverGestureRecognizer.zOffset`, the hover pose of taps and squeezes |

## Keyboard and text

| Command | What it does |
|---|---|
| `type TEXT` | type text into the focused field: the rest of the command; write `;` as `\;` (a bare `;` ends the command) |
| `key NAME` | press a key: `backspace`, `return`, `tab`, `escape`, arrows, letters, digits, … |
| `keydown NAME` / `keyup NAME` | press or release a hardware key (for `pressesBegan`, `GCKeyboard`): letters, digits, `space`, `return`, `escape`, `tab`, `backspace`, arrows (`up`, `down`, `left`, `right`), `home`, `end`, `pageup`, `pagedown`, `f1`…`f12`, modifiers (`shift`, `ctrl`, `alt`, `cmd`). A key nobody handles scrolls the main scroll view (`allowsKeyboardScrolling`) |
| `compose TEXT` | marked (composing) text, as from an input method |
| `dictate TEXT` · `dictate fail` | dictation: TEXT is what was said into the keyboard's mic (it starts listening if needed; "comma", "period", "new line", … become punctuation); `fail` reports a recognition failure |
| `scribble X Y TEXT` | Scribble (iPad): handwrite TEXT with Apple Pencil at (X, Y), into the text input there |
| `sms TEXT` | a text message arrives; AutoFill offers a one-time code in it to `oneTimeCode` fields for three minutes |

## Device

| Command | What it does |
|---|---|
| `rotate portrait\|upsidedown\|landscapeleft\|landscaperight\|left\|right` | turn the device |
| `fold open\|closed\|toggle` | a foldable (`--device iphoneduo`): unfold to the inner display (951 x 669 pt) or fold to the cover (466 x 678 pt). Apps resize (`viewWillTransition(to:with:)`, regular x regular on the inner display); apps linked against an Apple SDK older than iOS 27.1 stay at the cover's size, letterboxed. Logs `isim shell: unfolded, inner display (951x669)` (`isim host: ...` under `isim run`) |
| `shake` | Device ▸ Shake (Shake to Undo offers to undo the first responder's last change when `applicationSupportsShakeToEdit` is on) |
| `location LAT LON` / `location none` | Features ▸ Location |
| `beacon UUID MAJOR MINOR [immediate\|near\|far] [RSSI]` · `beacon off UUID MAJOR MINOR` · `beacon none` | an iBeacon comes into range (default `near`, RSSI from the proximity), leaves, or all leave: Core Location ranging, beacon regions and `CLMonitor` beacon conditions see it |
| `remote NAME [ARG]` | `MPRemoteCommandCenter` command: `play`, `pause`, `toggle`, `next`, `previous`, `skipforward`, `skipback`, `seek S`, `rate R`, `like`, `dislike`, `bookmark`, `repeat off\|one\|all`, `shuffle off\|items\|collections`, `rating N`, `language ID`, `nolanguage ID` (a language option of the Now Playing info, by identifier or display name); an active `MPNowPlayingSession` gets them; with `isim boot` it goes to the app that publishes Now Playing, like Control Center's controls |
| `volume up\|down\|V` | the device volume (the side buttons: steps of 1/16; or V from 0 to 1): `AVAudioSession.outputVolume`, `MPVolumeView`, the mixer's master gain; remembered in the device data. While an `AVCaptureEventInteraction` (or SwiftUI's `onCameraCaptureEvent`) is enabled on screen with a capture session running, the buttons are capture buttons instead: up is secondary, down primary (logged `isim: capture event …`) |
| `cameracontrol` · `cameracontrol press\|down\|up` · `cameracontrol lightpress\|select I\|swipe N\|set V\|dismiss` | the Camera Control of the iPhone 16 (not 16e), 17 and Air presets (the bezel's button presses it): `press` / `down` / `up` are capture events for an `AVCaptureEventInteraction` (primary); `lightpress` brings up the running capture session's controls and their overlay beside the button (`camera-control-overlay`, its text the control and value; a second `lightpress` lists them all to choose from: `camera-control-N`, `choosing=1`) (the controls delegate hears active and full screen), `select I` picks one, `swipe N` moves it N detents, `set V` sets it, `dismiss` puts them away; each prints the controls and their values, like bare `cameracontrol` (`isim: cameracontrol controls=N active=0\|1 selected=I [0] Zoom=1.0x …`) |
| `camerapressure nominal\|fair\|serious\|critical\|shutdown [temperature,power,depth,camera,battery]` | the cameras' `AVCaptureDevice.SystemPressureState` (KVO); `shutdown` interrupts running capture sessions (`videoDeviceNotAvailableDueToSystemPressure`) until the pressure eases |
| `audio interrupt begin [alert\|muted]` · `audio interrupt end [resume]` · `audio route NAME` · `audio silence begin\|end` · `audio reset` | `AVAudioSession` events: an interruption (like a phone call; it pauses `AVAudioPlayer`s, `resume` sets `.shouldResume`; `alert` is a system alert, which skips sessions that prefer no interruptions from system alerts, `muted` the built-in microphone being muted, reason `builtInMicMuted`, which skips sessions with `overrideMutedMicrophoneInterruption`), a route change to `headphones`, `headset`, `bluetooth`, `carplay`, `airplay`, `usb`, `hdmi`, `receiver` or `speaker`, the secondary-audio hint, media services reset |
| `midi send BYTES` · `midi note NOTE [VELOCITY [CHANNEL]]` · `midi offline\|online` · `midi list` | the simulated "isim MIDI" device (CoreMIDI): `send` sends MIDI 1.0 bytes in hexadecimal (`90 3C 64`, running status allowed) from its source, `note` a note on and, half a second later, its note off (channel 1–16); `offline`/`online` sets the device's `kMIDIPropertyOffline` (clients get the notifications); `list` logs the sources and destinations. What apps send to its destination is logged as `CoreMIDI: isim MIDI received 90 3C 64` |
| `ar pose X Y Z [YAW [PITCH]]` · `ar move DX DY DZ` · `ar turn DYAW [DPITCH]` · `ar tracking normal\|limited\|features\|notavailable\|auto` · `ar interrupt\|resume` · `ar status` | the simulated AR device (ARKit, with `ISIM_AR_SCENE`): `pose` places it (metres; yaw and pitch in degrees, yaw turning left), `move` moves it along its heading (x right, y up, z back), `turn` turns it; `tracking` makes its sessions report a tracking state (`auto`: their own); `interrupt`/`resume` interrupts its sessions. Each logs the pose: `isim ARKit: camera at 0.00 0.00 0.00 yaw 0 pitch -45 (planes 3)` |
| `shareplay join [CALL]` · `shareplay leave` · `shareplay` | the simulated FaceTime call SharePlay runs in (GroupActivities): `join` puts the device in the call `CALL` (default `isim`) shared with the other isim devices that joined it, `leave` takes it out (its sessions end), and with no argument it logs the call: `isim GroupActivities: in the SharePlay call movie-night with 1 other participant(s), 1 session(s)`. The call is kept in the device data, so every app on the device sees it |
| `gamesave offline` · `gamesave online` · `gamesave` | GameSave's simulated network: `offline` takes the device off it (open synced directories become `offline` and do not upload), `online` brings it back (they sync again, and may become `conflicted`); with no argument it logs the state: `isim GameSave: online, iCloud signed in` |
| `gamepad connect [NAME] [as ps5\|ps4\|xbox\|switchpro]` · `gamepad button NAME 0\|1` · `gamepad axis NAME VALUE` · `gamepad touch FINGER 0\|1 X Y` · `gamepad battery PERCENT [discharging\|charging\|full\|unknown]` · `gamepad motion AX AY AZ GX GY GZ` · `gamepad disconnect` | a virtual game controller: `as …` gives it that pad's vendor and product, so it gets that product profile (`GCDualSenseGamepad`, `GCDualShockGamepad`, `GCXboxGamepad`); buttons are SDL's names, including `misc1` (share), `paddle1`…`paddle4` and `touchpad`; `touch` moves a finger (0 or 1) on its touchpad (x, y in 0…1, y down); its battery, and accelerometer m/s² / gyroscope rad/s samples; its light colour is logged as `isim gamepad: led R G B`, effect reports (DualSense adaptive triggers) as `isim gamepad: effect XX …` |
| `mouse move DX DY` · `mouse button left\|right\|middle 0\|1` · `mouse scroll DX DY` | the host mouse as `GCMouse` sees it (points, y down; the pointer over the device window does the same) |
| `display connect [WxH]` · `display shot PATH` · `display disconnect` | a simulated external display (default 1920x1080): the app's external display scene (a scene accessory, or the manifest's `UIWindowSceneSessionRoleExternalDisplayNonInteractive` configuration) or the mirrored device; `display shot` saves what it shows as a PNG |
| `mainmenu [show\|hide]` | the app's main menu: logs its tree (`isim: main menu …` lines, shortcuts included, then `isim: main menu end`); `show` / `hide` shows or hides the keyboard shortcuts overlay (iPad: what holding Command shows) |
| `closescene [SESSION_ID]` | the user closes a window (iPad apps with multiple scenes; the key scene by default): the scene's `closureConfirmation` is shown first when it has one |
| `metrickit` · `metrickit deliver` | Debug ▸ Simulate MetricKit Payloads (fixed sample payloads) · the metric payload MetricKit measured in this run so far (and anything still waiting), delivered now: what iOS sends about once a day |
| `signposts [SUBSYSTEM\|CATEGORY]` | the signposts the foreground app recorded (Instruments' Points of Interest, as text): per subsystem, category and name, `isim signposts: SUBSYSTEM:CATEGORY NAME events N intervals N open N total … ms avg … ms max … ms` |
| `voiceover on\|off\|next\|prev\|activate\|increment\|decrement\|action\|escape\|magictap\|read` | drive the simulated VoiceOver (`read` reads `UIAccessibilityReadingContent` elements as their page content). While it runs, a touch focuses (`tap`) or activates (a double tap); a touch in a direct touch area (`allowsDirectInteraction`, SwiftUI `accessibilityDirectTouch`) reaches the app, after a VoiceOver activation with `requiresActivation` |
| `voiceover scroll up\|down\|left\|right\|next\|prev` | a three-finger swipe: the focused element or a container's SwiftUI `accessibilityScrollAction` or `accessibilityScroll(_:)`, else the nearest scroll view moves a page; VoiceOver says the scroll status (`UIScrollViewAccessibilityDelegate`, else "Page N of M") |
| `voiceover rotor [prev]`, `voiceover up\|down` | turn the VoiceOver rotor (custom rotors, Headings, Actions, More Content, Adjust Value) / move by its item (like swiping up / down; More Content reads the next default-importance custom content) |
| `voiceover focus ID` | move VoiceOver's focus to the element with that accessibility identifier (or the first element inside the view that has it), and speak it |
| `voiceover zoom in\|out` | the Zoom rotor's swipe: the focused element or a container zooms at its activation point (SwiftUI `accessibilityZoomAction`, UIKit `accessibilityZoomIn(at:)` / `accessibilityZoomOut(at:)`) |
| `switchcontrol on\|off\|next\|select\|autoSECS\|stop` | simulated Switch Control: item scanning (`auto0.5` moves the highlight every 0.5 s), select activates |
| `voicecontrol PHRASE` | simulated Voice Control: `tap NAME` (label or `accessibilityUserInputLabels`), `show numbers` / `show names` / `hide numbers`, `tap N`, `scroll down\|up\|left\|right`, `go back` |
| `accessibility SETTING on\|off` | a Settings ▸ Accessibility switch: `monoaudio`, `speakscreen`, `speakselection`, `assistivetouch`, `shaketoundo`, `buttonshapes`, `onofflabels`, `differentiate`, `reducemotion`, `reducetransparency`; the app gets the matching `UIAccessibility…DidChangeNotification`. Also the Accessibility framework's settings (`AccessibilitySettings`, with their notifications): `animatedimages` (on by default), `horizontaltext`, `nonblinkingcursor`, `showborders`, `reducehighlighting`, `actionslider`, `assistiveaccess` |
| `biometry [enrolled on\|off \| match \| nomatch \| lockout \| reset]` | Face ID / Touch ID, like the Simulator's Features ▸ Face ID menu: `enrolled on\|off` enrolls a face (finger) or removes it (enrolling again changes LocalAuthentication's domain state); `match` / `nomatch` answer the scan on screen; `lockout` / `reset` set five failed scans in a row (biometry locked out until the passcode) or none; bare `biometry` logs `isim: biometry enrolled=… failures=… lockedout=… enrollment=…`. Device-wide, every app follows |
| `privacy reset SERVICE\|all` | forget the app's answer to a privacy prompt, so it asks again (like Settings › General › Transfer or Reset › Reset Location & Privacy): `camera`, `microphone`, `photos`, `location`, `contacts`, `calendar`, `reminders`, `speech`, `medialibrary`, `siri`, `paste`, `health`, `notifications`, `tracking`; logs `isim: privacy reset SERVICE` (XCUITest's `resetAuthorizationStatus(for:)` clears them at the next launch) |
| `guidedaccess on\|off` · `guidedaccess restrict ID allow\|deny` | start / end a Guided Access session (the app delegate's `UIGuidedAccessRestrictionDelegate` restrictions are logged) / switch one of its restrictions, as in the Guided Access options |
| `tilt H V` | tilt the device (each −1…1) for `UIInterpolatingMotionEffect`s; `tilt 0 0` levels it |
| `attributions` | list the private click measurement clicks (`UIEventAttribution`) the app recorded |
| `fullpage PATH` | a full-page screenshot: the scene's `UIScreenshotServiceDelegate` PDF, written to PATH |

**Picture in Picture**: while an app shows a video in Picture in Picture (`isim boot`), the shell's floating window is
`pip-window` (its text is the title and `playing` / `paused`); `tapid pip-window` shows its controls: `pip-close`,
`pip-restore` (back to the app), `pip-play`, `pip-skip-back`, `pip-skip-forward`. **Route picker** (`AVRoutePickerView`,
`MPVolumeView`, the AirPlay button of `AVPlayerViewController`): `route-iphone`, `route-headphones` (when plugged in with
`audio route headphones`), `route-airplay`, `route-picker-background` (closes). `AVPlayerViewController` controls:
`avkit-pip`, `avkit-airplay`, `avkit-speed` (a menu: `menu-1×`, `menu-2×`, …), `avkit-fullscreen`. Media picker
(`MPMediaPickerController`): `media-picker-TITLE` (spaces as dashes), `media-picker-done`, `media-picker-cancel`.

## Inspecting

| Command | What it does |
|---|---|
| `shot FILE.png` | screenshot (the full screen at the device's pixel scale) |
| `dump` | print the foreground app's view tree (frames, text, identifiers; an empty text field shows its `placeholder=` and a field its `contentType=`; `ISIM_DUMP_ACCESSIBILITY=1` adds accessibility descriptions) |
| `dump FILE` | write an accessibility snapshot to FILE (used by XCUITest and the Python tests) |
| `dump views FILE` | write the view tree (as `dump` prints it) to FILE |
| `sysevent TEXT` | hand the app a system event as the shell would (`remote-notification FILE`, `nx-media play`, …); the shell drives extension helpers this way, through their control channel |

## The window

A device window has a toolbar above the screen and a device bezel around it (on by default):

- **device button**: the device, its iOS version and a status dot. It opens the device menu: device, iOS version
  (17, 18, 26, 27; the current one is marked "now") and zoom, which apply after a restart, and "Show device bezel",
  which applies at once and is remembered;
- **Home**, **Lock**, **Rotate** (Shift: the other way), **Screenshot** (saved as `~/Pictures/isim-HHMM.png`, then a
  "Saved … Show" message), **Appearance** (light / dark) and **More** (Shake, Location…, Open URL…, Send push
  notification…, Memory warning);
- the bezel's hardware buttons: the side (or top) button locks and unlocks, the volume buttons change the volume, the
  Action button runs its action, the Ring/Silent switch toggles Silent Mode, and the iPhone SE's Home button goes home.

Every control runs one of the script commands on this page through the same dispatcher as `--script` and the control
FIFO; the window prints each as `isim window: COMMAND`. What the toolbar shows (light or dark, locked, the location in
the Location form) is read from the device each time it is drawn, so a change from a script, `isim send`, Control
Center or Settings shows up too. Device, iOS version and zoom are boot options: **Apply…** asks "Restart the device?"
first (it lists what changes; "Don't ask again" is remembered in the device data), then the device shuts down and
boots again with them. Installed apps, their data and settings stay. Scripts, `isim boot --device … --os …` and
`restart` never ask.

`shot` and F12 save the screen alone; `windowshot` saves the window with the toolbar, bezel and any open menu.
`ISIM_CHROME=0` turns the toolbar and bezel off (the window is the screen alone). The window's choices live in the
device data (`Library/isim/Window.conf`).

Anything a click does in the window is also a command, so agents and tests reach it without a mouse:

| Command | What it does |
|---|---|
| `windowshot FILE.png` | the whole window (toolbar, bezel, menus, the screen) as a PNG, also headless |
| `window menu device\|more\|location\|openurl\|push\|pushhelp\|none` | open a menu or form (or close it) |
| `window tap ID` | click a control by its id: `device`, `home`, `lock`, `rotate`, `shot`, `appearance`, `more`; hardware `hw.side`, `hw.top`, `hw.volup`, `hw.voldown`, `hw.action`, `hw.silent`, `hw.home`; device menu `dev.ID` (e.g. `dev.iphonese`), `dev.all`, `os.26`, `zoom.minus`, `zoom.plus`, `bezel`, `apply`; restart dialog `dialog.dontask`, `dialog.cancel`, `dialog.restart`; More menu `more.shake`, `more.location`, `more.openurl`, `more.push`, `more.memorywarning` (and `more.appearance` in a compact window, whose toolbar has no Appearance button); forms `back`, `field.NAME`, `place.0`…`place.4`, `loc.set`, `loc.none`, `recent.N`, `url.open`, `url.cancel`, `push.app`, `pushapp.N`, `tab.alert`, `tab.json`, `push.sound`, `push.mutable`, `push.available`, `push.load`, `push.help`, `push.send`, `help.back`, `help.docs`; `toast.show` |
| `window els` | print the controls shown now, with their centres in window points |
| `window click X Y [shift]` · `window hover X Y` | click or point at window points (the toolbar starts at 0, 0); a click on the screen is a tap there; hovering a toolbar button shows its tooltip |
| `window type TEXT` | type into the focused field of a form (fields: `lat`, `lon`, `url`, `title`, `body`, `badge`, `json`) |
| `window key escape\|return\|tab\|backspace\|delete\|left\|right\|home\|end\|selectall\|paste\|copy\|cut` | a key in the open menu, form or dialog |
| `window bezel on\|off` | show or hide the device bezel (no restart; remembered) |
| `window load FILE` | load an `.apns` payload into the push form's JSON tab |
| `window state` | print what the toolbar shows: `appearance=dark locked=0 orientation=portrait location=… bezel=1 menu=none dialog=0 device=iphone15 ios=18 zoom=1 layout=438x996 scale=1.000`. `layout` is the window's size in points; `scale` the scale the window shows it at, centred and never stretched: below 1 when the window was fitted to a smaller screen, above 1 when maximized (`window els` gives control centres in layout points) |
| `restart [device=ID] [os=17\|18\|26\|27] [zoom=Z]` | restart the device with new boot options (what the restart dialog does, without asking); the device data stays |

## Push notifications

A remote notification is a JSON payload with an `aps` dictionary, as Apple's push service delivers it. isim delivers
it like Xcode's Simulator does (`xcrun simctl push`), with no server and no device token involved:

- in the window: More › **Send push notification…** builds the payload from a title, body, badge and options (the
  Alert tab), or takes it as JSON (the JSON payload tab, or **Load .apns file…**), and sends it to the app picked;
- `isim push BUNDLE_ID payload.apns` (or `-` for standard input) from a terminal, or `push BUNDLE_ID FILE` in a script;
- drop an `.apns` file with a `"Simulator Target Bundle"` key on the device window.

```json
{
  "Simulator Target Bundle": "dev.example.myapp",
  "aps": {
    "alert": { "title": "Your order is on its way", "body": "Arrives today." },
    "badge": 3,
    "sound": "default"
  }
}
```

`"mutable-content": 1` runs the app's Notification Service extension first; `"content-available": 1` wakes the app
in the background. See the `push` command under Timing and control for collapse ids, VoIP pushes and Live Activity
updates.

Like iOS, the system shows a push's alert (banner, Lock Screen, Notification Center) only for an app the user allowed
to send notifications: the app must have asked (`UNUserNotificationCenter.requestAuthorization`) and been allowed
(the prompt, or `ISIM_NOTIFICATION_PERMISSION=allow`; Settings › Notifications turns it off again). For any other app
the push still reaches it (`didReceiveRemoteNotification`, the service extension) but nothing is shown; the push form
says so under the app picker, and the window logs `isim window: note: …` when sending.

## Interactive shortcuts

In a window: click to touch, drag to swipe, Option-drag for a second finger (pinch/rotate), Option+Shift-drag
to move two fingers together. Swipe up from the bottom edge or press Ctrl+Shift+H to go home; Ctrl+Left/Right
rotates; F12 saves a screenshot (the screen alone; the toolbar's Screenshot button saves to `~/Pictures`). Under `isim boot`: Ctrl+Shift+H twice opens the app switcher (or swipe up from the
bottom edge and hold), Ctrl+L locks/unlocks, pulling down from the top edge opens Notification Center (Control
Center from the top-right corner), Ctrl+Shift+S brings up Siri (the side button held) or dismisses it.

The iOS version (`--os 17|18|26|27`, see [IOS-VERSIONS.md](IOS-VERSIONS.md)) changes what scripts see: frames of
system controls (e.g. the iOS 26 switch is 63 × 28, bar buttons are 44 pt glass circles), Control Center's parts
(iOS 18+ adds `cc-edit` and `cc-power`) and the look in screenshots. `ISIM_LOCK_TIME=H:MM` fixes the Lock Screen
clock for screenshots.
