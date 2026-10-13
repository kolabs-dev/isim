#pragma once
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScript.h>
NS_ASSUME_NONNULL_BEGIN
@class JSVirtualMachine, JSValue;
/* a JavaScript global context of the host's JavaScriptCore */
@interface JSContext : NSObject
- (instancetype)init;
- (instancetype)initWithVirtualMachine:(JSVirtualMachine *)virtualMachine;
- (nullable JSValue *)evaluateScript:(NSString *)script;
- (nullable JSValue *)evaluateScript:(NSString *)script withSourceURL:(nullable NSURL *)sourceURL;
+ (nullable JSContext *)currentContext;
+ (nullable JSValue *)currentCallee;
+ (nullable JSValue *)currentThis;
+ (nullable NSArray *)currentArguments;
@property (readonly, strong) JSValue *globalObject;
@property (nullable, strong) JSValue *exception;
@property (copy) void (^exceptionHandler)(JSContext * _Nullable context, JSValue * _Nullable exception);
@property (readonly, strong) JSVirtualMachine *virtualMachine;
@property (nullable, copy) NSString *name;
@property (getter=isInspectable) BOOL inspectable;
+ (JSContext *)contextWithJSGlobalContextRef:(JSGlobalContextRef)jsGlobalContextRef;
@property (readonly) JSGlobalContextRef JSGlobalContextRef;
@end
@interface JSContext (SubscriptSupport)
- (nullable JSValue *)objectForKeyedSubscript:(id)key;
- (void)setObject:(nullable id)object forKeyedSubscript:(NSObject<NSCopying> *)key;
@end
NS_ASSUME_NONNULL_END
