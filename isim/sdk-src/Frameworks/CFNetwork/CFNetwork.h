#pragma once
/* isim CFNetwork (self-authored, Apple's declarations and values). Adapted: CFHost resolves through the host's resolver
   (getaddrinfo / getnameinfo). The rest of CFNetwork (CFHTTPMessage, CFNetServices, CFProxySupport, the socket streams)
   is not in isim yet (docs/frameworks/CFNetwork.md). */
#include <CoreFoundation/CoreFoundation.h>
#include <CFNetwork/CFNetworkErrors.h>
#include <CFNetwork/CFHost.h>
