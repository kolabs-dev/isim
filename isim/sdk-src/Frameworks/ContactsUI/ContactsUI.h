#pragma once
/* isim ContactsUI for Objective-C: the classes are the ContactsUI Swift overlay's (ContactsUI.framework re-exports
   libswiftContactsUI.dylib): the contact picker (the device address book, outside the app's Contacts permission) and
   the contact card / new-contact form. Swift uses the overlay; these declarations are hidden from Swift. */
#import <UIKit/UIKit.h>
#import <Contacts/Contacts.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class CNContactPickerViewController, CNContactViewController;

@interface CNContactProperty : NSObject <NSCopying>
@property (readonly, copy, nonatomic) CNContact *contact;
@property (readonly, copy, nonatomic) NSString *key;
@property (readonly, nullable, nonatomic) id value;
@property (readonly, copy, nullable, nonatomic) NSString *identifier;
@property (readonly, copy, nullable, nonatomic) NSString *label;
@end

@protocol CNContactPickerDelegate <NSObject>
@optional
- (void)contactPickerDidCancel:(CNContactPickerViewController *)picker;
- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact;
- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContactProperty:(CNContactProperty *)contactProperty;
- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContacts:(NSArray<CNContact *> *)contacts;
- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContactProperties:(NSArray<CNContactProperty *> *)contactProperties;
@end
@interface CNContactPickerViewController : UIViewController
@property (nonatomic, weak, nullable) id<CNContactPickerDelegate> delegate;
@property (nonatomic, copy, nullable) NSArray<NSString *> *displayedPropertyKeys;
@property (nonatomic, copy, nullable) NSPredicate *predicateForEnablingContact;
@property (nonatomic, copy, nullable) NSPredicate *predicateForSelectionOfContact;
@property (nonatomic, copy, nullable) NSPredicate *predicateForSelectionOfProperty;
@end

@protocol CNContactViewControllerDelegate <NSObject>
@optional
- (BOOL)contactViewController:(CNContactViewController *)viewController shouldPerformDefaultActionForContactProperty:(CNContactProperty *)property;
- (void)contactViewController:(CNContactViewController *)viewController didCompleteWithContact:(nullable CNContact *)contact;
@end
@interface CNContactViewController : UIViewController
+ (id<CNKeyDescriptor>)descriptorForRequiredKeys;
+ (instancetype)viewControllerForContact:(CNContact *)contact;
+ (instancetype)viewControllerForUnknownContact:(CNContact *)contact;
+ (instancetype)viewControllerForNewContact:(nullable CNContact *)contact;
@property (nonatomic, readonly) CNContact *contact;
@property (nonatomic, weak, nullable) id<CNContactViewControllerDelegate> delegate;
@property (nonatomic, strong, nullable) CNContactStore *contactStore;
@property (nonatomic) BOOL allowsEditing;
@property (nonatomic) BOOL allowsActions;
@property (nonatomic, copy, nullable) NSArray<NSString *> *displayedPropertyKeys;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, copy, nullable) NSString *alternateName;
@end

NS_ASSUME_NONNULL_END
#endif
