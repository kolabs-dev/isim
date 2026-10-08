#pragma once
/* isim SDK: printing (self-authored, API-compatible names). Adapted, like the Simulator's Printer Simulator: one
 * simulated printer, "isim Printer", which writes each job as a PDF to $ISIM_DATA/Printer (pages × copies, collated);
 * UIPrinterPickerController offers it. Page content comes from a UIPrintPageRenderer, a print formatter (simple text,
 * markup as plain text, a view) or printing items (PDFs, images). */
#import <UIKit/UIViewController.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
@class UIPrintInteractionController, UIPrintPageRenderer, UIPrintFormatter, UIPrinter, UIPrinterPickerController, UIBarButtonItem, UIFont, UIColor;

UIKIT_EXTERN NSErrorDomain const UIPrintErrorDomain;
typedef NS_ENUM(NSInteger, UIPrintErrorCode) { UIPrintingNotAvailableError = 1, UIPrintNoContentError, UIPrintUnknownImageFormatError, UIPrintJobFailedError };

typedef NS_ENUM(NSInteger, UIPrintInfoOutputType) {
    UIPrintInfoOutputGeneral, UIPrintInfoOutputPhoto, UIPrintInfoOutputGrayscale, UIPrintInfoOutputPhotoGrayscale
} NS_SWIFT_NAME(UIPrintInfo.OutputType);
typedef NS_ENUM(NSInteger, UIPrintInfoOrientation) { UIPrintInfoOrientationPortrait, UIPrintInfoOrientationLandscape } NS_SWIFT_NAME(UIPrintInfo.Orientation);
typedef NS_ENUM(NSInteger, UIPrintInfoDuplex) { UIPrintInfoDuplexNone, UIPrintInfoDuplexLongEdge, UIPrintInfoDuplexShortEdge } NS_SWIFT_NAME(UIPrintInfo.Duplex);

NS_SWIFT_UI_ACTOR
@interface UIPrintInfo : NSObject <NSCopying, NSSecureCoding>
+ (UIPrintInfo *)printInfo NS_SWIFT_NAME(printInfo());
+ (UIPrintInfo *)printInfoWithDictionary:(nullable NSDictionary *)dictionary NS_SWIFT_NAME(init(dictionary:));
- (NSDictionary *)dictionaryRepresentation;
@property (nullable, nonatomic, copy) NSString *printerID;
@property (nonatomic, copy) NSString *jobName;
@property (nonatomic) UIPrintInfoOutputType outputType;
@property (nonatomic) UIPrintInfoOrientation orientation;
@property (nonatomic) UIPrintInfoDuplex duplex;
@end

NS_SWIFT_UI_ACTOR
@interface UIPrintPaper : NSObject
+ (UIPrintPaper *)bestPaperForPageSize:(CGSize)contentSize withPapersFromArray:(NSArray<UIPrintPaper *> *)paperList NS_SWIFT_NAME(bestPaper(forPageSize:withPapersFrom:));
@property (readonly) CGSize paperSize;
@property (readonly) CGRect printableRect;
@end

NS_SWIFT_UI_ACTOR
@interface UIPrintFormatter : NSObject <NSCopying>
@property (nullable, nonatomic, readonly, weak) UIPrintPageRenderer *printPageRenderer;
- (void)removeFromPrintPageRenderer;
@property (nonatomic) CGFloat maximumContentHeight;
@property (nonatomic) CGFloat maximumContentWidth;
@property (nonatomic) UIEdgeInsets contentInsets API_DEPRECATED("perPageContentInsets", ios(4.2, 10.0));
@property (nonatomic) UIEdgeInsets perPageContentInsets;
@property (nonatomic) NSInteger startPage;
@property (nonatomic, readonly) NSInteger pageCount;
- (CGRect)rectForPageAtIndex:(NSInteger)pageIndex;
- (void)drawInRect:(CGRect)rect forPageAtIndex:(NSInteger)pageIndex;
@end

NS_SWIFT_UI_ACTOR
@interface UISimpleTextPrintFormatter : UIPrintFormatter
- (instancetype)initWithText:(NSString *)text;
- (instancetype)initWithAttributedText:(NSAttributedString *)attributedText;
@property (nullable, nonatomic, copy) NSString *text;
@property (nullable, nonatomic, copy) NSAttributedString *attributedText;
@property (nullable, nonatomic, strong) UIFont *font;
@property (nullable, nonatomic, strong) UIColor *color;
@property (nonatomic) NSTextAlignment textAlignment;
@end

/* isim: the markup is printed as its text (tags removed, entities decoded; adapted: no HTML layout) */
NS_SWIFT_UI_ACTOR
@interface UIMarkupTextPrintFormatter : UIPrintFormatter
- (instancetype)initWithMarkupText:(NSString *)markupText;
@property (nullable, nonatomic, copy) NSString *markupText;
@end

/* isim: the view as drawn on screen, scaled to the page width and continued over as many pages as it needs */
NS_SWIFT_UI_ACTOR
@interface UIViewPrintFormatter : UIPrintFormatter
@property (nonatomic, readonly) UIView *view;
@end

@interface UIView (UIPrintFormatter)
- (UIViewPrintFormatter *)viewPrintFormatter;
- (void)drawRect:(CGRect)rect forViewPrintFormatter:(UIViewPrintFormatter *)formatter;
@end

NS_SWIFT_UI_ACTOR
@interface UIPrintPageRenderer : NSObject
@property (nonatomic) CGFloat headerHeight;
@property (nonatomic) CGFloat footerHeight;
@property (nonatomic, readonly) CGRect paperRect;
@property (nonatomic, readonly) CGRect printableRect;
@property (nullable, atomic, copy) NSArray<UIPrintFormatter *> *printFormatters;
@property (nonatomic, readonly) NSInteger numberOfPages;
- (nullable NSArray<UIPrintFormatter *> *)printFormattersForPageAtIndex:(NSInteger)pageIndex;
- (void)addPrintFormatter:(UIPrintFormatter *)formatter startingAtPageAtIndex:(NSInteger)pageIndex;
- (void)prepareForDrawingPages:(NSRange)range;
- (void)drawPageAtIndex:(NSInteger)pageIndex inRect:(CGRect)printableRect;
- (void)drawPrintFormatter:(UIPrintFormatter *)printFormatter forPageAtIndex:(NSInteger)pageIndex;
- (void)drawHeaderForPageAtIndex:(NSInteger)pageIndex inRect:(CGRect)headerRect;
- (void)drawContentForPageAtIndex:(NSInteger)pageIndex inRect:(CGRect)contentRect;
- (void)drawFooterForPageAtIndex:(NSInteger)pageIndex inRect:(CGRect)footerRect;
@end

typedef void (^UIPrintInteractionCompletionHandler)(UIPrintInteractionController *printInteractionController, BOOL completed, NSError *_Nullable error);

@protocol UIPrintInteractionControllerDelegate <NSObject>
@optional
- (nullable UIViewController *)printInteractionControllerParentViewController:(UIPrintInteractionController *)printInteractionController;
- (UIPrintPaper *)printInteractionController:(UIPrintInteractionController *)printInteractionController choosePaper:(NSArray<UIPrintPaper *> *)paperList;
- (void)printInteractionControllerWillPresentPrinterOptions:(UIPrintInteractionController *)printInteractionController;
- (void)printInteractionControllerDidPresentPrinterOptions:(UIPrintInteractionController *)printInteractionController;
- (void)printInteractionControllerWillDismissPrinterOptions:(UIPrintInteractionController *)printInteractionController;
- (void)printInteractionControllerDidDismissPrinterOptions:(UIPrintInteractionController *)printInteractionController;
- (void)printInteractionControllerWillStartJob:(UIPrintInteractionController *)printInteractionController;
- (void)printInteractionControllerDidFinishJob:(UIPrintInteractionController *)printInteractionController;
- (CGFloat)printInteractionController:(UIPrintInteractionController *)printInteractionController cutLengthForPaper:(UIPrintPaper *)paper;
@end

NS_SWIFT_UI_ACTOR
@interface UIPrintInteractionController : NSObject
@property (class, nonatomic, readonly, getter=isPrintingAvailable) BOOL printingAvailable;
@property (class, nonatomic, readonly) NSSet<NSString *> *printableUTIs;
+ (BOOL)canPrintURL:(NSURL *)url;
+ (BOOL)canPrintData:(NSData *)data;
@property (class, nonatomic, readonly) UIPrintInteractionController *sharedPrintController NS_SWIFT_NAME(shared);
@property (nullable, nonatomic, strong) UIPrintInfo *printInfo;
@property (nullable, nonatomic, weak) id<UIPrintInteractionControllerDelegate> delegate;
@property (nonatomic) BOOL showsPageRange API_DEPRECATED("pages are always selectable", ios(4.2, 10.0));
@property (nonatomic) BOOL showsNumberOfCopies;
@property (nonatomic) BOOL showsPaperSelectionForLoadedPapers;
@property (nonatomic) BOOL showsPaperOrientation;
@property (nullable, nonatomic, readonly) UIPrintPaper *printPaper;
@property (nullable, nonatomic, strong) UIPrintPageRenderer *printPageRenderer;
@property (nullable, nonatomic, strong) UIPrintFormatter *printFormatter;
@property (nullable, nonatomic, copy) id printingItem;
@property (nullable, nonatomic, copy) NSArray *printingItems;
- (BOOL)presentAnimated:(BOOL)animated completionHandler:(nullable UIPrintInteractionCompletionHandler)completion;
- (BOOL)presentFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated completionHandler:(nullable UIPrintInteractionCompletionHandler)completion;
- (BOOL)presentFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated completionHandler:(nullable UIPrintInteractionCompletionHandler)completion;
- (BOOL)printToPrinter:(UIPrinter *)printer completionHandler:(nullable UIPrintInteractionCompletionHandler)completion;
- (void)dismissAnimated:(BOOL)animated;
@end

typedef NS_OPTIONS(NSInteger, UIPrinterJobTypes) {
    UIPrinterJobTypeUnknown = 0, UIPrinterJobTypeDocument = 1 << 0, UIPrinterJobTypeEnvelope = 1 << 1, UIPrinterJobTypeLabel = 1 << 2,
    UIPrinterJobTypePhoto = 1 << 3, UIPrinterJobTypeReceipt = 1 << 4, UIPrinterJobTypeRoll = 1 << 5, UIPrinterJobTypeLargeFormat = 1 << 6, UIPrinterJobTypePostcard = 1 << 7
} NS_SWIFT_NAME(UIPrinter.JobTypes);

NS_SWIFT_UI_ACTOR
@interface UIPrinter : NSObject
+ (UIPrinter *)printerWithURL:(NSURL *)url;
@property (nonatomic, readonly, copy) NSURL *URL;
@property (nonatomic, readonly, copy) NSString *displayName;
@property (nullable, nonatomic, readonly, copy) NSString *displayLocation;
@property (nonatomic, readonly) UIPrinterJobTypes supportedJobTypes;
@property (nullable, nonatomic, readonly, copy) NSString *makeAndModel;
@property (nonatomic, readonly) BOOL supportsColor;
@property (nonatomic, readonly) BOOL supportsDuplex;
- (void)contactPrinter:(nullable void (^)(BOOL available))completionHandler;
@end

typedef void (^UIPrinterPickerCompletionHandler)(UIPrinterPickerController *printerPickerController, BOOL userDidSelect, NSError *_Nullable error);
@protocol UIPrinterPickerControllerDelegate <NSObject>
@optional
- (nullable UIViewController *)printerPickerControllerParentViewController:(UIPrinterPickerController *)printerPickerController;
- (BOOL)printerPickerController:(UIPrinterPickerController *)printerPickerController shouldShowPrinter:(UIPrinter *)printer;
- (void)printerPickerControllerWillPresent:(UIPrinterPickerController *)printerPickerController;
- (void)printerPickerControllerDidPresent:(UIPrinterPickerController *)printerPickerController;
- (void)printerPickerControllerWillDismiss:(UIPrinterPickerController *)printerPickerController;
- (void)printerPickerControllerDidDismiss:(UIPrinterPickerController *)printerPickerController;
- (void)printerPickerControllerDidSelectPrinter:(UIPrinterPickerController *)printerPickerController;
@end

NS_SWIFT_UI_ACTOR
@interface UIPrinterPickerController : NSObject
+ (UIPrinterPickerController *)printerPickerControllerWithInitiallySelectedPrinter:(nullable UIPrinter *)printer NS_SWIFT_NAME(init(initiallySelectedPrinter:));
@property (nullable, nonatomic, readonly) UIPrinter *selectedPrinter;
@property (nullable, nonatomic, weak) id<UIPrinterPickerControllerDelegate> delegate;
- (BOOL)presentAnimated:(BOOL)animated completionHandler:(nullable UIPrinterPickerCompletionHandler)completion;
- (BOOL)presentFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated completionHandler:(nullable UIPrinterPickerCompletionHandler)completion;
- (BOOL)presentFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated completionHandler:(nullable UIPrinterPickerCompletionHandler)completion;
- (void)dismissAnimated:(BOOL)animated;
@end
NS_ASSUME_NONNULL_END
