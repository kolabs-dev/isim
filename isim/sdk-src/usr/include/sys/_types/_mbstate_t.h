#pragma once
/* Darwin __mbstate_t layout */
typedef union { char __mbstate8[128]; long long _mbstateL; } __mbstate_t;
typedef __mbstate_t mbstate_t;
