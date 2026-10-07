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
| `lock` / `unlock` | show / dismiss the Lock Screen (`isim boot`; the look of the `--os` version) |
| `controlcenter` / `controlcenter off` | open / close Control Center (`isim boot`; iOS 17, the iOS 18 redesign, or iOS 26+ glass) |
| `openurl URL` | open a URL in the foreground app: custom schemes and universal links (`isim openurl URL --control FIFO` does the same from another terminal) |

## Touch

| Command | What it does |
|---|---|
| `tap X Y` | tap a point |
| `tapid ID` | tap the view whose `accessibilityIdentifier` is ID |
| `taptext TEXT` | tap the view that shows TEXT |
| `holdid ID S` | press and hold a view for S seconds |
| `drag X1 Y1 X2 Y2 [S]` | drag between two points, optionally over S seconds |
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
rotates; F12 saves a screenshot. Ctrl+L locks/unlocks; a swipe down from the top-right corner opens Control Center
(tap to close it).

The iOS version (`--os 17|18|26|27`, see [IOS-VERSIONS.md](IOS-VERSIONS.md)) changes what scripts see: frames of
system controls (e.g. the iOS 26 switch is 63 × 28, bar buttons are 44 pt glass circles) and the look in screenshots.
Set `ISIM_LOCK_TIME=H:MM` for a fixed Lock Screen clock in screenshots.
