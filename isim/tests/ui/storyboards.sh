#!/usr/bin/env bash
# UI test: Interface Builder on isim (HelloStoryboards sample, built from an .xcodeproj by `isim build` + isim's ibtool).
#  - classic app: UIMainStoryboardFile window + initial controller (initWithCoder:, awakeFromNib, outlets, outlet
#    collection, target-action), UILaunchScreen dictionary (asset color + navigation bar)
#  - scene app: UISceneStoryboardFile, LaunchScreen.storyboard, tab bar/navigation relationship segues, table view
#    controller with storyboard prototype cells (custom class + outlets, subtitle style) and a UINib-registered xib cell,
#    selection show segue + prepare(for:sender:) + shouldPerformSegue, embed segue, performSegue(withIdentifier:),
#    storyboard IDs, modal presentation from a bar button item, unwind segues (Done / Save / Cancel), bar button action
#  - controls scene: slider/switch/stepper/segmented/text field/button-configuration actions, gesture recognizer from
#    the storyboard, user defined runtime attributes, Auto Layout from IB (multiplier 1:2, priority, placeholder
#    constraint removed), xib-backed view controllers (explicit nibName and the default class-named nib),
#    UIFontPickerViewController
#  - Settings.bundle: the app's page in Settings (group/text field/toggle/multi value/slider/title value/child pane,
#    localized titles) writes the app's UserDefaults domain, which the app reads
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=$PWD/out/test-shots/HelloStoryboards; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/storyboards; rm -rf "$ISIM_DATA"
run() { ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_LAUNCH_SCREEN_SECS=${LS:-0.25} ISIM_SCRIPT="$2" timeout 90 out/bin/isim run "out/apps/$1.app" 2>&1; }
px() { magick "$1" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info:; }

classic=$(LS=1.5 run HelloStoryboardsClassic "wait 0.2; shot $shots/classic-launch.png; dump; wait 2; tapid classic-increment; wait 0.2; tapid classic-increment; wait 0.2; tapid classic-increment; wait 0.2; tapid classic-reset; wait 0.2; tapid classic-increment; wait 0.3; shot $shots/classic.png; dump; quit"); rc1=$?
notes=$(LS=1.5 run HelloStoryboards "wait 0.2; shot $shots/launch.png; wait 2; shot $shots/notes.png; dump; tapid note-1; wait 1; shot $shots/detail.png; dump; tapid detail-more; wait 1; dump; tapid nav-back; wait 0.8; tapid detail-done; wait 1; dump; tapid bar-Add; wait 1.2; tapid compose-title; type Hello IB; wait 0.3; tapid bar-Save; wait 1.2; shot $shots/saved.png; dump; tapid bar-Add; wait 1.2; tapid bar-Cancel; wait 1; tapid bar-Reset; wait 0.5; dump; quit"); rc2=$?
controls=$(run HelloStoryboards "wait 1; tapid tab-Controls; wait 0.8; shot $shots/controls.png; dump; tapid controls-switch; wait 0.3; tap 330 245; wait 0.3; tap 322 297; wait 0.3; drag 201 172 330 172 0.4; wait 0.3; tapid controls-name; type Ana; wait 0.3; key return; tapid apply-button; wait 0.3; tapid rounded-view; wait 0.3; dump; tapid open-profile; wait 1; shot $shots/profile.png; dump; tapid profile-close; wait 1; tapid open-default-nib; wait 1.2; dump; tapid profile-close; wait 1; tapid open-fonts; wait 1.2; shot $shots/fonts.png; tapid font-Georgia; wait 1.2; dump; quit"); rc3=$?

fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
nth_dump() { awk -v n="$2" '/^(UIWindow|__IsimLaunchWindow)/{if (!inw) k++; inw=1} !/^(UIWindow|__IsimLaunchWindow)/ && !/^ /{inw=0} k==n' <<<"$1"; }
# --- classic
check "classic: UIMainStoryboardFile window before willFinishLaunching" 'grep -q "classic: willFinishLaunching window=set" <<<"$classic" && grep -q "classic: didFinishLaunching root=ClassicViewController storyboard=yes" <<<"$classic"'
check "classic: initWithCoder + awakeFromNib (ObjC class)" 'grep -q "classic: initWithCoder title=Classic" <<<"$classic" && grep -q "classic: awakeFromNib" <<<"$classic"'
check "classic: outlets + outlet collection at viewDidLoad" 'grep -q "classic: viewDidLoad label=Count 0 buttons=2" <<<"$classic"'
check "classic: target-actions" 'grep -q "classic: count 3" <<<"$classic" && grep -q "classic: reset" <<<"$classic" && grep -q "id=classic-count text=Count 1" <<<"$classic"'
check "classic: UILaunchScreen dict (asset color + bar)" 'grep -q "launch screen: UILaunchScreen UIColorName,UINavigationBar" <<<"$classic" && grep -q "id=launch-navigation-bar" <<<"$classic" && [ "$(px $shots/classic-launch.png 200 500)" = "16 112 208" ]'
check "classic: launch screen goes away" 'grep -q "isim: launch screen hidden" <<<"$classic" && [ "$(px $shots/classic.png 30 700)" = "255 255 255" ]'
check "classic: Auto Layout from IB (centered label/button)" 'grep -q "UILabel (20 349; 362 x 44) id=classic-count" <<<"$classic"'
# --- launch storyboard + scene storyboard
check "LaunchScreen.storyboard shown while launching" 'grep -q "launch screen: storyboard LaunchScreen" <<<"$notes" && [ "$(px $shots/launch.png 30 300)" = "88 86 214" ]'
check "UISceneStoryboardFile: window + root before willConnect" 'grep -q "scene: window from storyboard: true, root=UITabBarController, storyboard=true" <<<"$notes"'
check "init(coder:) + awakeFromNib (Swift class)" 'grep -q "notes: init(coder:) title=Notes" <<<"$notes" && grep -q "notes: awakeFromNib navigationItem=Notes" <<<"$notes"'
check "tableView key=view + dataSource outlet + nib loading" 'grep -q "notes: viewDidLoad tableView=UITableView dataSource=true storyboard=true nib objects=1 first=BadgeCell" <<<"$notes"'
check "prototype cell: custom class + outlets" 'grep -q "_TtC16HelloStoryboards8NoteCell (0 [0-9]*; 402 x 64) id=note-1" <<<"$notes" && grep -q "text=Storyboards on Linux" <<<"$notes"'
check "prototype cell constraints (margins, image 24x24)" 'grep -q "UIImageView (20 20; 24 x 24)" <<<"$notes" && grep -q "UILabel (56 11; 304 x 21) text=Groceries" <<<"$notes"'
check "xib cell registered with UINib" 'grep -q "BadgeCell (0 [0-9]*; 402 x 56) id=badge-cell" <<<"$notes" && grep -q "UILabel (20 12; 180 x 32) id=badge-label text=Pinned from a xib" <<<"$notes"'
check "subtitle-style prototype (built-in labels)" 'grep -A3 "id=basic-cell" <<<"$notes" | grep -q "text=Subtitle style"'
check "tab bar items from the storyboard" 'grep -q "id=tab-Notes" <<<"$notes" && grep -q "id=tab-Controls" <<<"$notes"'
check "selection segue: shouldPerform + prepare(sender: cell)" 'grep -q "notes: shouldPerformSegue showNote" <<<"$notes" && grep -q "notes: prepare showNote -> NoteDetailViewController sender=NoteCell" <<<"$notes"'
check "show segue pushes; detail outlets" 'grep -q "detail: viewDidLoad Ideas" <<<"$notes" && grep -q "id=detail-title text=Ideas" <<<"$notes"'
check "embed segue (container view)" 'grep -q "detail: prepare embedInfo -> InfoViewController" <<<"$notes" && grep -q "info: viewDidLoad parent=NoteDetailViewController text=Embedded: Ideas" <<<"$notes" && grep -q "id=info-label text=Embedded: Ideas" <<<"$notes"'
check "performSegue(withIdentifier:) + storyboard ID" 'grep -q "detail: prepare showMore -> MoreViewController" <<<"$notes" && grep -q "more: viewDidLoad id-instantiable=true" <<<"$notes" && grep -q "id=more-label text=More about Ideas" <<<"$notes"'
check "unwind segue from a button (Done)" 'grep -q "notes: unwind doneUnwind from NoteDetailViewController" <<<"$notes"'
check "bar button segue presents (modal)" 'grep -q "notes: prepare compose -> UINavigationController sender=UIBarButtonItem" <<<"$notes" && grep -q "compose: viewDidLoad field=true placeholder=Title" <<<"$notes"'
check "unwind from a bar button (Save) with prepare" 'grep -q "compose: prepare saveUnwind -> NotesViewController" <<<"$notes" && grep -q "notes: saved \"Hello IB\" -> 3 notes" <<<"$notes" && grep -q "text=Hello IB" <<<"$notes"'
check "unwind (Cancel) + bar button action" 'grep -q "notes: unwind cancelUnwind from ComposeViewController" <<<"$notes" && grep -q "notes: reset -> 1" <<<"$notes"'
# --- controls
check "IB attributes reach the controls" 'grep -q "controls: viewDidLoad slider=0.5 \[0.0,1.0\] switch=true stepper=2.0/10.0 segment=1/3 progress=0.25 spinning=true labels=2" <<<"$controls"'
check "user defined runtime attributes; init(coder:) only" 'grep -q "corner=12.0 tag=teal-pill codedInit=true field=Your name" <<<"$controls"'
check "IB constraints: 1:2 width, priority, placeholder dropped" 'grep -q "(110.333 539; 181.333 x 40) id=rounded-view" <<<"$controls"'
check "actions: switch / stepper / segment / slider" 'grep -q "controls: switch false" <<<"$controls" && grep -q "controls: stepper 3" <<<"$controls" && grep -q "controls: segment 2" <<<"$controls" && grep -q "controls: slider" <<<"$controls"'
check "editingChanged action + button configuration" 'grep -q "controls: name Ana" <<<"$controls" && grep -q "controls: apply tapped (Apply)" <<<"$controls"'
check "gesture recognizer from the storyboard" 'grep -q "controls: rounded view tapped" <<<"$controls"'
check "init(nibName:bundle:) loads the xib" 'grep -q "profile: viewDidLoad nibName=ProfileViewController label=true button=Close" <<<"$controls" && grep -q "id=profile-name text=Profile (explicit nib)" <<<"$controls"'
check "default nib named after the class" 'grep -q "id=profile-name text=Profile (default nib)" <<<"$controls" && [ "$(grep -c "profile: close" <<<"$controls")" = 2 ]'
check "UIFontPickerViewController picks a family" 'grep -q "controls: font Georgia" <<<"$controls"'
check "apps exit cleanly" '[ $rc1 = 0 ] && [ $rc2 = 0 ] && [ $rc3 = 0 ]'

# --- Settings.bundle round trip (device shell: Settings app writes the app's domain, the app reads it)
if [ -x out/sdk/Applications/Settings.app/Settings ]; then
  export ISIM_DATA=$PWD/out/test-data/storyboards-settings; rm -rf "$ISIM_DATA"
  out/bin/isim install out/apps/HelloStoryboards.app >/dev/null
  settings=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_SHOT_SCALE=1 timeout 90 out/bin/isim boot --headless --script "wait 1; launch dev.isim.settings; wait 1.5; tapid settings-app-dev.isim.samples.HelloStoryboards; wait 1; shot $shots/settings-page.png; dump; tapid pref-enabled_preference; wait 0.4; tapid pref-name_preference; wait 0.3; key backspace; key backspace; key backspace; key backspace; key backspace; type Zoe; wait 0.3; key return; wait 0.3; tapid pref-theme_preference; wait 0.8; tapid pref-theme_preference-dark; wait 0.4; tapid isim-nav-back; wait 0.8; tapid pref-pane-Advanced; wait 0.8; tapid pref-advanced_preference; wait 0.4; dump; launch dev.isim.samples.HelloStoryboards; wait 2; quit" 2>&1); rc4=$?
  prefs=$ISIM_DATA/Containers/dev.isim.samples.HelloStoryboards/Library/Preferences/dev.isim.samples.HelloStoryboards.plist
  check "Settings: app page from Settings.bundle (localized)" 'grep -q "text=Display Name" <<<"$settings" && grep -q "text=Notifications" <<<"$settings" && grep -q "text=Automatic" <<<"$settings" && grep -q "text=1.0 (7)" <<<"$settings"'
  check "Settings: writes the app domain" '[ -f "$prefs" ] && grep -q "<string>dark</string>" "$prefs" && grep -q "<string>Zoe</string>" "$prefs"'
  check "Settings: child pane" 'grep -q "Settings: dev.isim.samples.HelloStoryboards advanced_preference = true" <<<"$settings"'
  check "app reads the Settings values" 'grep -q "settings(launch): name=Zoe enabled=false theme=dark volume=0.0 advanced=true" <<<"$settings"'
  check "shell exits cleanly" '[ $rc4 = 0 ]'
fi
[ $fail = 0 ] || { echo "--- logs"; echo "$classic$notes$controls${settings:-}" | grep -v "^ " | tail -60; }
exit $fail
