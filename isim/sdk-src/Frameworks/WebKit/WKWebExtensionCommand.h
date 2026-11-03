#pragma once
#import <WebKit/WKFoundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@class WKWebExtensionContext;
/* a keyboard shortcut from an extension's manifest `commands` */
API_AVAILABLE(ios(18.4))
@interface WKWebExtensionCommand : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, weak) WKWebExtensionContext *webExtensionContext;
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, nullable, copy) NSString *activationKey;
@property (nonatomic) UIKeyModifierFlags modifierFlags;
@property (nonatomic, readonly, copy) UIMenuElement *menuItem;
@property (nonatomic, readonly, copy, nullable) UIKeyCommand *keyCommand;
@end
NS_ASSUME_NONNULL_END
