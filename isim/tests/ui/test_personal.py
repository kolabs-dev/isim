"""Personal data (HelloPersonal): the Contacts permission alert (iOS 18 buttons) tapped, the seeded address book,
name/phone predicates, save + partial-key update, the contact picker, the new-contact form; EventKit full-access
alerts for calendar and reminders, saving an event and a reminder, event predicates, the EventKitUI New Event form;
answers remembered after a relaunch; ISIM_*_PERMISSION=deny; iOS 17's two-button contacts alert.
Port of tests/ui/personal.sh."""
import re


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
    assert "text=New Event" in new_event and has(r"^edit saved Dentist") and \
        has(r'events \["Team lunch", "Dentist"\]|events \["Dentist", "Team lunch"\]'), "EKEventEditViewController saves"
    assert has(r"^reminders access true") and has(r'^reminders \["Buy milk"\] in Reminders'), \
        "reminders access + save + fetch"

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


def test_personal_ios17(launch):
    app = launch("HelloPersonal", device="iphone15", os_version="17.5")
    app.wait_tap_id("contactsAccess")
    alert = app.wait_view(r"text=OK")
    app.tap_text("OK")
    app.wait_log(r"^contacts access ")
    app.quit()
    assert "text=Limit Access…" not in alert and re.search(r"^contacts access true status 3", app.log, re.M), \
        "iOS 17 contacts alert (Don’t Allow / OK)"
