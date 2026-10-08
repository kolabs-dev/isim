"""Security self-test (SecurityTest.app: CommonCrypto, CryptoKit, SQLite3, Keychain known-answer tests) on scratch
device data, and the os.Logger / os_log lines it writes to stderr. Port of tests/security/run.sh."""
import re

from isimtest import need_apps, selftest

LOG_LINES = {
    "Logger.notice: log-stream style line, strings private by default":
        r"^[0-9-]+ [0-9:.]+ Df SecurityTest\[[0-9]+:[0-9a-f]+\] \[dev\.isim\.test:security\] Loaded 3 items for <private>$",
    "Logger.info: .public, hex and minDigits formatting":
        r" I  ?SecurityTest.*\[dev\.isim\.test:security\] public alice@example\.com hex ff pad \[007\]$",
    "Logger.error: Bool and Double are public by default": r" E  ?SecurityTest.* failed: true 2\.50$",
    "Logger.debug: .private(mask: .hash)": r" Db SecurityTest.* hashed <mask\.hash: '[A-Za-z0-9+/=]+'>$",
    "os_log printf style: %{public}@ shown, %@ private, fault level":
        r" F  ?SecurityTest.*\[dev\.isim\.test:legacy\] legacy visible 42 <private>$",
    "os_log / Logger() without a subsystem": r"\] plain default log$",
    "C os_log: %{public} shown, %s/%@ private, scalars public":
        r" Df SecurityTest\[[0-9]+:[0-9a-f]+\] \[dev\.isim\.test:objc\] objc 42 <private> shown <private> "
        r"public-object 2\.50 ff$",
    "C os_log_error / os_log_debug, %{private}d, OS_LOG_DISABLED":
        r" E  SecurityTest.*\[dev\.isim\.test:objc\] objc error boom 7$",
    "C os_log_debug on OS_LOG_DEFAULT": r" Db SecurityTest\[[0-9]+:[0-9a-f]+\] objc default log <private>$",
}


def test_security(device_data):
    need_apps("SecurityTest")
    r = selftest("SecurityTest", data=device_data, timeout=60, split_stderr=True)
    err = r.stderr
    missing = [what for what, rx in LOG_LINES.items() if not re.search(rx, err, re.M)]
    assert not missing, f"os_log lines missing: {missing}\n{err[-3000:]}"
    assert not re.search(r"never printed|hidden-object|secret", err), "disabled log / private C arguments stay out"
    leaked = [l for l in err.splitlines() if "alice@example.com" in l and "public alice@example.com" not in l]
    assert not leaked, f"private values never reach the log: {leaked}"
