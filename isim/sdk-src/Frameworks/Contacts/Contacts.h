#pragma once
/* isim Contacts for Objective-C: the classes are the Contacts Swift overlay's (Contacts.framework re-exports
   libswiftContacts.dylib), on the same device address book as Swift, with the same permission prompt. CNLabeledValue is
   an Objective-C class here (the overlay's is a generic Swift class): a contact's labeled values convert between them.
   Swift uses the overlay; these declarations are hidden from Swift. The classes are not subclassable from Objective-C.
   Not from Objective-C yet: groups, containers, vCards, change history. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class CNContact, CNMutableContact;

FOUNDATION_EXPORT NSErrorDomain const CNErrorDomain;
typedef NS_ENUM(NSInteger, CNErrorCode) {
    CNErrorCodeCommunicationError = 1, CNErrorCodeDataAccessAuthorizationDenied = 2, CNErrorCodeAuthorizationDenied = 100,
    CNErrorCodeNoAccessableWritableContainers = 101, CNErrorCodeUnauthorizedKeys = 102, CNErrorCodeFeatureDisabledByUser = 103,
    CNErrorCodeFeatureNotAvailable = 104, CNErrorCodeRecordDoesNotExist = 200, CNErrorCodeInsertedRecordAlreadyExists = 201,
    CNErrorCodeContainmentCycle = 202, CNErrorCodeContainmentScope = 203, CNErrorCodeParentRecordDoesNotExist = 204,
    CNErrorCodeRecordIdentifierInvalid = 205, CNErrorCodeRecordNotWritable = 206, CNErrorCodeParentContainerNotWritable = 207,
    CNErrorCodeValidationMultipleErrors = 300, CNErrorCodeValidationTypeMismatch = 301, CNErrorCodeValidationConfigurationError = 302,
    CNErrorCodePredicateInvalid = 400, CNErrorCodePolicyViolation = 500, CNErrorCodeVCardMalformed = 700, CNErrorCodeVCardSummarizationError = 701,
};

FOUNDATION_EXPORT NSString * const CNContactIdentifierKey;
FOUNDATION_EXPORT NSString * const CNContactTypeKey;
FOUNDATION_EXPORT NSString * const CNContactNamePrefixKey;
FOUNDATION_EXPORT NSString * const CNContactGivenNameKey;
FOUNDATION_EXPORT NSString * const CNContactMiddleNameKey;
FOUNDATION_EXPORT NSString * const CNContactFamilyNameKey;
FOUNDATION_EXPORT NSString * const CNContactPreviousFamilyNameKey;
FOUNDATION_EXPORT NSString * const CNContactNameSuffixKey;
FOUNDATION_EXPORT NSString * const CNContactNicknameKey;
FOUNDATION_EXPORT NSString * const CNContactPhoneticGivenNameKey;
FOUNDATION_EXPORT NSString * const CNContactPhoneticMiddleNameKey;
FOUNDATION_EXPORT NSString * const CNContactPhoneticFamilyNameKey;
FOUNDATION_EXPORT NSString * const CNContactOrganizationNameKey;
FOUNDATION_EXPORT NSString * const CNContactDepartmentNameKey;
FOUNDATION_EXPORT NSString * const CNContactJobTitleKey;
FOUNDATION_EXPORT NSString * const CNContactBirthdayKey;
FOUNDATION_EXPORT NSString * const CNContactNonGregorianBirthdayKey;
FOUNDATION_EXPORT NSString * const CNContactNoteKey;
FOUNDATION_EXPORT NSString * const CNContactImageDataKey;
FOUNDATION_EXPORT NSString * const CNContactThumbnailImageDataKey;
FOUNDATION_EXPORT NSString * const CNContactImageDataAvailableKey;
FOUNDATION_EXPORT NSString * const CNContactPhoneNumbersKey;
FOUNDATION_EXPORT NSString * const CNContactEmailAddressesKey;
FOUNDATION_EXPORT NSString * const CNContactPostalAddressesKey;
FOUNDATION_EXPORT NSString * const CNContactDatesKey;
FOUNDATION_EXPORT NSString * const CNContactUrlAddressesKey;
FOUNDATION_EXPORT NSString * const CNContactRelationsKey;
FOUNDATION_EXPORT NSString * const CNContactSocialProfilesKey;
FOUNDATION_EXPORT NSString * const CNContactInstantMessageAddressesKey;
FOUNDATION_EXPORT NSString * const CNLabelHome;
FOUNDATION_EXPORT NSString * const CNLabelWork;
FOUNDATION_EXPORT NSString * const CNLabelSchool;
FOUNDATION_EXPORT NSString * const CNLabelOther;
FOUNDATION_EXPORT NSString * const CNLabelEmailiCloud;
FOUNDATION_EXPORT NSString * const CNLabelURLAddressHomePage;
FOUNDATION_EXPORT NSString * const CNLabelDateAnniversary;
FOUNDATION_EXPORT NSString * const CNLabelPhoneNumberiPhone;
FOUNDATION_EXPORT NSString * const CNLabelPhoneNumberAppleWatch;
FOUNDATION_EXPORT NSString * const CNLabelPhoneNumberMobile;
FOUNDATION_EXPORT NSString * const CNLabelPhoneNumberMain;
FOUNDATION_EXPORT NSString * const CNLabelPhoneNumberHomeFax;
FOUNDATION_EXPORT NSString * const CNLabelPhoneNumberWorkFax;
FOUNDATION_EXPORT NSString * const CNLabelPhoneNumberOtherFax;
FOUNDATION_EXPORT NSString * const CNLabelPhoneNumberPager;

@protocol CNKeyDescriptor <NSObject, NSSecureCoding, NSCopying>
@end
@interface NSString (Contacts) <CNKeyDescriptor>
@end

typedef NS_ENUM(NSInteger, CNContactType) { CNContactTypePerson = 0, CNContactTypeOrganization };
typedef NS_ENUM(NSInteger, CNContactSortOrder) {
    CNContactSortOrderNone = 0, CNContactSortOrderUserDefault, CNContactSortOrderGivenName, CNContactSortOrderFamilyName,
};
typedef NS_ENUM(NSInteger, CNEntityType) { CNEntityTypeContacts = 0 };
typedef NS_ENUM(NSInteger, CNAuthorizationStatus) {
    CNAuthorizationStatusNotDetermined = 0, CNAuthorizationStatusRestricted, CNAuthorizationStatusDenied, CNAuthorizationStatusAuthorized,
    CNAuthorizationStatusLimited,
};
typedef NS_ENUM(NSInteger, CNContactFormatterStyle) { CNContactFormatterStyleFullName = 0, CNContactFormatterStylePhoneticFullName };

/* values */
@interface CNLabeledValue<ValueType> : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)labeledValueWithLabel:(nullable NSString *)label value:(ValueType)value;
- (instancetype)initWithLabel:(nullable NSString *)label value:(ValueType)value;
- (instancetype)labeledValueBySettingLabel:(nullable NSString *)label;
- (instancetype)labeledValueBySettingValue:(ValueType)value;
@property (readonly, copy, nonatomic) NSString *identifier;
@property (readonly, copy, nullable, nonatomic) NSString *label;
@property (readonly, copy, nonatomic) ValueType value;
@end

@interface CNPhoneNumber : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)phoneNumberWithStringValue:(NSString *)stringValue;
- (instancetype)initWithStringValue:(NSString *)string;
@property (readonly, copy, nonatomic) NSString *stringValue;
@end

@interface CNPostalAddress : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>
@property (readonly, copy, nonatomic) NSString *street;
@property (readonly, copy, nonatomic) NSString *subLocality;
@property (readonly, copy, nonatomic) NSString *city;
@property (readonly, copy, nonatomic) NSString *subAdministrativeArea;
@property (readonly, copy, nonatomic) NSString *state;
@property (readonly, copy, nonatomic) NSString *postalCode;
@property (readonly, copy, nonatomic) NSString *country;
@property (readonly, copy, nonatomic) NSString *ISOCountryCode;
@end
@interface CNMutablePostalAddress : CNPostalAddress
@property (copy, nonatomic) NSString *street;
@property (copy, nonatomic) NSString *subLocality;
@property (copy, nonatomic) NSString *city;
@property (copy, nonatomic) NSString *subAdministrativeArea;
@property (copy, nonatomic) NSString *state;
@property (copy, nonatomic) NSString *postalCode;
@property (copy, nonatomic) NSString *country;
@property (copy, nonatomic) NSString *ISOCountryCode;
@end

/* contacts */
@interface CNContact : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>
@property (readonly, copy, nonatomic) NSString *identifier;
@property (readonly, nonatomic) CNContactType contactType;
@property (readonly, copy, nonatomic) NSString *namePrefix;
@property (readonly, copy, nonatomic) NSString *givenName;
@property (readonly, copy, nonatomic) NSString *middleName;
@property (readonly, copy, nonatomic) NSString *familyName;
@property (readonly, copy, nonatomic) NSString *previousFamilyName;
@property (readonly, copy, nonatomic) NSString *nameSuffix;
@property (readonly, copy, nonatomic) NSString *nickname;
@property (readonly, copy, nonatomic) NSString *organizationName;
@property (readonly, copy, nonatomic) NSString *departmentName;
@property (readonly, copy, nonatomic) NSString *jobTitle;
@property (readonly, copy, nullable, nonatomic) NSDateComponents *birthday;
@property (readonly, copy, nonatomic) NSString *note;
@property (readonly, copy, nullable, nonatomic) NSData *imageData;
@property (readonly, copy, nullable, nonatomic) NSData *thumbnailImageData;
@property (readonly, nonatomic) BOOL imageDataAvailable;
@property (readonly, copy, nonatomic) NSArray<CNLabeledValue<CNPhoneNumber *> *> *phoneNumbers;
@property (readonly, copy, nonatomic) NSArray<CNLabeledValue<NSString *> *> *emailAddresses;
@property (readonly, copy, nonatomic) NSArray<CNLabeledValue<NSString *> *> *urlAddresses;
@property (readonly, copy, nonatomic) NSArray<CNLabeledValue<CNPostalAddress *> *> *postalAddresses;
- (BOOL)isKeyAvailable:(NSString *)key;
- (BOOL)areKeysAvailable:(NSArray<id<CNKeyDescriptor>> *)keyDescriptors;
- (BOOL)isUnifiedWithContactWithIdentifier:(NSString *)contactIdentifier;
+ (NSString *)localizedStringForKey:(NSString *)key;
+ (id<CNKeyDescriptor>)descriptorForAllComparatorKeys;
+ (NSPredicate *)predicateForContactsMatchingName:(NSString *)name;
+ (NSPredicate *)predicateForContactsWithIdentifiers:(NSArray<NSString *> *)identifiers;
+ (NSPredicate *)predicateForContactsMatchingPhoneNumber:(CNPhoneNumber *)phoneNumber;
+ (NSPredicate *)predicateForContactsMatchingEmailAddress:(NSString *)emailAddress;
@end

@interface CNMutableContact : CNContact
@property (nonatomic) CNContactType contactType;
@property (copy, nonatomic) NSString *namePrefix;
@property (copy, nonatomic) NSString *givenName;
@property (copy, nonatomic) NSString *middleName;
@property (copy, nonatomic) NSString *familyName;
@property (copy, nonatomic) NSString *previousFamilyName;
@property (copy, nonatomic) NSString *nameSuffix;
@property (copy, nonatomic) NSString *nickname;
@property (copy, nonatomic) NSString *organizationName;
@property (copy, nonatomic) NSString *departmentName;
@property (copy, nonatomic) NSString *jobTitle;
@property (copy, nullable, nonatomic) NSDateComponents *birthday;
@property (copy, nonatomic) NSString *note;
@property (copy, nullable, nonatomic) NSData *imageData;
@property (copy, nonatomic) NSArray<CNLabeledValue<CNPhoneNumber *> *> *phoneNumbers;
@property (copy, nonatomic) NSArray<CNLabeledValue<NSString *> *> *emailAddresses;
@property (copy, nonatomic) NSArray<CNLabeledValue<NSString *> *> *urlAddresses;
@property (copy, nonatomic) NSArray<CNLabeledValue<CNPostalAddress *> *> *postalAddresses;
@end

@interface CNContactFormatter : NSFormatter
+ (nullable NSString *)stringFromContact:(CNContact *)contact style:(CNContactFormatterStyle)style;
+ (id<CNKeyDescriptor>)descriptorForRequiredKeysForStyle:(CNContactFormatterStyle)style;
@end

/* the store */
@interface CNFetchRequest : NSObject
@end
@interface CNContactFetchRequest : CNFetchRequest
- (instancetype)initWithKeysToFetch:(NSArray<id<CNKeyDescriptor>> *)keysToFetch;
@property (copy, nullable, nonatomic) NSPredicate *predicate;
@property (copy, nonatomic) NSArray<id<CNKeyDescriptor>> *keysToFetch;
@property (nonatomic) BOOL mutableObjects;
@property (nonatomic) BOOL unifyResults;
@property (nonatomic) CNContactSortOrder sortOrder;
@end
@interface CNSaveRequest : NSObject
- (void)addContact:(CNMutableContact *)contact toContainerWithIdentifier:(nullable NSString *)identifier;
- (void)updateContact:(CNMutableContact *)contact;
- (void)deleteContact:(CNMutableContact *)contact;
@property (nonatomic, strong, nullable) NSString *transactionAuthor;
@end
@interface CNContactStore : NSObject
+ (CNAuthorizationStatus)authorizationStatusForEntityType:(CNEntityType)entityType;
- (void)requestAccessForEntityType:(CNEntityType)entityType completionHandler:(void (^)(BOOL granted, NSError * _Nullable error))completionHandler;
- (nullable NSArray<CNContact *> *)unifiedContactsMatchingPredicate:(NSPredicate *)predicate keysToFetch:(NSArray<id<CNKeyDescriptor>> *)keys
                                                               error:(NSError **)error;
- (nullable CNContact *)unifiedContactWithIdentifier:(NSString *)identifier keysToFetch:(NSArray<id<CNKeyDescriptor>> *)keys error:(NSError **)error;
- (BOOL)enumerateContactsWithFetchRequest:(CNContactFetchRequest *)fetchRequest error:(NSError **)error
                               usingBlock:(void (^)(CNContact *contact, BOOL *stop))block;
- (BOOL)executeSaveRequest:(CNSaveRequest *)saveRequest error:(NSError **)error;
- (NSString *)defaultContainerIdentifier;
@end

NS_ASSUME_NONNULL_END
#endif
