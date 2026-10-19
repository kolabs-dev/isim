#pragma once
/* isim: drag and drop sessions for Objective-C. The classes are the UIKit Swift overlay's (objc_runtime_visible: Objective-C finds
   them through the runtime, so it cannot subclass them or add categories to them; UIKit loads the overlay on first use);
   Swift code uses the overlay's own declarations, so this header is hidden from Swift. */
#import <UIKit/UIKitDefines.h>
#import <Foundation/NSItemProvider.h>
#import <Foundation/NSProgress.h>
#import <UIKit/UIView.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class UIDragItem;
typedef NS_ENUM(NSUInteger, UIDropSessionProgressIndicatorStyle) {
    UIDropSessionProgressIndicatorStyleNone, UIDropSessionProgressIndicatorStyleDefault,
} API_AVAILABLE(ios(11.0));
NS_SWIFT_UI_ACTOR
@protocol UIDragDropSession <NSObject>
@property (nonatomic, readonly) NSArray<UIDragItem *> *items;
- (CGPoint)locationInView:(UIView *)view;
@property (nonatomic, readonly) BOOL allowsMoveOperation;
@property (nonatomic, readonly, getter=isRestrictedToDraggingApplication) BOOL restrictedToDraggingApplication;
- (BOOL)hasItemsConformingToTypeIdentifiers:(NSArray<NSString *> *)typeIdentifiers;
- (BOOL)canLoadObjectsOfClass:(Class<NSItemProviderReading>)aClass;
@end
NS_SWIFT_UI_ACTOR
@protocol UIDragSession <UIDragDropSession>
@property (nullable, nonatomic, strong) id localContext;
@end
NS_SWIFT_UI_ACTOR
@protocol UIDropSession <UIDragDropSession, NSProgressReporting>
@property (nullable, nonatomic, readonly) id<UIDragSession> localDragSession;
@property (nonatomic) UIDropSessionProgressIndicatorStyle progressIndicatorStyle;
- (NSProgress *)loadObjectsOfClass:(Class<NSItemProviderReading>)aClass completion:(void (^)(NSArray<__kindof id<NSItemProviderReading>> *objects))completion;
@end
NS_ASSUME_NONNULL_END
#endif
