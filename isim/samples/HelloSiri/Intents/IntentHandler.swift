// HelloSiri's Intents extension: messages to club members (resolution with disambiguation, confirmation), message
// search, editing and unsending a sent message, calls (continued in the app), the shopping list, music (played by the
// app: .handleInApp), adding music to a playlist and searching for it. Payments, the club car, workouts and photos:
// Domains.swift.
import Intents

class IntentHandler: INExtension, INSendMessageIntentHandling, INSearchForMessagesIntentHandling, INStartCallIntentHandling,
                     INAddTasksIntentHandling, INPlayMediaIntentHandling, INEditMessageIntentHandling, INUnsendMessagesIntentHandling,
                     INAddMediaIntentHandling, INSearchForMediaIntentHandling {
    override func handler(for intent: INIntent) -> Any {
        log("extension: handler for \(type(of: intent))")
        return self
    }

    // MARK: messages
    func resolveRecipients(for intent: INSendMessageIntent, with completion: @escaping ([INSendMessageRecipientResolutionResult]) -> Void) {
        guard let recipients = intent.recipients, !recipients.isEmpty else { completion([.needsValue()]); return }
        completion(recipients.map { r -> INSendMessageRecipientResolutionResult in
            let found = membersMatching(r)
            log("extension: recipient \(r.displayName): \(found.count) member(s)")
            if found.count == 1 { return .success(with: person(found[0])) }
            if found.count > 1 { return .disambiguation(with: found.map(person)) }
            return .unsupported(forReason: .noAccount)
        })
    }
    func resolveContent(for intent: INSendMessageIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let text = intent.content, !text.isEmpty { completion(.success(with: text)) } else { completion(.needsValue()) }
    }
    func confirm(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        completion(INSendMessageIntentResponse(code: .ready, userActivity: nil))
    }
    func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        let to = (intent.recipients ?? []).map { $0.displayName }.joined(separator: ", ")
        let id = "msg-\(sentIDs.count + 1)"
        sentMessages.append("\(to): \(intent.content ?? "")")
        sentIDs.append(id)
        log("extension: sent “\(intent.content ?? "")” to \(to)")
        let r = INSendMessageIntentResponse(code: .success, userActivity: nil)
        r.sentMessage = INMessage(identifier: id, content: intent.content, dateSent: Date(), sender: nil, recipients: intent.recipients)
        completion(r)
    }

    // MARK: editing and unsending (Siri names the last message it sent)
    func resolveEditedContent(for intent: INEditMessageIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let text = intent.editedContent, !text.isEmpty { completion(.success(with: text)) } else { completion(.needsValue()) }
    }
    func handle(intent: INEditMessageIntent, completion: @escaping (INEditMessageIntentResponse) -> Void) {
        guard let id = intent.messageIdentifier, let i = sentIDs.firstIndex(of: id), i < sentMessages.count else {
            log("extension: no message \(intent.messageIdentifier ?? "-") to edit")
            completion(INEditMessageIntentResponse(code: .failureMessageNotFound, userActivity: nil)); return
        }
        let to = sentMessages[i].components(separatedBy: ": ").first ?? ""
        sentMessages[i] = "\(to): \(intent.editedContent ?? "")"
        log("extension: edited \(id) to “\(intent.editedContent ?? "")”")
        completion(INEditMessageIntentResponse(code: .success, userActivity: nil))
    }
    func handle(intent: INUnsendMessagesIntent, completion: @escaping (INUnsendMessagesIntentResponse) -> Void) {
        let found = (intent.messageIdentifiers ?? []).filter { sentIDs.contains($0) }
        guard !found.isEmpty else {
            log("extension: no message \((intent.messageIdentifiers ?? []).joined(separator: ", ")) to unsend")
            completion(INUnsendMessagesIntentResponse(code: .failureMessageNotFound, userActivity: nil)); return
        }
        for id in found {
            if let i = sentIDs.firstIndex(of: id) { sentIDs.remove(at: i); if i < sentMessages.count { sentMessages.remove(at: i) } }
        }
        log("extension: unsent \(found.joined(separator: ", "))")
        completion(INUnsendMessagesIntentResponse(code: .success, userActivity: nil))
    }

    // MARK: message search (async form)
    func handle(intent: INSearchForMessagesIntent) async -> INSearchForMessagesIntentResponse {
        let from = intent.senders?.first.flatMap { membersMatching($0).first }
        let r = INSearchForMessagesIntentResponse(code: .success, userActivity: nil)
        r.messages = [INMessage(identifier: "m1", content: "See you at the bar at 9", dateSent: Date(), sender: person(from ?? members[2]), recipients: nil),
                      INMessage(identifier: "m2", content: "Oat milk is back", dateSent: Date(), sender: person(from ?? members[0]), recipients: nil)]
        log("extension: found \(r.messages?.count ?? 0) message(s)")
        return r
    }

    // MARK: calls
    func resolveContacts(for intent: INStartCallIntent, with completion: @escaping ([INStartCallContactResolutionResult]) -> Void) {
        guard let c = intent.contacts, !c.isEmpty else { completion([.needsValue()]); return }
        completion(c.map { p -> INStartCallContactResolutionResult in
            let found = membersMatching(p)
            return found.count == 1 ? .success(with: person(found[0])) : found.isEmpty ? .unsupported(forReason: .noContactFound) : .disambiguation(with: found.map(person))
        })
    }
    func handle(intent: INStartCallIntent, completion: @escaping (INStartCallIntentResponse) -> Void) {
        log("extension: call \(intent.contacts?.first?.displayName ?? "?") continues in the app")
        completion(INStartCallIntentResponse(code: .continueInApp, userActivity: nil))
    }

    // MARK: the shopping list
    func resolveTaskTitles(for intent: INAddTasksIntent, with completion: @escaping ([INSpeakableStringResolutionResult]) -> Void) {
        guard let t = intent.taskTitles, !t.isEmpty else { completion([.needsValue()]); return }
        completion(t.map { INSpeakableStringResolutionResult.success(with: $0) })
    }
    func handle(intent: INAddTasksIntent, completion: @escaping (INAddTasksIntentResponse) -> Void) {
        let titles = (intent.taskTitles ?? []).map { $0.spokenPhrase }
        tasks.append(contentsOf: titles)
        let list = INTaskList(title: INSpeakableString(spokenPhrase: intent.targetTaskList?.title.spokenPhrase ?? "Shopping"),
                              tasks: titles.map { INTask(title: INSpeakableString(spokenPhrase: $0), status: .notCompleted, taskType: .completable,
                                                         spatialEventTrigger: nil, temporalEventTrigger: nil, createdDateComponents: nil,
                                                         modifiedDateComponents: nil, identifier: nil) },
                              groupName: nil, createdDateComponents: nil, modifiedDateComponents: nil, identifier: "shopping")
        let r = INAddTasksIntentResponse(code: .success, userActivity: nil)
        r.modifiedTaskList = list; r.addedTasks = list.tasks
        log("extension: added \(titles.joined(separator: ", "))")
        completion(r)
    }

    // MARK: music: the app plays it
    func resolveMediaItems(for intent: INPlayMediaIntent, with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void) {
        guard let name = intent.mediaSearch?.mediaName else { completion([INPlayMediaMediaItemResolutionResult.needsValue()]); return }
        completion(INPlayMediaMediaItemResolutionResult.successes(with: [INMediaItem(identifier: "playlist-1", title: "\(name) Mix", type: .playlist, artwork: nil)]))
    }
    func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        completion(INPlayMediaIntentResponse(code: .handleInApp, userActivity: nil))
    }

    // MARK: adding music to the library or a playlist
    func resolveMediaItems(for intent: INAddMediaIntent, with completion: @escaping ([INAddMediaMediaItemResolutionResult]) -> Void) {
        if intent.mediaSearch?.reference == .currentlyPlaying {
            completion(INAddMediaMediaItemResolutionResult.successes(with: [INMediaItem(identifier: "now", title: nowPlaying, type: .song, artwork: nil)])); return
        }
        guard let name = intent.mediaSearch?.mediaName else { completion([INAddMediaMediaItemResolutionResult.needsValue()]); return }
        completion(INAddMediaMediaItemResolutionResult.successes(with: [INMediaItem(identifier: "mix-\(name)", title: "\(name) Mix", type: .playlist, artwork: nil)]))
    }
    func resolveMediaDestination(for intent: INAddMediaIntent, with completion: @escaping (INAddMediaMediaDestinationResolutionResult) -> Void) {
        switch intent.mediaDestination {
        case .none, .library?:
            completion(.success(with: .library))
        case .playlist(let name)?:
            log("extension: playlist “\(name)”")
            completion(playlists.contains(name) ? .success(with: .playlist(name)) : .unsupported(forReason: .playlistNameNotFound))
        @unknown default:
            completion(.unsupported(forReason: .playlistNotEditable))
        }
    }
    func handle(intent: INAddMediaIntent, completion: @escaping (INAddMediaIntentResponse) -> Void) {
        let item = intent.mediaItems?.first?.title ?? "?", to = intent.mediaDestination?.playlistName ?? "Library"
        playlistLog.append("\(to): \(item)")
        log("extension: added \(item) to \(to)")
        completion(INAddMediaIntentResponse(code: .success, userActivity: nil))
    }

    // MARK: searching the club's music
    func resolveMediaItems(for intent: INSearchForMediaIntent, with completion: @escaping ([INSearchForMediaMediaItemResolutionResult]) -> Void) {
        guard let name = intent.mediaSearch?.mediaName else { completion([INSearchForMediaMediaItemResolutionResult.needsValue()]); return }
        completion(INSearchForMediaMediaItemResolutionResult.successes(with: catalog.filter { $0.title?.localizedCaseInsensitiveContains(name) ?? false }))
    }
    func handle(intent: INSearchForMediaIntent, completion: @escaping (INSearchForMediaIntentResponse) -> Void) {
        let r = INSearchForMediaIntentResponse(code: .success, userActivity: nil)
        r.mediaItems = intent.mediaItems
        log("extension: found \(r.mediaItems?.count ?? 0) media item(s)")
        completion(r)
    }
}
