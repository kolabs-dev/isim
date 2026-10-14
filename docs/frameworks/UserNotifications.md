# UserNotifications

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 82.1% of Apple's iOS API (234 of 285, exact) · **Rows:** 80% (10: 8 ✅ 2 ❌) · **iOS:** 10.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [UserNotifications](https://developer.apple.com/documentation/usernotifications) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Adapted:** isim's own Objective-C framework (`isim/frameworks/UserNotifications`).
- The shell draws banners and Notification Center and runs the scheduler.
- Pushes come from `isim push`; content extensions run as helper processes.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| UserNotifications: authorization request | ✅ | ≤17 | the iOS permission alert, answer remembered per app; provisional authorization; `notificationSettings()`; `ISIM_NOTIFICATION_PERMISSION=allow\|deny`. No per-app page in isim Settings |
| Local notifications (`UNNotificationRequest`, time/calendar triggers) | ✅ | ≤17 | time-interval and calendar (`DateComponents`) triggers, repeating, pending/delivered lists, persisted across launches; fire while the app runs, and a suspended app is woken when one is due (the app delivers it). Apps that are not running under `isim boot` get them from the system, like iOS: the home screen's scheduler reads each app's pending requests (with their next fire time) and the shell shows the due ones; the request then leaves the pending list (a repeating one moves to its next time) and is listed as delivered, with its badge. Tested (systemui, push, HelloAlerts: test_alerts, OS matrix) |
| Notification presentation (banners, Notification Center, foreground delegate, sounds, attachments, thread grouping, interruption levels) | ✅ | ≤17 | `willPresent`/`didReceive` (+ async); iOS-style banner in the app (touches outside it reach the app) or, for a backgrounded or not-running app, drawn by the shell over the screen; tap opens the app with the default action. Notification Center and the lock screen list them (open, clear; `removeDeliveredNotifications`) and stack an app's notifications by `threadIdentifier` (newest on top, plates under it, the category's `categorySummaryFormat` with `summaryArgument` / `summaryArgumentCount`, else "N more notifications"; a tap expands the stack, Show Less collapses it); Focus hides banners. Sounds play (adapted: isim's own synthesized default and ringtone sounds; files from the app bundle or Library/Sounds; `UNNotificationSound` critical and ringtone sounds with their volume): the shell plays them under `isim boot` (Silent Mode mutes all but critical alerts; script `silent on\|off`), the app itself otherwise. Interruption levels: passive (listed, no banner or sound), active, time sensitive (through Focus, with the entitlement), critical (through Focus and Silent Mode, with the entitlement and the `.criticalAlert` grant). Image attachments (`UNNotificationAttachment`, copied to the attachment store) show as thumbnails. Tested (systemui, push, HelloAlerts: test_alerts, OS matrix). `relevanceScore` and `filterCriteria` are kept (no summaries or Focus filters on them) |
| Notification actions and categories (`UNNotificationCategory`, `UNNotificationAction`, `UNTextInputNotificationAction`) | ✅ | ≤17 | long press (`holdid nc-item-ID`) expands a notification: the category's actions (destructive in red), text input with a reply field, `.foreground` actions open the app, background actions run as a background task (the app is launched in the background when needed), `.customDismissAction` sends the dismiss action; responses reach the delegate even after a relaunch (adapted: the shell draws the expanded view). Tested (push) |
| Push notifications (registration, device token, payloads) | ✅ | ≤17 | adapted, like the Simulator (Xcode 14+): `registerForRemoteNotifications` gives a 32-byte device token (needs the `aps-environment` entitlement; `ISIM_PUSH_REGISTRATION=fail`); payloads from `isim push [BUNDLE] file\|-`, the `push` script command or a dropped `.apns` file (`Simulator Target Bundle`); no APNs. alert (title/subtitle/body, loc keys), badge, sound, category, thread-id, `content-available` (`didReceiveRemoteNotification:fetchCompletionHandler:` as a background task; a closed app is launched in the background with UIBackgroundModes remote-notification), `mutable-content`; launch options carry the payload; not-running apps' alerts are shown by the system. Tested (push) |
| Notification Service extensions (`UNNotificationServiceExtension`) | ✅ | ≤17 | run as a helper process before display for `mutable-content` pushes with an alert; the modified content and attachments are shown; `serviceExtensionTimeWillExpire` after 30 s (`ISIM_NOTIFICATION_SERVICE_SECONDS`), then the best attempt or the original. Tested (push) |
| Notification Content extensions (`UNNotificationContentExtension`, UserNotificationsUI) | ✅ | ≤17 | for the categories in `UNNotificationExtensionCategory`: the view controller gets `didReceive(_:)` in a helper process that lives as long as the expanded notification; its view is drawn there and again whenever it changes (size from `UNNotificationExtensionInitialContentSizeRatio` / `preferredContentSize`, `UNNotificationExtensionDefaultContentHidden`). With `UNNotificationExtensionUserInteractionEnabled` touches reach its views. The media play / pause button (`mediaPlayPauseButtonType`, frame, tint) calls `mediaPlay()` / `mediaPause()` (`mediaPlayingStarted` / `Paused` from the extension). `extensionContext.notificationActions` replaces the actions; choosing one calls `didReceive(_:completionHandler:)` (keep, dismiss, or dismiss and forward to the app; without it: forwarded); `performNotificationDefaultAction`, `dismissNotificationContentExtension`. Adapted: the shell draws the expanded notification. Tested (push, HelloAlerts: test_alerts, OS matrix) |
| App icon badges (`setBadgeCount`, `applicationIconBadgeNumber`, aps.badge) | ✅ | ≤17 | red badge on the home-screen icon when the app may badge (`UNAuthorizationOptionBadge`); set by the app, by a push (system) or by a delivered notification; 0 clears it. Tested (push) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `UNLocationNotificationTrigger`, `UNNotificationContentProviding` (2 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 18) | ❌ | 18.0 | not implemented, found by the 2026-10 sweep: `UNNotificationAttributedMessageContext` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
51 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`UNError`](https://developer.apple.com/documentation/usernotifications/unerror)
- [`static var attachmentCorrupt: UNError.Code`](https://developer.apple.com/documentation/usernotifications/unerror/attachmentcorrupt)
- [`static var attachmentInvalidFileSize: UNError.Code`](https://developer.apple.com/documentation/usernotifications/unerror/attachmentinvalidfilesize)
- [`static var attachmentInvalidURL: UNError.Code`](https://developer.apple.com/documentation/usernotifications/unerror/attachmentinvalidurl)
- [`static var attachmentMoveIntoDataStoreFailed: UNError.Code`](https://developer.apple.com/documentation/usernotifications/unerror/attachmentmoveintodatastorefailed)
- [`static var attachmentNotInDataStore: UNError.Code`](https://developer.apple.com/documentation/usernotifications/unerror/attachmentnotindatastore)
- [`static var attachmentUnrecognizedType: UNError.Code`](https://developer.apple.com/documentation/usernotifications/unerror/attachmentunrecognizedtype)
- [`static var badgeInputInvalid: UNError.Code`](https://developer.apple.com/documentation/usernotifications/unerror/badgeinputinvalid)
- [`UNError.Code`](https://developer.apple.com/documentation/usernotifications/unerror/code)
- [`UNError.Code`](https://developer.apple.com/documentation/usernotifications/unerror/code)
- [`case attachmentCorrupt`](https://developer.apple.com/documentation/usernotifications/unerror/code/attachmentcorrupt)
- [`case attachmentCorrupt`](https://developer.apple.com/documentation/usernotifications/unerror/code/attachmentcorrupt)
- [`case attachmentInvalidFileSize`](https://developer.apple.com/documentation/usernotifications/unerror/code/attachmentinvalidfilesize)
- [`case attachmentInvalidFileSize`](https://developer.apple.com/documentation/usernotifications/unerror/code/attachmentinvalidfilesize)
- [`case attachmentInvalidURL`](https://developer.apple.com/documentation/usernotifications/unerror/code/attachmentinvalidurl)
- [`case attachmentInvalidURL`](https://developer.apple.com/documentation/usernotifications/unerror/code/attachmentinvalidurl)
- [`case attachmentMoveIntoDataStoreFailed`](https://developer.apple.com/documentation/usernotifications/unerror/code/attachmentmoveintodatastorefailed)
- [`case attachmentMoveIntoDataStoreFailed`](https://developer.apple.com/documentation/usernotifications/unerror/code/attachmentmoveintodatastorefailed)
- [`case attachmentNotInDataStore`](https://developer.apple.com/documentation/usernotifications/unerror/code/attachmentnotindatastore)
- [`case attachmentNotInDataStore`](https://developer.apple.com/documentation/usernotifications/unerror/code/attachmentnotindatastore)
- [`case attachmentUnrecognizedType`](https://developer.apple.com/documentation/usernotifications/unerror/code/attachmentunrecognizedtype)
- [`case attachmentUnrecognizedType`](https://developer.apple.com/documentation/usernotifications/unerror/code/attachmentunrecognizedtype)
- [`case badgeInputInvalid`](https://developer.apple.com/documentation/usernotifications/unerror/code/badgeinputinvalid)
- [`case badgeInputInvalid`](https://developer.apple.com/documentation/usernotifications/unerror/code/badgeinputinvalid)
- [`case contentProvidingInvalid`](https://developer.apple.com/documentation/usernotifications/unerror/code/contentprovidinginvalid)
- [`case contentProvidingInvalid`](https://developer.apple.com/documentation/usernotifications/unerror/code/contentprovidinginvalid)
- [`case contentProvidingObjectNotAllowed`](https://developer.apple.com/documentation/usernotifications/unerror/code/contentprovidingobjectnotallowed)
- [`case contentProvidingObjectNotAllowed`](https://developer.apple.com/documentation/usernotifications/unerror/code/contentprovidingobjectnotallowed)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/usernotifications/unerror/code/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/usernotifications/unerror/code/init(rawvalue:))
- [`case notificationInvalidNoContent`](https://developer.apple.com/documentation/usernotifications/unerror/code/notificationinvalidnocontent)
- [`case notificationInvalidNoContent`](https://developer.apple.com/documentation/usernotifications/unerror/code/notificationinvalidnocontent)
- [`case notificationInvalidNoDate`](https://developer.apple.com/documentation/usernotifications/unerror/code/notificationinvalidnodate)
- [`case notificationInvalidNoDate`](https://developer.apple.com/documentation/usernotifications/unerror/code/notificationinvalidnodate)
- [`case notificationsNotAllowed`](https://developer.apple.com/documentation/usernotifications/unerror/code/notificationsnotallowed)
- [`case notificationsNotAllowed`](https://developer.apple.com/documentation/usernotifications/unerror/code/notificationsnotallowed)
- [`static var contentProvidingInvalid: UNError.Code`](https://developer.apple.com/documentation/usernotifications/unerror/contentprovidinginvalid)
- [`static var contentProvidingObjectNotAllowed: UNError.Code`](https://developer.apple.com/documentation/usernotifications/unerror/contentprovidingobjectnotallowed)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/usernotifications/unerror/errordomain)
- [`static var notificationInvalidNoContent: UNError.Code`](https://developer.apple.com/documentation/usernotifications/unerror/notificationinvalidnocontent)
- [`static var notificationInvalidNoDate: UNError.Code`](https://developer.apple.com/documentation/usernotifications/unerror/notificationinvalidnodate)
- [`static var notificationsNotAllowed: UNError.Code`](https://developer.apple.com/documentation/usernotifications/unerror/notificationsnotallowed)
- [`UNLocationNotificationTrigger`](https://developer.apple.com/documentation/usernotifications/unlocationnotificationtrigger)
- [`convenience init(region: CLRegion, repeats: Bool)`](https://developer.apple.com/documentation/usernotifications/unlocationnotificationtrigger/init(region:repeats:))
- [`var region: CLRegion`](https://developer.apple.com/documentation/usernotifications/unlocationnotificationtrigger/region)
- [`var appEntityIdentifiers: [EntityIdentifier]`](https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent/appentityidentifiers)
- [`UNNotificationAttributedMessageContext`](https://developer.apple.com/documentation/usernotifications/unnotificationattributedmessagecontext)
- [`convenience init(sendMessageIntent: INSendMessageIntent, attributedContent: NSAttributedString)`](https://developer.apple.com/documentation/usernotifications/unnotificationattributedmessagecontext/init(sendmessageintent:attributedcontent:))
- [`func updating(from: any UNNotificationContentProviding) throws -> UNNotificationContent`](https://developer.apple.com/documentation/usernotifications/unnotificationcontent/updating(from:))
- [`UNNotificationContentProviding`](https://developer.apple.com/documentation/usernotifications/unnotificationcontentproviding)
- [`var targetScene: UIScene?`](https://developer.apple.com/documentation/usernotifications/unnotificationresponse/targetscene)

</details>
<!-- /generated:missing -->
