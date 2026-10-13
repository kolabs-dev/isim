// HelloDiagnostics' C part: os_log and the os_signpost macros from C (they share the log store with Swift), and a
// crash in C code (a write through a null pointer: SIGSEGV, EXC_BAD_ACCESS).
#include <os/log.h>
#include <os/signpost.h>
#include <stdint.h>

void cdiag_log_and_signpost(void) {
    os_log_t log = os_log_create("dev.isim.diag", "c");
    os_log(log, "C says %d and %{public}s", 42, "hello");
    os_signpost_id_t spid = os_signpost_id_generate(log);
    os_signpost_interval_begin(log, spid, "CWork", "items %d", 3);
    os_signpost_event_emit(log, spid, "CTick");
    os_signpost_interval_end(log, spid, "CWork");
}

static volatile int *nowhere;
__attribute__((noinline)) void cdiag_crash_segv(void) { *nowhere = 1; }
