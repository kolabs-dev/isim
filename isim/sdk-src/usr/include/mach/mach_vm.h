#pragma once
/* isim SDK (self-authored): 64-bit virtual memory calls of the calling task. */
#include <mach/vm_prot.h>
#include <_isim_cdefs.h>
__BEGIN_DECLS
kern_return_t mach_vm_allocate(vm_map_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags);
kern_return_t mach_vm_deallocate(vm_map_t target, mach_vm_address_t address, mach_vm_size_t size);
kern_return_t mach_vm_protect(vm_map_t target, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_maximum, vm_prot_t prot);
kern_return_t mach_vm_read_overwrite(vm_map_read_t target, mach_vm_address_t address, mach_vm_size_t size, mach_vm_address_t data, mach_vm_size_t *outsize);
__END_DECLS
