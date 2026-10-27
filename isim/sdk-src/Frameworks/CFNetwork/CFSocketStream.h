#pragma once
/* isim SDK (self-authored, Apple's declarations and values): the socket stream properties (CoreFoundation's
 * CFStreamCreatePairWithSocketToHost streams; Foundation's NSStream keys are the same strings). Adapted: TLS
 * (kCFStreamPropertySSLSettings, kCFStreamPropertySocketSecurityLevel) runs through the host's OpenSSL and is set up
 * when the stream opens; kCFStreamPropertySSLPeerTrust is the peer's SecTrust. SOCKS proxies, network service types
 * and the cellular / expensive / constrained network properties are recorded, not acted on (connections are direct). */
#include <CoreFoundation/CoreFoundation.h>
#include <CFNetwork/CFNetworkErrors.h>
#include <CFNetwork/CFHost.h>
__BEGIN_DECLS
_Pragma("clang assume_nonnull begin")

CFN_EXPORT const CFStringRef kCFStreamPropertySSLPeerTrust;
CFN_EXPORT const CFStringRef kCFStreamSSLValidatesCertificateChain;
CFN_EXPORT const CFStringRef kCFStreamPropertySSLSettings;
CFN_EXPORT const CFStringRef kCFStreamSSLLevel;
CFN_EXPORT const CFStringRef kCFStreamSSLPeerName;
CFN_EXPORT const CFStringRef kCFStreamSSLCertificates;
CFN_EXPORT const CFStringRef kCFStreamSSLIsServer;

CFN_EXPORT const CFStringRef kCFStreamNetworkServiceType;
CFN_EXPORT const CFStringRef kCFStreamNetworkServiceTypeVideo;
CFN_EXPORT const CFStringRef kCFStreamNetworkServiceTypeVoice;
CFN_EXPORT const CFStringRef kCFStreamNetworkServiceTypeBackground;
CFN_EXPORT const CFStringRef kCFStreamNetworkServiceTypeResponsiveData;
CFN_EXPORT const CFStringRef kCFStreamNetworkServiceTypeCallSignaling;
CFN_EXPORT const CFStringRef kCFStreamNetworkServiceTypeAVStreaming;
CFN_EXPORT const CFStringRef kCFStreamNetworkServiceTypeResponsiveAV;
CFN_EXPORT const CFStringRef kCFStreamNetworkServiceTypeVoIP;

CFN_EXPORT const CFStringRef kCFStreamPropertyNoCellular;
CFN_EXPORT const CFStringRef kCFStreamPropertyConnectionIsCellular;
CFN_EXPORT const CFStringRef kCFStreamPropertyAllowExpensiveNetworkAccess;
CFN_EXPORT const CFStringRef kCFStreamPropertyConnectionIsExpensive;
CFN_EXPORT const CFStringRef kCFStreamPropertyAllowConstrainedNetworkAccess;

CFN_EXPORT const CFIndex kCFStreamErrorDomainWinSock;
CFN_EXPORT const int kCFStreamErrorDomainSOCKS;
CFN_EXPORT const int kCFStreamErrorDomainSSL;

/* the host a socket stream connects to (CFHost) */
CFN_EXPORT const CFStringRef kCFStreamPropertySocketRemoteHost;
CFN_EXPORT const CFStringRef kCFStreamPropertyProxyLocalBypass;
CFN_EXPORT const CFStringRef kCFStreamPropertySocketExtendedBackgroundIdleMode;

CFN_EXPORT void CFStreamCreatePairWithSocketToCFHost(CFAllocatorRef _Nullable alloc, CFHostRef host, SInt32 port,
                                                     CFReadStreamRef _Nullable *_Nullable readStream,
                                                     CFWriteStreamRef _Nullable *_Nullable writeStream);

CFN_EXPORT const CFStringRef kCFStreamPropertySOCKSProxy;
CFN_EXPORT const CFStringRef kCFStreamPropertySOCKSProxyHost;
CFN_EXPORT const CFStringRef kCFStreamPropertySOCKSProxyPort;
CFN_EXPORT const CFStringRef kCFStreamPropertySOCKSVersion;
CFN_EXPORT const CFStringRef kCFStreamSocketSOCKSVersion4;
CFN_EXPORT const CFStringRef kCFStreamSocketSOCKSVersion5;
CFN_EXPORT const CFStringRef kCFStreamPropertySOCKSUser;
CFN_EXPORT const CFStringRef kCFStreamPropertySOCKSPassword;

CFN_EXPORT const CFStringRef kCFStreamPropertySocketSecurityLevel;
CFN_EXPORT const CFStringRef kCFStreamSocketSecurityLevelNone;
CFN_EXPORT const CFStringRef kCFStreamSocketSecurityLevelSSLv2;
CFN_EXPORT const CFStringRef kCFStreamSocketSecurityLevelSSLv3;
CFN_EXPORT const CFStringRef kCFStreamSocketSecurityLevelTLSv1;
CFN_EXPORT const CFStringRef kCFStreamSocketSecurityLevelNegotiatedSSL;

/* whether closing the streams closes the native socket (CFBoolean; default: true for streams that made their own
   socket, false for CFStreamCreatePairWithSocket) */
CFN_EXPORT const CFStringRef kCFStreamPropertyShouldCloseNativeSocket;

typedef CF_ENUM(int, CFStreamErrorSOCKSSubDomain) {
    kCFStreamErrorSOCKSSubDomainNone = 0,
    kCFStreamErrorSOCKSSubDomainVersionCode = 1,
    kCFStreamErrorSOCKS4SubDomainResponse = 2,
    kCFStreamErrorSOCKS5SubDomainUserPass = 3,
    kCFStreamErrorSOCKS5SubDomainMethod = 4,
    kCFStreamErrorSOCKS5SubDomainResponse = 5
};
CFN_EXPORT SInt32 CFSocketStreamSOCKSGetErrorSubdomain(const CFStreamError *error);
CFN_EXPORT SInt32 CFSocketStreamSOCKSGetError(const CFStreamError *error);

_Pragma("clang assume_nonnull end")
__END_DECLS
