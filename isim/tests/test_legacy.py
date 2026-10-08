"""Shell suites that are not ported to Python yet, run through pytest (temporary).

Each entry: (test id, description, shell command run from isim/, apps that must be built, os_matrix, iOS 17 ok).
Port a suite to tests/<dir>/test_<name>.py, delete its shell script and remove its entry here."""
import os
import subprocess

import pytest
from isimtest import ROOT, exclusive, need_apps

SUITES = [
]


MATRIX = {"17": "iphone15", "18": "iphone16pro", "26": "iphone17", "27": "iphone17"}


def pytest_generate_tests(metafunc):
    """Each suite once; with --os-matrix the matrix suites again under every iOS version."""
    params = []
    for s in SUITES:
        params.append(pytest.param(s, None, id=s[0]))
        if metafunc.config.getoption("--os-matrix") and s[4]:
            params += [pytest.param(s, v, id=f"{s[0]}-ios{v}") for v in MATRIX if v != "17" or s[5]]
    metafunc.parametrize("suite,version", params)


def test_shell_suite(suite, version, device_data):
    ident, desc, cmd, apps, matrix, ios17 = suite
    need_apps(*apps)
    env = dict(os.environ, ISIM_STANDALONE="1", ISIM_DATA=str(device_data))
    if version:
        env.update(ISIM_OS_VERSION=version, ISIM_DEVICE=MATRIX[version], ISIM_TEST_DEVICE=MATRIX[version])
    script = cmd.split()[0] if cmd.startswith("tests/") else ident
    with exclusive(os.path.basename(script)):
        p = subprocess.run(["bash", "-c", cmd], cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, errors="replace", timeout=900)
    assert p.returncode == 0, f"{desc}\n{p.stdout[-6000:]}"
