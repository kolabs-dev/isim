#pragma once
#import <PDFKit/PDFKitPlatform.h>
#import <PDFKit/PDFPage.h>
#import <PDFKit/PDFAnnotationUtilities.h>
NS_ASSUME_NONNULL_BEGIN
@class PDFAction, PDFBorder, PDFDestination, PDFPage;

/* an annotation of a page: read from the page's /Annots, or made; its properties are its dictionary's values
 * (annotationKeyValues). isim draws an annotation from its properties (its appearance stream is kept for writing but
 * not drawn); writing puts the annotations back into the page's /Annots, or into the page content with
 * PDFDocumentBurnInAnnotationsOption. */
PDFKIT_CLASS_AVAILABLE(10_4, 11_0)
@interface PDFAnnotation : NSObject <NSCopying, NSCoding>
- (instancetype)initWithBounds:(PDFRect)bounds forType:(PDFAnnotationSubtype)annotationType
                withProperties:(nullable NSDictionary *)properties NS_DESIGNATED_INITIALIZER PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, weak, nullable) PDFPage *page;
@property (nonatomic, readonly, nullable) NSString *type;
@property (nonatomic) PDFRect bounds;
@property (nonatomic) BOOL shouldDisplay;
@property (nonatomic) BOOL shouldPrint;
@property (nonatomic, copy, nullable) NSString *userName PDFKIT_AVAILABLE(10_5, 11_0);
@property (nonatomic, copy, nullable) NSDate *modificationDate PDFKIT_AVAILABLE(10_5, 11_0);
@property (nonatomic, copy) PDFKitPlatformColor *color;
@property (nonatomic, copy, nullable) NSString *contents;
@property (nonatomic, strong, nullable) PDFAnnotation *popup;
@property (nonatomic, strong, nullable) PDFBorder *border;
@property (nonatomic, strong, nullable) PDFAction *action PDFKIT_AVAILABLE(10_5, 11_0);
@property (nonatomic, readonly) BOOL hasAppearanceStream;
@property (nonatomic, getter=isHighlighted) BOOL highlighted PDFKIT_AVAILABLE(10_13, 11_0);
- (void)drawWithBox:(PDFDisplayBox)box inContext:(CGContextRef)context PDFKIT_AVAILABLE(10_12, 11_0);
- (BOOL)setValue:(id)value forAnnotationKey:(PDFAnnotationKey)key PDFKIT_AVAILABLE(10_12, 11_0);
- (BOOL)setBoolean:(BOOL)value forAnnotationKey:(PDFAnnotationKey)key PDFKIT_AVAILABLE(10_13, 11_0);
- (BOOL)setRect:(PDFRect)value forAnnotationKey:(PDFAnnotationKey)key PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, readonly, copy) NSDictionary *annotationKeyValues PDFKIT_AVAILABLE(10_13, 11_0);
- (nullable id)valueForAnnotationKey:(PDFAnnotationKey)key PDFKIT_AVAILABLE(10_12, 11_0);
- (void)removeValueForAnnotationKey:(PDFAnnotationKey)key PDFKIT_AVAILABLE(10_12, 11_0);
@end

@interface PDFAnnotation (PDFAnnotationUtilities)
@property (nonatomic, copy, nullable) PDFKitPlatformFont *font PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, copy, nullable) PDFKitPlatformColor *fontColor PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, copy, nullable) PDFKitPlatformColor *interiorColor PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) NSTextAlignment alignment PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) PDFPoint startPoint PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) PDFPoint endPoint PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) PDFLineStyle startLineStyle PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) PDFLineStyle endLineStyle PDFKIT_AVAILABLE(10_13, 11_0);
+ (PDFLineStyle)lineStyleFromName:(NSString *)name PDFKIT_AVAILABLE(10_13, 11_0);
+ (NSString *)nameForLineStyle:(PDFLineStyle)style PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) PDFTextAnnotationIconType iconType PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, copy, nullable) NSArray<NSValue *> *quadrilateralPoints PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) PDFMarkupType markupType PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, copy) PDFAnnotationWidgetSubtype widgetFieldType PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) PDFWidgetControlType widgetControlType PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, getter=isMultiline) BOOL multiline PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, readonly) BOOL isPasswordField PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, getter=hasComb) BOOL comb PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) NSInteger maximumLength PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, copy, nullable) NSString *widgetStringValue PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, copy, nullable) NSString *widgetDefaultStringValue PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) BOOL allowsToggleToOff PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) BOOL radiosInUnison PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, getter=isReadOnly) BOOL readOnly PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, getter=isListChoice) BOOL listChoice PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, copy, nullable) NSArray<NSString *> *choices PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, copy, nullable) NSArray<NSString *> *values PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) PDFWidgetCellState buttonWidgetState PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, copy) NSString *buttonWidgetStateString PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, getter=isOpen) BOOL open PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, readonly, nullable) NSArray<PDFKitPlatformBezierPath *> *paths PDFKIT_AVAILABLE(10_13, 11_0);
- (void)addBezierPath:(PDFKitPlatformBezierPath *)path PDFKIT_AVAILABLE(10_13, 11_0);
- (void)removeBezierPath:(PDFKitPlatformBezierPath *)path PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, strong, nullable) PDFDestination *destination PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, copy, nullable) NSURL *URL PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, copy, nullable) NSString *fieldName PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, copy, nullable) NSString *caption PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, copy, nullable) PDFKitPlatformColor *backgroundColor PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, copy, nullable) NSString *stampName PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, readonly, getter=isActivatableTextField) BOOL activatableTextField API_AVAILABLE(macos(13.0), ios(16.0));
@end

NS_ASSUME_NONNULL_END
