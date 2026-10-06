#!/usr/bin/env bash
# Runs ObjCRuntimeTest.app (exceptions, forwarding, NSInvocation, NSProxy) and checks that uncaught
# exceptions (Objective-C and Swift callers) terminate with iOS's report. Last line: summary.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
export ISIM_STANDALONE=1
data=$PWD/out/test-data/objc-runtime; rm -rf "$data"; mkdir -p "$data"; export ISIM_DATA=$data
fail=0
out=$(timeout 60 out/bin/isim run out/apps/ObjCRuntimeTest.app 2>"$data/selftest.err"); rc=$?
echo "$out" | grep "^FAIL"
[ $rc = 0 ] || { fail=1; echo "FAIL  ObjCRuntimeTest exit $rc"; tail -20 "$data/selftest.err"; }
summary=$(grep -o "objc runtime test: .*" "$data/selftest.err")

# expect APP MODE EXIT-CODE regex... : the run must abort (SIGABRT, 134) and print each regex line
expect() {
  local app=$1 mode=$2; shift 2
  local log=$data/$app-$mode.log
  ( timeout 30 out/bin/isim run "out/apps/$app.app" "$mode" >"$log" 2>&1; exit $? ) 2>/dev/null; local rc=$?
  local ok=1
  [ $rc = 134 ] || { ok=0; echo "  exit code $rc (want 134 = SIGABRT)"; }
  for re in "$@"; do grep -qE -- "$re" "$log" || { ok=0; echo "  missing: $re"; }; done
  grep -q "NOT REACHED" "$log" && { ok=0; echo "  continued after the exception"; }
  if [ $ok = 1 ]; then echo "PASS  uncaught: $app $mode"; else echo "FAIL  uncaught: $app $mode"; tail -15 "$log"; fail=1; fi
}
term="^\*\*\* Terminating app due to uncaught exception"
expect ObjCUncaught raise "$term 'NSInternalInconsistencyException', reason: 'state 3 is invalid'$" \
    '^\*\*\* First throw call stack:$' 'ObjCUncaught`main' '^libc\+\+abi: terminating due to uncaught exception of type NSException$'
expect ObjCUncaught handler '^HANDLER NSInternalInconsistencyException state 3 is invalid$' "$term 'NSInternalInconsistencyException'"
expect ObjCUncaught unrecognized "$term 'NSInvalidArgumentException', reason: '-\[NSObject notImplemented\]: unrecognized selector sent to instance 0x[0-9a-f]+'$"
expect ObjCUncaught object "$term of class '__NSDate|NSDate'" 'terminating due to uncaught exception of type'
expect ObjCUncaught finally '^FINALLY ran$' "$term 'FinallyException', reason: 'after finally'$"
if [ -x out/apps/SwiftUncaught.app/SwiftUncaught ]; then
  expect SwiftUncaught range "$term 'NSRangeException', reason: '.*index 5 beyond bounds" 'SwiftUncaught`'
  expect SwiftUncaught raise "$term 'NSInvalidArgumentException', reason: 'raised from Swift'$"
  grep -q "SWIFT CAUGHT" "$data"/SwiftUncaught-*.log && { echo "FAIL  Swift do/catch must not catch NSException"; fail=1; }
fi
echo "$summary"
[ $fail = 0 ]
