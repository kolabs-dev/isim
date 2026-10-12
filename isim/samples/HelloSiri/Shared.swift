// HelloSiri: code the app and its Intents extension share (both targets compile this file, like Xcode).
import Foundation
import Intents

let appGroup = "group.dev.isim.samples.hellosiri"
var shared: UserDefaults { UserDefaults(suiteName: appGroup)! }
func log(_ s: String) { NSLog("HelloSiri: %@", s) }

/// the club's members (what the app knows; Siri gives it the names people said)
struct Member { let name: String, handle: String }
let members = [Member(name: "Anna Haro", handle: "anna@coffee.club"), Member(name: "Anna Lee", handle: "lee@coffee.club"),
               Member(name: "Ben Ito", handle: "ben@coffee.club")]
func person(_ m: Member) -> INPerson {
    var n = PersonNameComponents()
    let parts = m.name.split(separator: " ")
    n.givenName = String(parts[0]); n.familyName = parts.count > 1 ? String(parts[1]) : nil
    return INPerson(personHandle: INPersonHandle(value: m.handle, type: .emailAddress), nameComponents: n, displayName: m.name,
                    image: nil, contactIdentifier: nil, customIdentifier: m.handle)
}
func membersMatching(_ p: INPerson) -> [Member] {
    let said = p.displayName.lowercased()
    if let exact = members.first(where: { $0.name.lowercased() == said || $0.handle == p.personHandle?.value }) { return [exact] }
    return members.filter { $0.name.lowercased().hasPrefix(said) || $0.name.lowercased().split(separator: " ").contains { String($0) == said } }
}

/// the messages sent through Siri (the app shows them)
var sentMessages: [String] {
    get { shared.array(forKey: "sent") as? [String] ?? [] }
    set { shared.set(newValue, forKey: "sent") }
}
var tasks: [String] {
    get { shared.array(forKey: "tasks") as? [String] ?? [] }
    set { shared.set(newValue, forKey: "tasks") }
}
