#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class WKWebExtension, WKWebExtensionContext, WKWebViewConfiguration, WKWebsiteDataStore;
API_AVAILABLE(ios(18.4))
@interface WKWebExtensionControllerConfiguration : NSObject <NSSecureCoding, NSCopying>
+ (instancetype)defaultConfiguration;
+ (instancetype)nonPersistentConfiguration;
+ (instancetype)configurationWithIdentifier:(NSUUID *)identifier;
@property (nonatomic, readonly, getter=isPersistent) BOOL persistent;
@property (nonatomic, nullable, readonly, copy) NSUUID *identifier;
@property (nonatomic, null_resettable, copy) WKWebViewConfiguration *webViewConfiguration;
@property (nonatomic, null_resettable, retain) WKWebsiteDataStore *defaultWebsiteDataStore;
@end
/* loads web extension contexts; web views whose configuration has it run the loaded extensions' content scripts */
API_AVAILABLE(ios(18.4))
@interface WKWebExtensionController : NSObject
- (instancetype)init;
- (instancetype)initWithConfiguration:(WKWebExtensionControllerConfiguration *)configuration;
@property (nonatomic, readonly, copy) WKWebExtensionControllerConfiguration *configuration;
- (BOOL)loadExtensionContext:(WKWebExtensionContext *)extensionContext error:(NSError **)error;
- (BOOL)unloadExtensionContext:(WKWebExtensionContext *)extensionContext error:(NSError **)error;
- (nullable WKWebExtensionContext *)extensionContextForExtension:(WKWebExtension *)extension;
- (nullable WKWebExtensionContext *)extensionContextForURL:(NSURL *)URL;
@property (nonatomic, readonly, copy) NSSet<WKWebExtension *> *extensions;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionContext *> *extensionContexts;
@end
NS_ASSUME_NONNULL_END
