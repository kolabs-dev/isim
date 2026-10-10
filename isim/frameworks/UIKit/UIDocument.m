/* UIDocument: a document backed by a file.
 *
 * Adapted: reading and writing go through NSFileManager on the document's serial queue (UIKit coordinates them with
 * NSFileCoordinator; isim has none, so edits by other processes are not observed and there are no conflicts or file
 * versions). The calls follow UIKit's order, so subclasses override the same methods: opening reads the file on the
 * queue (readFromURL:error:) and loads it on the main queue (loadFromContents:ofType:error:); saving asks for the
 * contents on the main queue (contentsForType:error:) and writes them on the queue (writeContents:andAttributes:
 * safelyToURL:... -> writeContents:toURL:...: a temporary file renamed over the original). Changes counted through
 * updateChangeCount: or the undo manager start an autosave 2 s later (UIKit picks its own moment), and the document
 * also saves when the app goes to the background. Contents are NSData (no NSFileWrapper packages). */
#import "UIKitPrivate.h"
#import <UIKit/UIDocument.h>
#import <UIKit/UIApplication.h>
#include <dlfcn.h>
#include <stdlib.h>

const UIDocumentCreationIntent UIDocumentCreationIntentDefault = @"UIDocumentCreationIntentDefault";
NSNotificationName const UIDocumentStateChangedNotification = @"UIDocumentStateChangedNotification";
NSNotificationName const UIDocumentDidMoveToWritableLocationNotification = @"UIDocumentDidMoveToWritableLocationNotification";
NSString *const UIDocumentDidMoveToWritableLocationOldURLKey = @"UIDocumentDidMoveToWritableLocationOldURLKey";
NSString *const NSUserActivityDocumentURLKey = @"NSUserActivityDocumentURLKey";

/* the type identifier of a filename extension (UniformTypeIdentifiers, looked up at run time like the pickers do) */
NSString *isim_ui_type_for_extension(NSString *ext) {
    static char *(*fn)(const char *);
    static dispatch_once_t once;
    dispatch_once(&once, ^{ fn = (char *(*)(const char *))dlsym(RTLD_DEFAULT, "isim_uti_type_for_extension"); });
    if (!ext.length) return nil;
    if (!fn) return [ext.lowercaseString isEqualToString:@"txt"] ? @"public.plain-text" : nil;
    char *s = fn(ext.UTF8String);
    if (!s) return nil;
    NSString *r = [NSString stringWithUTF8String:s];
    free(s);
    return r;
}

@implementation UIDocument {
    NSURL *_fileURL;
    UIDocumentState _state;
    NSInteger _changes;
    NSUInteger _autosaveGeneration;
    dispatch_queue_t _queue;
    NSUndoManager *_undo;
    BOOL _saving;
}
- (instancetype)initWithFileURL:(NSURL *)url {
    if ((self = [super init])) {
        if (!url.isFileURL) [NSException raise:NSInvalidArgumentException format:@"UIDocument needs a file URL, not %@", url];
        _fileURL = url; _state = UIDocumentStateClosed;
        _queue = dispatch_queue_create("isim.uidocument", DISPATCH_QUEUE_SERIAL);
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_isimAppWillLeave:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_isimAppWillLeave:) name:UIApplicationWillTerminateNotification object:nil];
    }
    return self;
}
- (instancetype)init { return [self initWithFileURL:[NSURL fileURLWithPath:NSTemporaryDirectory()]]; }
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (NSString *)description { return [NSString stringWithFormat:@"<%@: %p fileURL: %@ documentState: [%@]>", self.class, self, _fileURL, [self _isimStateName]]; }
- (NSString *)_isimStateName {
    if (_state == UIDocumentStateNormal) return @"Normal";
    NSMutableArray *n = [NSMutableArray array];
    if (_state & UIDocumentStateClosed) [n addObject:@"Closed"];
    if (_state & UIDocumentStateInConflict) [n addObject:@"In Conflict"];
    if (_state & UIDocumentStateSavingError) [n addObject:@"Saving Error"];
    if (_state & UIDocumentStateEditingDisabled) [n addObject:@"Editing Disabled"];
    if (_state & UIDocumentStateProgressAvailable) [n addObject:@"Progress Available"];
    return [n componentsJoinedByString:@", "];
}

/* ---- attributes ---- */
- (NSURL *)fileURL { return _fileURL; }
- (NSString *)localizedName { return _fileURL.lastPathComponent.stringByDeletingPathExtension; }
- (NSString *)fileType { return isim_ui_type_for_extension(_fileURL.pathExtension); }
- (NSString *)savingFileType { return self.fileType; }
- (UIDocumentState)documentState { return _state; }
- (NSProgress *)progress { return nil; }
- (void)_isimSetState:(UIDocumentState)s {
    if (s == _state) return;
    _state = s;
    void (^post)(void) = ^{ [NSNotificationCenter.defaultCenter postNotificationName:UIDocumentStateChangedNotification object:self]; };
    if (NSThread.isMainThread) post(); else dispatch_async(dispatch_get_main_queue(), post);
}
- (NSError *)_isimError:(NSInteger)code text:(NSString *)text {
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:@{ NSLocalizedDescriptionKey: text, NSURLErrorKey: _fileURL }];
}
- (void)_isimUpdateModificationDate {
    NSDictionary *a = [NSFileManager.defaultManager attributesOfItemAtPath:_fileURL.path error:NULL];
    self.fileModificationDate = a[NSFileModificationDate];
}

/* ---- reading ---- */
- (void)openWithCompletionHandler:(void (^)(BOOL))done {
    if (!(_state & UIDocumentStateClosed)) { if (done) dispatch_async(dispatch_get_main_queue(), ^{ done(YES); }); return; }
    dispatch_async(_queue, ^{
        NSError *err = nil;
        BOOL ok = [self readFromURL:self->_fileURL error:&err];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ok) {
                [self _isimUpdateModificationDate];
                self->_changes = 0;
                [self _isimSetState:self->_state & ~(UIDocumentStateClosed | UIDocumentStateSavingError)];
                NSLog(@"isim UIKit: document opened %@", self->_fileURL.lastPathComponent);
            } else [self handleError:err ?: [self _isimError:NSFileReadUnknownError text:@"The document could not be opened."] userInteractionPermitted:YES];
            if (done) done(ok);
        });
    });
}
- (BOOL)readFromURL:(NSURL *)url error:(NSError **)outError {
    NSError *err = nil;
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&err];
    if (!data) { if (outError) *outError = err ?: [self _isimError:NSFileReadNoSuchFileError text:@"The file does not exist."]; return NO; }
    __block BOOL ok = NO; __block NSError *loadErr = nil;
    void (^load)(void) = ^{ NSError *e = nil; ok = [self loadFromContents:data ofType:self.fileType error:&e]; loadErr = e; };
    if (NSThread.isMainThread) load(); else dispatch_sync(dispatch_get_main_queue(), load);   /* UIKit loads on the main queue */
    if (!ok && outError) *outError = loadErr ?: [self _isimError:NSFileReadCorruptFileError text:@"The document could not be read."];
    return ok;
}
- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)outError {
    /* subclasses override this (UIKit raises in the base class) */
    [NSException raise:NSInternalInconsistencyException format:@"-[%@ loadFromContents:ofType:error:] is not implemented: UIDocument subclasses override it", self.class];
    return NO;
}
- (void)revertToContentsOfURL:(NSURL *)url completionHandler:(void (^)(BOOL))done {
    dispatch_async(_queue, ^{
        NSError *err = nil;
        BOOL ok = [self readFromURL:url error:&err];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ok) {
                self->_fileURL = url; self->_changes = 0; [self->_undo removeAllActions];
                [self _isimUpdateModificationDate];
                [self _isimSetState:self->_state & ~UIDocumentStateClosed];
            } else [self handleError:err userInteractionPermitted:YES];
            if (done) done(ok);
        });
    });
}

/* ---- writing ---- */
- (id)contentsForType:(NSString *)typeName error:(NSError **)outError {
    [NSException raise:NSInternalInconsistencyException format:@"-[%@ contentsForType:error:] is not implemented: UIDocument subclasses override it", self.class];
    return nil;
}
- (NSDictionary *)fileAttributesToWriteToURL:(NSURL *)url forSaveOperation:(UIDocumentSaveOperation)op error:(NSError **)outError {
    return op == UIDocumentSaveForCreating ? @{ NSFileExtensionHidden: @YES } : @{};
}
- (NSString *)fileNameExtensionForType:(NSString *)typeName saveOperation:(UIDocumentSaveOperation)op { return _fileURL.pathExtension; }
- (BOOL)writeContents:(id)contents toURL:(NSURL *)url forSaveOperation:(UIDocumentSaveOperation)op originalContentsURL:(NSURL *)original error:(NSError **)outError {
    if ([contents isKindOfClass:[NSString class]]) contents = [(NSString *)contents dataUsingEncoding:NSUTF8StringEncoding];
    if (![contents isKindOfClass:[NSData class]]) {
        if (outError) *outError = [self _isimError:NSFileWriteUnknownError text:[NSString stringWithFormat:@"isim writes NSData document contents, not %@", [contents class]]];
        return NO;
    }
    return [(NSData *)contents writeToURL:url options:0 error:outError];
}
- (BOOL)writeContents:(id)contents andAttributes:(NSDictionary *)attrs safelyToURL:(NSURL *)url forSaveOperation:(UIDocumentSaveOperation)op error:(NSError **)outError {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *dir = url.path.stringByDeletingLastPathComponent;
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSURL *tmp = [NSURL fileURLWithPath:[dir stringByAppendingPathComponent:[NSString stringWithFormat:@".%@.isim-saving", url.lastPathComponent]]];
    BOOL exists = [fm fileExistsAtPath:url.path];
    if (![self writeContents:contents toURL:tmp forSaveOperation:op originalContentsURL:exists ? url : nil error:outError]) { [fm removeItemAtURL:tmp error:NULL]; return NO; }
    NSMutableDictionary *a = [attrs mutableCopy] ?: [NSMutableDictionary dictionary];
    [a removeObjectForKey:NSFileExtensionHidden];                 /* not a POSIX attribute */
    if (a.count) [fm setAttributes:a ofItemAtPath:tmp.path error:NULL];
    if (rename(tmp.path.fileSystemRepresentation, url.path.fileSystemRepresentation) != 0) {
        [fm removeItemAtURL:tmp error:NULL];
        if (outError) *outError = [self _isimError:NSFileWriteUnknownError text:@"The document could not be saved."];
        return NO;
    }
    return YES;
}
- (void)saveToURL:(NSURL *)url forSaveOperation:(UIDocumentSaveOperation)op completionHandler:(void (^)(BOOL))done {
    NSError *err = nil;
    id contents = [self contentsForType:self.savingFileType ?: @"public.data" error:&err];
    id token = [self changeCountTokenForSaveOperation:op];
    if (!contents) {
        [self _isimSetState:_state | UIDocumentStateSavingError];
        [self handleError:err ?: [self _isimError:NSFileWriteUnknownError text:@"The document has no contents to save."] userInteractionPermitted:YES];
        if (done) dispatch_async(dispatch_get_main_queue(), ^{ done(NO); });
        return;
    }
    _saving = YES;
    dispatch_async(_queue, ^{
        NSError *e = nil;
        NSDictionary *attrs = [self fileAttributesToWriteToURL:url forSaveOperation:op error:&e];
        BOOL ok = [self writeContents:contents andAttributes:attrs safelyToURL:url forSaveOperation:op error:&e];
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_saving = NO;
            if (ok) {
                self->_fileURL = url;
                [self updateChangeCountWithToken:token forSaveOperation:op];
                [self _isimUpdateModificationDate];
                [self _isimSetState:self->_state & ~(UIDocumentStateSavingError | (op == UIDocumentSaveForCreating ? UIDocumentStateClosed : 0))];
                NSLog(@"isim UIKit: document saved %@", url.lastPathComponent);
            } else {
                [self _isimSetState:self->_state | UIDocumentStateSavingError];
                [self handleError:e ?: [self _isimError:NSFileWriteUnknownError text:@"The document could not be saved."] userInteractionPermitted:YES];
            }
            if (done) done(ok);
        });
    });
}
- (void)closeWithCompletionHandler:(void (^)(BOOL))done {
    if (_state & UIDocumentStateClosed) { if (done) dispatch_async(dispatch_get_main_queue(), ^{ done(YES); }); return; }
    [self autosaveWithCompletionHandler:^(BOOL ok) {
        dispatch_async(self->_queue, ^{                         /* after any file access still queued */
            dispatch_async(dispatch_get_main_queue(), ^{
                [self _isimSetState:self->_state | UIDocumentStateClosed];
                NSLog(@"isim UIKit: document closed %@", self->_fileURL.lastPathComponent);
                if (done) done(ok);
            });
        });
    }];
}

/* ---- file access ---- */
- (void)performAsynchronousFileAccessUsingBlock:(void (^)(void))block { if (block) dispatch_async(_queue, block); }

/* ---- editing ---- */
- (void)disableEditing { [self _isimSetState:_state | UIDocumentStateEditingDisabled]; }
- (void)enableEditing { [self _isimSetState:_state & ~UIDocumentStateEditingDisabled]; }

/* ---- changes and autosaving ---- */
- (BOOL)hasUnsavedChanges { return _changes != 0; }
- (void)updateChangeCount:(UIDocumentChangeKind)change {
    switch (change) {
    case UIDocumentChangeDone: case UIDocumentChangeRedone: _changes++; break;
    case UIDocumentChangeUndone: _changes--; break;
    case UIDocumentChangeCleared: _changes = 0; break;
    }
    if (_changes) [self _isimScheduleAutosave];
}
- (void)_isimScheduleAutosave {
    NSUInteger gen = ++_autosaveGeneration;
    __weak UIDocument *w = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIDocument *s = w;
        if (s && s->_autosaveGeneration == gen) [s autosaveWithCompletionHandler:nil];
    });
}
- (id)changeCountTokenForSaveOperation:(UIDocumentSaveOperation)op { return @(_changes); }
- (void)updateChangeCountWithToken:(id)token forSaveOperation:(UIDocumentSaveOperation)op {
    if ([token isKindOfClass:[NSNumber class]]) _changes -= [token integerValue];   /* changes made while saving stay unsaved */
}
- (void)autosaveWithCompletionHandler:(void (^)(BOOL))done {
    if (!self.hasUnsavedChanges || (_state & UIDocumentStateClosed) || _saving) { if (done) dispatch_async(dispatch_get_main_queue(), ^{ done(YES); }); return; }
    [self saveToURL:_fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:done];
}
- (void)_isimAppWillLeave:(NSNotification *)n {
    if (![n.name isEqualToString:UIApplicationWillTerminateNotification]) { [self autosaveWithCompletionHandler:nil]; return; }
    /* terminating: the app exits after this notification, so the save cannot wait for the main queue */
    if (!self.hasUnsavedChanges || (_state & UIDocumentStateClosed)) return;
    NSError *e = nil;
    id contents = [self contentsForType:self.savingFileType ?: @"public.data" error:&e];
    if (!contents) return;
    __block BOOL ok = NO;
    dispatch_sync(_queue, ^{
        NSError *we = nil;
        ok = [self writeContents:contents andAttributes:[self fileAttributesToWriteToURL:self->_fileURL forSaveOperation:UIDocumentSaveForOverwriting error:&we]
                     safelyToURL:self->_fileURL forSaveOperation:UIDocumentSaveForOverwriting error:&we];
    });
    if (ok) { _changes = 0; NSLog(@"isim UIKit: document saved %@", _fileURL.lastPathComponent); }
}
- (NSUndoManager *)undoManager {
    if (!_undo) self.undoManager = [NSUndoManager new];
    return _undo;
}
- (void)setUndoManager:(NSUndoManager *)m {
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    if (_undo) for (NSString *n in @[NSUndoManagerDidCloseUndoGroupNotification, NSUndoManagerDidUndoChangeNotification, NSUndoManagerDidRedoChangeNotification]) [nc removeObserver:self name:n object:_undo];
    _undo = m;
    if (!m) return;
    [nc addObserver:self selector:@selector(_isimUndoGroupClosed:) name:NSUndoManagerDidCloseUndoGroupNotification object:m];
    [nc addObserver:self selector:@selector(_isimUndid:) name:NSUndoManagerDidUndoChangeNotification object:m];
    [nc addObserver:self selector:@selector(_isimRedid:) name:NSUndoManagerDidRedoChangeNotification object:m];
}
- (void)_isimUndoGroupClosed:(NSNotification *)n {
    NSUndoManager *m = n.object;
    if (m.groupingLevel == 0 && !m.isUndoing && !m.isRedoing) [self updateChangeCount:UIDocumentChangeDone];
}
- (void)_isimUndid:(NSNotification *)n { [self updateChangeCount:UIDocumentChangeUndone]; }
- (void)_isimRedid:(NSNotification *)n { [self updateChangeCount:UIDocumentChangeRedone]; }

/* ---- user activities ---- */
- (void)updateUserActivityState:(NSUserActivity *)activity { [activity addUserInfoEntriesFromDictionary:@{ NSUserActivityDocumentURLKey: _fileURL }]; }
- (void)restoreUserActivityState:(NSUserActivity *)activity {}

/* ---- errors ---- */
- (void)handleError:(NSError *)error userInteractionPermitted:(BOOL)permitted {
    NSLog(@"isim UIKit: document %@: %@", _fileURL.lastPathComponent, error.localizedDescription);
    [self finishedHandlingError:error recovered:NO];
}
- (void)finishedHandlingError:(NSError *)error recovered:(BOOL)recovered {}
- (void)userInteractionNoLongerPermittedForError:(NSError *)error {}
@end
