#pragma once
/* isim SDK: UIDocument (self-authored, API-compatible names). Adapted: documents are files read and written through
 * NSFileManager on a background queue (no NSFileCoordinator / NSFilePresenter: other processes' edits are not
 * observed, and there are no conflicts, versions or iCloud). Reading and writing follow UIKit's call order
 * (readFromURL -> loadFromContents, contentsForType -> writeContents...), so subclasses override the same methods.
 * File packages (NSFileWrapper contents) are not supported: contents are NSData. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class NSUndoManager, NSUserActivity, NSProgress;

typedef NS_ENUM(NSInteger, UIDocumentChangeKind) {
    UIDocumentChangeDone, UIDocumentChangeUndone, UIDocumentChangeRedone, UIDocumentChangeCleared
} NS_SWIFT_NAME(UIDocument.ChangeKind);
typedef NS_ENUM(NSInteger, UIDocumentSaveOperation) {
    UIDocumentSaveForCreating, UIDocumentSaveForOverwriting
} NS_SWIFT_NAME(UIDocument.SaveOperation);
typedef NS_OPTIONS(NSUInteger, UIDocumentState) {
    UIDocumentStateNormal = 0,
    UIDocumentStateClosed = 1 << 0,
    UIDocumentStateInConflict = 1 << 1,
    UIDocumentStateSavingError = 1 << 2,
    UIDocumentStateEditingDisabled = 1 << 3,
    UIDocumentStateProgressAvailable = 1 << 4,
} NS_SWIFT_NAME(UIDocument.State);

/* iOS 18: how a new document is created (UIDocumentViewController's launch view, the browser's creation request) */
typedef NSString *UIDocumentCreationIntent NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(UIDocument.CreationIntent) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN const UIDocumentCreationIntent UIDocumentCreationIntentDefault API_AVAILABLE(ios(18.0));

UIKIT_EXTERN NSNotificationName const UIDocumentStateChangedNotification NS_SWIFT_NAME(UIDocument.stateChangedNotification);
UIKIT_EXTERN NSNotificationName const UIDocumentDidMoveToWritableLocationNotification
    NS_SWIFT_NAME(UIDocument.didMoveToWritableLocationNotification) API_AVAILABLE(ios(26.0));
UIKIT_EXTERN NSString *const UIDocumentDidMoveToWritableLocationOldURLKey
    NS_SWIFT_NAME(UIDocument.didMoveToWritableLocationOldURLKey) API_AVAILABLE(ios(26.0));
UIKIT_EXTERN NSString *const NSUserActivityDocumentURLKey NS_SWIFT_NAME(UIDocument.userActivityURLKey);

NS_SWIFT_UI_ACTOR
@interface UIDocument : NSObject
- (instancetype)initWithFileURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/* attributes */
@property (readonly) NSURL *fileURL;
@property (readonly, copy) NSString *localizedName;
@property (readonly, copy, nullable) NSString *fileType;
@property (copy, nullable) NSDate *fileModificationDate;
@property (readonly) UIDocumentState documentState;
@property (readonly, nullable) NSProgress *progress API_AVAILABLE(ios(9.0));

/* reading */
- (void)openWithCompletionHandler:(void (^__nullable)(BOOL success))completionHandler;
- (void)closeWithCompletionHandler:(void (^__nullable)(BOOL success))completionHandler;
- (BOOL)loadFromContents:(id)contents ofType:(nullable NSString *)typeName error:(NSError **)outError;
- (BOOL)readFromURL:(NSURL *)url error:(NSError **)outError;

/* writing */
- (nullable id)contentsForType:(NSString *)typeName error:(NSError **)outError;
- (void)saveToURL:(NSURL *)url forSaveOperation:(UIDocumentSaveOperation)saveOperation completionHandler:(void (^__nullable)(BOOL success))completionHandler;
- (BOOL)writeContents:(id)contents andAttributes:(nullable NSDictionary *)additionalFileAttributes safelyToURL:(NSURL *)url
     forSaveOperation:(UIDocumentSaveOperation)saveOperation error:(NSError **)outError;
- (BOOL)writeContents:(id)contents toURL:(NSURL *)url forSaveOperation:(UIDocumentSaveOperation)saveOperation
  originalContentsURL:(nullable NSURL *)originalContentsURL error:(NSError **)outError;
@property (readonly, copy, nullable) NSString *savingFileType;
- (nullable NSDictionary *)fileAttributesToWriteToURL:(NSURL *)url forSaveOperation:(UIDocumentSaveOperation)saveOperation error:(NSError **)outError;
- (NSString *)fileNameExtensionForType:(nullable NSString *)typeName saveOperation:(UIDocumentSaveOperation)saveOperation;

/* file access on the document's serial queue */
- (void)performAsynchronousFileAccessUsingBlock:(void (^)(void))block;
- (void)revertToContentsOfURL:(NSURL *)url completionHandler:(void (^__nullable)(BOOL success))completionHandler;

/* editing */
- (void)disableEditing;
- (void)enableEditing;

/* changes and autosaving: a change starts an autosave after a short delay (adapted: 2 s; UIKit picks its own time) */
@property (readonly) BOOL hasUnsavedChanges;
- (void)updateChangeCount:(UIDocumentChangeKind)change;
@property (strong, null_resettable) NSUndoManager *undoManager;
- (id)changeCountTokenForSaveOperation:(UIDocumentSaveOperation)saveOperation;
- (void)updateChangeCountWithToken:(id)changeCountToken forSaveOperation:(UIDocumentSaveOperation)saveOperation;
- (void)autosaveWithCompletionHandler:(void (^__nullable)(BOOL success))completionHandler;

/* user activities */
@property (strong, nullable) NSUserActivity *userActivity API_AVAILABLE(ios(8.0));
- (void)updateUserActivityState:(NSUserActivity *)userActivity API_AVAILABLE(ios(8.0));
- (void)restoreUserActivityState:(NSUserActivity *)userActivity API_AVAILABLE(ios(8.0));

/* errors */
- (void)handleError:(NSError *)error userInteractionPermitted:(BOOL)userInteractionPermitted;
- (void)finishedHandlingError:(NSError *)error recovered:(BOOL)recovered;
- (void)userInteractionNoLongerPermittedForError:(NSError *)error;
@end
NS_ASSUME_NONNULL_END
