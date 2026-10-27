// isim CFNetwork: the socket stream properties (adapted). The streams are CoreFoundation's (Foundation's Streams.m,
// toll-free bridged with NSStream); these are their CFNetwork keys, the same strings as Foundation's NSStream keys.
// TLS settings are read when a stream opens; SOCKS, network service types and the cellular / expensive / constrained
// properties are kept as properties and not acted on.
#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>
#include <netinet/in.h>
#include <sys/socket.h>

#define KEY(name) const CFStringRef name = CFSTR(#name);
KEY(kCFStreamPropertySSLPeerTrust) KEY(kCFStreamSSLValidatesCertificateChain) KEY(kCFStreamPropertySSLSettings) KEY(kCFStreamSSLLevel)
KEY(kCFStreamSSLPeerName) KEY(kCFStreamSSLCertificates) KEY(kCFStreamSSLIsServer)
KEY(kCFStreamNetworkServiceType) KEY(kCFStreamNetworkServiceTypeVideo) KEY(kCFStreamNetworkServiceTypeVoice)
KEY(kCFStreamNetworkServiceTypeBackground) KEY(kCFStreamNetworkServiceTypeResponsiveData) KEY(kCFStreamNetworkServiceTypeCallSignaling)
KEY(kCFStreamNetworkServiceTypeAVStreaming) KEY(kCFStreamNetworkServiceTypeResponsiveAV) KEY(kCFStreamNetworkServiceTypeVoIP)
KEY(kCFStreamPropertyNoCellular) KEY(kCFStreamPropertyConnectionIsCellular) KEY(kCFStreamPropertyAllowExpensiveNetworkAccess)
KEY(kCFStreamPropertyConnectionIsExpensive) KEY(kCFStreamPropertyAllowConstrainedNetworkAccess)
KEY(kCFStreamPropertySocketRemoteHost) KEY(kCFStreamPropertyProxyLocalBypass) KEY(kCFStreamPropertySocketExtendedBackgroundIdleMode)
KEY(kCFStreamPropertySOCKSProxy) KEY(kCFStreamPropertySOCKSProxyHost) KEY(kCFStreamPropertySOCKSProxyPort) KEY(kCFStreamPropertySOCKSVersion)
KEY(kCFStreamSocketSOCKSVersion4) KEY(kCFStreamSocketSOCKSVersion5) KEY(kCFStreamPropertySOCKSUser) KEY(kCFStreamPropertySOCKSPassword)
KEY(kCFStreamPropertySocketSecurityLevel) KEY(kCFStreamSocketSecurityLevelNone) KEY(kCFStreamSocketSecurityLevelSSLv2)
KEY(kCFStreamSocketSecurityLevelSSLv3) KEY(kCFStreamSocketSecurityLevelTLSv1) KEY(kCFStreamSocketSecurityLevelNegotiatedSSL)
KEY(kCFStreamPropertyShouldCloseNativeSocket)

const CFIndex kCFStreamErrorDomainWinSock = 10;
const int kCFStreamErrorDomainSOCKS = 5;
const int kCFStreamErrorDomainSSL = 3;

/* to the host's name, or its first resolved address */
void CFStreamCreatePairWithSocketToCFHost(CFAllocatorRef alloc, CFHostRef host, SInt32 port, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream) {
    CFArrayRef names = CFHostGetNames(host, NULL);
    if (names && CFArrayGetCount(names)) {
        CFStreamCreatePairWithSocketToHost(alloc, CFArrayGetValueAtIndex(names, 0), (UInt32)port, readStream, writeStream);
        return;
    }
    CFArrayRef addrs = CFHostGetAddressing(host, NULL);
    if (!addrs || !CFArrayGetCount(addrs)) { if (readStream) *readStream = NULL; if (writeStream) *writeStream = NULL; return; }
    NSMutableData *a = [(__bridge NSData *)CFArrayGetValueAtIndex(addrs, 0) mutableCopy];
    struct sockaddr *sa = a.mutableBytes;
    if (sa->sa_family == AF_INET && a.length >= sizeof(struct sockaddr_in)) ((struct sockaddr_in *)sa)->sin_port = htons((uint16_t)port);
    else if (sa->sa_family == AF_INET6 && a.length >= sizeof(struct sockaddr_in6)) ((struct sockaddr_in6 *)sa)->sin6_port = htons((uint16_t)port);
    CFSocketSignature sig = { sa->sa_family, SOCK_STREAM, IPPROTO_TCP, (__bridge CFDataRef)a };
    CFStreamCreatePairWithPeerSocketSignature(alloc, &sig, readStream, writeStream);
}
SInt32 CFSocketStreamSOCKSGetErrorSubdomain(const CFStreamError *error) { return (error->error >> 16) & 0xffff; }
SInt32 CFSocketStreamSOCKSGetError(const CFStreamError *error) { return error->error & 0xffff; }
