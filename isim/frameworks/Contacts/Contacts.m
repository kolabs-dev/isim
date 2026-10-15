// isim Contacts for Objective-C: the C constants, Objective-C's CNLabeledValue (the overlay's is a generic Swift class,
// which Objective-C cannot see) and the labeled-value properties, which convert between them through the overlay's
// _isim_ members ([identifier, label or NSNull, value] triples). The values match the overlay's.
#import <Contacts/Contacts.h>
// the categories implement what the header declares on the classes (the overlay's Swift classes cannot)
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

NSErrorDomain const CNErrorDomain = @"CNErrorDomain";
NSString * const CNContactIdentifierKey = @"identifier";
NSString * const CNContactTypeKey = @"contactType";
NSString * const CNContactNamePrefixKey = @"namePrefix";
NSString * const CNContactGivenNameKey = @"givenName";
NSString * const CNContactMiddleNameKey = @"middleName";
NSString * const CNContactFamilyNameKey = @"familyName";
NSString * const CNContactPreviousFamilyNameKey = @"previousFamilyName";
NSString * const CNContactNameSuffixKey = @"nameSuffix";
NSString * const CNContactNicknameKey = @"nickname";
NSString * const CNContactPhoneticGivenNameKey = @"phoneticGivenName";
NSString * const CNContactPhoneticMiddleNameKey = @"phoneticMiddleName";
NSString * const CNContactPhoneticFamilyNameKey = @"phoneticFamilyName";
NSString * const CNContactOrganizationNameKey = @"organizationName";
NSString * const CNContactDepartmentNameKey = @"departmentName";
NSString * const CNContactJobTitleKey = @"jobTitle";
NSString * const CNContactBirthdayKey = @"birthday";
NSString * const CNContactNonGregorianBirthdayKey = @"nonGregorianBirthday";
NSString * const CNContactNoteKey = @"note";
NSString * const CNContactImageDataKey = @"imageData";
NSString * const CNContactThumbnailImageDataKey = @"thumbnailImageData";
NSString * const CNContactImageDataAvailableKey = @"imageDataAvailable";
NSString * const CNContactPhoneNumbersKey = @"phoneNumbers";
NSString * const CNContactEmailAddressesKey = @"emailAddresses";
NSString * const CNContactPostalAddressesKey = @"postalAddresses";
NSString * const CNContactDatesKey = @"dates";
NSString * const CNContactUrlAddressesKey = @"urlAddresses";
NSString * const CNContactRelationsKey = @"contactRelations";
NSString * const CNContactSocialProfilesKey = @"socialProfiles";
NSString * const CNContactInstantMessageAddressesKey = @"instantMessageAddresses";
NSString * const CNLabelHome = @"_$!<Home>!$_";
NSString * const CNLabelWork = @"_$!<Work>!$_";
NSString * const CNLabelSchool = @"_$!<School>!$_";
NSString * const CNLabelOther = @"_$!<Other>!$_";
NSString * const CNLabelEmailiCloud = @"iCloud";
NSString * const CNLabelURLAddressHomePage = @"_$!<HomePage>!$_";
NSString * const CNLabelDateAnniversary = @"_$!<Anniversary>!$_";
NSString * const CNLabelPhoneNumberiPhone = @"iPhone";
NSString * const CNLabelPhoneNumberAppleWatch = @"_$!<AppleWatch>!$_";
NSString * const CNLabelPhoneNumberMobile = @"_$!<Mobile>!$_";
NSString * const CNLabelPhoneNumberMain = @"_$!<Main>!$_";
NSString * const CNLabelPhoneNumberHomeFax = @"_$!<HomeFAX>!$_";
NSString * const CNLabelPhoneNumberWorkFax = @"_$!<WorkFAX>!$_";
NSString * const CNLabelPhoneNumberOtherFax = @"_$!<OtherFAX>!$_";
NSString * const CNLabelPhoneNumberPager = @"_$!<Pager>!$_";

@interface CNLabeledValue ()
- (instancetype)_initWithIdentifier:(NSString *)identifier label:(NSString *)label value:(id)value;
@end

@implementation CNLabeledValue {
    NSString *_identifier, *_label;
    id _value;
}
- (instancetype)_initWithIdentifier:(NSString *)identifier label:(NSString *)label value:(id)value {
    if ((self = [super init])) { _identifier = [identifier copy]; _label = [label copy]; _value = value; }
    return self;
}
+ (instancetype)labeledValueWithLabel:(NSString *)label value:(id)value { return [[self alloc] initWithLabel:label value:value]; }
- (instancetype)initWithLabel:(NSString *)label value:(id)value {
    return [self _initWithIdentifier:[NSUUID UUID].UUIDString label:label value:value];
}
- (instancetype)labeledValueBySettingLabel:(NSString *)label { return [[[self class] alloc] _initWithIdentifier:_identifier label:label value:_value]; }
- (instancetype)labeledValueBySettingValue:(id)value { return [[[self class] alloc] _initWithIdentifier:_identifier label:_label value:value]; }
- (NSString *)identifier { return _identifier; }
- (NSString *)label { return _label; }
- (id)value { return _value; }
- (id)copyWithZone:(NSZone *)zone { return self; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_identifier forKey:@"identifier"]; [coder encodeObject:_label forKey:@"label"]; [coder encodeObject:_value forKey:@"value"];
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    return [self _initWithIdentifier:[coder decodeObjectForKey:@"identifier"] ?: [NSUUID UUID].UUIDString label:[coder decodeObjectForKey:@"label"]
                               value:[coder decodeObjectForKey:@"value"]];
}
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[CNLabeledValue class]]) return NO;
    CNLabeledValue *l = o;
    return [_identifier isEqual:l.identifier] && (_label == l.label || [_label isEqual:l.label]) && [_value isEqual:l.value];
}
- (NSUInteger)hash { return _identifier.hash; }
- (NSString *)description { return [NSString stringWithFormat:@"<CNLabeledValue: identifier=%@, label=%@, value=%@>", _identifier, _label, _value]; }
@end

static NSArray *labeled(NSArray<NSArray *> *triples) {
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:triples.count];
    for (NSArray *t in triples) {
        if (t.count != 3) continue;
        id label = t[1] == [NSNull null] ? nil : t[1];
        [a addObject:[[CNLabeledValue alloc] _initWithIdentifier:t[0] label:label value:t[2]]];
    }
    return a;
}
static NSArray *pairs(NSArray<CNLabeledValue *> *values) {
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:values.count];
    for (CNLabeledValue *v in values) [a addObject:@[v.label ?: [NSNull null], v.value]];
    return a;
}

@interface CNContact (ISIMLabeledValues)
- (NSArray<NSArray *> *)_isim_phoneNumbers;
- (NSArray<NSArray *> *)_isim_emailAddresses;
- (NSArray<NSArray *> *)_isim_urlAddresses;
- (NSArray<NSArray *> *)_isim_postalAddresses;
@end
@implementation CNContact (ISIMObjC)
- (NSArray *)phoneNumbers { return labeled([self _isim_phoneNumbers]); }
- (NSArray *)emailAddresses { return labeled([self _isim_emailAddresses]); }
- (NSArray *)urlAddresses { return labeled([self _isim_urlAddresses]); }
- (NSArray *)postalAddresses { return labeled([self _isim_postalAddresses]); }
@end
@interface CNMutableContact (ISIMLabeledValues)
- (void)_isim_setPhoneNumbers:(NSArray *)v;
- (void)_isim_setEmailAddresses:(NSArray *)v;
- (void)_isim_setUrlAddresses:(NSArray *)v;
- (void)_isim_setPostalAddresses:(NSArray *)v;
@end
@implementation CNMutableContact (ISIMObjC)
- (void)setPhoneNumbers:(NSArray *)v { [self _isim_setPhoneNumbers:pairs(v)]; }
- (void)setEmailAddresses:(NSArray *)v { [self _isim_setEmailAddresses:pairs(v)]; }
- (void)setUrlAddresses:(NSArray *)v { [self _isim_setUrlAddresses:pairs(v)]; }
- (void)setPostalAddresses:(NSArray *)v { [self _isim_setPostalAddresses:pairs(v)]; }
@end
