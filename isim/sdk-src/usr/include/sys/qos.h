#pragma once
/* isim: Quality-of-service classes. isim has no QoS scheduling: threads report the class
 * they were asked for (main thread: user-interactive), nothing changes priority. */
#include <_isim_cdefs.h>
__BEGIN_DECLS
typedef unsigned int qos_class_t;
#define QOS_CLASS_USER_INTERACTIVE 0x21u
#define QOS_CLASS_USER_INITIATED 0x19u
#define QOS_CLASS_DEFAULT 0x15u
#define QOS_CLASS_UTILITY 0x11u
#define QOS_CLASS_BACKGROUND 0x09u
#define QOS_CLASS_UNSPECIFIED 0x00u
#define QOS_MIN_RELATIVE_PRIORITY (-15)
qos_class_t qos_class_self(void);
qos_class_t qos_class_main(void);
__END_DECLS
