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
/// their identifiers (INSendMessageIntentResponse.sentMessage; Siri edits and unsends messages by identifier)
var sentIDs: [String] {
    get { shared.array(forKey: "sentIDs") as? [String] ?? [] }
    set { shared.set(newValue, forKey: "sentIDs") }
}
/// the club's playlists (Siri adds music to them; the app's vocabulary spells their names) and what was added
let playlists = ["Café Noir", "Morning Brew"]
var playlistLog: [String] {
    get { shared.array(forKey: "playlistLog") as? [String] ?? [] }
    set { shared.set(newValue, forKey: "playlistLog") }
}
/// what the app plays (Siri's "this song")
var nowPlaying: String {
    get { shared.string(forKey: "nowPlaying") ?? "House Blend Radio" }
    set { shared.set(newValue, forKey: "nowPlaying") }
}
/// the club's music, for Siri's media search
let catalog = [INMediaItem(identifier: "morning-jazz", title: "Morning Jazz Mix", type: .playlist, artwork: nil, artist: "Coffee Club DJs"),
               INMediaItem(identifier: "brew-podcast", title: "Morning Brew Podcast", type: .podcastShow, artwork: nil, artist: "Ben Ito"),
               INMediaItem(identifier: "evening-jazz", title: "Evening Jazz", type: .playlist, artwork: nil, artist: "Anna Lee")]
var tasks: [String] {
    get { shared.array(forKey: "tasks") as? [String] ?? [] }
    set { shared.set(newValue, forKey: "tasks") }
}
