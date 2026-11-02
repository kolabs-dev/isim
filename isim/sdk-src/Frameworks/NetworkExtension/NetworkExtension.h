#pragma once
/* isim NetworkExtension for Objective-C (issue #424): the classes are the NetworkExtension Swift overlay's
   (NetworkExtension.framework re-exports libswiftNetworkExtension.dylib); Swift uses the overlay, so these declarations
   are hidden from Swift. The managers' configurations are stored per app in the device data; tunnels are simulated
   (no traffic is routed). NEURLFilterManager is Swift only, like Apple's. */
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

/* MARK: hotspots */

FOUNDATION_EXPORT NSString * const NEHotspotConfigurationErrorDomain;
typedef NS_ENUM(NSInteger, NEHotspotConfigurationError) {
    NEHotspotConfigurationErrorInvalid = 0, NEHotspotConfigurationErrorInvalidSSID = 1, NEHotspotConfigurationErrorInvalidWPAPassphrase = 2,
    NEHotspotConfigurationErrorInvalidWEPPassphrase = 3, NEHotspotConfigurationErrorInvalidEAPSettings = 4,
    NEHotspotConfigurationErrorInvalidHS20Settings = 5, NEHotspotConfigurationErrorInvalidHS20DomainName = 6,
    NEHotspotConfigurationErrorUserDenied = 7, NEHotspotConfigurationErrorInternal = 8, NEHotspotConfigurationErrorPending = 9,
    NEHotspotConfigurationErrorSystemConfiguration = 10, NEHotspotConfigurationErrorUnknown = 11, NEHotspotConfigurationErrorJoinOnceNotSupported = 12,
    NEHotspotConfigurationErrorAlreadyAssociated = 13, NEHotspotConfigurationErrorApplicationIsNotInForeground = 14,
    NEHotspotConfigurationErrorInvalidSSIDPrefix = 15, NEHotspotConfigurationErrorUserUnauthorized = 16, NEHotspotConfigurationErrorSystemDenied = 17,
};
typedef NS_ENUM(NSInteger, NEHotspotConfigurationEAPType) {
    NEHotspotConfigurationEAPTypeEAPTLS = 13, NEHotspotConfigurationEAPTypeEAPTTLS = 21,
    NEHotspotConfigurationEAPTypeEAPPEAP = 25, NEHotspotConfigurationEAPTypeEAPFAST = 43,
};
typedef NS_ENUM(NSInteger, NEHotspotConfigurationTTLSInnerAuthenticationType) {
    NEHotspotConfigurationEAPTTLSInnerAuthenticationPAP = 0, NEHotspotConfigurationEAPTTLSInnerAuthenticationCHAP = 1,
    NEHotspotConfigurationEAPTTLSInnerAuthenticationMSCHAP = 2, NEHotspotConfigurationEAPTTLSInnerAuthenticationMSCHAPv2 = 3,
    NEHotspotConfigurationEAPTTLSInnerAuthenticationEAP = 4,
};
typedef NS_ENUM(NSInteger, NEHotspotConfigurationEAPTLSVersion) {
    NEHotspotConfigurationEAPTLSVersion_1_0 = 0, NEHotspotConfigurationEAPTLSVersion_1_1 = 1, NEHotspotConfigurationEAPTLSVersion_1_2 = 2,
};

@interface NEHotspotHS20Settings : NSObject <NSCopying>
- (instancetype)initWithDomainName:(NSString *)domainName roamingEnabled:(BOOL)roamingEnabled;
@property (readonly) NSString *domainName;
@property (getter=isRoamingEnabled) BOOL roamingEnabled;
@property (copy) NSArray<NSString *> *roamingConsortiumOIs;
@property (copy) NSArray<NSString *> *naiRealmNames;
@property (copy) NSArray<NSString *> *MCCAndMNCs;
@end

@interface NEHotspotEAPSettings : NSObject <NSCopying>
@property (copy) NSArray<NSNumber *> *supportedEAPTypes;
@property (copy) NSString *username;
@property (copy) NSString *outerIdentity;
@property NEHotspotConfigurationTTLSInnerAuthenticationType ttlsInnerAuthenticationType;
@property (copy) NSString *password;
@property (copy) NSArray<NSString *> *trustedServerNames;
@property (getter=isTLSClientCertificateRequired) BOOL tlsClientCertificateRequired;
@property NEHotspotConfigurationEAPTLSVersion preferredTLSVersion;
- (BOOL)setIdentity:(SecIdentityRef)identity;
- (BOOL)setTrustedServerCertificates:(NSArray *)certificates;
@end

@interface NEHotspotConfiguration : NSObject <NSCopying>
@property (readonly) NSString *SSID;
@property (readonly) NSString *SSIDPrefix;
@property BOOL joinOnce;
@property (copy) NSNumber *lifeTimeInDays;
@property BOOL hidden;
- (instancetype)initWithSSID:(NSString *)SSID;
- (instancetype)initWithSSID:(NSString *)SSID passphrase:(NSString *)passphrase isWEP:(BOOL)isWEP;
- (instancetype)initWithSSID:(NSString *)SSID eapSettings:(NEHotspotEAPSettings *)eapSettings;
- (instancetype)initWithHS20Settings:(NEHotspotHS20Settings *)hs20Settings eapSettings:(NEHotspotEAPSettings *)eapSettings;
- (instancetype)initWithSSIDPrefix:(NSString *)SSIDPrefix;
- (instancetype)initWithSSIDPrefix:(NSString *)SSIDPrefix passphrase:(NSString *)passphrase isWEP:(BOOL)isWEP;
@end

@interface NEHotspotConfigurationManager : NSObject
@property (class, readonly, strong) NEHotspotConfigurationManager *sharedManager;
- (void)applyConfiguration:(NEHotspotConfiguration *)configuration completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)removeConfigurationForSSID:(NSString *)SSID;
- (void)removeConfigurationForHS20DomainName:(NSString *)domainName;
- (void)getConfiguredSSIDsWithCompletionHandler:(void (^)(NSArray<NSString *> *))completionHandler;
@end

/* MARK: VPN */

FOUNDATION_EXPORT NSString * const NEVPNErrorDomain;
typedef NS_ENUM(NSInteger, NEVPNError) {
    NEVPNErrorConfigurationInvalid = 1, NEVPNErrorConfigurationDisabled = 2, NEVPNErrorConnectionFailed = 3,
    NEVPNErrorConfigurationStale = 4, NEVPNErrorConfigurationReadWriteFailed = 5, NEVPNErrorConfigurationUnknown = 6,
};
FOUNDATION_EXPORT NSString * const NEVPNConnectionErrorDomain;
typedef NS_ENUM(NSInteger, NEVPNConnectionError) {
    NEVPNConnectionErrorOverslept = 1, NEVPNConnectionErrorNoNetworkAvailable = 2, NEVPNConnectionErrorUnrecoverableNetworkChange = 3,
    NEVPNConnectionErrorConfigurationFailed = 4, NEVPNConnectionErrorServerAddressResolutionFailed = 5, NEVPNConnectionErrorServerNotResponding = 6,
    NEVPNConnectionErrorServerDead = 7, NEVPNConnectionErrorAuthenticationFailed = 8, NEVPNConnectionErrorClientCertificateInvalid = 9,
    NEVPNConnectionErrorClientCertificateNotYetValid = 10, NEVPNConnectionErrorClientCertificateExpired = 11, NEVPNConnectionErrorPluginFailed = 12,
    NEVPNConnectionErrorConfigurationNotFound = 13, NEVPNConnectionErrorPluginDisabled = 14, NEVPNConnectionErrorNegotiationFailed = 15,
    NEVPNConnectionErrorServerDisconnected = 16, NEVPNConnectionErrorServerCertificateInvalid = 17,
    NEVPNConnectionErrorServerCertificateNotYetValid = 18, NEVPNConnectionErrorServerCertificateExpired = 19,
};
typedef NS_ENUM(NSInteger, NEVPNStatus) {
    NEVPNStatusInvalid = 0, NEVPNStatusDisconnected = 1, NEVPNStatusConnecting = 2, NEVPNStatusConnected = 3,
    NEVPNStatusReasserting = 4, NEVPNStatusDisconnecting = 5,
};
FOUNDATION_EXPORT NSString * const NEVPNStatusDidChangeNotification;
FOUNDATION_EXPORT NSString * const NEVPNConfigurationChangeNotification;
FOUNDATION_EXPORT NSString * const NEVPNConnectionStartOptionUsername;
FOUNDATION_EXPORT NSString * const NEVPNConnectionStartOptionPassword;

@interface NEProxyServer : NSObject <NSCopying>
- (instancetype)initWithAddress:(NSString *)address port:(NSInteger)port;
@property (readonly) NSString *address;
@property (readonly) NSInteger port;
@property BOOL authenticationRequired;
@property (copy, nullable) NSString *username;
@property (copy, nullable) NSString *password;
@end

@interface NEProxySettings : NSObject <NSCopying>
@property BOOL autoProxyConfigurationEnabled;
@property (copy, nullable) NSURL *proxyAutoConfigurationURL;
@property (copy, nullable) NSString *proxyAutoConfigurationJavaScript;
@property BOOL HTTPEnabled;
@property (copy, nullable) NEProxyServer *HTTPServer;
@property BOOL HTTPSEnabled;
@property (copy, nullable) NEProxyServer *HTTPSServer;
@property BOOL excludeSimpleHostnames;
@property (copy, nullable) NSArray<NSString *> *exceptionList;
@property (copy, nullable) NSArray<NSString *> *matchDomains;
@end

@interface NEVPNProtocol : NSObject <NSCopying>
@property (copy, nullable) NSString *serverAddress;
@property (copy, nullable) NSString *username;
@property (copy, nullable) NSData *passwordReference;
@property (copy, nullable) NSData *identityReference;
@property (copy, nullable) NSData *identityData;
@property (copy, nullable) NSString *identityDataPassword;
@property BOOL disconnectOnSleep;
@property (copy, nullable) NEProxySettings *proxySettings;
@property BOOL includeAllNetworks;
@property BOOL excludeLocalNetworks;
@property BOOL excludeCellularServices;
@property BOOL excludeAPNs;
@property BOOL excludeDeviceCommunication;
@property BOOL enforceRoutes;
@property (copy, nullable) NSString *sliceUUID;
@end

typedef NS_ENUM(NSInteger, NEVPNIKEAuthenticationMethod) {
    NEVPNIKEAuthenticationMethodNone = 0, NEVPNIKEAuthenticationMethodCertificate = 1, NEVPNIKEAuthenticationMethodSharedSecret = 2,
};
@interface NEVPNProtocolIPSec : NEVPNProtocol
@property NEVPNIKEAuthenticationMethod authenticationMethod;
@property BOOL useExtendedAuthentication;
@property (copy, nullable) NSData *sharedSecretReference;
@property (copy, nullable) NSString *localIdentifier;
@property (copy, nullable) NSString *remoteIdentifier;
@end

typedef NS_ENUM(NSInteger, NEVPNIKEv2EncryptionAlgorithm) {
    NEVPNIKEv2EncryptionAlgorithmAES128 = 3, NEVPNIKEv2EncryptionAlgorithmAES256 = 4, NEVPNIKEv2EncryptionAlgorithmAES128GCM = 5,
    NEVPNIKEv2EncryptionAlgorithmAES256GCM = 6, NEVPNIKEv2EncryptionAlgorithmChaCha20Poly1305 = 7,
};
typedef NS_ENUM(NSInteger, NEVPNIKEv2IntegrityAlgorithm) {
    NEVPNIKEv2IntegrityAlgorithmSHA256 = 3, NEVPNIKEv2IntegrityAlgorithmSHA384 = 4, NEVPNIKEv2IntegrityAlgorithmSHA512 = 5,
};
typedef NS_ENUM(NSInteger, NEVPNIKEv2DeadPeerDetectionRate) {
    NEVPNIKEv2DeadPeerDetectionRateNone = 0, NEVPNIKEv2DeadPeerDetectionRateLow = 1,
    NEVPNIKEv2DeadPeerDetectionRateMedium = 2, NEVPNIKEv2DeadPeerDetectionRateHigh = 3,
};
typedef NS_ENUM(NSInteger, NEVPNIKEv2DiffieHellmanGroup) {
    NEVPNIKEv2DiffieHellmanGroupInvalid = 0, NEVPNIKEv2DiffieHellmanGroup14 = 14, NEVPNIKEv2DiffieHellmanGroup15 = 15,
    NEVPNIKEv2DiffieHellmanGroup16 = 16, NEVPNIKEv2DiffieHellmanGroup17 = 17, NEVPNIKEv2DiffieHellmanGroup18 = 18,
    NEVPNIKEv2DiffieHellmanGroup19 = 19, NEVPNIKEv2DiffieHellmanGroup20 = 20, NEVPNIKEv2DiffieHellmanGroup21 = 21,
    NEVPNIKEv2DiffieHellmanGroup31 = 31, NEVPNIKEv2DiffieHellmanGroup32 = 32,
};
typedef NS_ENUM(NSInteger, NEVPNIKEv2CertificateType) {
    NEVPNIKEv2CertificateTypeRSA = 1, NEVPNIKEv2CertificateTypeECDSA256 = 2, NEVPNIKEv2CertificateTypeECDSA384 = 3,
    NEVPNIKEv2CertificateTypeECDSA521 = 4, NEVPNIKEv2CertificateTypeEd25519 = 5, NEVPNIKEv2CertificateTypeRSAPSS = 6,
};
typedef NS_ENUM(NSInteger, NEVPNIKEv2TLSVersion) {
    NEVPNIKEv2TLSVersionDefault = 0, NEVPNIKEv2TLSVersion1_0 = 1, NEVPNIKEv2TLSVersion1_1 = 2,
    NEVPNIKEv2TLSVersion1_2 = 3, NEVPNIKEv2TLSVersion1_3 = 4,
};
typedef NS_ENUM(NSInteger, NEVPNIKEv2PostQuantumKeyExchangeMethod) {
    NEVPNIKEv2PostQuantumKeyExchangeMethodNone = 0, NEVPNIKEv2PostQuantumKeyExchangeMethod36 = 36, NEVPNIKEv2PostQuantumKeyExchangeMethod37 = 37,
};

@interface NEVPNIKEv2SecurityAssociationParameters : NSObject <NSCopying>
@property NEVPNIKEv2EncryptionAlgorithm encryptionAlgorithm;
@property NEVPNIKEv2IntegrityAlgorithm integrityAlgorithm;
@property NEVPNIKEv2DiffieHellmanGroup diffieHellmanGroup;
@property int32_t lifetimeMinutes;
@property (copy) NSArray<NSNumber *> *postQuantumKeyExchangeMethods;
@end

@interface NEVPNIKEv2PPKConfiguration : NSObject <NSCopying>
- (instancetype)initWithIdentifier:(NSString *)identifier keychainReference:(NSData *)keychainReference;
@property (readonly, copy) NSString *identifier;
@property (readonly, copy) NSData *keychainReference;
@property BOOL isMandatory;
@end

@interface NEVPNProtocolIKEv2 : NEVPNProtocolIPSec
@property NEVPNIKEv2DeadPeerDetectionRate deadPeerDetectionRate;
@property (copy, nullable) NSString *serverCertificateIssuerCommonName;
@property (copy, nullable) NSString *serverCertificateCommonName;
@property NEVPNIKEv2CertificateType certificateType;
@property BOOL useConfigurationAttributeInternalIPSubnet;
@property (readonly) NEVPNIKEv2SecurityAssociationParameters *IKESecurityAssociationParameters;
@property (readonly) NEVPNIKEv2SecurityAssociationParameters *childSecurityAssociationParameters;
@property BOOL disableMOBIKE;
@property BOOL disableRedirect;
@property BOOL enablePFS;
@property BOOL allowPostQuantumKeyExchangeFallback;
@property BOOL enableRevocationCheck;
@property BOOL strictRevocationCheck;
@property NEVPNIKEv2TLSVersion minimumTLSVersion;
@property NEVPNIKEv2TLSVersion maximumTLSVersion;
@property BOOL enableFallback;
@property NSUInteger mtu;
@property (copy, nullable) NEVPNIKEv2PPKConfiguration *ppkConfiguration;
@end

typedef NS_ENUM(NSInteger, NEOnDemandRuleAction) {
    NEOnDemandRuleActionConnect = 1, NEOnDemandRuleActionDisconnect = 2, NEOnDemandRuleActionEvaluateConnection = 3, NEOnDemandRuleActionIgnore = 4,
};
typedef NS_ENUM(NSInteger, NEOnDemandRuleInterfaceType) {
    NEOnDemandRuleInterfaceTypeAny = 0, NEOnDemandRuleInterfaceTypeEthernet = 1, NEOnDemandRuleInterfaceTypeWiFi = 2, NEOnDemandRuleInterfaceTypeCellular = 3,
};
typedef NS_ENUM(NSInteger, NEEvaluateConnectionRuleAction) {
    NEEvaluateConnectionRuleActionConnectIfNeeded = 1, NEEvaluateConnectionRuleActionNeverConnect = 2,
};

@interface NEEvaluateConnectionRule : NSObject <NSCopying>
- (instancetype)initWithMatchDomains:(NSArray<NSString *> *)domains andAction:(NEEvaluateConnectionRuleAction)action;
@property (readonly) NEEvaluateConnectionRuleAction action;
@property (readonly) NSArray<NSString *> *matchDomains;
@property (copy, nullable) NSArray<NSString *> *useDNSServers;
@property (copy, nullable) NSURL *probeURL;
@end

@interface NEOnDemandRule : NSObject <NSCopying>
@property (readonly) NEOnDemandRuleAction action;
@property (copy, nullable) NSArray<NSString *> *DNSSearchDomainMatch;
@property (copy, nullable) NSArray<NSString *> *DNSServerAddressMatch;
@property NEOnDemandRuleInterfaceType interfaceTypeMatch;
@property (copy, nullable) NSArray<NSString *> *SSIDMatch;
@property (copy, nullable) NSURL *probeURL;
@end
@interface NEOnDemandRuleConnect : NEOnDemandRule
@end
@interface NEOnDemandRuleDisconnect : NEOnDemandRule
@end
@interface NEOnDemandRuleIgnore : NEOnDemandRule
@end
@interface NEOnDemandRuleEvaluateConnection : NEOnDemandRule
@property (copy, nullable) NSArray<NEEvaluateConnectionRule *> *connectionRules;
@end

@class NEVPNManager;
@interface NEVPNConnection : NSObject
- (BOOL)startVPNTunnelAndReturnError:(NSError **)error;
- (BOOL)startVPNTunnelWithOptions:(nullable NSDictionary<NSString *, NSObject *> *)options andReturnError:(NSError **)error;
- (void)stopVPNTunnel;
- (void)fetchLastDisconnectErrorWithCompletionHandler:(void (^)(NSError * _Nullable error))handler;
@property (readonly) NEVPNStatus status;
@property (readonly, nullable) NSDate *connectedDate;
@property (readonly) NEVPNManager *manager;
@end

@interface NEVPNManager : NSObject
+ (NEVPNManager *)sharedManager NS_SWIFT_NAME(shared());
- (void)loadFromPreferencesWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)removeFromPreferencesWithCompletionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)saveToPreferencesWithCompletionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
@property (copy, nullable) NSArray<NEOnDemandRule *> *onDemandRules;
@property (getter=isOnDemandEnabled) BOOL onDemandEnabled;
@property (copy, nullable) NSString *localizedDescription;
@property (strong, nullable) NEVPNProtocol *protocolConfiguration;
@property (readonly) NEVPNConnection *connection;
@property (getter=isEnabled) BOOL enabled;
@end

/* MARK: tunnel providers */

typedef NS_ENUM(NSInteger, NETunnelProviderRoutingMethod) {
    NETunnelProviderRoutingMethodDestinationIP = 1, NETunnelProviderRoutingMethodSourceApplication = 2, NETunnelProviderRoutingMethodNetworkRule = 3,
};

@interface NETunnelProviderProtocol : NEVPNProtocol
@property (copy, nullable) NSDictionary<NSString *, id> *providerConfiguration;
@property (copy, nullable) NSString *providerBundleIdentifier;
@end

@interface NEAppRule : NSObject <NSCopying>
- (instancetype)initWithSigningIdentifier:(NSString *)signingIdentifier;
- (instancetype)initWithSigningIdentifier:(NSString *)signingIdentifier designatedRequirement:(NSString *)designatedRequirement;
@property (readonly) NSString *matchSigningIdentifier;
@property (readonly) NSString *matchDesignatedRequirement;
@property (copy, nullable) NSString *matchPath;
@property (copy, nullable) NSArray *matchDomains;
@property (copy, nullable) NSArray<NEAppRule *> *matchTools;
@end

@interface NETunnelProviderSession : NEVPNConnection
- (BOOL)startTunnelWithOptions:(nullable NSDictionary<NSString *, id> *)options andReturnError:(NSError **)error;
- (void)stopTunnel;
- (BOOL)sendProviderMessage:(NSData *)messageData returnError:(NSError **)error
            responseHandler:(void (^ _Nullable)(NSData * _Nullable responseData))responseHandler;
@end

@interface NETunnelProviderManager : NEVPNManager
+ (void)loadAllFromPreferencesWithCompletionHandler:(void (^)(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error))completionHandler;
+ (instancetype)forPerAppVPN;
- (nullable NSArray<NEAppRule *> *)copyAppRules;
@property (readonly) NETunnelProviderRoutingMethod routingMethod;
@property (copy) NSArray<NSString *> *safariDomains;
@property (copy) NSArray<NSString *> *mailDomains;
@property (copy) NSArray<NSString *> *calendarDomains;
@property (copy) NSArray<NSString *> *contactsDomains;
@property (copy) NSArray<NSString *> *associatedDomains;
@property (copy) NSArray<NSString *> *excludedDomains;
@property (copy) NSArray<NEAppRule *> *appRules;
@end

/* MARK: app push */

FOUNDATION_EXPORT NSString * const NEAppPushErrorDomain API_AVAILABLE(ios(14.0));
typedef NS_ERROR_ENUM(NEAppPushErrorDomain, NEAppPushManagerError) {
    NEAppPushManagerErrorConfigurationInvalid = 1, NEAppPushManagerErrorConfigurationNotLoaded = 2,
    NEAppPushManagerErrorInternalError = 3, NEAppPushManagerErrorInactiveSession = 4,
} API_AVAILABLE(ios(14.0));

@interface NEPrivateLTENetwork : NSObject <NSCopying>
@property (copy) NSString *mobileCountryCode;
@property (copy) NSString *mobileNetworkCode;
@property (copy, nullable) NSString *trackingAreaCode;
@end

@class NEAppPushManager;
@protocol NEAppPushDelegate <NSObject>
- (void)appPushManager:(NEAppPushManager *)manager didReceiveIncomingCallWithUserInfo:(NSDictionary *)userInfo;
@end

API_AVAILABLE(ios(14.0))
@interface NEAppPushManager : NSObject
@property (copy) NSArray<NSString *> *matchSSIDs;
@property (copy) NSArray<NEPrivateLTENetwork *> *matchPrivateLTENetworks;
@property BOOL matchEthernet;
@property BOOL matchMissionCriticalService API_AVAILABLE(ios(27.0));
@property (copy) NSDictionary<NSString *, id> *providerConfiguration;
@property (copy, nullable) NSString *providerBundleIdentifier;
@property (weak, nullable) id<NEAppPushDelegate> delegate;
+ (void)loadAllFromPreferencesWithCompletionHandler:(void (^)(NSArray<NEAppPushManager *> * _Nullable managers, NSError * _Nullable error))completionHandler;
- (void)loadFromPreferencesWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)removeFromPreferencesWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)saveToPreferencesWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;
@property (copy, nullable) NSString *localizedDescription;
@property (getter=isEnabled) BOOL enabled;
@property (readonly, getter=isActive) BOOL active;
@end

NS_ASSUME_NONNULL_END
#endif
