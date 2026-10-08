#pragma once
/* isim SDK: UIReferenceLibraryViewController (self-authored, API-compatible names). Adapted: like a Simulator without
 * downloaded dictionaries there are no definitions ("No definition found"), unless the host has WordNet's `wn`
 * (definitions are then the host's WordNet overview; unverified). */
#import <UIKit/UIViewController.h>
NS_ASSUME_NONNULL_BEGIN
NS_SWIFT_UI_ACTOR
@interface UIReferenceLibraryViewController : UIViewController
+ (BOOL)dictionaryHasDefinitionForTerm:(NSString *)term;
- (instancetype)initWithTerm:(NSString *)term NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
