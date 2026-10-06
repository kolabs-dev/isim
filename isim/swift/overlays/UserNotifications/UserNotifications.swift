// isim UserNotifications Swift overlay: DateComponents for calendar triggers (isim's Objective-C framework
// keeps the components as a dictionary because isim's Foundation has no NSDateComponents).
@_exported import UserNotifications
import Foundation

extension UNCalendarNotificationTrigger {
    public convenience init(dateMatching dateComponents: DateComponents, repeats: Bool) {
        var v: [String: NSNumber] = [:]
        if let x = dateComponents.era { v["era"] = NSNumber(value: x) }
        if let x = dateComponents.year { v["year"] = NSNumber(value: x) }
        if let x = dateComponents.month { v["month"] = NSNumber(value: x) }
        if let x = dateComponents.day { v["day"] = NSNumber(value: x) }
        if let x = dateComponents.hour { v["hour"] = NSNumber(value: x) }
        if let x = dateComponents.minute { v["minute"] = NSNumber(value: x) }
        if let x = dateComponents.second { v["second"] = NSNumber(value: x) }
        if let x = dateComponents.weekday { v["weekday"] = NSNumber(value: x) }
        self.init(__componentValues: v, repeats: repeats)
    }
    public var dateComponents: DateComponents {
        let v = __componentValues
        var c = DateComponents()
        c.era = v["era"]?.integerValue; c.year = v["year"]?.integerValue; c.month = v["month"]?.integerValue; c.day = v["day"]?.integerValue
        c.hour = v["hour"]?.integerValue; c.minute = v["minute"]?.integerValue; c.second = v["second"]?.integerValue; c.weekday = v["weekday"]?.integerValue
        return c
    }
}
