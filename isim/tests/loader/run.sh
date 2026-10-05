#!/usr/bin/env bash
# Loader tests against isim's runtime: links minimal Mach-O executables with LLVM and a
# self-authored libSystem stub (no Apple SDK), then asserts `isim run` exit codes.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
CC=${CLANG:-clang}; LD=${LD64:-ld64.lld}
F=(-ffreestanding -fno-builtin -O1 -fno-stack-protector)
o=../../out/tests/loader; isim=../../out/bin/isim
mkdir -p $o
"$CC" -target x86_64-apple-ios15.0-simulator "${F[@]}" -c hello.c  -o $o/hello.sim.o  || exit 1
"$CC" -target arm64-apple-ios15.0            "${F[@]}" -c hello.c  -o $o/hello.dev.o  || exit 1
"$CC" -target x86_64-apple-ios15.0-simulator "${F[@]}" -c unimpl.c -o $o/unimpl.sim.o || exit 1
"$CC" -target x86_64-apple-macos12.0         "${F[@]}" -c unimpl.c -o $o/unimpl.mac.o || exit 1
"$LD" -arch x86_64 -platform_version ios-simulator 15.0 0 -o $o/hello.sim $o/hello.sim.o libSystem.tbd || exit 1
"$LD" -arch x86_64 -platform_version ios-simulator 15.0 0 -fixup_chains -o $o/hello.sim.chained $o/hello.sim.o libSystem.tbd || exit 1
"$LD" -arch arm64  -platform_version ios 15.0 0 -o $o/hello.dev $o/hello.dev.o libSystem.tbd || exit 1
"$LD" -arch x86_64 -platform_version ios-simulator 15.0 0 -o $o/unimpl.sim $o/unimpl.sim.o libSystem.tbd || exit 1
"$LD" -arch x86_64 -platform_version macos 12.0 0 -o $o/unimpl.macos $o/unimpl.mac.o libSystem.tbd || exit 1
pass=0 fail=0
t() { local want=$1; shift; out=$("$isim" run "$@" 2>&1); got=$?
      if [ "$got" = "$want" ]; then pass=$((pass+1)); r=PASS; else fail=$((fail+1)); r=FAIL; fi
      printf '%s  want=%s got=%s  %s\n%s\n' "$r" "$want" "$got" "${*#$o/}" "$(sed 's/^/      | /' <<<"$out")"; }
t 42  $o/hello.sim
t 42  $o/hello.sim.chained
t 127 $o/hello.dev            # arm64 device: refused
t 127 $o/unimpl.macos         # macOS platform: refused
t 134 $o/unimpl.sim           # unimplemented import: named trap + abort (SIGABRT=134)
echo "passed=$pass failed=$fail"; [ $fail = 0 ]
