#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
NS_SWIFT_UI_ACTOR
@interface UILayoutGuide : NSObject
@property (nonatomic, readonly) CGRect layoutFrame;
@property (nonatomic, weak, nullable) UIView *owningView;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, readonly, strong) NSLayoutXAxisAnchor *leadingAnchor, *trailingAnchor, *leftAnchor, *rightAnchor, *centerXAnchor;
@property (nonatomic, readonly, strong) NSLayoutYAxisAnchor *topAnchor, *bottomAnchor, *centerYAnchor;
@property (nonatomic, readonly, strong) NSLayoutDimension *widthAnchor, *heightAnchor;
@end
NS_ASSUME_NONNULL_END
