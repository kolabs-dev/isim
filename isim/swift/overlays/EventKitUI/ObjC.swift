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
