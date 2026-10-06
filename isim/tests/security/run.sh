#!/usr/bin/env bash
# Runs SecurityTest.app (known-answer tests, SQLite3, keychain) on an isolated device data directory and checks
# the os.Logger/os_log lines it writes to stderr. Last line: "security test: N/M passed".
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
data=$PWD/out/test-data/security-test; rm -rf "$data"; mkdir -p "$data"
err=$data/stderr.log
out=$(ISIM_DATA=$data ISIM_STANDALONE=1 timeout 60 out/bin/isim run out/apps/SecurityTest.app 2>"$err"); rc=$?
fail=0
check() { if grep -qE -- "$2" "$err"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "Logger.notice: log-stream style line, strings private by default" '^[0-9-]+ [0-9:.]+ Df SecurityTest\[[0-9]+:[0-9a-f]+\] \[dev\.isim\.test:security\] Loaded 3 items for <private>$'
check "Logger.info: .public, hex and minDigits formatting" ' I  ?SecurityTest.*\[dev\.isim\.test:security\] public alice@example\.com hex ff pad \[007\]$'
check "Logger.error: Bool and Double are public by default" ' E  ?SecurityTest.* failed: true 2\.50$'
check "Logger.debug: .private(mask: .hash)" " Db SecurityTest.* hashed <mask\.hash: '[A-Za-z0-9+/=]+'>$"
check "os_log printf style: %{public}@ shown, %@ private, fault level" ' F  ?SecurityTest.*\[dev\.isim\.test:legacy\] legacy visible 42 <private>$'
check "os_log / Logger() without a subsystem" '\] plain default log$'
check "C os_log: %{public} shown, %s/%@ private, scalars public" ' Df SecurityTest\[[0-9]+:[0-9a-f]+\] \[dev\.isim\.test:objc\] objc 42 <private> shown <private> public-object 2\.50 ff$'
check "C os_log_error / os_log_debug, %{private}d, OS_LOG_DISABLED" ' E  SecurityTest.*\[dev\.isim\.test:objc\] objc error boom 7$'
check "C os_log_debug on OS_LOG_DEFAULT" ' Db SecurityTest\[[0-9]+:[0-9a-f]+\] objc default log <private>$'
if grep -q "never printed\|hidden-object\|secret" "$err"; then echo "FAIL  disabled log / private C arguments stay out"; fail=1; else echo "PASS  disabled log / private C arguments stay out"; fi
if grep -q "alice@example.com" <(grep -v "public alice@example.com" "$err"); then echo "FAIL  private values never reach the log"; fail=1; else echo "PASS  private values never reach the log"; fi
echo "$out" | grep -v "^security test:"
summary=$(echo "$out" | tail -1)
[ $fail = 0 ] || { echo "--- stderr"; tail -20 "$err"; }
echo "$summary"
[ $rc = 0 ] && [ $fail = 0 ]
