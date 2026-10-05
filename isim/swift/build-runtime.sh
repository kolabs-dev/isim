#!/usr/bin/env bash
# Compile the Swift runtime (C++/ObjC++: runtime, stubs, demangler, LLVMSupport, threading)
# for x86_64-apple-ios-simulator against the isim SDK. Objects go to out/swift/obj/runtime.
# Usage: build-runtime.sh [--keep-going]   (prints a per-file error summary)
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
SRC=$(realpath ${SWIFT_SRC:-../../third_party/swift}); OUT=$(realpath -m ${OUT:-../out/swift}); SDK=$(realpath ${ISIM_SDK:-../out/sdk})
OBJ=$OUT/obj/runtime; mkdir -p "$OBJ" "$OUT/gyb-runtime"
P=$SRC/stdlib/public
python3 "$SRC/utils/gyb.py" -DCMAKE_SIZEOF_VOID_P=8 --line-directive '' "$P/stubs/SwiftNativeNSXXXBase.mm.gyb" -o "$OUT/gyb-runtime/SwiftNativeNSXXXBase.mm"
runtime=(../CompatibilityOverride/CompatibilityOverride.cpp AnyHashableSupport.cpp Array.cpp AutoDiffSupport.cpp Bincompat.cpp
  BytecodeLayouts.cpp Casting.cpp CrashReporter.cpp Demangle.cpp DynamicCast.cpp Enum.cpp EnvironmentVariables.cpp
  ErrorObjectCommon.cpp ErrorObjectNative.cpp Errors.cpp ErrorDefaultImpls.cpp Exception.cpp Exclusivity.cpp
  ExistentialContainer.cpp Float16Support.cpp FoundationSupport.cpp FunctionReplacement.cpp GenericMetadataBuilder.cpp
  Heap.cpp HeapObject.cpp ImageInspectionCommon.cpp ImageInspectionMachO.cpp SymbolInfo.cpp KeyPaths.cpp
  KnownMetadata.cpp LibPrespecialized.cpp Metadata.cpp MetadataLookup.cpp Numeric.cpp Once.cpp Paths.cpp Portability.cpp
  ProtocolConformance.cpp RefCount.cpp ReflectionMirror.cpp RuntimeInvocationsTracking.cpp SwiftDtoa.cpp
  SwiftTLSContext.cpp ThreadingError.cpp Tracing.cpp AccessibleFunction.cpp
  ErrorObject.mm SwiftObject.mm SwiftValue.mm ReflectionMirrorObjC.mm ObjCRuntimeGetImageNameFromClass.mm)
stubs=(Assert.cpp GlobalObjects.cpp LibcShims.cpp Random.cpp Stubs.cpp ThreadLocalStorage.cpp MathStubs.cpp
  Unicode/UnicodeData.cpp Unicode/UnicodeGrapheme.cpp Unicode/UnicodeNormalization.cpp Unicode/UnicodeScalarProps.cpp
  Unicode/UnicodeWord.cpp Availability.mm FoundationHelpers.mm OptionalBridgingHelper.mm Reflection.mm
  SwiftNativeNSObject.mm SwiftNativeNSXXXBaseARC.m)
files=()
for f in "${runtime[@]}"; do files+=("$P/runtime/$f"); done
for f in "${stubs[@]}"; do files+=("$P/stubs/$f"); done
files+=("$OUT/gyb-runtime/SwiftNativeNSXXXBase.mm")
for f in "$SRC"/lib/Demangling/*.cpp "$P"/LLVMSupport/*.cpp; do files+=("$f"); done
# stdlib/public/Threading/CMakeLists.txt: the platform files only (Errors.cpp belongs to the compiler)
for f in C11 Linux Pthreads Win32 ThreadSanitizer; do files+=("$SRC/lib/Threading/$f.cpp"); done
FLAGS=(-target x86_64-apple-ios15.0-simulator -isysroot "$SDK" -O2 -fno-exceptions -fno-rtti -fPIC
  -fvisibility=hidden -fvisibility-inlines-hidden -fno-stack-protector -Wno-everything
  -I "$PWD/gen-include" -I "$SRC/include" -I "$SRC/stdlib/include" -I "$P/SwiftShims" -I "$P/stubs/Unicode" -I "$P/runtime"
  -DNDEBUG -DswiftCore_EXPORTS -DSWIFT_TARGET_LIBRARY_NAME=swiftRuntimeCore -DSWIFT_RUNTIME -DSWIFT_LIBRARY_EVOLUTION=1 -DSWIFT_ENABLE_REFLECTION
  -DSWIFT_STDLIB_HAS_DLADDR -DSWIFT_STDLIB_HAS_DLSYM=0 -DSWIFT_STDLIB_HAS_DARWIN_LIBMALLOC=0 -DSWIFT_STDLIB_HAS_STDIN
  -DSWIFT_STDLIB_HAS_ENVIRON -DSWIFT_THREADING_PTHREADS -DSWIFT_STDLIB_HAS_TYPE_PRINTING
  -DSWIFT_STDLIB_ENABLE_UNICODE_DATA -DSWIFT_STDLIB_ENABLE_VECTOR_TYPES
  -DSWIFT_OBJC_INTEROP=1 -D__STDC_LIMIT_MACROS -D__STDC_CONSTANT_MACROS)
compile() {
  local f=$1 o=$OBJ/$(echo "$1" | sed "s|$SRC/||; s|$OUT/||; s|/|_|g").o lang=()
  case "$f" in *ARC.m) lang=(-x objective-c -fobjc-arc) ;; *.mm) lang=(-x objective-c++ -std=c++17) ;; *.m) lang=(-x objective-c) ;; *) lang=(-x c++ -std=c++17) ;; esac
  if ! clang "${FLAGS[@]}" "${lang[@]}" -c "$f" -o "$o" 2> "$o.log"; then echo "FAIL $(basename "$f")"; else rm -f "$o.log"; fi
}
export -f compile; export SRC OUT OBJ; export FLAGS_STR="${FLAGS[*]}"
fails=0
printf '%s\n' "${files[@]}" | xargs -P "$(nproc)" -I{} bash -c 'FLAGS=($FLAGS_STR); '"$(declare -f compile)"'; compile "{}"' | sort | tee "$OUT/runtime-failures.txt"
echo "compiled $(( ${#files[@]} - $(wc -l < "$OUT/runtime-failures.txt") ))/${#files[@]} files"
