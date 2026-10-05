#!/usr/bin/env bash
# Build libc++.1.dylib (libc++ + the libc++abi pieces the Swift runtime needs) for the isim
# simulator from llvmorg-22.1.8 sources, no exceptions/RTTI. Installs into the SDK at /usr/lib.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
L=$(realpath ${LIBCXX_SRC:-../../third_party/llvm-project}); SDK=$(realpath ../out/sdk); OBJ=../out/obj/libcxx
mkdir -p "$OBJ"
srcs=(libcxx/src/algorithm.cpp libcxx/src/atomic.cpp libcxx/src/bind.cpp libcxx/src/call_once.cpp libcxx/src/chrono.cpp
      libcxx/src/condition_variable.cpp libcxx/src/condition_variable_destructor.cpp libcxx/src/error_category.cpp
      libcxx/src/exception.cpp libcxx/src/functional.cpp libcxx/src/future.cpp libcxx/src/hash.cpp libcxx/src/memory.cpp
      libcxx/src/mutex.cpp libcxx/src/mutex_destructor.cpp libcxx/src/new_helpers.cpp libcxx/src/optional.cpp
      libcxx/src/stdexcept.cpp libcxx/src/string.cpp libcxx/src/system_error.cpp libcxx/src/thread.cpp
      libcxx/src/vector.cpp libcxx/src/verbose_abort.cpp
      libcxxabi/src/abort_message.cpp libcxxabi/src/cxa_aux_runtime.cpp libcxxabi/src/cxa_default_handlers.cpp
      libcxxabi/src/cxa_guard.cpp libcxxabi/src/cxa_handlers.cpp libcxxabi/src/cxa_noexception.cpp
      libcxxabi/src/cxa_virtual.cpp libcxxabi/src/stdlib_exception.cpp libcxxabi/src/stdlib_new_delete.cpp
      libcxxabi/src/stdlib_stdexcept.cpp)
objs=()
for f in "${srcs[@]}"; do
  o=$OBJ/$(basename "$f").o
  clang++ -target x86_64-apple-ios15.0-simulator -isysroot "$SDK" -std=c++23 -O2 -fno-exceptions -fno-rtti -D_LIBCXXABI_HAS_NO_EXCEPTIONS \
    -fvisibility-inlines-hidden -D_LIBCPP_BUILDING_LIBRARY -D_LIBCXXABI_BUILDING_LIBRARY -DLIBCXX_BUILDING_LIBCXXABI \
    -DNDEBUG -I "$L/libcxx/src" -I "$L/libcxxabi/include" -Wno-everything -c "$L/$f" -o "$o" || { echo "compile failed: $f"; exit 1; }
  true || clang++ -target x86_64-apple-ios15.0-simulator -isysroot "$SDK" -std=c++23 -O2 -fno-exceptions -fno-rtti \
    -fvisibility-inlines-hidden -D_LIBCPP_BUILDING_LIBRARY -D_LIBCXXABI_BUILDING_LIBRARY -DLIBCXX_BUILDING_LIBCXXABI \
    -DNDEBUG -I "$L/libcxx/src" -I "$L/libcxxabi/include" -Wno-everything -c "$L/$f" -o "$o"
  objs+=("$o")
done
ld64.lld -arch x86_64 -platform_version ios-simulator 15.0 0 -dylib -install_name /usr/lib/libc++.1.dylib \
  -o "$SDK/usr/lib/libc++.1.dylib" "${objs[@]}" -L "$SDK/usr/lib" -lSystem
ln -sf libc++.1.dylib "$SDK/usr/lib/libc++.dylib"
echo "built $SDK/usr/lib/libc++.1.dylib"
