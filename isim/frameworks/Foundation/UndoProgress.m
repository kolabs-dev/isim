/* isim Foundation (ARC): NSUndoManager and NSProgress. */
#import <Foundation/Foundation.h>
#include <objc/message.h>
#include "isim_foundation.h"

NSNotificationName const NSUndoManagerCheckpointNotification = @"NSUndoManagerCheckpointNotification",
    NSUndoManagerWillUndoChangeNotification = @"NSUndoManagerWillUndoChangeNotification",
    NSUndoManagerWillRedoChangeNotification = @"NSUndoManagerWillRedoChangeNotification",
    NSUndoManagerDidUndoChangeNotification = @"NSUndoManagerDidUndoChangeNotification",
    NSUndoManagerDidRedoChangeNotification = @"NSUndoManagerDidRedoChangeNotification",
    NSUndoManagerDidOpenUndoGroupNotification = @"NSUndoManagerDidOpenUndoGroupNotification",
    NSUndoManagerWillCloseUndoGroupNotification = @"NSUndoManagerWillCloseUndoGroupNotification",
    NSUndoManagerDidCloseUndoGroupNotification = @"NSUndoManagerDidCloseUndoGroupNotification";

/* ================= NSUndoManager ================= */
@interface _IsimUndoAction : NSObject
@property (nonatomic, weak) id target;
@property (nonatomic, strong) id strongTarget;      /* targets of block actions are kept alive like Apple's */
@property (nonatomic) SEL selector;
@property (nonatomic, strong) id object;
@property (nonatomic, copy) void (^block)(id);
@end
@implementation _IsimUndoAction
- (void)perform {
    id t = self.strongTarget ?: self.target;
    if (self.block) self.block(t);
    else if (t) ((void (*)(id, SEL, id))objc_msgSend)(t, self.selector, self.object);
}
@end
@interface _IsimUndoGroup : NSObject
@property (nonatomic, strong) NSMutableArray<_IsimUndoAction *> *actions;
@property (nonatomic, copy) NSString *actionName;
@end
@implementation _IsimUndoGroup
- (instancetype)init { if ((self = [super init])) { _actions = [NSMutableArray array]; _actionName = @""; } return self; }
@end

@implementation NSUndoManager {
    NSMutableArray<_IsimUndoGroup *> *_undo, *_redo;
    NSMutableArray<_IsimUndoGroup *> *_open;     /* nested open groups */
    NSInteger _disabled; BOOL _undoing, _redoing, _implicitOpen;
}
- (instancetype)init {
    if ((self = [super init])) { _undo = [NSMutableArray array]; _redo = [NSMutableArray array]; _open = [NSMutableArray array]; _groupsByEvent = YES; }
    return self;
}
- (void)_post:(NSString *)name { [[NSNotificationCenter defaultCenter] postNotificationName:name object:self]; }
- (NSInteger)groupingLevel { return (NSInteger)_open.count; }
- (void)beginUndoGrouping {
    [_open addObject:[_IsimUndoGroup new]];
    [self _post:NSUndoManagerDidOpenUndoGroupNotification];
}
- (void)endUndoGrouping {
    if (!_open.count) [NSException raise:NSInternalInconsistencyException format:@"endUndoGrouping called with no matching begin"];
    [self _post:NSUndoManagerWillCloseUndoGroupNotification];
    _IsimUndoGroup *g = _open.lastObject; [_open removeLastObject];
    if (_open.count) { [_open.lastObject.actions addObjectsFromArray:g.actions]; if (g.actionName.length) _open.lastObject.actionName = g.actionName; }
    else if (g.actions.count) {
        NSMutableArray *stack = _undoing ? _redo : _undo;
        [stack addObject:g];
        if (_levelsOfUndo > 0 && stack.count > _levelsOfUndo) [stack removeObjectAtIndex:0];
    }
    if (_open.count == 0) _implicitOpen = NO;
    [self _post:NSUndoManagerDidCloseUndoGroupNotification];
}
- (void)_closeImplicitGroup { if (_implicitOpen && _open.count == 1) [self endUndoGrouping]; }
- (void)_register:(_IsimUndoAction *)a {
    if (_disabled > 0) return;
    if (!_undoing && !_redoing) [_redo removeAllObjects];
    if (!_open.count) {
        if (_groupsByEvent && !_undoing && !_redoing) {
            /* like Apple: all registrations of one run loop turn form one group */
            [self beginUndoGrouping]; _implicitOpen = YES;
            dispatch_async(dispatch_get_main_queue(), ^{ [self _closeImplicitGroup]; });
        } else {
            _IsimUndoGroup *g = [_IsimUndoGroup new]; [g.actions addObject:a];
            [(_undoing ? _redo : _undo) addObject:g];
            return;
        }
    }
    [_open.lastObject.actions addObject:a];
}
- (void)registerUndoWithTarget:(id)target selector:(SEL)selector object:(id)object {
    _IsimUndoAction *a = [_IsimUndoAction new]; a.target = target; a.selector = selector; a.object = object;
    [self _register:a];
}
- (void)registerUndoWithTarget:(id)target handler:(void (^)(id))handler {
    _IsimUndoAction *a = [_IsimUndoAction new]; a.strongTarget = target; a.block = handler;
    [self _register:a];
}
- (BOOL)canUndo { [self _closeImplicitGroup]; return _undo.count > 0; }
- (BOOL)canRedo { [self _closeImplicitGroup]; return _redo.count > 0; }
- (BOOL)isUndoing { return _undoing; }
- (BOOL)isRedoing { return _redoing; }
- (void)undo {
    [self _closeImplicitGroup];
    if (_open.count) [NSException raise:NSInternalInconsistencyException format:@"undo was called with too many nested undo groups"];
    [self undoNestedGroup];
}
- (void)undoNestedGroup {
    [self _closeImplicitGroup];
    _IsimUndoGroup *g = _undo.lastObject;
    if (!g) return;
    [self _post:NSUndoManagerWillUndoChangeNotification];
    [_undo removeLastObject];
    _undoing = YES;
    [self beginUndoGrouping];
    for (_IsimUndoAction *a in g.actions.reverseObjectEnumerator) [a perform];
    _open.lastObject.actionName = g.actionName;
    [self endUndoGrouping];
    _undoing = NO;
    [self _post:NSUndoManagerDidUndoChangeNotification];
}
- (void)redo {
    [self _closeImplicitGroup];
    _IsimUndoGroup *g = _redo.lastObject;
    if (!g) return;
    [self _post:NSUndoManagerWillRedoChangeNotification];
    [_redo removeLastObject];
    _redoing = YES;
    [self beginUndoGrouping];
    for (_IsimUndoAction *a in g.actions.reverseObjectEnumerator) [a perform];
    _open.lastObject.actionName = g.actionName;
    NSMutableArray *saved = _redo;
    /* the actions registered while redoing go to the undo stack */
    _IsimUndoGroup *ng = _open.lastObject; [_open removeLastObject];
    if (ng.actions.count) [_undo addObject:ng];
    _redo = saved;
    _redoing = NO;
    [self _post:NSUndoManagerDidRedoChangeNotification];
}
- (void)removeAllActions { [_undo removeAllObjects]; [_redo removeAllObjects]; [_open removeAllObjects]; _implicitOpen = NO; }
- (void)removeAllActionsWithTarget:(id)target {
    for (NSMutableArray *stack in @[_undo, _redo, _open]) {
        for (_IsimUndoGroup *g in [stack copy]) {
            for (_IsimUndoAction *a in [g.actions copy]) if ((a.strongTarget ?: a.target) == target) [g.actions removeObject:a];
            if (!g.actions.count && stack != _open) [stack removeObject:g];
        }
    }
}
- (void)disableUndoRegistration { _disabled++; }
- (void)enableUndoRegistration { if (_disabled > 0) _disabled--; }
- (BOOL)isUndoRegistrationEnabled { return _disabled == 0; }
- (void)setActionName:(NSString *)name {
    if (_open.count) _open.lastObject.actionName = name ?: @"";
    else if (_undoing && _redo.count) _redo.lastObject.actionName = name ?: @"";
    else if (_undo.count) _undo.lastObject.actionName = name ?: @"";
}
- (NSString *)undoActionName { [self _closeImplicitGroup]; return _undo.lastObject.actionName ?: @""; }
- (NSString *)redoActionName { return _redo.lastObject.actionName ?: @""; }
- (NSString *)undoMenuItemTitle { NSString *n = self.undoActionName; return n.length ? [@"Undo " stringByAppendingString:n] : @"Undo"; }
- (NSString *)redoMenuItemTitle { NSString *n = self.redoActionName; return n.length ? [@"Redo " stringByAppendingString:n] : @"Redo"; }
- (NSString *)undoMenuTitleForUndoActionName:(NSString *)n { return n.length ? [@"Undo " stringByAppendingString:n] : @"Undo"; }
- (NSString *)redoMenuTitleForUndoActionName:(NSString *)n { return n.length ? [@"Redo " stringByAppendingString:n] : @"Redo"; }
@synthesize runLoopModes = _runLoopModes;
- (NSArray *)runLoopModes { return _runLoopModes ?: @[NSDefaultRunLoopMode]; }
- (void)setRunLoopModes:(NSArray *)modes { _runLoopModes = [modes copy]; }
@end

/* ================= NSProgress ================= */
NSProgressKind const NSProgressKindFile = @"NSProgressKindFile";
NSProgressUserInfoKey const NSProgressEstimatedTimeRemainingKey = @"NSProgressEstimatedTimeRemainingKey", NSProgressThroughputKey = @"NSProgressThroughputKey";
static __thread __unsafe_unretained NSProgress *current_progress;   /* retained by its becomeCurrent caller */
static __thread int64_t current_pending;
@interface NSProgress ()
@property (nonatomic, weak) NSProgress *_parent;
@property (nonatomic) int64_t _pendingInParent;
@end
@implementation NSProgress {
    NSMutableArray<NSProgress *> *_children;
    NSMutableDictionary *_info;
    int64_t _total, _completed;
    BOOL _cancelled, _paused;
    NSString *_desc, *_addDesc;
}
+ (NSProgress *)currentProgress { return current_progress; }
+ (NSProgress *)progressWithTotalUnitCount:(int64_t)n { NSProgress *p = [[NSProgress alloc] initWithParent:current_progress userInfo:nil]; p.totalUnitCount = n; return p; }
+ (NSProgress *)discreteProgressWithTotalUnitCount:(int64_t)n { NSProgress *p = [[NSProgress alloc] initWithParent:nil userInfo:nil]; p.totalUnitCount = n; return p; }
+ (NSProgress *)progressWithTotalUnitCount:(int64_t)n parent:(NSProgress *)parent pendingUnitCount:(int64_t)pending {
    NSProgress *p = [[NSProgress alloc] initWithParent:nil userInfo:nil]; p.totalUnitCount = n;
    [parent addChild:p withPendingUnitCount:pending];
    return p;
}
- (instancetype)init { return [self initWithParent:nil userInfo:nil]; }
- (instancetype)initWithParent:(NSProgress *)parent userInfo:(NSDictionary *)userInfo {
    if ((self = [super init])) {
        _children = [NSMutableArray array]; _info = [userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
        _cancellable = YES; _total = -1;
        if (parent && parent == current_progress && current_pending > 0) { [parent addChild:self withPendingUnitCount:current_pending]; current_pending = 0; }
    }
    return self;
}
- (void)becomeCurrentWithPendingUnitCount:(int64_t)n { current_progress = self; current_pending = n; }
- (void)resignCurrent {
    if (current_progress == self && current_pending > 0) { [self _isim_setCompleted:_completed + current_pending]; }
    current_progress = nil; current_pending = 0;
}
- (void)addChild:(NSProgress *)child withPendingUnitCount:(int64_t)n {
    child._parent = self; child._pendingInParent = n;
    [_children addObject:child];
    if (_cancelled) [child cancel];
    [self _childChanged];
}
- (int64_t)totalUnitCount { return _total; }
- (void)setTotalUnitCount:(int64_t)n {
    [self willChangeValueForKey:@"totalUnitCount"]; [self willChangeValueForKey:@"fractionCompleted"];
    _total = n;
    [self didChangeValueForKey:@"fractionCompleted"]; [self didChangeValueForKey:@"totalUnitCount"];
    [self._parent _childChanged];
}
- (int64_t)completedUnitCount { return _completed; }
- (void)setCompletedUnitCount:(int64_t)n { [self _isim_setCompleted:n]; }
- (void)_isim_setCompleted:(int64_t)n {
    [self willChangeValueForKey:@"completedUnitCount"]; [self willChangeValueForKey:@"fractionCompleted"];
    _completed = n;
    /* finished children are folded into the completed count */
    [self didChangeValueForKey:@"fractionCompleted"]; [self didChangeValueForKey:@"completedUnitCount"];
    [self._parent _childChanged];
}
- (void)_childChanged {
    for (NSProgress *c in [_children copy]) {
        if (c.isFinished && c._pendingInParent > 0) {
            int64_t add = c._pendingInParent; c._pendingInParent = 0;
            [_children removeObject:c];
            [self _isim_setCompleted:_completed + add];
            return;
        }
    }
    [self willChangeValueForKey:@"fractionCompleted"]; [self didChangeValueForKey:@"fractionCompleted"];
    [self._parent _childChanged];
}
- (double)fractionCompleted {
    if (_total <= 0) {
        if (!_children.count) return 0;
    }
    double done = (double)_completed;
    for (NSProgress *c in _children) done += c.fractionCompleted * (double)c._pendingInParent;
    double total = _total > 0 ? (double)_total : 0;
    if (total <= 0) return 0;
    double f = done / total;
    return f > 1 ? 1 : f < 0 ? 0 : f;
}
- (BOOL)isIndeterminate { return _total < 0 || (_total == 0 && _completed == 0); }
- (BOOL)isFinished { return _total > 0 ? _completed >= _total : (_total == 0 && _completed > 0); }
- (BOOL)isCancelled { return _cancelled; }
- (void)cancel {
    if (_cancelled) return;
    [self willChangeValueForKey:@"cancelled"]; _cancelled = YES; [self didChangeValueForKey:@"cancelled"];
    if (_cancellationHandler) _cancellationHandler();
    for (NSProgress *c in [_children copy]) [c cancel];
}
- (BOOL)isPaused { return _paused; }
- (void)pause { if (_paused || !_pausable) return; _paused = YES; if (_pausingHandler) _pausingHandler(); for (NSProgress *c in _children) [c pause]; }
- (void)resume { if (!_paused) return; _paused = NO; if (_resumingHandler) _resumingHandler(); for (NSProgress *c in _children) [c resume]; }
- (NSDictionary *)userInfo { return [_info copy]; }
- (void)setUserInfoObject:(id)obj forKey:(NSProgressUserInfoKey)key { _info[key] = obj; }
- (NSString *)localizedDescription {
    if (_desc) return _desc;
    NSNumberFormatter *f = [NSNumberFormatter new]; f.numberStyle = NSNumberFormatterPercentStyle;
    return [NSString stringWithFormat:@"%@ completed", [f stringFromNumber:@(self.fractionCompleted)]];
}
- (void)setLocalizedDescription:(NSString *)s { _desc = [s copy]; }
- (NSString *)localizedAdditionalDescription {
    if (_addDesc) return _addDesc;
    if (_total <= 0) return @"";
    NSNumberFormatter *f = [NSNumberFormatter new]; f.numberStyle = NSNumberFormatterDecimalStyle;
    return [NSString stringWithFormat:@"%@ of %@", [f stringFromNumber:@(_completed)], [f stringFromNumber:@(_total)]];
}
- (void)setLocalizedAdditionalDescription:(NSString *)s { _addDesc = [s copy]; }
- (NSString *)description { return [NSString stringWithFormat:@"<NSProgress %p> : Fraction completed: %.4f / Completed: %lld of %lld", self, self.fractionCompleted, _completed, _total]; }
/* the setters notify by hand (and keep parents in sync) */
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key { return ![@[@"completedUnitCount", @"totalUnitCount", @"fractionCompleted", @"cancelled"] containsObject:key]; }
+ (NSSet *)keyPathsForValuesAffectingLocalizedDescription { return [NSSet setWithObjects:@"fractionCompleted", nil]; }
@end
