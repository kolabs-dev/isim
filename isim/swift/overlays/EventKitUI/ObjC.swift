// isim EventKitUI for Objective-C (sdk-src/Frameworks/EventKitUI): the classes carry Apple's Objective-C names and these
// members Apple's selectors. The delegate protocols are @objc with Apple's selectors.
import UIKit
import EventKit

extension EKEventEditViewController {
    @objc(editViewDelegate) var _objc_editViewDelegate: EKEventEditViewDelegate? { get { editViewDelegate } set { editViewDelegate = newValue } }
    @objc(eventStore) var _objc_eventStore: EKEventStore? { get { eventStore } set { eventStore = newValue } }
    @objc(event) var _objc_event: EKEvent? { get { event } set { event = newValue } }
    @objc(cancelEditing) func _objc_cancelEditing() { cancelEditing() }
}

extension EKEventViewController {
    @objc(delegate) var _objc_delegate: EKEventViewDelegate? { get { delegate } set { delegate = newValue } }
    @objc(event) var _objc_event: EKEvent? { get { event } set { event = newValue } }
    @objc(allowsEditing) var _objc_allowsEditing: Bool { get { allowsEditing } set { allowsEditing = newValue } }
    @objc(allowsCalendarPreview) var _objc_allowsCalendarPreview: Bool { get { allowsCalendarPreview } set { allowsCalendarPreview = newValue } }
}

extension EKCalendarChooser {
    @objc(initWithSelectionStyle:displayStyle:eventStore:)
    convenience init(_objcSelection s: EKCalendarChooserSelectionStyle, displayStyle: EKCalendarChooserDisplayStyle, eventStore: EKEventStore) {
        self.init(selectionStyle: s, displayStyle: displayStyle, eventStore: eventStore)
    }
    @objc(initWithSelectionStyle:displayStyle:entityType:eventStore:)
    convenience init(_objcSelection s: EKCalendarChooserSelectionStyle, displayStyle: EKCalendarChooserDisplayStyle, entityType: EKEntityType, eventStore: EKEventStore) {
        self.init(selectionStyle: s, displayStyle: displayStyle, entityType: entityType, eventStore: eventStore)
    }
    @objc(selectionStyle) var _objc_selectionStyle: EKCalendarChooserSelectionStyle { selectionStyle }
    @objc(delegate) var _objc_delegate: EKCalendarChooserDelegate? { get { delegate } set { delegate = newValue } }
    @objc(showsDoneButton) var _objc_showsDoneButton: Bool { get { showsDoneButton } set { showsDoneButton = newValue } }
    @objc(showsCancelButton) var _objc_showsCancelButton: Bool { get { showsCancelButton } set { showsCancelButton = newValue } }
    @objc(selectedCalendars) var _objc_selectedCalendars: Set<EKCalendar> { get { selectedCalendars } set { selectedCalendars = newValue } }
}
