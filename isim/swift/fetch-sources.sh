#!/usr/bin/env bash
# Fetch the pinned third-party sources isim builds from (sparse, shallow). Not committed to git.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
mkdir -p third_party && cd third_party
if [ ! -d swift ]; then   # swift-6.2.4-RELEASE = ee343b46aef81c3ac7c5d7960cb35a41a88c5a9b (Apache-2.0 with Runtime Library Exception)
  git clone -q --depth 1 --branch swift-6.2.4-RELEASE --filter=blob:none --sparse https://github.com/swiftlang/swift.git swift
  git -C swift sparse-checkout set --no-cone /stdlib/ /include/swift/Runtime/ /include/swift/ABI/ /include/swift/Basic/ \
    /include/swift/Demangling/ /include/swift/Threading/ /include/swift/Concurrency/ /include/swift/shims/ /include/llvm/ /include/swift/RemoteInspection/ \
    /lib/Demangling/ /lib/Threading/ /cmake/modules/ /utils/gyb.py /utils/gyb_syntax_support/ /utils/swift_build_support/ \
    /utils/SwiftIntTypes.py /utils/SwiftFloatingPointTypes.py /utils/gyb_stdlib_support.py /utils/availability-macros.def
fi
if [ ! -d llvm-project ]; then   # llvmorg-22.1.8 = ca7933e47d3a3451d81e72ac174dcb5aa28b59d1 (Apache-2.0 with LLVM exception)
  git clone -q --depth 1 --branch llvmorg-22.1.8 --filter=blob:none --sparse https://github.com/llvm/llvm-project.git llvm-project
  git -C llvm-project sparse-checkout set --no-cone /libcxx/include/ /libcxx/src/ /libcxx/CMakeLists.txt /libcxxabi/include/ \
    /libcxxabi/src/ /libcxx/vendor/ /runtimes/cmake/
fi
git -C swift log -1 --format='swift %H'; git -C llvm-project log -1 --format='llvm-project %H'
