#pragma once
/* isim Foundation: NSXMLParser, an event-driven XML parser (adapted: the host's libxml2 SAX parser, which Apple's is
   built on too, so the error codes are the same) */
#import <Foundation/NSObject.h>
#import <Foundation/NSError.h>
NS_ASSUME_NONNULL_BEGIN
@class NSData, NSDictionary<KeyType, ObjectType>, NSError, NSInputStream, NSSet<ObjectType>, NSString, NSURL;
@protocol NSXMLParserDelegate;

typedef NS_ENUM(NSUInteger, NSXMLParserExternalEntityResolvingPolicy) {
    NSXMLParserResolveExternalEntitiesNever NS_SWIFT_NAME(never) = 0,
    NSXMLParserResolveExternalEntitiesNoNetwork NS_SWIFT_NAME(noNetwork),
    NSXMLParserResolveExternalEntitiesSameOriginOnly NS_SWIFT_NAME(sameOriginOnly),
    NSXMLParserResolveExternalEntitiesAlways NS_SWIFT_NAME(always),
} NS_SWIFT_NAME(XMLParser.ExternalEntityResolvingPolicy);

NS_SWIFT_NAME(XMLParser)
@interface NSXMLParser : NSObject
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url;
- (instancetype)initWithData:(NSData *)data NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithStream:(NSInputStream *)stream;
@property (nullable, assign) id <NSXMLParserDelegate> delegate;
@property BOOL shouldProcessNamespaces;
@property BOOL shouldReportNamespacePrefixes;
@property NSXMLParserExternalEntityResolvingPolicy externalEntityResolvingPolicy;
@property (nullable, copy) NSSet<NSURL *> *allowedExternalEntityURLs;
- (BOOL)parse;
- (void)abortParsing;
@property (nullable, readonly, copy) NSError *parserError;
@property BOOL shouldResolveExternalEntities;
@end

@interface NSXMLParser (NSXMLParserLocatorAdditions)
@property (nullable, readonly, copy) NSString *publicID;
@property (nullable, readonly, copy) NSString *systemID;
@property (readonly) NSInteger lineNumber;
@property (readonly) NSInteger columnNumber;
@end

NS_SWIFT_NAME(XMLParserDelegate)
@protocol NSXMLParserDelegate <NSObject>
@optional
- (void)parserDidStartDocument:(NSXMLParser *)parser;
- (void)parserDidEndDocument:(NSXMLParser *)parser;
- (void)parser:(NSXMLParser *)parser foundNotationDeclarationWithName:(NSString *)name publicID:(nullable NSString *)publicID systemID:(nullable NSString *)systemID;
- (void)parser:(NSXMLParser *)parser foundUnparsedEntityDeclarationWithName:(NSString *)name publicID:(nullable NSString *)publicID
      systemID:(nullable NSString *)systemID notationName:(nullable NSString *)notationName;
- (void)parser:(NSXMLParser *)parser foundAttributeDeclarationWithName:(NSString *)attributeName forElement:(NSString *)elementName
          type:(nullable NSString *)type defaultValue:(nullable NSString *)defaultValue;
- (void)parser:(NSXMLParser *)parser foundElementDeclarationWithName:(NSString *)elementName model:(NSString *)model;
- (void)parser:(NSXMLParser *)parser foundInternalEntityDeclarationWithName:(NSString *)name value:(nullable NSString *)value;
- (void)parser:(NSXMLParser *)parser foundExternalEntityDeclarationWithName:(NSString *)name publicID:(nullable NSString *)publicID systemID:(nullable NSString *)systemID;
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI
 qualifiedName:(nullable NSString *)qName attributes:(NSDictionary<NSString *, NSString *> *)attributeDict;
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName;
- (void)parser:(NSXMLParser *)parser didStartMappingPrefix:(NSString *)prefix toURI:(NSString *)namespaceURI;
- (void)parser:(NSXMLParser *)parser didEndMappingPrefix:(NSString *)prefix;
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string;
- (void)parser:(NSXMLParser *)parser foundIgnorableWhitespace:(NSString *)whitespaceString;
- (void)parser:(NSXMLParser *)parser foundProcessingInstructionWithTarget:(NSString *)target data:(nullable NSString *)data;
- (void)parser:(NSXMLParser *)parser foundComment:(NSString *)comment;
- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock;
- (nullable NSData *)parser:(NSXMLParser *)parser resolveExternalEntityName:(NSString *)name systemID:(nullable NSString *)systemID;
- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError;
- (void)parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)validationError;
@end

FOUNDATION_EXPORT NSErrorDomain const NSXMLParserErrorDomain;

/* libxml2's error numbers */
typedef NS_ENUM(NSInteger, NSXMLParserError) {
    NSXMLParserInternalError = 1, NSXMLParserOutOfMemoryError = 2, NSXMLParserDocumentStartError = 3,
    NSXMLParserEmptyDocumentError = 4, NSXMLParserPrematureDocumentEndError = 5, NSXMLParserInvalidHexCharacterRefError = 6,
    NSXMLParserInvalidDecimalCharacterRefError = 7, NSXMLParserInvalidCharacterRefError = 8, NSXMLParserInvalidCharacterError = 9,
    NSXMLParserCharacterRefAtEOFError = 10, NSXMLParserCharacterRefInPrologError = 11, NSXMLParserCharacterRefInEpilogError = 12,
    NSXMLParserCharacterRefInDTDError = 13, NSXMLParserEntityRefAtEOFError = 14, NSXMLParserEntityRefInPrologError = 15,
    NSXMLParserEntityRefInEpilogError = 16, NSXMLParserEntityRefInDTDError = 17, NSXMLParserParsedEntityRefAtEOFError = 18,
    NSXMLParserParsedEntityRefInPrologError = 19, NSXMLParserParsedEntityRefInEpilogError = 20,
    NSXMLParserParsedEntityRefInInternalSubsetError = 21, NSXMLParserEntityReferenceWithoutNameError = 22,
    NSXMLParserEntityReferenceMissingSemiError = 23, NSXMLParserParsedEntityRefNoNameError = 24,
    NSXMLParserParsedEntityRefMissingSemiError = 25, NSXMLParserUndeclaredEntityError = 26, NSXMLParserUnparsedEntityError = 28,
    NSXMLParserEntityIsExternalError = 29, NSXMLParserEntityIsParameterError = 30, NSXMLParserUnknownEncodingError = 31,
    NSXMLParserEncodingNotSupportedError = 32, NSXMLParserStringNotStartedError = 33, NSXMLParserStringNotClosedError = 34,
    NSXMLParserNamespaceDeclarationError = 35, NSXMLParserEntityNotStartedError = 36, NSXMLParserEntityNotFinishedError = 37,
    NSXMLParserLessThanSymbolInAttributeError = 38, NSXMLParserAttributeNotStartedError = 39, NSXMLParserAttributeNotFinishedError = 40,
    NSXMLParserAttributeHasNoValueError = 41, NSXMLParserAttributeRedefinedError = 42, NSXMLParserLiteralNotStartedError = 43,
    NSXMLParserLiteralNotFinishedError = 44, NSXMLParserCommentNotFinishedError = 45,
    NSXMLParserProcessingInstructionNotStartedError = 46, NSXMLParserProcessingInstructionNotFinishedError = 47,
    NSXMLParserNotationNotStartedError = 48, NSXMLParserNotationNotFinishedError = 49, NSXMLParserAttributeListNotStartedError = 50,
    NSXMLParserAttributeListNotFinishedError = 51, NSXMLParserMixedContentDeclNotStartedError = 52,
    NSXMLParserMixedContentDeclNotFinishedError = 53, NSXMLParserElementContentDeclNotStartedError = 54,
    NSXMLParserElementContentDeclNotFinishedError = 55, NSXMLParserXMLDeclNotStartedError = 56, NSXMLParserXMLDeclNotFinishedError = 57,
    NSXMLParserConditionalSectionNotStartedError = 58, NSXMLParserConditionalSectionNotFinishedError = 59,
    NSXMLParserExternalSubsetNotFinishedError = 60, NSXMLParserDOCTYPEDeclNotFinishedError = 61,
    NSXMLParserMisplacedCDATAEndStringError = 62, NSXMLParserCDATANotFinishedError = 63, NSXMLParserMisplacedXMLDeclarationError = 64,
    NSXMLParserSpaceRequiredError = 65, NSXMLParserSeparatorRequiredError = 66, NSXMLParserNMTOKENRequiredError = 67,
    NSXMLParserNAMERequiredError = 68, NSXMLParserPCDATARequiredError = 69, NSXMLParserURIRequiredError = 70,
    NSXMLParserPublicIdentifierRequiredError = 71, NSXMLParserLTRequiredError = 72, NSXMLParserGTRequiredError = 73,
    NSXMLParserLTSlashRequiredError = 74, NSXMLParserEqualExpectedError = 75, NSXMLParserTagNameMismatchError = 76,
    NSXMLParserUnfinishedTagError = 77, NSXMLParserStandaloneValueError = 78, NSXMLParserInvalidEncodingNameError = 79,
    NSXMLParserCommentContainsDoubleHyphenError = 80, NSXMLParserInvalidEncodingError = 81,
    NSXMLParserExternalStandaloneEntityError = 82, NSXMLParserInvalidConditionalSectionError = 83,
    NSXMLParserEntityValueRequiredError = 84, NSXMLParserNotWellBalancedError = 85, NSXMLParserExtraContentError = 86,
    NSXMLParserInvalidCharacterInEntityError = 87, NSXMLParserParsedEntityRefInInternalError = 88, NSXMLParserEntityRefLoopError = 89,
    NSXMLParserEntityBoundaryError = 90, NSXMLParserInvalidURIError = 91, NSXMLParserURIFragmentError = 92,
    NSXMLParserNoDTDError = 94, NSXMLParserDelegateAbortedParseError = 512
} NS_SWIFT_NAME(XMLParser.ErrorCode);
NS_ASSUME_NONNULL_END
