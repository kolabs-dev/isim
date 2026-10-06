/* xctest: isim's test runner tool (SDK /usr/bin/xctest). Loads a .xctest bundle and runs its tests in this process:
 * standalone unit tests (no TEST_HOST) and UI tests (XCUIApplication launches the app as another process).
 *   xctest Path/To/Tests.xctest     (filters: ISIM_XCTEST_ONLY / ISIM_XCTEST_SKIP, report: ISIM_XCTEST_JUNIT) */
#import <XCTest/XCTest.h>

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: xctest Tests.xctest\n"); return 64; }
    @autoreleasepool { return XCTIsimRunTestBundle(argv[1]); }
}
