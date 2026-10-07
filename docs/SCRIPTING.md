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
| `wait S` | wait S seconds (fractions allowed) |
| `quit` | stop the device |
| `home` | go to the home screen |
| `launch BUNDLE_ID` | open an installed app |
| `openurl URL` | open a URL: under `isim boot` the home screen opens it in the app that handles it (its `CFBundleURLTypes` scheme, or an https universal link of its `applinks:` domains); with `isim run` the running app gets it (custom schemes, its own universal links, other web URLs "open in Safari"). `isim openurl URL --control FIFO` does the same from another terminal |
| `bgtask BUNDLE_ID TASK_ID` | launch a submitted BackgroundTasks request (like Xcode's `_simulateLaunchForTaskWithIdentifier`); a closed app is started in the background. `TASK_ID` `--fetch` runs a background fetch |

## System UI (`isim boot`)

| Command | What it does |
|---|---|
| `lock` / `unlock` | lock the device (the foreground app goes to the background; the lock screen shows the clock, notifications and Live Activities) / unlock |
| `switcher` | the app switcher (cards of running apps; `swipeid switcher-NAME 0 -300 0.3` closes an app, `tapid switcher-NAME` switches) |
| `notifications` | Notification Center (`tapid nc-item-ID` opens a notification, `tapid nc-clear` clears) |
| `controlcenter` | Control Center (`tapid cc-wifi`, `cc-airplane`, `cc-dark`, `cc-orientation`, `cc-focus`, …; `tapid cc-background` closes) |
| `spotlight` | Spotlight on the home screen |
| `island` | expand / collapse the Dynamic Island's Live Activity |
| `homepage N` / `homepage library` | show home-screen page N (1-based) or the App Library |
| `swipehome left\|right` | swipe across the home screen (left: the next page) |

While one of these is shown, `dump` lists its parts (ids and text) and `tapid` / `swipeid` act on them.

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
| `dump FILE` | write an accessibility snapshot to FILE (used by XCUITest) |

## Interactive shortcuts

In a window: click to touch, drag to swipe, Option-drag for a second finger (pinch/rotate), Option+Shift-drag
to move two fingers together. Swipe up from the bottom edge or press Ctrl+Shift+H to go home; Ctrl+Left/Right
rotates; F12 saves a screenshot. Under `isim boot`: Ctrl+Shift+H twice opens the app switcher (or swipe up from the
bottom edge and hold), Ctrl+L locks/unlocks, pulling down from the top edge opens Notification Center (Control
Center from the top-right corner).
