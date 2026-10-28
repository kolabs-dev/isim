# GroupActivities

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Games & 3D](../COVERAGE.md#games) · **Apple:** [GroupActivities](https://developer.apple.com/documentation/groupactivities) · **Issues:** [`area:games`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agames)

## How isim implements it

- **Approach:** adapted, a Swift overlay (`isim/swift/overlays/GroupActivities`) over isim's local SharePlay bus.
  - **The call:** real SharePlay runs in a FaceTime call through Apple's servers. On isim, a device joins a simulated
    call with the `shareplay join NAME` script command ([SCRIPTING.md](../SCRIPTING.md)) or `ISIM_SHAREPLAY_CALL=NAME`.
    The call is kept in the device data (`Library/SharePlay/call`), so every app on the device sees it.
  - **The bus:** the isim devices on this computer share one directory, `ISIM_SHAREPLAY` (default
    `~/.local/share/isim-shareplay`; [SYSTEM-PROMPTS.md](../SYSTEM-PROMPTS.md)). It holds the call's members (a
    heartbeat each second), the shared activities, who joined each session, each participant's message inbox and the
    session journals (layout in `Bus.swift`). Apps poll it 20 times a second. Nothing is sent to Apple.
  - **Participants:** each device is one participant, with an identifier kept in its device data.
  - **Playback:** `AVPlaybackCoordinator.coordinateWithSession(_:)` sends rate, time and item changes as session
    messages. AVFoundation's coordinators apply them (see [AVFoundation](AVFoundation.md)).
- **Objective-C / C interface:** none; Apple's GroupActivities is Swift only. The AVFoundation coordinator classes are
  Objective-C classes, declared in `AVFoundation.h`.
- **Versus Apple's Simulator:**
  - Apple's Simulator cannot start SharePlay (it has no FaceTime). isim connects its own devices to each other, never
    to real iPhones.
  - Unreliable messages are delivered like reliable ones; the bus loses nothing.
  - The system's SharePlay UI is not drawn: there is no SharePlay pill in the status bar, notices are logged rather
    than shown, and spatial Personas (visionOS) do not exist.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `GroupActivity` (`activityIdentifier`, `metadata`, `prepareForActivation()`, `activate()`, `sessions()`, `Sessions`, `transferRepresentation`), `GroupActivityActivationResult` | ✅ | ≤17 | adapted: `activate()` shares the activity in the call (false outside one). `prepareForActivation()` asks "Do you want to SharePlay “title”?" (SharePlay / Start Only for Me / Cancel), or answers from `ISIM_SHAREPLAY_ACTIVATION`; it returns `activationDisabled` outside a call. `sessions()` delivers the activity's sessions in every participant's app; tested (HelloSharePlay, test_shareplay) |
| `GroupActivityMetadata` (title, subtitle, localized title and subtitle, preview image, fallback URL, `ActivityType`, `SceneAssociationBehavior`, `supportsContinuationOnTV`, `BroadcastOptions`, `LifetimePolicy`, `Experience`) | ✅ | ≤17 | adapted: the title is used by the activation alert; `endsWhenInitiatorLeaves` ends the session when its initiator leaves; the other fields are kept |
| `GroupSession` (`id`, `activity` (set: shared with everyone), `state`, `activeParticipants`, `localParticipant`, `isLocallyInitiated`, `join()`, `leave()`, `end()`, `$activity` / `$state` / `$activeParticipants`, `Event`, `postEvent(_:)`, `showNotice(_:)`, `requestForegroundPresentation()`, `sceneSessionIdentifier`) | ✅ | ≤17 | adapted: participants are the joined devices that are still in the call; leaving the call invalidates its sessions; a session ends when everyone who joined has left. Events posted to the others, and notices, are logged; tested (HelloSharePlay, test_shareplay) |
| `Participant`, `Participants`, `GroupSessionEvent` (actions, queue changes) | ✅ | ≤17 | adapted: `isNearbyWithLocalParticipant` is always false |
| `GroupSessionMessenger` (`init(session:)`, `init(session:deliveryMode:)`, `send` (async and with a completion handler, `Data` or `Codable`, to all or some participants), `messages(of:)`, `MessageContext`, `DeliveryMode`), `CustomMessageIdentifiable` | ✅ | ≤17 | adapted: JSON messages in each recipient's inbox on the bus. A message for a type nobody iterates yet waits until someone does. Sending outside a joined session throws; tested (HelloSharePlay, test_shareplay: reliable and unreliable) |
| `GroupSessionJournal` (`add(_:)`, `add(_:metadata:)`, `remove(attachment:)`, `attachments`, `Attachment.load(_:)`, `loadMetadata(of:)`) | ✅ | ≤17 | adapted: the item's first exported Transferable representation, kept on the bus while the session lasts; tested (HelloSharePlay, test_shareplay) |
| `GroupStateObserver` (`isEligibleForGroupSession`) | ✅ | ≤17 | adapted: true while the device is in a simulated call; tested (HelloSharePlay, test_shareplay) |
| `GroupActivitySharingController` (`init(_:)`, `init(preparationHandler:)`, `result`), `GroupActivitySharingResult` | ✅ | ≤17 | adapted: a sheet with "Start SharePlay" and "Cancel". Start joins the call (`ISIM_SHAREPLAY_CALL`, else `isim`) and shares the activity; tested (HelloSharePlay, test_shareplay) |
| `GroupActivityTransferRepresentation` | ✅ | ≤17 | adapted: exports the activity as JSON (`com.apple.group-activity`); drops and shares do not start SharePlay; proposed |
| `AVPlaybackCoordinator.coordinateWithSession(_:)` | ✅ | ≤17 | adapted: keeps an `AVPlayerPlaybackCoordinator` or an `AVDelegatingPlaybackCoordinator` in step with the session's other participants; a participant who joins gets the current state; tested (HelloSharePlay, test_shareplay) |
| `SystemCoordinator` (configuration, participant states, immersion styles, roles), `SpatialTemplate`, `SpatialTemplatePreference`, `SpatialTemplateElement`, `SpatialTemplateSeatElement`, the element position, direction and axis, `SpatialTemplateRole`, `SpatialTemplateConfiguration`, `GroupActivityAssociationInteraction`, `GroupActivityAssociationKind` | 🟡 | 17.0 | stub: spatial coordination is visionOS's; an iOS session's `systemCoordinator` is nil and the types only hold their values |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
