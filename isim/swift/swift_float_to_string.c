/* Float -> text entry points the Swift stdlib calls (normally in libswiftCore's Stubs.cpp).
 * Same semantics as stdlib/public/stubs/Stubs.cpp: forward to SwiftDtoa's optimal algorithm. */
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "swift/Runtime/SwiftDtoa.h"

#define SWIFTCC __attribute__((swiftcall)) __attribute__((visibility("default")))
SWIFTCC uint64_t swift_float32ToString(char *buf, size_t len, float v, bool debug) { return swift_dtoa_optimal_float(v, buf, len); }
SWIFTCC uint64_t swift_float64ToString(char *buf, size_t len, double v, bool debug) { return swift_dtoa_optimal_double(v, buf, len); }
SWIFTCC uint64_t swift_float80ToString(char *buf, size_t len, long double v, bool debug) { return swift_dtoa_optimal_float80_p(&v, buf, len); }
