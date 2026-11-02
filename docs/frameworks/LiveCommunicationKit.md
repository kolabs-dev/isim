# LiveCommunicationKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (185 of 185, exact) · **Rows:** 8: 4 ✅ 4 🟡 · **iOS:** 17.4+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [LiveCommunicationKit](https://developer.apple.com/documentation/livecommunicationkit) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** adapted, on isim's CallKit engine (`isim/swift/overlays/LiveCommunicationKit`):
  - a `ConversationManager` owns a CallKit provider, so its conversations get the system call UI (the incoming banner and full
    screen, the ringtone, the in-call screen, the call indicator) and the audio session like CallKit calls;
  - the call screen's buttons (`call-accept`, `call-mute`, `call-hold`, `call-keypad`, `call-end`, … in SCRIPTING.md's call
    ids) arrive as conversation actions;
  - recents are kept per app in the device data (`Library/isim/Conversations/<bundle ID>.json`).
- **Objective-C / C interface:** Swift only, like Apple's.
- **Versus Apple's Simulator:** the Simulator shows no call UI for LiveCommunicationKit; isim does. There is no telephony
  (`TelephonyConversationManager` has no cellular services) and no live assistance extension runs.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `ConversationManager` (`init(configuration:)`, `Configuration`, `delegate`, `conversations`, `pendingActions`, `pendingConversationActions(of:for:)`, `reportNewIncomingConversation`, `reportConversationEvent`, `perform(_:)`, `invalidate()`), `ConversationManagerDelegate` | ✅ | 17.4 | adapted: on isim's CallKit engine; `perform` is checked like CallKit's requests (an unknown conversation, a duplicate, too many groups); the delegate performs the system's and the app's actions; an action not completed by its `timeoutDate` fails after `timedOutPerforming`; the audio session callbacks are CallKit's. Tested: test_conversations (HelloConversation) |
| `ConversationManager.reportNewIncomingVoIPPushPayload(_:)` | 🟡 | 17.4 | adapted: reports a conversation to the app's manager from the payload's `uuid`, `handle`, `displayName` and `isVideo` (proposed: Apple does not document the payload's keys) |
| `Conversation` (`uuid`, `state`, `localMember`, `State`, `Event`, `EndedReason`, `Update`, `Capabilities`), `Handle` (`Kind`) | ✅ | 17.4 | the members and capabilities become the call UI's caller and buttons (pausing: hold, playing tones: keypad, video). Tested: test_conversations |
| `ConversationAction` and `StartConversationAction`, `JoinConversationAction`, `EndConversationAction`, `MuteConversationAction`, `PauseConversationAction`, `MergeConversationAction`, `UnmergeConversationAction`, `PlayToneAction` (`fulfill`, `fail`, `state`) | ✅ | 17.4 | adapted: each is a CallKit action underneath; fulfilling it changes the conversation and the call UI. Tested: test_conversations |
| `SetTranslatingAction` (`fulfill(using:)`, `TranslationEngine`), `Configuration.supportsAudioTranslation` | 🟡 | 26.0 | adapted: given to the delegate (CallKit has no counterpart); no audio is translated |
| `ConversationHistoryManager` (`sharedInstance`, `recentConversations(matching:)`, `markConversationAsRead`, `markConversationsAsRead`, `RecentConversation`, `ConversationHistoryDidUpdate`) | ✅ | 26.0 | adapted: the app's ended conversations (unless the configuration excludes them from recents), read with a Foundation `Predicate`; missed incoming conversations are unread. Tested: test_conversations (iOS 26 and 27) |
| `TelephonyConversationManager`, `StartCellularConversationAction`, `CellularService` | 🟡 | 26.0 | stub: no cellular services; starting a cellular conversation throws (isim has no telephony, like the Simulator) |
| `LiveAssistance`, `LiveAssistanceExtension`, `LiveAssistanceRequest`, `LiveAssistanceLaunchReason`, `LiveAssistanceRequestError`, `LiveAssistanceExtensionConfiguration` | 🟡 | 26.0 | stub: Apple's types; the extensions are not run |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
