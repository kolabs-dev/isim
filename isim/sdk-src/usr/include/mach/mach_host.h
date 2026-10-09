#pragma once
/* isim SDK (self-authored): host information (the simulated device's memory; the host's processors and load). */
#include <mach/host_info.h>
#include <mach/processor_info.h>
#include <mach/clock_types.h>
#include <_isim_cdefs.h>
__BEGIN_DECLS
kern_return_t host_info(host_t host, host_flavor_t flavor, host_info_t info, mach_msg_type_number_t *count);
kern_return_t host_statistics(host_t host, host_flavor_t flavor, host_info_t info, mach_msg_type_number_t *count);
kern_return_t host_statistics64(host_t host, host_flavor_t flavor, host_info64_t info, mach_msg_type_number_t *count);
kern_return_t host_processor_info(host_t host, processor_flavor_t flavor, natural_t *processor_count,
                                  processor_info_array_t *info, mach_msg_type_number_t *info_count);
kern_return_t host_get_clock_service(host_t host, clock_id_t clock_id, clock_serv_t *clock_serv);
__END_DECLS
