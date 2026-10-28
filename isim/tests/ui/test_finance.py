"""FinanceKit and FinanceKitUI (issue #398, HelloFinance): the device's simulated Wallet financial data (`isim finance
seed`), the access prompt, accounts, balances, transaction queries with FinanceKit's predicates and sort descriptors, a
transaction history that delivers what `isim finance add-transaction` adds, the transaction picker, and an order added
to Wallet (`isim wallet orders` lists it)."""
import os
import subprocess

from isimtest import ISIM, need_apps

APP = "HelloFinance"


def isim(data, *args):
    r = subprocess.run([str(ISIM), *args], env=dict(os.environ, ISIM_DATA=str(data)), stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True, timeout=60)
    assert r.returncode == 0, r.stdout
    return r.stdout


def test_finance(launch, device_data):
    need_apps(APP)
    assert "seeded 2 accounts" in isim(device_data, "finance", "seed")
    app = launch(APP, os_version="18")
    app.wait_log(r"data available true orders true")
    app.tap_id("read")
    app.wait_view("Allow")                                                 # isim's access prompt
    app.tap_text("Allow")
    app.wait_log(r"authorization: authorized")
    app.wait_log(r"accounts: Apple Card liability, Savings asset")
    app.wait_log(r"card limit 5000")
    app.wait_log(r"balances: 2 booked true")
    app.wait_log(r"pending: City Parking")
    app.wait_log(r"groceries: Whole Foods Market 62\.18")
    app.wait_log(r"history: 3 at first")
    assert "added transaction" in isim(device_data, "finance", "add-transaction", "Apple Card", "9.99", "Music Store", "--mcc", "5735")
    app.wait_log(r"history: inserted Music Store")
    # the picker: the person shares two transactions
    app.tap_id("pick")
    app.wait_view("txn-share")
    app.tap_id("txn-Blue Bottle Coffee")
    app.tap_id("txn-Music Store")
    app.tap_id("txn-share")
    app.wait_log(r"picked: Blue Bottle Coffee,Music Store")
    # an order to Wallet
    app.tap_id("add-order-to-wallet")
    app.wait_view("Add")
    app.tap_text("Add")
    app.wait_log(r"order: added")
    assert "order.dev.isim.samples.shop A-1001" in isim(device_data, "wallet", "orders")
    app.tap_id("add-order-to-wallet")
    app.wait_view("Add")
    app.tap_text("Add")
    app.wait_log(r"order: added", count=2)
    assert app.quit() == 0


def test_finance_denied(launch, device_data):
    """denied access: the data calls throw dataRestricted"""
    need_apps(APP)
    isim(device_data, "finance", "seed")
    app = launch(APP, os_version="18", env={"ISIM_FINANCEKIT_PERMISSION": "deny"})
    app.tap_id("read")
    app.wait_log(r"authorization: denied")
    assert app.quit() == 0
