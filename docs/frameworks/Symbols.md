# Symbols

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 86.5% of Apple's iOS API (115 of 133, exact) · **iOS:** 17.0+
<!-- /generated:header -->

**Area:** [Graphics & text](../COVERAGE.md#graphics) · **Apple:** [Symbols](https://developer.apple.com/documentation/symbols) · **Issues:** [`area:graphics`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agraphics)

## How isim implements it

- **Adapted:** symbol effects on isim's stand-in symbol drawings. Rows: [UIKit](UIKit.md).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Objective-C interface (`Symbols.framework`): `NSSymbolEffect` and its effects (pulse, bounce, variable colour, scale, appear, disappear; wiggle, rotate, breathe iOS 18; draw on / off iOS 26), `NSSymbolEffectOptions` (repeat count, speed, `NSSymbolEffectOptionsRepeatBehavior`), `NSSymbolReplaceContentTransition`, `NSSymbolAutomaticContentTransition` | ✅ | 17.0 | adapted: each object describes its effect the way the Swift overlay's do, and UIKit plays it (`-[UIImageView addSymbolEffect:…]`); isim animates the whole image, so `byLayer` and the variable-colour modes only change the timing. Symbols.framework re-exports the Swift overlay and links UIKit's. Tested (HelloConfigurationsObjC, tests/ui/test_configurations_objc.py) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
18 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var configuration: SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/appearsymboleffect/configuration)
- [`var configuration: SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/automaticsymboleffect/configuration)
- [`var configuration: SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/bouncesymboleffect/configuration)
- [`var configuration: SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/breathesymboleffect/configuration)
- [`var configuration: SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/disappearsymboleffect/configuration)
- [`var configuration: SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/drawoffsymboleffect/configuration)
- [`var configuration: SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/drawonsymboleffect/configuration)
- [`var configuration: SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/pulsesymboleffect/configuration)
- [`var configuration: SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/replacesymboleffect/configuration)
- [`func magic(fallback: ReplaceSymbolEffect) -> ReplaceSymbolEffect.MagicReplace`](https://developer.apple.com/documentation/symbols/replacesymboleffect/magic(fallback:))
- [`ReplaceSymbolEffect.MagicReplace`](https://developer.apple.com/documentation/symbols/replacesymboleffect/magicreplace)
- [`var configuration: SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/replacesymboleffect/magicreplace/configuration)
- [`var configuration: SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/rotatesymboleffect/configuration)
- [`var configuration: SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/scalesymboleffect/configuration)
- [`var configuration: SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/symboleffect/configuration)
- [`SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/symboleffectconfiguration)
- [`var configuration: SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/variablecolorsymboleffect/configuration)
- [`var configuration: SymbolEffectConfiguration`](https://developer.apple.com/documentation/symbols/wigglesymboleffect/configuration)

</details>
<!-- /generated:missing -->
