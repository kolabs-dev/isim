// The arm64 slices of the test's Vendor.xcframework: isim builds x86_64 simulator code only, so they hold this
// placeholder (the app never runs them; isim build keeps the x86_64 slice when it embeds the framework).
int vendor_arm64_placeholder(void) { return 0; }
