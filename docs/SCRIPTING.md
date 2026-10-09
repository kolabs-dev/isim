# Scripting and automation

`isim boot` and `isim run` accept `--headless --script "…"`: a list of commands separated by `;` that drive the
device like a person (or like Xcode's Simulator menus) and then quit. Tests and CI use this. With
`--control FIFO`, the same commands can be sent to a running device, one per line, e.g. `echo "shot s.png" > FIFO`.

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
| `home` | go to the home screen |
| `launch BUNDLE_ID` | open an installed app |
| `openurl URL` | open a URL: under `isim boot` the home screen opens it in the app that handles it (its `CFBundleURLTypes` scheme, or an https universal link of its `applinks:` domains); with `isim run` the running app gets it (custom schemes, its own universal links, other web URLs "open in Safari"). `isim openurl URL --control FIFO` does the same from another terminal |
| `bgtask BUNDLE_ID TASK_ID` | launch a submitted BackgroundTasks request (like Xcode's `_simulateLaunchForTaskWithIdentifier`); a closed app is started in the background (a suspended one is resumed). `TASK_ID` `--fetch` runs a background fetch (with `UIBackgroundModes` `fetch` and a minimum fetch interval other than never, like iOS) |
| `push BUNDLE_ID FILE` | deliver a remote notification payload (JSON with an `aps` dictionary), like `xcrun simctl push`: the Notification Service extension runs for `mutable-content`, then the running app gets it, or the system shows it (app not running), or `content-available` launches the app in the background. With `isim run` (the app alone) the payload goes straight to the app. Outside scripts: `isim push [BUNDLE_ID] payload.apns\|-`, or drop a `.apns` file (with a `"Simulator Target Bundle"` key) on the device window. A top-level `"apns-collapse-id"` key becomes the notification's identifier |
| `appearance light\|dark` | switch the device appearance (like Settings > Display & Brightness); running apps get a trait change (`traitCollectionDidChange`, `registerForTraitChanges`) |
| `contrast on\|off` | Increase Contrast (`accessibilityContrast`): high-contrast system and asset colors |
| `boldtext on\|off` | Bold Text (`legibilityWeight`) |
| `memorywarning` | simulate a memory warning (like the Simulator's Debug menu): the app delegate, `didReceiveMemoryWarningNotification` and every loaded view controller |

## System UI (`isim boot`)

| Command | What it does |
|---|---|
| `lock` / `unlock` | lock the device (the foreground app goes to the background; the lock screen shows the clock, notifications and Live Activities) / unlock |
| `switcher` | the app switcher (cards of running apps; `swipeid switcher-NAME 0 -300 0.3` closes an app, `tapid switcher-NAME` switches) |
| `notifications` | Notification Center (`tapid nc-item-ID` opens a notification, `holdid nc-item-ID 0.8` expands it, `tapid nc-clear` clears) |
| `controlcenter` | Control Center (`tapid cc-wifi`, `cc-airplane`, `cc-dark`, `cc-orientation`, `cc-focus`, …; `tapid cc-background` closes) |
| `spotlight` | Spotlight on the home screen |
| `island` | expand / collapse the Dynamic Island's Live Activity |
| `homepage N` / `homepage library` | show home-screen page N (1-based) or the App Library |
| `swipehome left\|right` | swipe across the home screen (left: the next page) |

While one of these is shown, `dump` lists its parts (ids and text) and `tapid` / `swipeid` act on them.

**Expanded notifications** (a long press on a Notification Center / lock-screen item or a banner, `holdid … 0.8`):
`dump` lists `nx-content` (tap: open the app), `nx-action-ID` for each action of the notification's category and
`nx-background` (tap: close; categories with `.customDismissAction` send the dismiss action). A text input action
opens `nx-reply-field`: `type TEXT` then `key return` (or `tapid nx-reply-send`) sends the reply. A Notification Content
extension's view is drawn at the top of the card.

**Notification banners**: while the shell shows a banner (a notification for an app in the background or not running),
`dump` lists it before the app's view tree:
`IsimNotificationBanner … id=isim-notification-banner notification=ID text=TITLE body=BODY` (line breaks become spaces).
`tapid isim-notification-banner` opens it and `holdid isim-notification-banner 0.8` expands it.

**Location indicator**: while an app uses location in the background, the status bar's time sits on a blue capsule
(`dump`: `IsimLocationIndicator … id=location-indicator`); `tapid location-indicator` opens that app.

## Touch

| Command | What it does |
|---|---|
| `tap X Y` | tap a point |
| `tapid ID` | tap the view whose `accessibilityIdentifier` is ID |
| `taptext TEXT` | tap the view that shows TEXT |
| `holdid ID S` | press and hold a view for S seconds |
| `drag X1 Y1 X2 Y2 [S [HOLD]]` | drag between two points, optionally over S seconds, then held HOLD seconds before lifting (e.g. at the screen edge to turn a home-screen page in edit mode) |
| `swipeid ID DX DY S` | drag from a view's centre by (DX, DY) over S seconds |
| `longdrag X1 Y1 X2 Y2 HOLD S` | press, hold HOLD seconds (to start drag and drop), then move over S seconds |
| `pinch X Y SCALE S` | two-finger pinch around (X, Y) to SCALE over S seconds |
| `rotate2 X Y DEGREES S` | two-finger rotation around (X, Y) |
| `twofinger X Y DX DY S` | two fingers moving together by (DX, DY) |
| `hover X Y` / `hover` | move the pointer without pressing (iPad pointer, `UIHoverGestureRecognizer`); no arguments ends hovering |

## Keyboard and text

| Command | What it does |
|---|---|
| `type TEXT` | type text into the focused field |
| `key NAME` | press a key: `backspace`, `return`, `tab`, `escape`, arrows, letters, digits, … |
| `keydown NAME` / `keyup NAME` | press or release a hardware key (for `pressesBegan`, `GCKeyboard`) |
| `compose TEXT` | marked (composing) text, as from an input method |
| `dictate TEXT` · `dictate fail` | dictation: TEXT is what was said into the keyboard's mic (it starts listening if needed; "comma", "period", "new line", … become punctuation); `fail` reports a recognition failure |
| `scribble X Y TEXT` | Scribble (iPad): handwrite TEXT with Apple Pencil at (X, Y), into the text input there |
| `sms TEXT` | a text message arrives; AutoFill offers a one-time code in it to `oneTimeCode` fields for three minutes |

## Device

| Command | What it does |
|---|---|
| `rotate portrait\|upsidedown\|landscapeleft\|landscaperight\|left\|right` | turn the device |
| `shake` | Device ▸ Shake |
| `location LAT LON` / `location none` | Features ▸ Location |
| `remote NAME [ARG]` | `MPRemoteCommandCenter` command: `play`, `pause`, `toggle`, `next`, `previous`, `skipforward`, `skipback`, `seek S`, `rate R` |
| `audio interrupt begin` · `audio interrupt end [resume]` · `audio route NAME` · `audio silence begin\|end` · `audio reset` | `AVAudioSession` events: an interruption (like a phone call; it pauses `AVAudioPlayer`s, `resume` sets `.shouldResume`), a route change to `headphones`, `headset`, `bluetooth`, `carplay`, `airplay`, `usb`, `hdmi`, `receiver` or `speaker`, the secondary-audio hint, media services reset |
| `gamepad connect [NAME]` · `gamepad button NAME 0\|1` · `gamepad axis NAME VALUE` · `gamepad disconnect` | a virtual game controller |
| `metrickit` | Debug ▸ Simulate MetricKit Payloads |
| `voiceover on\|off\|next\|prev\|activate\|increment\|decrement\|action\|escape\|read` | drive the simulated VoiceOver |

## Inspecting

| Command | What it does |
|---|---|
| `shot FILE.png` | screenshot (the full screen at the device's pixel scale) |
| `dump` | print the foreground app's view tree (frames, text, identifiers; `ISIM_DUMP_ACCESSIBILITY=1` adds accessibility descriptions) |
| `dump FILE` | write an accessibility snapshot to FILE (used by XCUITest and the Python tests) |
| `dump views FILE` | write the view tree (as `dump` prints it) to FILE |

## Interactive shortcuts

In a window: click to touch, drag to swipe, Option-drag for a second finger (pinch/rotate), Option+Shift-drag
to move two fingers together. Swipe up from the bottom edge or press Ctrl+Shift+H to go home; Ctrl+Left/Right
rotates; F12 saves a screenshot. Under `isim boot`: Ctrl+Shift+H twice opens the app switcher (or swipe up from the
bottom edge and hold), Ctrl+L locks/unlocks, pulling down from the top edge opens Notification Center (Control
Center from the top-right corner).

The iOS version (`--os 17|18|26|27`, see [IOS-VERSIONS.md](IOS-VERSIONS.md)) changes what scripts see: frames of
system controls (e.g. the iOS 26 switch is 63 × 28, bar buttons are 44 pt glass circles), Control Center's parts
(iOS 18+ adds `cc-edit` and `cc-power`) and the look in screenshots. `ISIM_LOCK_TIME=H:MM` fixes the Lock Screen
clock for screenshots.
