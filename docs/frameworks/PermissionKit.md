# PermissionKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Commerce & privacy](../COVERAGE.md#commerce) · **Apple:** [PermissionKit](https://developer.apple.com/documentation/permissionkit) · **Issues:** [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

## How isim implements it

- **Adapted:** isim has no family, so the parent is simulated. `AskCenter.ask` shows isim's rendition of the "Ask"
  sheet a child sees; a sent question waits in `ISIM_DATA/Library/isim/PermissionKit/<bundle id>.json`, and
  `isim permission <app> list|approve|decline [id|all]` answers as the parent (the latest pending question by default).
  The answer arrives in `AskCenter.responses(for:)` and `CommunicationLimits.updates` (checked twice a second).
- Asking needs a child account with Communication Limits (`isim agerange set <age> --controls communicationLimits`),
  else `AskError.communicationLimitsNotEnabled`. `ISIM_PERMISSION_ANSWER=yes|no` answers the child's sheets without them.
- **Objective-C / C interface:** Swift only, as in Apple's SDK.
- **Versus a device:** no Messages, no Screen Time; the sheets' wording and layout are isim's.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `AskCenter.shared.ask(_:in:)`, `responses(for:)`, `PermissionQuestion` (`init(handle:)`, `init(handles:)`, `init(communicationTopic:)`, `init(significantAppUpdateTopic:)`, `choices`, `defaultChoice`, `id`, `topic`, `expirationDate`), `PermissionResponse`, `PermissionChoice`, `QuestionTopic`, `CommunicationTopic` (with `Action` and `PersonInformation`), `SignificantAppUpdateTopic`, `CommunicationHandle` | ✅ | 26.0 | adapted: the Ask sheet, the simulated parent's answer delivered as a response; `expirationDate` is a week after asking (isim's choice). Tested (HelloAgeRange, test_agerange: asked, approved, delivered) |
| `CommunicationLimits.current` (`isKnownHandle`, `knownHandles(in:)`, `updates`, `ask(_:in:)`) | ✅ | 26.0 | known handles are those of approved communication questions (unknown before, known after approval: tested) |
| `askSignificantChangePermission(for:permissionFlow:in:)`, `PermissionFlow`, `PermissionResult` | 🟡 | 26.0 | ask to approve: the Ask sheet (`askToApprove(didSend:)`); approve in person: a parent approves on this device (`approveInPerson(approved:)`); acknowledgment alert: the parent is told (`askToApprove(didSend: true)` after OK); unverified |
| `AskError` | ✅ | 26.0 | `communicationLimitsNotEnabled` for an account without Communication Limits (tested) |
| `PermissionButton`, `CommunicationLimitsButton`, `AskPermissionAction` (`@Environment(\.askPermission)`) | 🟡 | 26.0 | ask the question when tapped; unverified |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
