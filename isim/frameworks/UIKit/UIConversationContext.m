/* Conversation context and input suggestions (UIConversationContext.h): data classes the keyboard reads. isim has no
 * Apple Intelligence, so nothing suggests replies; a text field or view keeps its context, and inserting a smart
 * reply suggestion types its text. */
#import "UIKitPrivate.h"
#import <UIKit/UIConversationContext.h>
#import <objc/runtime.h>

/* copies and archives every property a class and its superclasses declare (they are all objects or integers) */
static NSArray<NSString *> *keys_of(Class c) {
    NSMutableArray *keys = [NSMutableArray array];
    for (; c && c != [NSObject class]; c = class_getSuperclass(c)) {
        unsigned n = 0; objc_property_t *ps = class_copyPropertyList(c, &n);
        for (unsigned i = 0; i < n; i++) [keys addObject:@(property_getName(ps[i]))];
        free(ps);
    }
    return keys;
}
static id copy_of(id o) {
    id c = [[[o class] alloc] init];
    for (NSString *k in keys_of([o class])) [c setValue:[o valueForKey:k] forKey:k];
    return c;
}
static void encode(id o, NSCoder *coder) {
    for (NSString *k in keys_of([o class])) { id v = [o valueForKey:k]; if (v) [coder encodeObject:v forKey:k]; }
}
static id decode(id o, NSCoder *coder) {
    for (NSString *k in keys_of([o class])) { id v = [coder decodeObjectForKey:k]; if (v) [o setValue:v forKey:k]; }
    return o;
}
#define ISIM_CONVERSATION_DATA \
+ (BOOL)supportsSecureCoding { return YES; } \
- (id)copyWithZone:(NSZone *)z { return copy_of(self); } \
- (void)encodeWithCoder:(NSCoder *)c { encode(self, c); } \
- (instancetype)initWithCoder:(NSCoder *)c { return (self = [self init]) ? decode(self, c) : nil; }

@implementation UIConversationEntry
- (instancetype)init {
    if ((self = [super init])) {
        _entryIdentifier = [NSUUID UUID].UUIDString; _text = @""; _senderIdentifier = @"";
        _primaryRecipientIdentifiers = [NSSet set]; _sentDate = [NSDate date];
    }
    return self;
}
ISIM_CONVERSATION_DATA
@end
@implementation UIConversationContext
- (instancetype)init {
    if ((self = [super init])) {
        _conversationEntries = @[]; _selfIdentifiers = [NSSet set]; _responsePrimaryRecipientIdentifiers = [NSSet set];
        _participantNameByIdentifier = @{};
    }
    return self;
}
ISIM_CONVERSATION_DATA
@end
@implementation UIMessageConversationEntry @end
@implementation UIMessageConversationContext @end
@implementation UIMailConversationEntry
- (instancetype)init { if ((self = [super init])) _secondaryRecipientIdentifiers = [NSSet set]; return self; }
@end
@implementation UIMailConversationContext
- (instancetype)init {
    if ((self = [super init])) { _responseSubject = @""; _responseSecondaryRecipientIdentifiers = [NSSet set]; }
    return self;
}
@end

@implementation UIInputSuggestion @end
@implementation UISmartReplySuggestion
- (instancetype)initWithSmartReply:(NSString *)s { if ((self = [super init])) _smartReply = [s copy]; return self; }
@end
@implementation UIPhotoSearchSuggestion
- (NSArray *)whatValues { return @[]; }
- (NSArray *)whoValues { return @[]; }
- (NSArray *)whereValues { return @[]; }
- (NSArray *)whenValues { return @[]; }
@end

static char kContext;
static void set_context(id<UITextInput> v, UIConversationContext *c) {
    objc_setAssociatedObject(v, &kContext, c, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    id<UITextInputDelegate> d = v.inputDelegate;
    if ([d respondsToSelector:@selector(conversationContext:didChange:)]) [d conversationContext:c didChange:v];
}
static void insert_suggestion(id<UITextInput> v, UIInputSuggestion *s) {
    if ([s isKindOfClass:[UISmartReplySuggestion class]]) [v insertText:((UISmartReplySuggestion *)s).smartReply];
}
#define ISIM_CONVERSATION_INPUT \
- (UIConversationContext *)conversationContext { return objc_getAssociatedObject(self, &kContext); } \
- (void)setConversationContext:(UIConversationContext *)c { set_context(self, c); } \
- (void)insertInputSuggestion:(UIInputSuggestion *)s { insert_suggestion(self, s); }
@implementation UITextField (IsimConversationContext)
ISIM_CONVERSATION_INPUT
@end
@implementation UITextView (IsimConversationContext)
ISIM_CONVERSATION_INPUT
@end
