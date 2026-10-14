"""ABI compatibility: (1) every symbol exported by a released SDK (abi/v*.txt.gz) is still exported;
(2) ABIProbe.app, built with the isim 0.2.0 release (build_probe.py) and committed as a binary, still runs: CoreGraphics
members and SwiftUI gesture modifiers whose signatures changed after 0.2.0."""
import subprocess
import sys
from pathlib import Path

from isimtest import ROOT


def test_released_symbols():
    p = subprocess.run([sys.executable, str(ROOT / "tools" / "abi-check.py")], stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True, cwd=ROOT)
    lines = p.stdout.splitlines()
    missing = [l for l in lines if "MISSING" in l][:20]
    assert any(l.startswith("abi check: OK") for l in lines), \
        "released symbols still exported\n" + "\n".join(missing or lines[-20:])


def test_probe_app(launch):
    app = launch(Path(__file__).parent / "ABIProbe.app")
    app.wait_log(r"^abi cg: width=60 height=30 crop=4x3 drawn=true")   # CGImage width/height/cropping, CGContext.draw
    app.drag(150, 291, 250, 291, 0.4)
    app.wait_log(r"^abi drag ended dx=100")                              # DragGesture().onChanged/onEnded
    app.tap(201, 451)
    app.wait_log(r"^abi tap ended")                                      # TapGesture().onEnded
    app.send("longdrag 201 611 201 611 0.6 0.05")
    app.wait_log(r"^abi long press ended true")                          # LongPressGesture().onEnded
    assert "unresolved symbol" not in app.log, "the 0.2.0 app links (no unresolved symbols)"
    assert app.quit() == 0


def test_stale_sdk_binaries_removed(tmp_path):
    """build.py ci removes SDK binaries the graph no longer builds (a cached out/ kept the Google Mobile Ads stand-in
    and it reached two releases, issue #206), with their .swiftmodule / .framework, but keeps outputs and links."""
    sys.path.insert(0, str(ROOT))
    from buildlib import ninja
    sdk = tmp_path / "out" / "sdk"
    swift, fw = sdk / "usr/lib/swift", sdk / "System/Library/Frameworks"
    for f in ("usr/lib/swift/libswiftKept.dylib", "usr/lib/swift/Kept.swiftmodule/x.swiftmodule",
              "usr/lib/swift/libswiftGone.dylib", "usr/lib/swift/Gone.swiftmodule/x.swiftmodule",
              "System/Library/Frameworks/Kept.framework/Kept", "System/Library/Frameworks/Gone.framework/Gone",
              "System/Library/Frameworks/Gone.framework/Headers/Gone.h"):
        (sdk / f).parent.mkdir(parents=True, exist_ok=True)
        (sdk / f).write_text("")
    (sdk / "usr/lib/libc++.dylib").symlink_to("libc++.1.dylib")
    kept = ["out/sdk/usr/lib/swift/libswiftKept.dylib", "out/sdk/usr/lib/swift/Kept.swiftmodule/x.swiftmodule",
            "out/sdk/System/Library/Frameworks/Kept.framework/Kept"]
    (tmp_path / "out" / "build.ninja").write_text("rule touch\n  command = touch $out\n" + "".join(f"build {k}: touch\n" for k in kept))
    exe = ninja.find_ninja(str(ROOT / "out" / "pyenv")) or "ninja"
    removed = ninja.remove_stale_sdk(exe, str(tmp_path))
    assert sorted(removed) == ["out/sdk/System/Library/Frameworks/Gone.framework", "out/sdk/usr/lib/swift/Gone.swiftmodule",
                               "out/sdk/usr/lib/swift/libswiftGone.dylib"], removed
    assert all((tmp_path / k).exists() for k in kept) and (sdk / "usr/lib/libc++.dylib").is_symlink()
    assert not (swift / "Gone.swiftmodule").exists() and not (fw / "Gone.framework").exists()
