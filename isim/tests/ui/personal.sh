#!/usr/bin/env bash
# UI test: personal data (HelloPersonal sample) — Contacts permission alert (iOS 18: Limit Access / Allow Full
# Access / Don't Allow) tapped, the seeded address book (the Simulator's sample contacts), name/phone predicates,
# save + partial-key update, the contact picker (tap a row -> delegate), the new-contact form saving into the
# address book; EventKit full-access alerts for calendar and reminders, saving an event and a reminder, event
# predicates, the EventKitUI New Event form; answers remembered after a relaunch; ISIM_CONTACTS_PERMISSION=deny;
# iOS 17's two-button contacts alert (ISIM_OS_VERSION=17.5).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloPersonal; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/personal; rm -rf "$ISIM_DATA"
run() { ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 60 out/bin/isim run out/apps/HelloPersonal.app 2>&1; }
log=$(run "wait 1; tapid contactsAccess; wait 0.8; shot $shots/contacts-permission.png; dump; taptext Allow Full Access; wait 0.8; tapid addContact; wait 0.5;
           tapid pickContact; wait 1; shot $shots/picker.png; dump; taptext John Appleseed; wait 1;
           tapid newContact; wait 1; tapid contact-field-givenName; wait 0.2; type Grace; tapid contact-field-familyName; wait 0.2; type Hopper; wait 0.2; tapid contact-done; wait 1;
           tapid calendarAccess; wait 0.8; dump; taptext Allow Full Access; wait 0.8; tapid addEvent; wait 0.5;
           tapid editEvent; wait 1; shot $shots/new-event.png; dump; tapid event-title; wait 0.2; type Dentist; wait 0.2; tapid event-add; wait 1;
           tapid reminders; wait 0.8; taptext Allow Full Access; wait 1; dump; quit"); rc=$?
log2=$(run "wait 1; tapid contactsAccess; wait 0.8; tapid calendarAccess; wait 0.8; quit"); rc2=$?
export ISIM_DATA=$PWD/out/test-data/personal-deny; rm -rf "$ISIM_DATA"
log3=$(ISIM_CONTACTS_PERMISSION=deny ISIM_CALENDAR_PERMISSION=deny run "wait 1; tapid contactsAccess; wait 0.8; tapid calendarAccess; wait 0.6; tapid addEvent; wait 0.5; quit")
export ISIM_DATA=$PWD/out/test-data/personal-ios17; rm -rf "$ISIM_DATA"
log4=$(ISIM_TEST_DEVICE=iphone15 ISIM_OS_VERSION=17.5 run "wait 1; tapid contactsAccess; wait 0.8; dump; taptext OK; wait 0.8; quit")
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "contacts alert (iOS 18 buttons, purpose)"        'grep -q "text=“Personal” Would Like to Access Your Contacts" <<<"$log" && grep -q "text=Limit Access…" <<<"$log" && grep -q "text=Finds friends to invite." <<<"$log"'
check "full access -> authorized"                       'grep -q "^contacts access true status 3 error 0" <<<"$log"'
check "seeded sample contacts, sorted by given name"    'grep -q "^contacts 6: Anna Haro, Daniel Higgins, David Taylor, Hank Zakroff, John Appleseed, Kate Bell" <<<"$log"'
check "name predicate + labels + fetched keys"          'grep -q "^kate phone (555) 564-8583 label mobile emailKeyAvailable false" <<<"$log"'
check "phone number predicate"                          'grep -q "^byPhone \[\"John\"\]" <<<"$log"'
check "save request: add + partial-key update"          'grep -q "^added \[\"Ada Lovelace\"\] city London" <<<"$log" && grep -q "^updated King phone kept (555) 010-1815" <<<"$log" && grep -q "^contacts 7:" <<<"$log"'
check "contact picker list -> didSelect"                'grep -q "text=Kate Bell" <<<"$log" && grep -q "^picked John Appleseed phones 2" <<<"$log" && grep -q "text=John Appleseed" <<<"$log"'
check "new-contact form saves to the address book"      'grep -q "^new contact Grace Hopper" <<<"$log" && grep -q "saved new contact Grace Hopper" <<<"$log"'
check "calendar full-access alert"                      'grep -q "text=“Personal” Would Like Full Access to Your Calendar" <<<"$log" && grep -q "^calendar access true status 3" <<<"$log"'
check "save event in the default calendar + predicate"  'grep -q "^saved event true in Calendar" <<<"$log" && grep -q "^calendars \[\"Calendar\"\] events \[\"Team lunch\"\]" <<<"$log"'
check "EKEventEditViewController saves"                 'grep -q "text=New Event" <<<"$log" && grep -q "^edit saved Dentist" <<<"$log" && grep -q "events \[\"Team lunch\", \"Dentist\"\]\|events \[\"Dentist\", \"Team lunch\"\]" <<<"$log"'
check "reminders access + save + fetch"                 'grep -q "^reminders access true" <<<"$log" && grep -q "^reminders \[\"Buy milk\"\] in Reminders" <<<"$log"'
check "answers remembered; data persists"               'grep -q "^contacts access true status 3" <<<"$log2" && grep -q "^contacts 8:" <<<"$log2" && grep -q "Grace Hopper" <<<"$log2" && grep -q "events \[" <<<"$log2" && ! grep -q "Would Like" <<<"$log2"'
check "ISIM_*_PERMISSION=deny"                           'grep -q "^contacts access false status 2 error 100" <<<"$log3" && grep -q "^contacts error 100" <<<"$log3" && grep -q "^calendar access false status 2" <<<"$log3" && grep -q "^save event error" <<<"$log3"'
check "iOS 17 contacts alert (Don’t Allow / OK)"        'grep -q "text=OK" <<<"$log4" && ! grep -q "text=Limit Access…" <<<"$log4" && grep -q "^contacts access true status 3" <<<"$log4"'
check "exits cleanly"                                    '[ $rc = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -50; for l in "$log2" "$log3" "$log4"; do echo "---"; echo "$l" | grep -v "^ " | tail -12; done; }
exit $fail
