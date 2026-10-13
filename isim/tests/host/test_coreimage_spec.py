"""Core Image's generated files are in sync with their spec: CIFilterBuiltins.h (the SDK header) and CIFilterSpec.inc
(the framework's filter table) are written by frameworks/CoreImage/gen_filters.py; editing the spec without
regenerating them (or the files by hand) fails here."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_filter_spec_generated():
    gen = ROOT / "frameworks" / "CoreImage" / "gen_filters.py"
    r = subprocess.run([sys.executable, str(gen), "--check"], capture_output=True, text=True)
    assert r.returncode == 0, f"run {gen.relative_to(ROOT)} to regenerate:\n{r.stdout}{r.stderr}"
