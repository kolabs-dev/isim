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
