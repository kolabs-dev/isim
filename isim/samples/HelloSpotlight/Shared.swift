// HelloSpotlight's notes, shared by the app and its Spotlight index extension: each note becomes a CSSearchableItem
// with Apple's attributes (title, description, keywords, rating, authors, dates) and a custom attribute (mood).
import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

struct Note {
    let id, title, text: String
    let keywords: [String]
    let rating: Int
    let author: String
    let mood: String
    let daysAgo: Double
}

let notes = [
    Note(id: "note-coffee", title: "Coffee tasting", text: "Three beans from Kenya, Ethiopia and Colombia. The Kenyan one was the brightest. Buy more next week.",
         keywords: ["coffee", "tasting"], rating: 5, author: "Anna Haro", mood: "happy", daysAgo: 1),
    Note(id: "note-standup", title: "Standup notes", text: "Ship the release on Friday. Review the coffee machine budget.",
         keywords: ["work", "meeting"], rating: 3, author: "Ben Ito", mood: "busy", daysAgo: 3),
    Note(id: "note-trip", title: "Trip to Lisbon", text: "Flights booked. Visit the tram museum and the old town.",
         keywords: ["travel", "lisbon"], rating: 4, author: "Anna Haro", mood: "excited", daysAgo: 20),
]

let moodKey = CSCustomAttributeKey(keyName: "mood", searchable: true, searchableByDefault: true, unique: false, multiValued: false)!

func searchableItem(_ n: Note) -> CSSearchableItem {
    let a = CSSearchableItemAttributeSet(contentType: .text)
    a.title = n.title
    a.contentDescription = n.text
    a.textContent = n.text
    a.keywords = n.keywords
    a.rating = NSNumber(value: n.rating)
    a.authors = [CSPerson(displayName: n.author, handles: [n.author.lowercased().replacingOccurrences(of: " ", with: ".") + "@example.com"], handleIdentifier: "emailAddresses")]
    a.contentCreationDate = Date(timeIntervalSinceNow: -n.daysAgo * 86400)
    a.setValue(n.mood as NSString, forCustomKey: moodKey)
    let item = CSSearchableItem(uniqueIdentifier: n.id, domainIdentifier: "notes", attributeSet: a)
    if #available(iOS 18.0, *) { item.updateListenerOptions = [.summarization] }
    return item
}
