#pragma once
/* isim SDK (self-authored): Mach port management (ports of the calling process). */
#include <mach/port.h>
#include <_isim_cdefs.h>
__BEGIN_DECLS
kern_return_t mach_port_allocate(ipc_space_t task, mach_port_right_t right, mach_port_name_t *name);
kern_return_t mach_port_deallocate(ipc_space_t task, mach_port_name_t name);
kern_return_t mach_port_destroy(ipc_space_t task, mach_port_name_t name);
kern_return_t mach_port_mod_refs(ipc_space_t task, mach_port_name_t name, mach_port_right_t right, mach_port_delta_t delta);
kern_return_t mach_port_get_refs(ipc_space_t task, mach_port_name_t name, mach_port_right_t right, mach_port_urefs_t *refs);
kern_return_t mach_port_insert_right(ipc_space_t task, mach_port_name_t name, mach_port_t poly, unsigned int polyPoly);
kern_return_t mach_port_type(ipc_space_t task, mach_port_name_t name, mach_port_type_t *ptype);
kern_return_t mach_port_construct(ipc_space_t task, mach_port_options_ptr_t options, mach_port_context_t context, mach_port_name_t *name);
kern_return_t mach_port_destruct(ipc_space_t task, mach_port_name_t name, mach_port_delta_t srdelta, mach_port_context_t guard);
kern_return_t mach_port_set_attributes(ipc_space_t task, mach_port_name_t name, mach_port_flavor_t flavor,
                                       mach_port_info_t info, mach_msg_type_number_t count);
kern_return_t mach_port_get_attributes(ipc_space_t task, mach_port_name_t name, mach_port_flavor_t flavor,
                                       mach_port_info_t info, mach_msg_type_number_t *count);
mach_port_t mach_reply_port(void);
__END_DECLS
