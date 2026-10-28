# DeclaredAgeRange

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Commerce & privacy](../COVERAGE.md#commerce) · **Apple:** [DeclaredAgeRange](https://developer.apple.com/documentation/declaredagerange) · **Issues:** [`area:commerce`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Acommerce)

## How isim implements it

- **Adapted:** isim has no Apple Account, so the age comes from the device's simulated account:
  `isim agerange set <age>|none [--declaration KIND] [--controls communicationLimits,significantAppChangeApprovalRequired]
  [--regulated]` writes `ISIM_DATA/Library/isim/AgeRange.json` (`isim agerange show` prints it). Under 18 the declaration
  defaults to `guardianDeclared`, from 18 to `selfDeclared`.
- `requestAgeRange` shows isim's rendition of iOS's "Share Age Range?" sheet (`ISIM_AGERANGE_ANSWER=share|decline`
  answers it without the sheet); sharing answers with the range between the app's age gates the age falls in.
- **Objective-C / C interface:** Swift only, as in Apple's SDK.
- **Versus a device:** no family, no Screen Time; the sheets' wording and layout are isim's.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `AgeRangeService.shared.requestAgeRange(ageGates:_:_:in:)`, `Response`, `AgeRange` (`lowerBound`, `upperBound`, `ageRangeDeclaration`, `activeParentalControls`), `AgeRangeDeclaration`, `ParentalControls`, `Error` | ✅ | 26.0 | adapted: the share sheet, then the range between the gates (13–15 for 14 with gates 13, 16, 18; 18+ for 30); declining; `notAvailable` without an age; `invalidRequest` for gates less than 2 years apart. Tested (HelloAgeRange, test_agerange) |
| `isEligibleForAgeFeatures`, `requiredRegulatoryFeatures`, `RegulatoryFeature` | ✅ | 26.0 | adapted: from `--regulated`; a regulated account under 18 needs parental consent for significant changes, an adult only a notice. Eligibility tested |
| `showSignificantUpdateAcknowledgment(in:updateDescription:)` | 🟡 | 26.0 | isim's sheet with the description and OK; unverified |
| `DeclaredAgeRangeAction` (`@Environment(\.requestAgeRange)`), `SignificantUpdateAction` (`@Environment(\.showSignificantUpdateAcknowledgment)`) | ✅ | 26.0 | the view's window; the age range action tested (HelloAgeRange) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
