#pragma once
#import <PDFKit/PDFKitPlatform.h>
#import <PDFKit/PDFAnnotationUtilities.h>
NS_ASSUME_NONNULL_BEGIN

typedef NSString *const PDFAppearanceCharacteristicsKey NS_STRING_ENUM;
PDFKIT_EXTERN PDFAppearanceCharacteristicsKey PDFAppearanceCharacteristicsKeyBackgroundColor PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAppearanceCharacteristicsKey PDFAppearanceCharacteristicsKeyBorderColor PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAppearanceCharacteristicsKey PDFAppearanceCharacteristicsKeyRotation PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAppearanceCharacteristicsKey PDFAppearanceCharacteristicsKeyCaption PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAppearanceCharacteristicsKey PDFAppearanceCharacteristicsKeyRolloverCaption PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAppearanceCharacteristicsKey PDFAppearanceCharacteristicsKeyDownCaption PDFKIT_AVAILABLE(10_13, 11_0);

/* a widget's appearance characteristics (its /MK dictionary) */
PDFKIT_CLASS_AVAILABLE(10_13, 11_0)
@interface PDFAppearanceCharacteristics : NSObject <NSCopying>
@property (nonatomic) PDFWidgetControlType controlType;
@property (nonatomic, copy, nullable) PDFKitPlatformColor *backgroundColor;
@property (nonatomic, copy, nullable) PDFKitPlatformColor *borderColor;
@property (nonatomic) NSInteger rotation;
@property (nonatomic, copy, nullable) NSString *caption;
@property (nonatomic, copy, nullable) NSString *rolloverCaption;
@property (nonatomic, copy, nullable) NSString *downCaption;
@property (nonatomic, readonly, copy) NSDictionary *appearanceCharacteristicsKeyValues;
@end

NS_ASSUME_NONNULL_END
