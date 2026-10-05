#!/usr/bin/env bash
# Negative/positive loader tests. Expected exit codes are asserted.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
F=(-ffreestanding -fno-builtin -O1 -fno-stack-protector)
clang -target x86_64-apple-ios15.0-simulator "${F[@]}" -c tests/unimpl.c -o out/tests/unimpl.o
ld64.lld -arch x86_64 -platform_version ios-simulator 15.0 0 -o out/tests/unimpl.sim out/tests/unimpl.o tests/libSystem-extra.tbd
clang -target x86_64-apple-macos12.0 "${F[@]}" -c tests/unimpl.c -o out/tests/unimpl.mac.o
ld64.lld -arch x86_64 -platform_version macos 12.0 0 -o out/tests/unimpl.macos out/tests/unimpl.mac.o tests/libSystem-extra.tbd
pass=0 fail=0
t() { local want=$1; shift; out=$("$@" 2>&1); got=$?
      if [ "$got" = "$want" ]; then pass=$((pass+1)); r=PASS; else fail=$((fail+1)); r=FAIL; fi
      printf '%s  want=%s got=%s  %s\n%s\n' "$r" "$want" "$got" "${*#out/machoload }" "$(sed 's/^/      | /' <<<"$out")"; }
t 42  out/machoload ../02-link/out/hello.sim
t 42  out/machoload ../02-link/out/hello.sim.chained
t 127 out/machoload ../02-link/out/hello.dev          # arm64 device: refused
t 127 out/machoload out/tests/unimpl.macos            # macOS platform: refused
t 134 out/machoload out/tests/unimpl.sim              # unimplemented import: named trap + abort (SIGABRT=134)
echo "passed=$pass failed=$fail"; [ $fail = 0 ]
