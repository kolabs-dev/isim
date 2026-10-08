import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from isimtest import App, APPS  # noqa: E402


def pytest_addoption(parser):
    parser.addoption("--os", default=os.environ.get("ISIM_OS_VERSION"), help="iOS version to run the apps under")
    parser.addoption("--device", default=None, help="device preset (default: ISIM_TEST_DEVICE or iphone16pro)")


@pytest.fixture
def launch(request, tmp_path):
    """launch("HelloNavigation", **options) -> App, quit automatically at the end of the test."""
    apps = []

    def _launch(name, **kw):
        if not (APPS / f"{name}.app").is_dir():
            pytest.skip(f"{name}.app not built")
        kw.setdefault("os_version", request.config.getoption("--os"))
        kw.setdefault("device", request.config.getoption("--device"))
        kw.setdefault("data", tmp_path / "data")
        app = App(name, **kw).__enter__()
        apps.append(app)
        return app

    yield _launch
    for app in apps:
        app.quit()
