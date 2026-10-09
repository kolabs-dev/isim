#pragma once
/* isim SDK (self-authored): VM protections and allocation flags. */
#include <mach/mach_types.h>
#define VM_PROT_NONE ((vm_prot_t)0x00)
#define VM_PROT_READ ((vm_prot_t)0x01)
#define VM_PROT_WRITE ((vm_prot_t)0x02)
#define VM_PROT_EXECUTE ((vm_prot_t)0x04)
#define VM_PROT_DEFAULT (VM_PROT_READ | VM_PROT_WRITE)
#define VM_PROT_ALL (VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE)
#define VM_FLAGS_FIXED 0x0000
#define VM_FLAGS_ANYWHERE 0x0001
#define VM_FLAGS_PURGABLE 0x0002
#define VM_FLAGS_OVERWRITE 0x4000
