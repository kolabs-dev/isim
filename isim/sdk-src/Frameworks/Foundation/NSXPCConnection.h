#pragma once
/* isim Foundation: NSXPCConnection, NSXPCListener, NSXPCInterface, NSXPCListenerEndpoint, NSXPCCoder (Apple's API).
 * Adapted: over isim's XPC connections (a named service is reachable from every process of the booted device); a remote
 * object proxy sends each message as an XPC message carrying the selector and the archived arguments (NSSecureCoding
 * objects and numbers), and a reply block's arguments come back the same way. */
#import <Foundation/NSObject.h>
#import <Foundation/NSError.h>
#import <Foundation/NSCoder.h>
#include <xpc/base.h>

NS_ASSUME_NONNULL_BEGIN

@class NSXPCConnection, NSXPCListener, NSXPCInterface, NSXPCListenerEndpoint, NSSet<ObjectType>, NSString, NSLock;
@protocol NSXPCListenerDelegate;

@protocol NSXPCProxyCreating
- (id)remoteObjectProxy;
- (id)remoteObjectProxyWithErrorHandler:(void (^)(NSError *error))handler;
@optional
- (id)synchronousRemoteObjectProxyWithErrorHandler:(void (^)(NSError *error))handler;
@end

typedef NS_OPTIONS(NSUInteger, NSXPCConnectionOptions) {
    NSXPCConnectionPrivileged = (1 << 12UL)
};

@interface NSXPCConnection : NSObject <NSXPCProxyCreating>
- (instancetype)initWithServiceName:(NSString *)serviceName;
@property (nullable, readonly, copy) NSString *serviceName;
- (instancetype)initWithMachServiceName:(NSString *)name options:(NSXPCConnectionOptions)options;
- (instancetype)initWithListenerEndpoint:(NSXPCListenerEndpoint *)endpoint;
@property (readonly, retain) NSXPCListenerEndpoint *endpoint;
@property (nullable, retain) NSXPCInterface *exportedInterface;
@property (nullable, retain) id exportedObject;
@property (nullable, retain) NSXPCInterface *remoteObjectInterface;
@property (readonly, retain) id remoteObjectProxy;
- (id)remoteObjectProxyWithErrorHandler:(void (^)(NSError *error))handler;
- (id)synchronousRemoteObjectProxyWithErrorHandler:(void (^)(NSError *error))handler;
@property (nullable, copy) void (^interruptionHandler)(void);
@property (nullable, copy) void (^invalidationHandler)(void);
- (void)resume;
- (void)suspend;
- (void)activate;
- (void)invalidate;
@property (readonly) au_asid_t auditSessionIdentifier;
@property (readonly) pid_t processIdentifier;
@property (readonly) uid_t effectiveUserIdentifier;
@property (readonly) gid_t effectiveGroupIdentifier;
+ (nullable NSXPCConnection *)currentConnection;
- (void)scheduleSendBarrierBlock:(void (^)(void))block;
- (void)setCodeSigningRequirement:(NSString *)requirement;
@end

@interface NSXPCListener : NSObject
+ (NSXPCListener *)serviceListener;
+ (NSXPCListener *)anonymousListener;
- (instancetype)initWithMachServiceName:(NSString *)name NS_DESIGNATED_INITIALIZER;
@property (nullable, weak) id <NSXPCListenerDelegate> delegate;
@property (readonly, retain) NSXPCListenerEndpoint *endpoint;
- (void)resume;
- (void)suspend;
- (void)activate;
- (void)invalidate;
- (void)setConnectionCodeSigningRequirement:(NSString *)requirement;
@end

@protocol NSXPCListenerDelegate <NSObject>
@optional
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection;
@end

@interface NSXPCInterface : NSObject
+ (NSXPCInterface *)interfaceWithProtocol:(Protocol *)protocol;
@property (assign) Protocol *protocol;
- (void)setClasses:(NSSet<Class> *)classes forSelector:(SEL)sel argumentIndex:(NSUInteger)arg ofReply:(BOOL)ofReply;
- (NSSet<Class> *)classesForSelector:(SEL)sel argumentIndex:(NSUInteger)arg ofReply:(BOOL)ofReply;
- (void)setInterface:(NSXPCInterface *)ifc forSelector:(SEL)sel argumentIndex:(NSUInteger)arg ofReply:(BOOL)ofReply;
- (nullable NSXPCInterface *)interfaceForSelector:(SEL)sel argumentIndex:(NSUInteger)arg ofReply:(BOOL)ofReply;
- (void)setXPCType:(xpc_type_t)type forSelector:(SEL)sel argumentIndex:(NSUInteger)arg ofReply:(BOOL)ofReply;
- (nullable xpc_type_t)XPCTypeForSelector:(SEL)sel argumentIndex:(NSUInteger)arg ofReply:(BOOL)ofReply;
@end

@interface NSXPCListenerEndpoint : NSObject <NSSecureCoding>
@end

@interface NSXPCCoder : NSCoder
@property (nullable, retain) id userInfo;
@property (nullable, readonly, strong) NSXPCConnection *connection;
- (void)encodeXPCObject:(xpc_object_t)xpcObject forKey:(NSString *)key;
- (nullable xpc_object_t)decodeXPCObjectOfType:(xpc_type_t)type forKey:(NSString *)key;
@end

NS_ASSUME_NONNULL_END
