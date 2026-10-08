#pragma once
/* isim SDK: UIDocumentPickerViewController and UIDocumentBrowserViewController (self-authored, API-compatible names).
 * They browse the device's files like the Files app: "On My iPhone" ($ISIM_DATA/Files, shared by the device's apps)
 * with a folder for each app that shares its Documents (UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace).
 * No iCloud Drive or other file providers (like a Simulator without an Apple Account). The Swift initializers that take
 * UTType (init(forOpeningContentTypes:asCopy:), init(forOpening:)) come from isim's UIKit overlay. */
#import <UIKit/UIViewController.h>
NS_ASSUME_NONNULL_BEGIN
@class UIDocumentPickerViewController, UIDocumentBrowserViewController, UIBarButtonItem;

typedef NS_ENUM(NSUInteger, UIDocumentPickerMode) {
    UIDocumentPickerModeImport, UIDocumentPickerModeOpen, UIDocumentPickerModeExportToService, UIDocumentPickerModeMoveToService
};

@protocol UIDocumentPickerDelegate <NSObject>
@optional
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls;
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller;
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url API_DEPRECATED("didPickDocumentsAtURLs", ios(8.0, 11.0));
@end

NS_SWIFT_UI_ACTOR
@interface UIDocumentPickerViewController : UIViewController
- (instancetype)initWithDocumentTypes:(NSArray<NSString *> *)allowedUTIs inMode:(UIDocumentPickerMode)mode API_DEPRECATED("init(forOpeningContentTypes:asCopy:)", ios(8.0, 14.0));
- (instancetype)initWithURL:(NSURL *)url inMode:(UIDocumentPickerMode)mode API_DEPRECATED("init(forExporting:asCopy:)", ios(8.0, 14.0));
- (instancetype)initWithURLs:(NSArray<NSURL *> *)urls inMode:(UIDocumentPickerMode)mode API_DEPRECATED("init(forExporting:asCopy:)", ios(11.0, 14.0));
- (instancetype)initForExportingURLs:(NSArray<NSURL *> *)urls asCopy:(BOOL)asCopy API_AVAILABLE(ios(14.0));
- (instancetype)initForExportingURLs:(NSArray<NSURL *> *)urls API_AVAILABLE(ios(14.0));
/* isim: what the overlay's init(forOpeningContentTypes:asCopy:) calls, with the types' identifiers */
- (instancetype)initForIsimOpeningTypeIdentifiers:(NSArray<NSString *> *)identifiers asCopy:(BOOL)asCopy NS_SWIFT_NAME(init(_isimOpeningTypeIdentifiers:asCopy:));
@property (nullable, nonatomic, weak) id<UIDocumentPickerDelegate> delegate;
@property (nonatomic, readonly) UIDocumentPickerMode documentPickerMode;
@property (nonatomic) BOOL allowsMultipleSelection;
@property (nonatomic) BOOL shouldShowFileExtensions;
@property (nullable, nonatomic, copy) NSURL *directoryURL;
@end

typedef NS_ENUM(NSInteger, UIDocumentBrowserImportMode) { UIDocumentBrowserImportModeNone, UIDocumentBrowserImportModeCopy, UIDocumentBrowserImportModeMove } NS_SWIFT_NAME(UIDocumentBrowserViewController.ImportMode);
typedef NS_ENUM(NSInteger, UIDocumentBrowserUserInterfaceStyle) { UIDocumentBrowserUserInterfaceStyleWhite, UIDocumentBrowserUserInterfaceStyleLight, UIDocumentBrowserUserInterfaceStyleDark } NS_SWIFT_NAME(UIDocumentBrowserViewController.BrowserUserInterfaceStyle);
UIKIT_EXTERN NSErrorDomain const UIDocumentBrowserErrorDomain;
typedef NS_ERROR_ENUM(UIDocumentBrowserErrorDomain, UIDocumentBrowserErrorCode) { UIDocumentBrowserErrorGeneric = 1, UIDocumentBrowserErrorNoLocationAvailable = 2 };

@protocol UIDocumentBrowserViewControllerDelegate <NSObject>
@optional
- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)documentURLs;
- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didRequestDocumentCreationWithHandler:(void (^)(NSURL *_Nullable urlToImport, UIDocumentBrowserImportMode importMode))importHandler;
- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didImportDocumentAtURL:(NSURL *)sourceURL toDestinationURL:(NSURL *)destinationURL;
- (void)documentBrowser:(UIDocumentBrowserViewController *)controller failedToImportDocumentAtURL:(NSURL *)documentURL error:(nullable NSError *)error;
@end

NS_SWIFT_UI_ACTOR
@interface UIDocumentBrowserViewController : UIViewController
- (instancetype)initForOpeningFilesWithContentTypes:(nullable NSArray<NSString *> *)allowedContentTypes API_DEPRECATED("init(forOpening:)", ios(11.0, 14.0));
- (instancetype)initForIsimOpeningTypeIdentifiers:(nullable NSArray<NSString *> *)identifiers NS_SWIFT_NAME(init(_isimOpeningTypeIdentifiers:));
@property (nullable, nonatomic, weak) id<UIDocumentBrowserViewControllerDelegate> delegate;
@property (nonatomic, readonly, nullable) NSArray<NSString *> *allowedContentTypes;
@property (nonatomic) BOOL allowsDocumentCreation;
@property (nonatomic) BOOL allowsPickingMultipleItems;
@property (nonatomic) BOOL shouldShowFileExtensions;
@property (nonatomic) UIDocumentBrowserUserInterfaceStyle browserUserInterfaceStyle;
@property (nonatomic, copy) NSArray<UIBarButtonItem *> *additionalLeadingNavigationBarButtonItems;
@property (nonatomic, copy) NSArray<UIBarButtonItem *> *additionalTrailingNavigationBarButtonItems;
@property (nonatomic, copy) NSString *localizedCreateDocumentActionTitle;
@property (nonatomic) CGFloat defaultDocumentAspectRatio;
- (void)revealDocumentAtURL:(NSURL *)url importIfNeeded:(BOOL)importIfNeeded completion:(nullable void (^)(NSURL *_Nullable revealedDocumentURL, NSError *_Nullable error))completion;
- (void)importDocumentAtURL:(NSURL *)documentURL nextToDocumentAtURL:(NSURL *)neighbourURL mode:(UIDocumentBrowserImportMode)importMode
          completionHandler:(void (^)(NSURL *_Nullable, NSError *_Nullable))completion;
@end
NS_ASSUME_NONNULL_END
