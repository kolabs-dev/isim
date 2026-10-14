// isim libswiftCore: the force-load markers of Apple's Swift libraries. Binaries built with Apple's toolchain for older
// iOS versions reference _swift_FORCE_LOAD_$_swiftCompatibility51... (the static compatibility libraries the driver links
// to backport runtime fixes) and, for some imported modules, _swift_FORCE_LOAD_$_swift<Module>. isim's runtime already
// has those fixes and its overlays load as dylibs, so these symbols are markers only: they let such binaries (Google
// Mobile Ads' Swift code) link; nothing reads them.
#define MARK(name) __attribute__((visibility("default"), used)) const char marker_##name __asm__("__swift_FORCE_LOAD_$_" #name) = 0;
MARK(swiftCompatibility50) MARK(swiftCompatibility51) MARK(swiftCompatibility56) MARK(swiftCompatibilityConcurrency)
MARK(swiftCompatibilityDynamicReplacements) MARK(swiftCompatibilityPacks) MARK(swiftCompatibilitySpan)
MARK(swiftFoundation) MARK(swiftDispatch) MARK(swiftObjectiveC) MARK(swiftCoreFoundation) MARK(swiftXPC) MARK(swiftos)
MARK(swiftOSLog) MARK(swift_Builtin_float) MARK(swiftDarwin) MARK(swift_DarwinFoundation1) MARK(swift_DarwinFoundation2)
MARK(swift_DarwinFoundation3) MARK(swiftSystem) MARK(swiftDistributed) MARK(swiftObservation) MARK(swift_Concurrency)
MARK(swift_StringProcessing) MARK(swiftNetwork) MARK(swiftUIKit) MARK(swiftCoreGraphics) MARK(swiftQuartzCore)
MARK(swiftCoreImage) MARK(swiftMetal) MARK(swiftCoreMedia) MARK(swiftCoreAudio) MARK(swiftAVFoundation) MARK(swiftsimd)
MARK(swiftCoreLocation) MARK(swiftWebKit) MARK(swiftCombine) MARK(swiftSwiftUI) MARK(swiftCryptoKit) MARK(swiftUniformTypeIdentifiers)
