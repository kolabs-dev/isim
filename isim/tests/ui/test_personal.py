"""Personal data (HelloPersonal): the Contacts permission alert (iOS 18 buttons) tapped, the seeded address book,
name/phone predicates, save + partial-key update, the contact picker, the new-contact form; EventKit full-access
alerts for calendar and reminders, saving an event and a reminder, event predicates, the EventKitUI New Event form;
answers remembered after a relaunch; ISIM_*_PERMISSION=deny; iOS 17's two-button contacts alert.
Port of tests/ui/personal.sh."""
import re

import pytest


def test_personal(launch):
    app = launch("HelloPersonal")
    app.wait_tap_id("contactsAccess")
    alert = app.wait_view(r"text=Allow Full Access")
    app.screenshot("contacts-permission")
    app.tap_text("Allow Full Access")
    app.wait_log(r"^contacts access ")
    app.wait_log(r"^byPhone ")
    app.wait_tap_id("addContact")
    app.wait_log(r"^updated ")
    app.tap_id("pickContact")
    picker = app.wait_view(r"text=John Appleseed")
    app.wait_still()
    app.screenshot("picker")
    app.tap_text("John Appleseed")
    app.wait_log(r"^picked ")
    app.wait_tap_id("newContact")
    app.wait_tap_id("contact-field-givenName")
    app.type("Grace")
    app.tap_id("contact-field-familyName")
    app.type("Hopper")
    app.tap_id("contact-done")
    app.wait_log(r"^new contact ")
    app.wait_tap_id("calendarAccess")
    calendar_alert = app.wait_view(r"text=Allow Full Access")
    app.tap_text("Allow Full Access")
    app.wait_log(r"^calendar access ")
    app.wait_tap_id("addEvent")
    app.wait_log(r"^calendars ")
    app.wait_log(r"^event metadata alarms -300\.0 recurrence 1/2")
    app.wait_log(r"^event removed true")
    app.wait_log(r"^event store changed")
    app.tap_id("editEvent")
    new_event = app.wait_view(r"id=event-title")
    app.wait_still()
    app.screenshot("new-event")
    app.tap_id("event-title")
    app.type("Dentist")
    app.tap_id("event-add")
    app.wait_log(r"^edit ")
    app.wait_log(r"^calendars ", count=2)
    app.wait_tap_id("reminders")
    app.wait_view(r"text=Allow Full Access")
    app.tap_text("Allow Full Access")
    app.wait_log(r"^reminders \[")
    final = app.view_dump()
    assert app.quit() == 0, "exits cleanly"
    log = app.log + "\n" + "\n".join((alert, picker, calendar_alert, new_event, final))

    def has(p):
        return re.search(p, log, re.M)
    assert "text=“Personal” Would Like to Access Your Contacts" in alert and "text=Limit Access…" in alert and \
        "text=Finds friends to invite." in alert, "contacts alert (iOS 18 buttons, purpose)"
    assert has(r"^contacts access true status 3 error 0"), "full access -> authorized"
    assert has(r"^contacts 6: Anna Haro, Daniel Higgins, David Taylor, Hank Zakroff, John Appleseed, Kate Bell"), \
        "seeded sample contacts, sorted by given name"
    assert has(r"^kate phone \(555\) 564-8583 label mobile emailKeyAvailable false"), "name predicate + labels + fetched keys"
    assert has(r'^byPhone \["John"\]'), "phone number predicate"
    assert has(r'^added \["Ada Lovelace"\] city London') and has(r"^updated King phone kept \(555\) 010-1815") and \
        has(r"^contacts 7:"), "save request: add + partial-key update"
    assert "text=Kate Bell" in picker and has(r"^picked John Appleseed phones 2") and "text=John Appleseed" in log, \
        "contact picker list -> didSelect"
    assert has(r"^new contact Grace Hopper") and has(r"saved new contact Grace Hopper"), \
        "new-contact form saves to the address book"
    assert "text=“Personal” Would Like Full Access to Your Calendar" in calendar_alert and \
        has(r"^calendar access true status 3"), "calendar full-access alert"
    assert has(r"^saved event true in Calendar") and has(r'^calendars \["Calendar"\] events \["Team lunch"\]'), \
        "save event in the default calendar + predicate"
    assert "text=New Event" in new_event and has(r"^edit saved Dentist location - allDay false") and \
        has(r'events \["Team lunch", "Dentist"\]|events \["Dentist", "Team lunch"\]'), "EKEventEditViewController saves"
    assert has(r"^reminders access true") and has(r'^reminders \["Buy milk"\] in Reminders'), \
        "reminders access + save + fetch"
    assert has(r'^completed reminders \["Buy milk"\]') and has(r"^reminders after remove 0"), \
        "completion-date predicate + reminder removal"

    app = launch("HelloPersonal")                                     # answers remembered; data persists
    app.wait_tap_id("contactsAccess")
    app.wait_log(r"^contacts 8:")
    app.wait_tap_id("calendarAccess")
    app.wait_log(r"events \[")
    assert app.quit() == 0, "exits cleanly"
    log2 = app.log
    assert re.search(r"^contacts access true status 3", log2, re.M) and "Grace Hopper" in log2 and \
        "Would Like" not in log2, "answers remembered; data persists"


def test_personal_denied(launch):
    app = launch("HelloPersonal", env={"ISIM_CONTACTS_PERMISSION": "deny", "ISIM_CALENDAR_PERMISSION": "deny"})
    app.wait_tap_id("contactsAccess")
    app.wait_log(r"^contacts error ")
    app.tap_id("calendarAccess")
    app.wait_log(r"^calendar access ")
    app.tap_id("addEvent")
    app.wait_log(r"^save event ")
    app.quit()
    log = app.log
    assert re.search(r"^contacts access false status 2 error 100", log, re.M) and \
        re.search(r"^contacts error 100", log, re.M) and re.search(r"^calendar access false status 2", log, re.M) and \
        re.search(r"^save event error", log, re.M), "ISIM_*_PERMISSION=deny"


@pytest.mark.os_matrix
def test_eventkit_write_only_and_editor_without_access(launch):
    app = launch("HelloPersonal", env={"ISIM_CALENDAR_PERMISSION": "writeonly"})
    app.wait_tap_id("calendarWriteOnly")
    app.wait_log(r"^calendar write-only true status 4 read 0 saved true")
    assert app.quit() == 0

    app = launch("HelloPersonal", env={"ISIM_CALENDAR_PERMISSION": "allow"})
    app.wait_tap_id("editEvent")
    form = app.wait_view(r"id=event-title")
    app.tap_id("event-title")
    app.type("Private appointment")
    app.tap_id("event-location")
    app.type("Clinic")
    app.tap_id("event-allday")
    app.tap_id("event-add")
    app.wait_log(r"^edit saved Private appointment location Clinic allDay true")
    app.wait_tap_id("calendarAccess")
    app.wait_log(r'events \["Write-only event", "Private appointment"\]|events \["Private appointment", "Write-only event"\]')
    assert "id=event-starts" in form and "id=event-ends" in form, "editor shows its non-editable dates"
    assert app.quit() == 0


def test_personal_ios17(launch):
    app = launch("HelloPersonal", device="iphone15", os_version="17.5")
    app.wait_tap_id("contactsAccess")
    alert = app.wait_view(r"text=OK")
    app.tap_text("OK")
    app.wait_log(r"^contacts access ")
    app.quit()
    assert "text=Limit Access…" not in alert and re.search(r"^contacts access true status 3", app.log, re.M), \
        "iOS 17 contacts alert (Don’t Allow / OK)"


def seed_invitation(device_data):
    """An invitation in the device calendar: apps cannot add attendees, they come from the calendar (an account)."""
    import json
    import time
    d = device_data / "Library" / "Calendar"
    d.mkdir(parents=True, exist_ok=True)
    start = time.time() + 86400
    person = lambda name, mail, status, role, kind, me=False: {"name": name, "url": "mailto:" + mail, "status": status, "role": role, "type": kind, "me": me}
    (d / "calendar.json").write_text(json.dumps({
        "calendars": [
            {"id": "isim-calendar-default", "title": "Calendar", "type": 0, "color": [0.94, 0.22, 0.22], "readOnly": False},
            {"id": "isim-calendar-work", "title": "Work", "type": 0, "color": [0.2, 0.6, 0.9], "readOnly": False},
            {"id": "isim-reminders-default", "title": "Reminders", "type": 1, "color": [0.0, 0.48, 1.0], "readOnly": False},
        ],
        "items": [{
            "id": "isim-invitation-1", "kind": 0, "calendar": "isim-calendar-work", "title": "Design review", "start": start,
            "end": start + 3600, "allDay": False, "completed": False, "priority": 0, "alarms": [], "availability": 0,
            "created": start - 86400, "modified": start - 86400, "app": "com.apple.mobilecal", "status": 1,
            "attendees": [person("Ada Lovelace", "ada@example.com", 2, 1, 1), person("Conference Room B", "room-b@example.com", 2, 4, 2),
                          person("Kevin", "kevin@example.com", 1, 2, 1, True)],
            "organizer": person("Grace Hopper", "grace@example.com", 2, 3, 1),
        }],
    }))


@pytest.mark.os_matrix
def test_eventkit_recurrence_alarms_attendees(launch, device_data):
    """Recurring events expanded in date-range queries (weekly on three days with a count, the second Tuesday of the
    month, the last day of the month), one occurrence detached (.thisEvent), one removed, the rest of the series removed
    (.futureEvents); a structured location and location / email alarms stored; attendees and the organizer of a seeded
    invitation; an alarm firing as Calendar's alert banner; EKCalendarChooser (multiple selection, Done)."""
    seed_invitation(device_data)
    app = launch("HelloPersonal", env={"ISIM_CALENDAR_PERMISSION": "allow"})
    app.wait_tap_id("calendarAccess")
    app.wait_log(r"^calendar access true status 3")
    app.tap_id("recurring")
    app.wait_log(r"^recurring 6 Mon,Wed,Fri,Mon,Wed,Fri one id true rule MO,WE,FR")
    app.wait_log(r"^monthly 3 second tuesdays true")
    app.wait_log(r"^month ends 2 last days true")
    app.wait_log(r'^detached \["Standup \(moved\)"\] count 6 series 5')
    app.wait_log(r"^after removing one 5 Mon,Wed,Mon,Wed,Fri")
    app.wait_log(r"^after removing future 3 Mon,Wed,Mon")
    app.wait_log(r"^location Apple Park 37\.3349,-122\.0090 radius 150 text Apple Park alarms 1/0,0/3")
    app.wait_log(r"^attendees Design review Ada Lovelace 2/1/1, Conference Room B 2/4/2, Kevin 1/2/1 organizer Grace Hopper mailto:grace@example\.com")
    app.wait_log(r"^alarm set")
    app.wait_log(r"isim EventKit: alarm “Coffee” event")
    app.wait_view(r"id=isim-calendar-alarm")
    banner = app.wait_view(r"text=Coffee")
    app.wait_still()
    app.screenshot("calendar-alarm")
    assert "Caffè Macs" in banner
    app.wait_view(r"id=isim-calendar-alarm", gone=True, timeout=15)
    app.tap_id("chooseCalendars")
    chooser = app.wait_view(r"id=calendar-Work")
    app.wait_still()
    app.screenshot("calendar-chooser")
    assert "text=Calendars" in chooser and "id=calendar-Calendar" in chooser and "Reminders" not in chooser.split("id=calendar-chooser")[1]
    app.tap_id("calendar-Work")
    app.wait_log(r'^chooser selected \["Work"\]')
    app.tap_id("calendar-Calendar")
    app.wait_log(r'^chooser selected \["Calendar", "Work"\]')
    app.tap_id("calendar-chooser-done")
    app.wait_log(r'^chooser finished \["Calendar", "Work"\]')
