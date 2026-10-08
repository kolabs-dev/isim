"""The pinned third-party sources isim builds from (sparse, shallow clones into third_party/; not committed)."""
import os
import subprocess

# name: (repository, tag, sparse paths or None for the whole tree); licenses: Apache-2.0 with the Runtime Library
# Exception (Swift projects), Apache-2.0 with the LLVM exception (llvm-project)
SOURCES = {
    "swift": ("https://github.com/swiftlang/swift.git", "swift-6.2.4-RELEASE",   # ee343b46aef81c3ac7c5d7960cb35a41a88c5a9b
              ["/stdlib/", "/include/swift/Runtime/", "/include/swift/ABI/", "/include/swift/Basic/", "/include/swift/Demangling/",
               "/include/swift/Threading/", "/include/swift/Concurrency/", "/include/swift/shims/", "/include/llvm/",
               "/include/swift/RemoteInspection/", "/lib/Demangling/", "/lib/Threading/", "/cmake/modules/", "/utils/gyb.py",
               "/utils/gyb_syntax_support/", "/utils/swift_build_support/", "/utils/SwiftIntTypes.py",
               "/utils/SwiftFloatingPointTypes.py", "/utils/gyb_stdlib_support.py", "/utils/availability-macros.def",
               "/include/swift/AST/LayoutConstraintKind.h", "/include/swift/AST/Ownership.h", "/include/swift/AST/ReferenceStorage.def",
               "/include/swift/AST/RequirementKind.h", "/include/swift/Strings.h"]),
    "llvm-project": ("https://github.com/llvm/llvm-project.git", "llvmorg-22.1.8",   # ca7933e47d3a3451d81e72ac174dcb5aa28b59d1
                     ["/libcxx/include/", "/libcxx/src/", "/libcxx/CMakeLists.txt", "/libcxxabi/include/", "/libcxxabi/src/",
                      "/libcxx/vendor/", "/runtimes/cmake/"]),
    "swift-experimental-string-processing": ("https://github.com/swiftlang/swift-experimental-string-processing.git",
                                             "swift-6.2.4-RELEASE", None),   # Regex, RegexBuilder
    "swift-testing": ("https://github.com/swiftlang/swift-testing.git", "swift-6.2.4-RELEASE", None),   # 5ee435b15ad40ec1f644b5eb9d247f263ccd2170
}


def fetch(tp):
    os.makedirs(tp, exist_ok=True)
    for name, (url, tag, sparse) in SOURCES.items():
        d = os.path.join(tp, name)
        if not os.path.isdir(d):
            if sparse:
                subprocess.run(["git", "clone", "-q", "--depth", "1", "--branch", tag, "--filter=blob:none", "--sparse", url, d], check=True)
                subprocess.run(["git", "-C", d, "sparse-checkout", "set", "--no-cone", *sparse], check=True)
            else:
                subprocess.run(["git", "clone", "-q", "--depth", "1", "--branch", tag, url, d], check=True)
        subprocess.run(["git", "-C", d, "log", "-1", f"--format={name} %H"])
    return 0
