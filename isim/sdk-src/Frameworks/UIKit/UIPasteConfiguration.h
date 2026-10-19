#pragma once
/* isim: paste configurations for Objective-C. The classes are the UIKit Swift overlay's (objc_runtime_visible: Objective-C finds
   them through the runtime, so it cannot subclass them or add categories to them; UIKit loads the overlay on first use);
   Swift code uses the overlay's own declarations, so this header is hidden from Swift. */
#import <UIKit/UIKitDefines.h>
#import <Foundation/NSItemProvider.h>
#import <UIKit/UIResponder.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
ISIM_RUNTIME_VISIBLE NS_SWIFT_UI_ACTOR
@interface UIPasteConfiguration : NSObject <NSCopying>
@property (nonatomic, copy) NSArray<NSString *> *acceptableTypeIdentifiers;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithAcceptableTypeIdentifiers:(NSArray<NSString *> *)acceptableTypeIdentifiers;
- (void)addAcceptableTypeIdentifiers:(NSArray<NSString *> *)acceptableTypeIdentifiers;
- (instancetype)initWithTypeIdentifiersForAcceptingClass:(Class<NSItemProviderReading>)aClass;
- (void)addTypeIdentifiersForAcceptingClass:(Class<NSItemProviderReading>)aClass;
@end
NS_SWIFT_UI_ACTOR
@protocol UIPasteConfigurationSupporting <NSObject>
@property (nullable, nonatomic, copy) UIPasteConfiguration *pasteConfiguration;
@optional
- (void)pasteItemProviders:(NSArray<NSItemProvider *> *)itemProviders;
- (BOOL)canPasteItemProviders:(NSArray<NSItemProvider *> *)itemProviders;
@end
/* every responder supports a paste configuration (the overlay's UIResponder extension) */
@interface UIResponder (UIPasteConfigurationSupporting) <UIPasteConfigurationSupporting>
@end
NS_ASSUME_NONNULL_END
#endif
