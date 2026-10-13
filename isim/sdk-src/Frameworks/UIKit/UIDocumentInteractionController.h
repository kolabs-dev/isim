#pragma once
/* isim: UIDocumentInteractionController (iOS 3.2) and UIManagedDocument (iOS 5), from the documentation sweep (#9).
   UIDocumentExtras.m. The preview is QuickLook's QLPreviewController presented from the delegate's controller; the
   options and Open In menus are the share sheet (adapted: isim lists its Share and Action extensions, not apps). */
#import <UIKit/UIDocument.h>
#import <UIKit/UIViewController.h>
NS_ASSUME_NONNULL_BEGIN
@class UIDocumentInteractionController, UIBarButtonItem, UIImage, UIGestureRecognizer, UIView;

NS_SWIFT_UI_ACTOR
@protocol UIDocumentInteractionControllerDelegate <NSObject>
@optional
/* the controller the preview is presented from (no controller: no preview) */
- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller;
- (nullable UIView *)documentInteractionControllerViewForPreview:(UIDocumentInteractionController *)controller;
- (CGRect)documentInteractionControllerRectForPreview:(UIDocumentInteractionController *)controller;
- (void)documentInteractionControllerWillBeginPreview:(UIDocumentInteractionController *)controller;
- (void)documentInteractionControllerDidEndPreview:(UIDocumentInteractionController *)controller;
- (void)documentInteractionControllerWillPresentOptionsMenu:(UIDocumentInteractionController *)controller;
- (void)documentInteractionControllerDidDismissOptionsMenu:(UIDocumentInteractionController *)controller;
- (void)documentInteractionControllerWillPresentOpenInMenu:(UIDocumentInteractionController *)controller;
- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller;
/* sending the file to another app (isim: never sent; there is no other app to open it in) */
- (void)documentInteractionController:(UIDocumentInteractionController *)controller willBeginSendingToApplication:(nullable NSString *)application;
- (void)documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(nullable NSString *)application;
@end

NS_SWIFT_UI_ACTOR
@interface UIDocumentInteractionController : NSObject
+ (UIDocumentInteractionController *)interactionControllerWithURL:(NSURL *)url NS_SWIFT_NAME(init(url:));
@property (nullable, nonatomic, weak) id<UIDocumentInteractionControllerDelegate> delegate;
@property (nullable, strong) NSURL *URL;
@property (nullable, nonatomic, copy) NSString *UTI;            /* from the file's extension unless set */
@property (nullable, copy) NSString *name;                      /* the file name unless set */
@property (nonatomic, readonly) NSArray<UIImage *> *icons;
@property (nullable, nonatomic, strong) id annotation;
- (BOOL)presentPreviewAnimated:(BOOL)animated;
- (void)dismissPreviewAnimated:(BOOL)animated;
- (BOOL)presentOptionsMenuFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated;
- (BOOL)presentOptionsMenuFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated;
- (BOOL)presentOpenInMenuFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated;
- (BOOL)presentOpenInMenuFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated;
- (void)dismissMenuAnimated:(BOOL)animated;
@property (nonatomic, readonly) NSArray<UIGestureRecognizer *> *gestureRecognizers;
@end

/* a document backed by a Core Data store in its package (<document>/StoreContent/persistentStore, SQLite); saving
   saves the context. The app links CoreData (isim's UIKit looks it up at run time) */
@class NSManagedObjectContext, NSManagedObjectModel, NSPersistentStoreCoordinator;
NS_SWIFT_UI_ACTOR
@interface UIManagedDocument : UIDocument
@property (class, nonatomic, readonly) NSString *persistentStoreName;
@property (nonatomic, readonly, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readonly, strong) NSManagedObjectModel *managedObjectModel;
@property (nullable, nonatomic, copy) NSDictionary *persistentStoreOptions;
@property (nullable, nonatomic, copy) NSString *modelConfiguration;
- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)storeURL ofType:(NSString *)fileType modelConfiguration:(nullable NSString *)configuration
                                     storeOptions:(nullable NSDictionary *)storeOptions error:(NSError **)error;
- (NSString *)persistentStoreTypeForFileType:(NSString *)fileType;
/* content kept beside the store (<document>/AdditionalContent) */
- (BOOL)readAdditionalContentFromURL:(NSURL *)absoluteURL error:(NSError **)error;
- (nullable id)additionalContentForURL:(NSURL *)absoluteURL error:(NSError **)error;
- (BOOL)writeAdditionalContent:(id)content toURL:(NSURL *)absoluteURL originalContentsURL:(nullable NSURL *)absoluteOriginalContentsURL error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
