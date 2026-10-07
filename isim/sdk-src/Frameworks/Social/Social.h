#pragma once
/* isim SDK (self-authored): Social — SLComposeServiceViewController, the standard compose sheet of Share extensions.
 * isim draws an iOS-style card: Cancel / title / Post, a text view with the shared text, an optional preview, the
 * configuration items and the characters remaining. Post calls didSelectPost (default: completes the request), Cancel
 * calls didSelectCancel (default: cancels it). SLComposeViewController (posting to social services) is not available. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

typedef void (^SLComposeSheetConfigurationItemTapHandler)(void);

@interface SLComposeSheetConfigurationItem : NSObject
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *value;
@property (nonatomic, assign) BOOL valuePending;
@property (nonatomic, copy, nullable) SLComposeSheetConfigurationItemTapHandler tapHandler;
- (null_unspecified instancetype)init;
@end

@interface SLComposeServiceViewController : UIViewController <UITextViewDelegate>
@property (nonatomic, readonly) UITextView *textView;
@property (nonatomic, readonly, null_unspecified) NSString *contentText;
@property (nonatomic, copy, null_unspecified) NSString *placeholder;
@property (nonatomic, strong, nullable) NSNumber *charactersRemaining;
@property (nonatomic, strong, nullable) UIViewController *autoCompletionViewController;
- (void)presentationAnimationDidFinish;
- (void)didSelectPost;
- (void)didSelectCancel;
- (void)cancel;
- (BOOL)isContentValid;
- (void)validateContent;
- (null_unspecified NSArray *)configurationItems;
- (void)reloadConfigurationItems;
- (void)pushConfigurationViewController:(UIViewController *)viewController;
- (void)popConfigurationViewController;
- (nullable UIView *)loadPreviewView;
@end

NS_ASSUME_NONNULL_END
