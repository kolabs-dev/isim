# Messages

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (156 of 156, exact) · **Rows:** 9: 5 ✅ 4 🟡 · **iOS:** 10.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [Messages](https://developer.apple.com/documentation/messages) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** adapted (`isim/swift/overlays/Messages`, hosted by isim's Messages app, `isim/system/Messages`):
  - the Messages app has one conversation with a simulated participant (Ana Lima): the transcript, the compose field
    and the + menu, which lists the installed apps' iMessage apps (Messages extensions,
    `com.apple.message-payload-provider` with an executable) and sticker packs (`isim build` indexes their stickers in
    `isim-stickers.json`, issue #341);
  - an iMessage app is loaded into the Messages app's process, like iOS's Messages runs it, and shows in the compact
    area under the compose field or expanded; `insert…` puts the content in the compose field (Send sends it), `send…`
    sends it at once;
  - messages of one session replace the session's earlier bubbles, which show as their summary; tapping a bubble
    opens its app expanded with the message selected;
  - the conversation is kept in the device data (`Library/isim/Messages/conversation.json`; `isim messages list`).
    `isim messages receive TEXT` or `isim messages receive --app EXTENSION [--url] [--caption] [--subcaption]
    [--summary] [--session last|UUID]` delivers a message from the other participant.
- **Objective-C / C interface:** `sdk-src/Frameworks/Messages/Messages.h` over the overlay's classes;
  `MSMessagesAppViewController` and `MSStickerBrowserViewController` can be subclassed. `MSCriticalSMSMessenger` is
  Swift only, like Apple's.
- **Versus Apple's Simulator:** the Simulator's Messages has two simulated people; isim has one conversation. Not in
  isim: iMessage itself (other people, the network, SMS), the media presentation context (the camera's effects),
  dragging stickers onto bubbles, live layouts drawn by the app in the transcript (the alternate layout shows).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `MSMessagesAppViewController` (`activeConversation`, `presentationStyle`, `presentationContext`, `requestPresentationStyle(_:)`, `dismiss()`, the become / resign active, select, receive, start / cancel sending and transition callbacks) | ✅ | ≤17 | adapted: hosted by isim's Messages app, compact or expanded; `didReceive` for a message of the app arriving while it is active (`isim messages receive`). Tested: test_messages_apps (HelloStickers) |
| `MSConversation` (`localParticipantIdentifier`, `remoteParticipantIdentifiers`, `selectedMessage`, `insert` of messages, stickers, text and attachments, `send…`, with completion handlers and async) | ✅ | ≤17 | adapted: `insert…` stages in the compose field, `send…` sends at once only while the app is visible and within 5 s of a tap in it (`sendWhileNotVisible`, `sendWithoutRecentInteraction`); a URL over 5000 bytes is `urlExceedsMaxSize`; attachments must be existing file URLs. Tested: test_messages_apps |
| `MSMessage` (`session`, `layout`, `url`, `summaryText`, `accessibilityLabel`, `shouldExpire`, `isPending`, `senderParticipantIdentifier`, `error`, NSSecureCoding), `MSSession` | ✅ | ≤17 | a session's later messages replace its bubble; `isPending` until sent. Tested: test_messages_apps |
| `MSMessageLayout`, `MSMessageTemplateLayout` (image or media, image title and subtitle, captions), `MSMessageLiveLayout` | 🟡 | ≤17 | adapted: the transcript draws the template layout (iOS's bubble: the image, then the captions); a live layout shows its alternate layout (the app is not run in the transcript style) |
| `MSSticker`, `MSStickerView` (`startAnimating`, `stopAnimating`, `isAnimating`, `animationDuration`), `MSStickerBrowserView`, `MSStickerBrowserViewController`, `MSStickerBrowserViewDataSource`, `MSStickerSize`, `MSStickersErrorDomain` | ✅ | ≤17 | adapted: a sticker must be a PNG, APNG, GIF or JPEG file of at most 500 KB (`stickerFileImproperFileFormat`, `…FileSize`, `fileNotFound`); animated PNGs and GIFs animate; tapping a sticker view inserts it; the browser is a grid (4, 3 or 2 a row). Sticker packs open as such a browser. Tested: test_messages_apps |
| `MSMessagesAppTranscriptPresentation` (`contentSizeThatFits`; iOS 26: `messageCornerRadius`, `messageTintColor`, `invalidateMessageTintColor`) | 🟡 | ≤17 | declared; the transcript style is not run (live layouts show their alternate layout) |
| `MSMessageErrorCode`, `MSMessagesErrorDomain`, `MSMessagesAppPresentationStyle`, `MSMessagesAppPresentationContext` | ✅ | ≤17 | Apple's codes and values. Tested: test_messages_apps |
| `MSCriticalSMSMessenger`, `MSRecipient`, `MSCriticalMessage`, `MSCriticalMessagingAuthorizationStatus`, `MSCriticalMessagingError` | 🟡 | 18.2 | stub: isim has no SMS; the calls throw `notSupported` (like the Simulator) |
| `MSUPIRequest` | 🟡 | 27.0 | stub: no UPI payment messages on isim; `send` reports false |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
