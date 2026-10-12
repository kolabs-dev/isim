"""Entitlements are enforced (adapted, like iOS): an app group is shared only when it is in the app's
com.apple.security.application-groups entitlement (<App>.app/archived-expanded-entitlements.xcent) — otherwise
containerURL(forSecurityApplicationGroupIdentifier:) is nil and UserDefaults(suiteName:) is a domain of the app's own;
`isim build` expands $(AppIdentifierPrefix) / $(TeamIdentifierPrefix) in CODE_SIGN_ENTITLEMENTS. Keychain access groups:
tests/security (KeychainTests.swift, errSecMissingEntitlement)."""
import plistlib
import shutil
import subprocess
import sys
from pathlib import Path

from isimtest import APPS

ROOT = Path(__file__).resolve().parents[2]
GROUP = "group.dev.isim.samples.shared"


def test_app_group_needs_entitlement(launch, device_data, tmp_path):
    app_dir = tmp_path / "HelloSharedData.app"
    shutil.copytree(APPS / "HelloSharedData.app", app_dir, symlinks=True)
    (app_dir / "archived-expanded-entitlements.xcent").unlink()          # the same app without its app group
    app = launch(app_dir)
    app.wait_log(r"group defaults opens 1")
    assert app.quit() == 0
    assert f"app group '{GROUP}' is not in the app's com.apple.security.application-groups entitlement" in app.log, \
        "a hint names the missing entitlement"
    assert "group container " not in app.log, "containerURL(forSecurityApplicationGroupIdentifier:) is nil"
    assert not (device_data / "Shared/AppGroup" / GROUP).exists(), "nothing in the shared group container"
    own = [p for p in device_data.rglob(f"{GROUP}.plist") if "Shared/AppGroup" not in str(p)]
    assert own and "/Library/Preferences/" in str(own[0]), "UserDefaults(suiteName:) is the app's own domain"

    app = launch("HelloSharedData")                                      # entitled: the group is shared
    app.wait_log(r"group defaults opens 1")
    assert app.quit() == 0
    assert "group container " in app.log and (device_data / "Shared/AppGroup" / GROUP / "shared.txt").is_file()


def test_entitlement_variables(tmp_path):
    """isim build: CODE_SIGN_ENTITLEMENTS values are expanded; the prefixes are "TEAM." (empty without DEVELOPMENT_TEAM)"""
    ent = tmp_path / "App.entitlements"
    with open(ent, "wb") as f:
        plistlib.dump({"keychain-access-groups": ["$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)"],
                       "com.apple.security.application-groups": ["group.$(PRODUCT_BUNDLE_IDENTIFIER)"],
                       "com.apple.developer.team-identifier": "$(TeamIdentifierPrefix)"}, f)
    code = ("import importlib.util, sys, types; s = importlib.util.spec_from_file_location('b', sys.argv[1]); "
            "m = importlib.util.module_from_spec(s); s.loader.exec_module(m); "
            "t = types.SimpleNamespace(p=types.SimpleNamespace(root=sys.argv[2])); "
            "st = {'CODE_SIGN_ENTITLEMENTS': 'App.entitlements', 'PRODUCT_BUNDLE_IDENTIFIER': 'dev.isim.app'}; "
            "b1 = sys.argv[2] + '/A.app'; b2 = sys.argv[2] + '/B.app'; import os; os.mkdir(b1); os.mkdir(b2); "
            "m.apply_entitlements(t, st, b1); m.apply_entitlements(t, dict(st, DEVELOPMENT_TEAM='ABCDE12345'), b2)")
    subprocess.run([sys.executable, "-c", code, str(ROOT / "out/bin/isim-build.py"), str(tmp_path)], check=True)
    a = plistlib.loads((tmp_path / "A.app/archived-expanded-entitlements.xcent").read_bytes())
    b = plistlib.loads((tmp_path / "B.app/archived-expanded-entitlements.xcent").read_bytes())
    assert a["keychain-access-groups"] == ["dev.isim.app"] and a["com.apple.security.application-groups"] == ["group.dev.isim.app"]
    assert b["keychain-access-groups"] == ["ABCDE12345.dev.isim.app"] and b["com.apple.developer.team-identifier"] == "ABCDE12345."
