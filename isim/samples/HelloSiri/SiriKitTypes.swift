// HelloSiri, SiriKit's shared types (issue #309): the app's vocabulary (INVocabulary: the members' names, the playlists'
// names with a pronunciation hint and an alternative speakable match), relevant shortcuts (INRelevantShortcut with date
// and daily-routine relevance providers and a card template; the Shortcuts app lists the ones relevant now), and
// INObjectCollection / INCurrencyAmount values.
import Foundation
import Intents

enum SiriKitTypes {
    static func vocabulary() {
        let v = INVocabulary.shared()
        v.setVocabularyStrings(NSOrderedSet(array: members.map(\.name)), of: .contactName)
        let brew = INObject(identifier: "morning-brew", display: "Morning Brew")
        brew.alternativeSpeakableMatches = [INSpeakableString(spokenPhrase: "breakfast")]
        let noir = INSpeakableString(vocabularyIdentifier: "cafe-noir", spokenPhrase: "Café Noir", pronunciationHint: "ka-fay nwahr")
        v.setVocabulary(NSOrderedSet(array: [noir, brew]), of: .mediaPlaylistTitle)
    }
    static func relevantShortcuts() {
        let play = INPlayMediaIntent(mediaItems: nil, mediaContainer: nil, playShuffled: nil, playbackRepeatMode: .unknown, resumePlayback: nil,
                                     playbackQueueLocation: .now, playbackSpeed: nil,
                                     mediaSearch: INMediaSearch(mediaType: .playlist, sortOrder: .unknown, mediaName: "Morning Jazz", artistName: nil,
                                                                albumName: nil, genreNames: nil, moodNames: nil, releaseDate: nil, reference: .unknown,
                                                                mediaIdentifier: nil))
        let morning = INRelevantShortcut(shortcut: INShortcut(intent: play)!)
        morning.relevanceProviders = [INDateRelevanceProvider(start: Date().addingTimeInterval(-60), end: Date().addingTimeInterval(3600)),
                                      INDailyRoutineRelevanceProvider(situation: .morning)]
        let card = INDefaultCardTemplate(title: "Morning Jazz")
        card.subtitle = "Start the day"
        morning.watchTemplate = card
        morning.shortcutRole = .action
        let last = INRelevantShortcut(shortcut: INShortcut(intent: play)!)        // last night: not relevant any more
        last.relevanceProviders = [INDateRelevanceProvider(start: Date().addingTimeInterval(-86400), end: Date().addingTimeInterval(-43200))]
        last.watchTemplate = INDefaultCardTemplate(title: "Last Night’s Jazz")
        last.shortcutRole = .information
        INRelevantShortcutStore.default.setRelevantShortcuts([morning, last]) { error in
            log("relevant shortcuts \(error == nil ? "set" : "failed"): \(morning.relevanceProviders.count) provider(s), role \(morning.shortcutRole.rawValue)")
        }
    }
    static func values() {
        let tip = INCurrencyAmount(amount: NSDecimalNumber(string: "4.50"), currencyCode: "EUR")
        var back: INCurrencyAmount?
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: tip, requiringSecureCoding: true)
            back = try NSKeyedUnarchiver.unarchivedObject(ofClass: INCurrencyAmount.self, from: data)
        } catch { log("archiving failed: \(error)") }
        let menu = INObjectCollection(sections: [
            INObjectSection(title: "Hot", items: [INObject(identifier: "latte", display: "Latte"), INObject(identifier: "flat-white", display: "Flat White", subtitle: "Double shot", image: nil)]),
            INObjectSection(title: "Cold", items: [INObject(identifier: "cold-brew", display: "Cold Brew")])])
        menu.usesIndexedCollation = false
        let flat = INObjectCollection(items: [INObject(identifier: "espresso", display: "Espresso")])
        log("shared types: tip \(back?.amount?.stringValue ?? "?") \(back?.currencyCode ?? "?") equal \(back == tip), " +
            "menu \(menu.sections.count) section(s): \(menu.allItems.map(\.displayString).joined(separator: ", ")), flat \(flat.sections.count) section, " +
            "\(menu.allItems[1].subtitleString ?? "-")")
    }
}
