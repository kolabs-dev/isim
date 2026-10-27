#pragma once
#import <PDFKit/PDFKitPlatform.h>
NS_ASSUME_NONNULL_BEGIN

/* the keys of an annotation's dictionary (PDFAnnotation.valueForAnnotationKey:), and the names of its values */
typedef NSString *const PDFAnnotationKey NS_STRING_ENUM;
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyAppearanceDictionary PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyAppearanceState PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyBorder PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyColor PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyContents PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyFlags PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyDate PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyName PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyPage PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyRect PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeySubtype PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyAction PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyAdditionalActions PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyBorderStyle PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyDefaultAppearance PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyDestination PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyHighlightingMode PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyInklist PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyInteriorColor PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyLinePoints PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyLineEndingStyles PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyIconName PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyOpen PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyParent PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyPopup PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyQuadding PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyQuadPoints PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyTextLabel PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyWidgetDownCaption PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyWidgetBorderColor PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyWidgetBackgroundColor PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyWidgetCaption PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyWidgetDefaultValue PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyWidgetFieldFlags PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyWidgetFieldType PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyWidgetAppearanceDictionary PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyWidgetMaxLen PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyWidgetOptions PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyWidgetRotation PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyWidgetRolloverCaption PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyWidgetTextLabelUI PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationKey PDFAnnotationKeyWidgetValue PDFKIT_AVAILABLE(10_13, 11_0);

typedef NSString *const PDFAnnotationLineEndingStyle NS_STRING_ENUM;
PDFKIT_EXTERN PDFAnnotationLineEndingStyle PDFAnnotationLineEndingStyleNone PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationLineEndingStyle PDFAnnotationLineEndingStyleSquare PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationLineEndingStyle PDFAnnotationLineEndingStyleCircle PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationLineEndingStyle PDFAnnotationLineEndingStyleDiamond PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationLineEndingStyle PDFAnnotationLineEndingStyleOpenArrow PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationLineEndingStyle PDFAnnotationLineEndingStyleClosedArrow PDFKIT_AVAILABLE(10_13, 11_0);

typedef NSString *const PDFAnnotationTextIconType NS_STRING_ENUM;
PDFKIT_EXTERN PDFAnnotationTextIconType PDFAnnotationTextIconTypeComment PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationTextIconType PDFAnnotationTextIconTypeKey PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationTextIconType PDFAnnotationTextIconTypeNote PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationTextIconType PDFAnnotationTextIconTypeHelp PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationTextIconType PDFAnnotationTextIconTypeNewParagraph PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationTextIconType PDFAnnotationTextIconTypeParagraph PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationTextIconType PDFAnnotationTextIconTypeInsert PDFKIT_AVAILABLE(10_13, 11_0);

typedef NSString *const PDFAnnotationHighlightingMode NS_STRING_ENUM;
PDFKIT_EXTERN PDFAnnotationHighlightingMode PDFAnnotationHighlightingModeNone PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationHighlightingMode PDFAnnotationHighlightingModeInvert PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationHighlightingMode PDFAnnotationHighlightingModeOutline PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationHighlightingMode PDFAnnotationHighlightingModePush PDFKIT_AVAILABLE(10_13, 11_0);

typedef NSString *const PDFAnnotationWidgetSubtype NS_STRING_ENUM;
PDFKIT_EXTERN PDFAnnotationWidgetSubtype PDFAnnotationWidgetSubtypeButton PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationWidgetSubtype PDFAnnotationWidgetSubtypeChoice PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationWidgetSubtype PDFAnnotationWidgetSubtypeSignature PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationWidgetSubtype PDFAnnotationWidgetSubtypeText PDFKIT_AVAILABLE(10_13, 11_0);

typedef NSString *const PDFAnnotationSubtype NS_STRING_ENUM;
PDFKIT_EXTERN PDFAnnotationSubtype PDFAnnotationSubtypeText PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationSubtype PDFAnnotationSubtypeLink PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationSubtype PDFAnnotationSubtypeFreeText PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationSubtype PDFAnnotationSubtypeLine PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationSubtype PDFAnnotationSubtypeSquare PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationSubtype PDFAnnotationSubtypeCircle PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationSubtype PDFAnnotationSubtypeHighlight PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationSubtype PDFAnnotationSubtypeUnderline PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationSubtype PDFAnnotationSubtypeStrikeOut PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationSubtype PDFAnnotationSubtypeInk PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationSubtype PDFAnnotationSubtypeStamp PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationSubtype PDFAnnotationSubtypePopup PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFAnnotationSubtype PDFAnnotationSubtypeWidget PDFKIT_AVAILABLE(10_13, 11_0);

typedef NS_ENUM(NSInteger, PDFWidgetControlType) {
    kPDFWidgetUnknownControl = -1, kPDFWidgetPushButtonControl = 0, kPDFWidgetRadioButtonControl = 1, kPDFWidgetCheckBoxControl = 2
};
typedef NS_ENUM(NSInteger, PDFWidgetCellState) { kPDFWidgetMixedState = -1, kPDFWidgetOffState = 0, kPDFWidgetOnState = 1 };
typedef NS_ENUM(NSInteger, PDFLineStyle) {
    kPDFLineStyleNone = 0, kPDFLineStyleSquare = 1, kPDFLineStyleCircle = 2, kPDFLineStyleDiamond = 3,
    kPDFLineStyleOpenArrow = 4, kPDFLineStyleClosedArrow = 5
};
typedef NS_ENUM(NSInteger, PDFTextAnnotationIconType) {
    kPDFTextAnnotationIconComment = 0, kPDFTextAnnotationIconKey = 1, kPDFTextAnnotationIconNote = 2,
    kPDFTextAnnotationIconHelp = 3, kPDFTextAnnotationIconNewParagraph = 4, kPDFTextAnnotationIconParagraph = 5,
    kPDFTextAnnotationIconInsert = 6
};
typedef NS_ENUM(NSInteger, PDFMarkupType) {
    kPDFMarkupTypeHighlight = 0, kPDFMarkupTypeStrikeOut = 1, kPDFMarkupTypeUnderline = 2,
    kPDFMarkupTypeRedact API_AVAILABLE(macos(10.15), ios(13.0)) = 3
};

NS_ASSUME_NONNULL_END
