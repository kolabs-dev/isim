"""Binary SDKs built with Apple's newer toolchains link against isim's SDK unchanged (issue #606: Google Mobile Ads 12.14
failed to link). They reference the force-load markers of Darwin's per-header Swift overlays (_errno, _signal, _stdio,
_math, _time, sys_time, unistd), CFNetwork's CFHost and UIKit's status bar orientation notification name."""
import subprocess
import tempfile
from pathlib import Path

from isimtest import ISIM, ROOT

SOURCE = r'''
#import <UIKit/UIKit.h>
#import <CFNetwork/CFNetwork.h>
#define REF(name) extern const char ref_##name __asm__("__swift_FORCE_LOAD_$_" #name);
REF(swift_errno) REF(swift_signal) REF(swift_stdio) REF(swift_math) REF(swift_time) REF(swiftsys_time) REF(swiftunistd)
const void *refs[] = { &ref_swift_errno, &ref_swift_signal, &ref_swift_stdio, &ref_swift_math, &ref_swift_time,
                       &ref_swiftsys_time, &ref_swiftunistd, (const void *)CFHostCreateWithName,
                       (const void *)CFHostStartInfoResolution, (const void *)CFHostGetAddressing };
int main(void) { return UIApplicationDidChangeStatusBarOrientationNotification.length > 0 && refs[0] ? 0 : 1; }
'''


def test_link_markers_cfhost_orientation_notification():
    with tempfile.TemporaryDirectory(prefix="isim-link-") as d:
        d = Path(d)
        (d / "probe.m").write_text(SOURCE)
        p = subprocess.run([str(ISIM), "cc", "-fobjc-arc", "-Wno-deprecated-declarations", "probe.m", "-o", "probe",
                            "-framework", "UIKit", "-framework", "Foundation", "-framework", "CFNetwork",
                            "-L", str(ROOT / "out/sdk/usr/lib/swift"), "-lswiftCore"],
                           cwd=d, capture_output=True, text=True, timeout=300)
        assert p.returncode == 0 and (d / "probe").is_file(), p.stdout + p.stderr
