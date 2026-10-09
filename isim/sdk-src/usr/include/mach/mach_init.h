#pragma once
/* isim SDK (self-authored): the calling task's, thread's and host's ports; page sizes. */
#include <mach/mach_types.h>
#include <_isim_cdefs.h>
__BEGIN_DECLS
extern mach_port_t mach_task_self_;
mach_port_t mach_host_self(void);
mach_port_t mach_thread_self(void);
kern_return_t host_page_size(host_t host, vm_size_t *size);
extern vm_size_t vm_page_size;
extern vm_size_t vm_page_mask;
extern int vm_page_shift;
extern vm_size_t vm_kernel_page_size;
extern vm_size_t vm_kernel_page_mask;
extern int vm_kernel_page_shift;
__END_DECLS
#define mach_task_self() mach_task_self_
#define current_task() mach_task_self()
#define trunc_page(x) ((x) & (~(vm_page_size - 1)))
#define round_page(x) trunc_page((x) + (vm_page_size - 1))
