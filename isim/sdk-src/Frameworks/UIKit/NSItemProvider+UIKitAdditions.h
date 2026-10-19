#pragma once
/* isim: UIKit's NSItemProvider additions. Objects that give a preferred presentation size set it on the item provider
   they are registered with (UIImage gives its size); a reading class can designate an augmenter that reads further
   type identifiers (before and after its own) and turns their data into objects (Foundation's NSItemProvider asks
   for them in canLoadObject(ofClass:) / loadObject(ofClass:)). */
#import <Foundation/Foundation.h>
#import <UIKit/UIKitDefines.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(11.0))
@protocol UIItemProviderPresentationSizeProviding <NSObject>
@property (nonatomic, readonly) CGSize preferredPresentationSizeForItemProvider;
@end
/* how a receiver should present the item: inline (the content) or as an attachment (a file); stored on the provider */
typedef NS_ENUM(NSInteger, UIPreferredPresentationStyle) {
    UIPreferredPresentationStyleUnspecified = 0,
    UIPreferredPresentationStyleInline,
    UIPreferredPresentationStyleAttachment,
} NS_SWIFT_NAME(NSItemProvider.PreferredPresentationStyle) API_AVAILABLE(ios(11.0));
@interface NSItemProvider (UIKitAdditions)
@property (nonatomic) UIPreferredPresentationStyle preferredPresentationStyle API_AVAILABLE(ios(11.0));
@end
@protocol UIItemProviderReadingAugmentationProviding <NSObject>
@required
/* read before / after the designating class's own readableTypeIdentifiersForItemProvider */
@property (class, nonatomic, readonly, copy) NSArray<NSString *> *additionalLeadingReadableTypeIdentifiersForItemProvider;
@property (class, nonatomic, readonly, copy) NSArray<NSString *> *additionalTrailingReadableTypeIdentifiersForItemProvider;
+ (nullable id)objectWithItemProviderData:(NSData *)data typeIdentifier:(NSString *)typeIdentifier
                           requestedClass:(Class<NSItemProviderReading>)requestedClass error:(NSError **)outError;
@end
@protocol UIItemProviderReadingAugmentationDesignating <NSItemProviderReading>
@required
@property (class, nonatomic, readonly) Class<UIItemProviderReadingAugmentationProviding> _ui_augmentingNSItemProviderReadingClass;
@end
NS_ASSUME_NONNULL_END
