# XPC

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Foundation & CoreFoundation](../COVERAGE.md#foundation) · **Apple:** [XPC](https://developer.apple.com/documentation/xpc) · **Issues:** [`area:foundation`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Afoundation)

## How isim implements it

- **Approach:** isim's own XPC in Foundation (`isim/frameworks/Foundation/XPC.m`, `XPCStatic.mrc.m`), Apple's C API
  (`<xpc/xpc.h>`), and the Swift API in isim's XPC overlay (`isim/swift/overlays/XPC`). A named service is a Unix
  socket that every process of the booted device can reach: the app, its extensions and other apps (on Apple, a launchd
  service). The socket's address comes from the device's data directory and the service name, and
  `$ISIM_DATA/Library/isim/xpc/<name>` records which process listens. An anonymous listener gets a unique address,
  which its endpoint carries. Messages are length-prefixed frames carrying isim's encoding of the XPC objects. Swift's
  Codable messages travel as JSON inside an XPC dictionary.
- **Objective-C / C interface:** `<xpc/xpc.h>` and its headers in `isim/sdk-src/usr/include/xpc` (XPC objects are
  Objective-C objects in Objective-C and Swift, as on Apple). NSXPCConnection is in Foundation
  ([Foundation.md](Foundation.md)).
- **Versus Apple's Simulator:**
  - nothing launches a service on demand. A connection to a service that nobody listens on is interrupted and retries
    on its next message; a session fails to activate;
  - file descriptors and shared memory stay in their process (they arrive as null);
  - code-signing, entitlement and team requirements are accepted and never checked (isim doesn't sign code);
  - an activity runs in its own process after its delay, and again every interval when it repeats.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| XPC objects (`xpc_dictionary_*`, `xpc_array_*`, `xpc_string` / `int64` / `uint64` / `double` / `bool` / `date` / `data` / `uuid` / `null` create and get, `xpc_get_type`, `xpc_copy`, `xpc_equal`, `xpc_hash`, `xpc_copy_description`, `xpc_retain` / `xpc_release`, the `XPC_TYPE_*` and `XPC_ERROR_*` constants, appliers) | ✅ | ≤17 | adapted: Objective-C objects (`OS_xpc_object`); fd and shmem objects stay local. Tested: test_xpc (XPCTest) |
| `xpc_connection_t` (`xpc_connection_create`, `…_create_mach_service` with `XPC_CONNECTION_MACH_SERVICE_LISTENER`, `…_create_from_endpoint`, event handlers, `resume` / `suspend` / `cancel` / `activate`, `send_message`, `send_message_with_reply`, `…_with_reply_sync`, `xpc_dictionary_create_reply`, `get_pid` / `euid` / `egid` / `asid`, `set_target_queue`, `set_context`, `xpc_endpoint_create`) | 🟡 | ≤17 | adapted: a named service is a Unix socket of the device (above); `XPC_ERROR_CONNECTION_INTERRUPTED` when nobody listens, `XPC_ERROR_CONNECTION_INVALID` after a cancel. Peer code-signing requirements are accepted and not checked. Tested: test_xpc (XPCTest) |
| `xpc_session_t` (`xpc_session_create_mach_service`, `…_create_xpc_service`, `activate`, `cancel`, `send_message`, `send_message_with_reply_async`, `…_with_reply_sync`, incoming message and cancel handlers, `set_target_queue`, `copy_description`), `xpc_rich_error_t` | ✅ | 17.4 | adapted: a session to nobody fails to activate with a retryable rich error; a rejected peer is cancelled with the listener's reason. Tested: test_xpc (XPCTest) |
| `xpc_listener_t` (`xpc_listener_create` named or anonymous, `activate`, `cancel`, `copy_endpoint`, `reject_peer`, `xpc_session_*` of the incoming peer) | ✅ | 17.4 | adapted. Tested: test_xpc (XPCTest) |
| `xpc_activity_*` (`register`, `unregister`, criteria, `get_state` / `set_state`, `should_defer`) | 🟡 | ≤17 | adapted: runs in its own process after `XPC_ACTIVITY_DELAY`, then every `XPC_ACTIVITY_INTERVAL` when repeating; the system's criteria (power, network) are not evaluated (proposed) |
| `XPCSession` (`machService:` / `xpcService:` / `endpoint:` initializers with the incoming message and cancellation handlers, `activate`, `cancel(reason:)`, `send` with and without a reply handler, `sendSync`, Codable and `XPCDictionary` messages, `setTargetQueue`, `setPeerRequirement`) | ✅ | 17.4 | adapted: Codable messages are JSON in an XPC dictionary. Tested: test_xpc (SwiftXPCTest) |
| `XPCListener` (named or anonymous, `incomingSessionHandler`, `IncomingSessionRequest.accept(…)` / `reject(reason:)`, `XPCPeerHandler`, `endpoint`, `activate`, `cancel`), `XPCReceivedMessage` (`decode`, `reply`, `handoffReply(to:_:)`, `isSync`, `expectsReply`) | ✅ | 17.4 | adapted. Tested: test_xpc (SwiftXPCTest) |
| `XPCDictionary`, `XPCArray`, `XPCEndpoint`, `XPCRichError`, `XPCPeerRequirement` | ✅ | 17.4 | adapted: peer requirements are accepted and every peer satisfies them (isim doesn't sign code). Tested: test_xpc (SwiftXPCTest) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
