"""StoreKitTest (HelloStoreTesting, issue #296): an app's hosted Swift Testing bundle drives isim's local store with
SKTestSession — the project's Products.storekit (found in the project, as Xcode does not copy .storekit files into
products), purchases without dialogs, refunds, Ask to Buy (approve, decline of an answered request), interrupted
purchases (resolveIssueForTransaction), a subscription's auto-renew, forced renewal and expiration, time rate,
clearing, and errors for unknown transactions. `isim test` runs it like `xcodebuild test`."""
import os
import re
import subprocess

from isimtest import DEFAULT_DEVICE, ISIM, ROOT

PROJ = ROOT / "samples/HelloStoreTesting"


def test_storekit_test_session(device_data, tmp_path):
    env = dict(os.environ, ISIM_DATA=str(device_data), ISIM_DEVICE=DEFAULT_DEVICE, ISIM_HEADLESS="1")
    p = subprocess.run([str(ISIM), "test", "-project", "HelloStoreTesting.xcodeproj", "-scheme", "HelloStoreTesting",
                        "-only-testing:HelloStoreTestingTests", "-o", str(tmp_path / "build")],
                       cwd=PROJ, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace", timeout=900)
    log = p.stdout
    assert p.returncode == 0 and re.search(r"^\*\* TEST SUCCEEDED \*\*", log, re.M), log[-4000:]
    for name in ("productsFromTheConfiguration", "purchaseAndRefund", "askToBuy", "interruptedPurchase", "subscriptionLifecycle",
                 "timeRateAndClearing"):
        assert re.search(rf"✔ Test {name}\(\) passed", log), f"{name} passes\n{log[-4000:]}"
    assert "isim StoreKit: SKTestSession uses Products.storekit (5 products)" in log
    assert re.search(r"Ask to Buy: request [0-9]+ approved: transaction", log), "an approved Ask to Buy request"
    assert re.search(r"purchase [0-9]+ of dev\.isim\.store\.full_game interrupted", log), "an interrupted purchase"
