#pragma once
#import <PDFKit/PDFKitPlatform.h>
#import <PDFKit/PDFDocument.h>
#import <PDFKit/PDFPage.h>
NS_ASSUME_NONNULL_BEGIN
@class PDFDestination;
@protocol PDFViewDelegate, PDFPageOverlayViewProvider;

typedef NS_ENUM(NSInteger, PDFDisplayMode) {
    kPDFDisplaySinglePage = 0, kPDFDisplaySinglePageContinuous = 1, kPDFDisplayTwoUp = 2, kPDFDisplayTwoUpContinuous = 3
};
typedef NS_ENUM(NSInteger, PDFDisplayDirection) { kPDFDisplayDirectionVertical = 0, kPDFDisplayDirectionHorizontal = 1 }
    PDFKIT_AVAILABLE(10_13, 11_0);
typedef NS_ENUM(NSInteger, PDFInterpolationQuality) {
    kPDFInterpolationQualityNone = 0, kPDFInterpolationQualityLow = 1, kPDFInterpolationQualityHigh = 2
};
typedef NS_OPTIONS(NSInteger, PDFAreaOfInterest) {
    kPDFNoArea = 0, kPDFPageArea = (1UL << 0), kPDFTextArea = (1UL << 1), kPDFAnnotationArea = (1UL << 2), kPDFLinkArea = (1UL << 3),
    kPDFControlArea = (1UL << 4), kPDFTextFieldArea = (1UL << 5), kPDFIconArea = (1UL << 6), kPDFPopupArea = (1UL << 7),
    kPDFImageArea = (1UL << 8), kPDFAnyArea = NSIntegerMax
};

PDFKIT_EXTERN NSNotificationName const PDFViewDocumentChangedNotification PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN NSNotificationName const PDFViewChangedHistoryNotification PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN NSNotificationName const PDFViewPageChangedNotification PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN NSNotificationName const PDFViewScaleChangedNotification PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN NSNotificationName const PDFViewAnnotationHitNotification PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN NSNotificationName const PDFViewCopyPermissionNotification PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN NSNotificationName const PDFViewPrintPermissionNotification PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN NSNotificationName const PDFViewAnnotationWillHitNotification PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN NSNotificationName const PDFViewSelectionChangedNotification PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN NSNotificationName const PDFViewDisplayModeChangedNotification PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN NSNotificationName const PDFViewDisplayBoxChangedNotification PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN NSNotificationName const PDFViewVisiblePagesChangedNotification PDFKIT_AVAILABLE(10_4, 11_0);

/* isim: a scroll view of page views, laid out by isim at the scale factor (pages redraw at each scale, so they stay
 * sharp): pinch to zoom, double-tap to zoom in or back to fit, tap a link to follow it. Selection, find, annotations
 * and PDFAction (issue #358) are not in isim yet. */
PDFKIT_CLASS_AVAILABLE(10_4, 11_0)
@interface PDFView : PDFKitPlatformView
@property (nonatomic, strong, nullable) PDFDocument *document;
@property (nonatomic, readonly) BOOL canGoToFirstPage;
- (IBAction)goToFirstPage:(nullable id)sender;
@property (nonatomic, readonly) BOOL canGoToLastPage;
- (IBAction)goToLastPage:(nullable id)sender;
@property (nonatomic, readonly) BOOL canGoToNextPage;
- (IBAction)goToNextPage:(nullable id)sender;
@property (nonatomic, readonly) BOOL canGoToPreviousPage;
- (IBAction)goToPreviousPage:(nullable id)sender;
@property (nonatomic, readonly) BOOL canGoBack;
- (IBAction)goBack:(nullable id)sender;
@property (nonatomic, readonly) BOOL canGoForward;
- (IBAction)goForward:(nullable id)sender;
@property (nonatomic, readonly, nullable) PDFPage *currentPage;
- (void)goToPage:(PDFPage *)page;
@property (nonatomic, readonly, nullable) PDFDestination *currentDestination;
- (void)goToDestination:(PDFDestination *)destination;
- (void)goToRect:(PDFRect)rect onPage:(PDFPage *)page PDFKIT_AVAILABLE(10_7, 11_0);
@property (nonatomic) PDFDisplayMode displayMode;
@property (nonatomic) PDFDisplayDirection displayDirection PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) BOOL displaysPageBreaks;
@property (nonatomic) PDFEdgeInsets pageBreakMargins PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) PDFDisplayBox displayBox;
@property (nonatomic) BOOL displaysAsBook;
@property (nonatomic) BOOL displaysRTL PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, copy) PDFKitPlatformColor *backgroundColor;
@property (nonatomic) PDFInterpolationQuality interpolationQuality PDFKIT_AVAILABLE(10_7, 11_0);
@property (nonatomic) BOOL pageShadowsEnabled PDFKIT_AVAILABLE(10_14, 12_0);
@property (nonatomic) BOOL shouldAntiAlias;
@property (nonatomic) CGFloat greekingThreshold;
@property (nonatomic, weak, nullable) id<PDFViewDelegate> delegate;
@property (nonatomic) CGFloat scaleFactor;
@property (nonatomic) CGFloat minScaleFactor PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) CGFloat maxScaleFactor PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic) BOOL autoScales;
@property (nonatomic, readonly) CGFloat scaleFactorForSizeToFit PDFKIT_AVAILABLE(10_13, 11_0);
- (IBAction)zoomIn:(nullable id)sender;
@property (nonatomic, readonly) BOOL canZoomIn;
- (IBAction)zoomOut:(nullable id)sender;
@property (nonatomic, readonly) BOOL canZoomOut;
- (PDFAreaOfInterest)areaOfInterestForMouse:(PDFKitPlatformEvent *)event;
- (PDFAreaOfInterest)areaOfInterestForPoint:(PDFPoint)cursorLocation PDFKIT_AVAILABLE(10_12, 11_0);
- (void)setCursorForAreaOfInterest:(PDFAreaOfInterest)area;
- (void)drawPage:(PDFPage *)page toContext:(CGContextRef)context PDFKIT_AVAILABLE(10_12, 11_0);
- (void)drawPagePost:(PDFPage *)page toContext:(CGContextRef)context PDFKIT_AVAILABLE(10_12, 11_0);
- (nullable PDFPage *)pageForPoint:(PDFPoint)point nearest:(BOOL)nearest;
- (PDFPoint)convertPoint:(PDFPoint)point toPage:(PDFPage *)page;
- (PDFRect)convertRect:(PDFRect)rect toPage:(PDFPage *)page;
- (PDFPoint)convertPoint:(PDFPoint)point fromPage:(PDFPage *)page;
- (PDFRect)convertRect:(PDFRect)rect fromPage:(PDFPage *)page;
@property (nonatomic, readonly, nullable) PDFKitPlatformView *documentView;
- (void)layoutDocumentView;
- (void)annotationsChangedOnPage:(PDFPage *)page;
- (PDFSize)rowSizeForPage:(PDFPage *)page;
@property (nonatomic) BOOL allowsDragging;
@property (nonatomic) BOOL acceptsDraggedFiles PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, readonly) NSArray<PDFPage *> *visiblePages;
@property (nonatomic) BOOL enableDataDetectors PDFKIT_AVAILABLE(10_6, 11_0);
@property (nonatomic, getter=isInMarkupMode) BOOL inMarkupMode API_AVAILABLE(macos(13.0), ios(16.0));
@property (nonatomic, weak, nullable) id<PDFPageOverlayViewProvider> pageOverlayViewProvider API_AVAILABLE(macos(13.0), ios(16.0));
- (void)usePageViewController:(BOOL)enable withViewOptions:(nullable NSDictionary *)viewOptions PDFKIT_AVAILABLE(NA, 11_0);
- (BOOL)isUsingPageViewController PDFKIT_AVAILABLE(NA, 11_0);
@end

@protocol PDFViewDelegate <NSObject>
@optional
- (CGFloat)PDFViewWillChangeScaleFactor:(PDFView *)sender toScale:(CGFloat)scale NS_SWIFT_NAME(pdfViewWillChangeScaleFactor(_:toScale:));
- (void)PDFViewWillClickOnLink:(PDFView *)sender withURL:(NSURL *)url NS_SWIFT_NAME(pdfViewWillClick(onLink:with:));
- (NSString *)PDFViewPrintJobTitle:(PDFView *)sender NS_SWIFT_NAME(pdfViewPrintJobTitle(_:));
- (void)PDFViewPerformFind:(PDFView *)sender NS_SWIFT_NAME(pdfViewPerformFind(_:));
- (void)PDFViewPerformGoToPage:(PDFView *)sender NS_SWIFT_NAME(pdfViewPerformGo(toPage:));
- (void)PDFViewPerformPrint:(PDFView *)sender NS_SWIFT_NAME(pdfViewPerformPrint(_:));
- (PDFKitPlatformViewController *)PDFViewParentViewController PDFKIT_AVAILABLE(NA, 13_0) NS_SWIFT_NAME(pdfViewParentViewController());
@end

API_AVAILABLE(macos(13.0), ios(16.0))
@protocol PDFPageOverlayViewProvider <NSObject>
@required
- (nullable PDFKitPlatformView *)pdfView:(PDFView *)view overlayViewForPage:(PDFPage *)page;
@optional
- (void)pdfView:(PDFView *)pdfView willDisplayOverlayView:(PDFKitPlatformView *)overlayView forPage:(PDFPage *)page;
- (void)pdfView:(PDFView *)pdfView willEndDisplayingOverlayView:(PDFKitPlatformView *)overlayView forPage:(PDFPage *)page;
@end

NS_ASSUME_NONNULL_END
