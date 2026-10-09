#pragma once
/* isim SDK (self-authored): virtual memory of the calling task (mmap / munmap / mprotect underneath). */
#include <mach/vm_prot.h>
#include <_isim_cdefs.h>
__BEGIN_DECLS
kern_return_t vm_allocate(vm_map_t target, vm_address_t *address, vm_size_t size, int flags);
kern_return_t vm_deallocate(vm_map_t target, vm_address_t address, vm_size_t size);
kern_return_t vm_protect(vm_map_t target, vm_address_t address, vm_size_t size, boolean_t set_maximum, vm_prot_t prot);
kern_return_t vm_read_overwrite(vm_map_read_t target, vm_address_t address, vm_size_t size, vm_address_t data, vm_size_t *outsize);
__END_DECLS
