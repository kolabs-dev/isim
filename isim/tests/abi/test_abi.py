"""ABI compatibility: (1) every symbol exported by a released SDK (abi/v*.txt.gz) is still exported;
(2) ABIProbe.app, built with the isim 0.2.0 release (build_probe.py) and committed as a binary, still runs: CoreGraphics
members and SwiftUI gesture modifiers whose signatures changed after 0.2.0. Port of tests/abi/run.sh."""
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
