#pragma once
#import <WebKit/WKFoundation.h>
#import <WebKit/WKWebExtensionDataType.h>
#import <WebKit/WKWebExtensionTab.h>
#import <WebKit/WKWebExtensionControllerDelegate.h>
NS_ASSUME_NONNULL_BEGIN
@class WKWebExtension, WKWebExtensionContext, WKWebViewConfiguration, WKWebsiteDataStore, WKWebExtensionDataRecord;
@protocol WKWebExtensionWindow;
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
/* issue #791 */
@property (nonatomic, weak) id <WKWebExtensionControllerDelegate> delegate;
@property (class, nonatomic, readonly, copy) NSSet<WKWebExtensionDataType> *allExtensionDataTypes;
- (void)fetchDataRecordsOfTypes:(NSSet<WKWebExtensionDataType> *)dataTypes completionHandler:(void (^)(NSArray<WKWebExtensionDataRecord *> *))completionHandler;
- (void)fetchDataRecordOfTypes:(NSSet<WKWebExtensionDataType> *)dataTypes forExtensionContext:(WKWebExtensionContext *)extensionContext completionHandler:(void (^)(WKWebExtensionDataRecord * _Nullable))completionHandler;
- (void)removeDataOfTypes:(NSSet<WKWebExtensionDataType> *)dataTypes fromDataRecords:(NSArray<WKWebExtensionDataRecord *> *)dataRecords completionHandler:(void (^)(void))completionHandler;
- (void)didOpenWindow:(id <WKWebExtensionWindow>)newWindow;
- (void)didCloseWindow:(id <WKWebExtensionWindow>)closedWindow;
- (void)didFocusWindow:(nullable id <WKWebExtensionWindow>)focusedWindow;
- (void)didOpenTab:(id <WKWebExtensionTab>)newTab;
- (void)didCloseTab:(id <WKWebExtensionTab>)closedTab windowIsClosing:(BOOL)windowIsClosing;
- (void)didActivateTab:(id <WKWebExtensionTab>)activatedTab previousActiveTab:(nullable id <WKWebExtensionTab>)previousTab;
- (void)didSelectTabs:(NSArray<id <WKWebExtensionTab>> *)selectedTabs;
- (void)didDeselectTabs:(NSArray<id <WKWebExtensionTab>> *)deselectedTabs;
- (void)didMoveTab:(id <WKWebExtensionTab>)movedTab fromIndex:(NSUInteger)index inWindow:(nullable id <WKWebExtensionWindow>)oldWindow;
- (void)didReplaceTab:(id <WKWebExtensionTab>)oldTab withTab:(id <WKWebExtensionTab>)newTab;
- (void)didChangeTabProperties:(WKWebExtensionTabChangedProperties)properties forTab:(id <WKWebExtensionTab>)changedTab;
@end
NS_ASSUME_NONNULL_END
