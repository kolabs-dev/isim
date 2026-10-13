#pragma once
/* isim: conversation context and input suggestions (iOS 18 / 26, #9). An app describes the conversation a text input
   replies in (messages or mail) so the keyboard can suggest replies; suggestions come from Apple Intelligence, which
   isim does not have, so the keyboard keeps the context and suggests nothing (as on an iPhone without it). Inserting
   a suggestion (insertInputSuggestion:) types a smart reply's text. UIConversationContext.m. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKitDefines.h>
#import <UIKit/UITextInput.h>
NS_ASSUME_NONNULL_BEGIN

/* one message or mail in the conversation */
NS_SWIFT_NAME(UIConversationContext.Entry) API_AVAILABLE(ios(18.4))
@interface UIConversationEntry : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, copy) NSString *entryIdentifier;
@property (nonatomic, copy, nullable) NSString *replyThreadIdentifier;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *senderIdentifier;
@property (nonatomic, copy) NSSet<NSString *> *primaryRecipientIdentifiers;
@property (nonatomic, copy) NSDate *sentDate;
@end
API_AVAILABLE(ios(18.4))
@interface UIConversationContext : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, copy) NSArray<UIConversationEntry *> *conversationEntries;
@property (nonatomic, copy) NSSet<NSString *> *selfIdentifiers;
@property (nonatomic, copy) NSSet<NSString *> *responsePrimaryRecipientIdentifiers;
@property (nonatomic, copy) NSDictionary<NSString *, NSPersonNameComponents *> *participantNameByIdentifier;
@end

typedef NS_ENUM(NSInteger, UIMessageConversationEntryDataKind) {
    UIMessageConversationEntryDataKindText, UIMessageConversationEntryDataKindAttachment, UIMessageConversationEntryDataKindOther,
} NS_SWIFT_NAME(UIMessageConversationContext.MessageEntry.DataKind) API_AVAILABLE(ios(26.0));
NS_SWIFT_NAME(UIMessageConversationContext.MessageEntry) API_AVAILABLE(ios(26.0))
@interface UIMessageConversationEntry : UIConversationEntry
@property (nonatomic) UIMessageConversationEntryDataKind dataKind;
@end
API_AVAILABLE(ios(26.0))
@interface UIMessageConversationContext : UIConversationContext
@end

typedef NS_ENUM(NSInteger, UIMailConversationEntryKind) {
    UIMailConversationEntryKindNone, UIMailConversationEntryKindPersonal, UIMailConversationEntryKindTransaction,
    UIMailConversationEntryKindPromotion, UIMailConversationEntryKindSocial, UIMailConversationEntryKindNews,
} NS_SWIFT_NAME(UIMailConversationContext.MailEntry.Kind) API_AVAILABLE(ios(26.0));
NS_SWIFT_NAME(UIMailConversationContext.MailEntry) API_AVAILABLE(ios(26.0))
@interface UIMailConversationEntry : UIConversationEntry
@property (nonatomic) UIMailConversationEntryKind kind;
@property (nonatomic, copy) NSSet<NSString *> *secondaryRecipientIdentifiers;
@property (nonatomic) BOOL isJunk;
@end
API_AVAILABLE(ios(26.0))
@interface UIMailConversationContext : UIConversationContext
@property (nonatomic, copy) NSString *responseSubject;
@property (nonatomic, copy) NSSet<NSString *> *responseSecondaryRecipientIdentifiers;
@property (nonatomic) BOOL responseHasCustomSignature;
@end

/* suggestions the keyboard inserts (insertInputSuggestion:) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0))
@interface UIInputSuggestion : NSObject
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.4))
@interface UISmartReplySuggestion : UIInputSuggestion
- (instancetype)initWithSmartReply:(NSString *)smartReply;
@property (nonatomic, readonly) NSString *smartReply;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0))
@interface UIPhotoSearchSuggestion : UIInputSuggestion
@property (nonatomic, readonly) NSArray<NSString *> *whatValues;
@property (nonatomic, readonly) NSArray<NSString *> *whoValues;
@property (nonatomic, readonly) NSArray<NSString *> *whereValues;
@property (nonatomic, readonly) NSArray<NSString *> *whenValues;
@end

/* a text field's or text view's conversation is its conversationContext trait (UITextInputTraits); setting it tells
   the input delegate (conversationContext:didChange:) */
NS_ASSUME_NONNULL_END
