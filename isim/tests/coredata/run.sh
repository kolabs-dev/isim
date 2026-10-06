#!/usr/bin/env bash
# Runs CoreDataTest.app on an isolated device data directory (stores live in its container).
# Last line: "coredata test: N/M passed".
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
data=$PWD/out/test-data/coredata-test; rm -rf "$data"; mkdir -p "$data"
ISIM_DATA=$data ISIM_STANDALONE=1 timeout 120 out/bin/isim run out/apps/CoreDataTest.app 2>"$data/stderr.log"
rc=$?
[ $rc = 0 ] || { echo "--- stderr"; tail -20 "$data/stderr.log"; }
exit $rc
