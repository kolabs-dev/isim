#!/usr/bin/env bash
# Runs ObjCLiteralsTest.app (Objective-C constant literals + Swift bridging). Last line: summary.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
export ISIM_STANDALONE=1
data=$PWD/out/test-data/objc-literals; rm -rf "$data"; mkdir -p "$data"; export ISIM_DATA=$data
out=$(timeout 60 out/bin/isim run out/apps/ObjCLiteralsTest.app 2>"$data/stderr.log"); rc=$?
echo "$out" | grep -E "^FAIL|^  mismatch"
summary=$(echo "$out" | grep -o "objc literals test: .*")
if [ $rc != 0 ] || [ -z "$summary" ]; then
  echo "FAIL  ObjCLiteralsTest exit $rc"; tail -20 "$data/stderr.log"
  echo "${summary:-objc literals test: did not finish}"
  exit 1
fi
echo "$summary"
