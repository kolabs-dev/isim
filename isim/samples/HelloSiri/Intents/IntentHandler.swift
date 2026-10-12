// HelloSiri's Intents extension: messages to club members (resolution with disambiguation, confirmation), message
// search, calls (continued in the app), the shopping list and music (played by the app: .handleInApp).
import Intents

class IntentHandler: INExtension, INSendMessageIntentHandling, INSearchForMessagesIntentHandling, INStartCallIntentHandling,
                     INAddTasksIntentHandling, INPlayMediaIntentHandling {
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
        sentMessages.append("\(to): \(intent.content ?? "")")
        log("extension: sent “\(intent.content ?? "")” to \(to)")
        completion(INSendMessageIntentResponse(code: .success, userActivity: nil))
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
}
