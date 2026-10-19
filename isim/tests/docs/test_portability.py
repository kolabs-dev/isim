"""isim/tools/portability-check.py (docs/BUILD.md, "Portability"; native Windows, issue #491): the host runtime has no
Linux-only call beyond its baseline and every function guests call is marked ISIM_GUEST_ABI; and the check itself
catches a new fork(), an unmarked guest function or prototype, while a /* linux-only: */ line and a function a marked
macro makes pass. No build needed."""
import importlib.util
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]                     # isim/
CHECK = ROOT / "tools" / "portability-check.py"


def load(runtime: Path, baseline: Path):
    spec = importlib.util.spec_from_file_location("portability_check", CHECK)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    m.RUNTIME, m.BASELINE = str(runtime), str(baseline)
    return m


def test_runtime_is_within_its_baseline():
    p = subprocess.run([sys.executable, str(CHECK)], capture_output=True, text=True)
    assert p.returncode == 0, p.stdout + p.stderr


def test_the_check_catches_new_problems(tmp_path):
    runtime = tmp_path / "runtime"
    shutil.copytree(ROOT / "runtime", runtime)
    baseline = tmp_path / "baseline.txt"
    shutil.copy(ROOT / "data" / "portability-baseline.txt", baseline)
    m = load(runtime, baseline)
    grown = lambda: [k for k, n in m.current().items() if n > m.read_baseline().get(k, 0)]
    assert grown() == []

    (runtime / "extra.c").write_text(
        '#include "runtime.h"\n'
        'static int spawn_it(void) { return fork(); }\n'                                    # rule 1: use isim_spawn
        'static int keep_it(void) { return fork(); }   /* linux-only: a Darwin API over Linux */\n'
        'static int d_new(int x) { return x; }\n'                                            # rule 2: unmarked
        'ISIM_GUEST_ABI static int d_ok(int x);\n'
        'ISIM_GUEST_ABI static int d_ok(int x) { return x; }\n'
        'static int d_proto(int x);\n'                                                       # a prototype without it
        'ISIM_GUEST_ABI static int d_proto(int x) { return x; }\n'
        '#define MK(n) ISIM_GUEST_ABI static int d_mk_##n(void) { return 0; }\n'
        'MK(one)\n'
        'static const struct shim t[] = { A("_new", d_new), A("_ok", d_ok), A("_proto", d_proto), I("_mk", d_mk_one) };\n')
    found = sorted(grown())
    assert ("extra.c", r"\bfork\s*\(") in found, found
    assert m.current()[("extra.c", r"\bfork\s*\(")] == 1, "the linux-only: line is exempt"
    assert ("extra.c", "unmarked:d_new") in found and ("extra.c", "unmarked:d_proto") in found, found
    assert not any("d_ok" in k[1] or "d_mk_one" in k[1] for k in found), found
