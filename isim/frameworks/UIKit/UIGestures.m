/* Swipe and screen-edge pan recognizers; hardware keyboard input (UIKey, UIPress, presses on the responder chain,
 * UIKeyCommand); motion (shake) events. The host's mouse is a single finger; Ctrl+Shift+Z or the script command
 * `shake` shakes the device, like the Simulator's Device > Shake. */
#import "UIKitPrivate.h"
#include <math.h>
#include <objc/runtime.h>

@interface UIGestureRecognizer ()
@property (nonatomic, readwrite) UIGestureRecognizerState state;
@property (nonatomic) CGPoint startPoint, lastPoint;
@property (nonatomic) NSTimeInterval startTime;
- (void)_fire;
- (BOOL)_isim_deferUntilFailures:(void (^)(void))fire;
@end

/* ================= UISwipeGestureRecognizer ================= */
@implementation UISwipeGestureRecognizer
- (instancetype)initWithTarget:(id)t action:(SEL)a {
    if ((self = [super initWithTarget:t action:a])) { _direction = UISwipeGestureRecognizerDirectionRight; _numberOfTouchesRequired = 1; }
    return self;
}
/* discrete: recognized once the finger has travelled 40 pt along an allowed direction, mostly straight, within 0.6 s */
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event {
    CGPoint p = [touch locationInView:self.view.window];
    if (phase == UITouchPhaseBegan) { self.startPoint = p; self.startTime = touch.timestamp; self.state = UIGestureRecognizerStatePossible; self.lastPoint = p; return; }
    if (self.state != UIGestureRecognizerStatePossible) { if (phase == UITouchPhaseEnded) self.state = UIGestureRecognizerStatePossible; return; }
    double dx = p.x - self.startPoint.x, dy = p.y - self.startPoint.y, dt = touch.timestamp - self.startTime;
    self.lastPoint = p;
    UISwipeGestureRecognizerDirection dir = fabs(dx) >= fabs(dy) ? (dx > 0 ? UISwipeGestureRecognizerDirectionRight : UISwipeGestureRecognizerDirectionLeft)
                                                                  : (dy > 0 ? UISwipeGestureRecognizerDirectionDown : UISwipeGestureRecognizerDirectionUp);
    double along = fmax(fabs(dx), fabs(dy)), across = fmin(fabs(dx), fabs(dy));
    if (dt > 0.6 || (along > 20 && !(dir & _direction)) || (along > 20 && across > along * 0.7)) { self.state = UIGestureRecognizerStateFailed; return; }
    if (along >= 40 && (dir & _direction)) {
        if (![self _isim_shouldBegin]) { self.state = UIGestureRecognizerStateFailed; return; }
        __weak UISwipeGestureRecognizer *ws = self;
        void (^fire)(void) = ^{ UISwipeGestureRecognizer *s = ws; s.state = UIGestureRecognizerStateEnded; [s _fire]; s.state = UIGestureRecognizerStateFailed; };
        if (![self _isim_deferUntilFailures:fire]) fire(); else self.state = UIGestureRecognizerStateFailed;
    }
    if (phase == UITouchPhaseEnded && self.state == UIGestureRecognizerStatePossible) self.state = UIGestureRecognizerStatePossible;
}
- (BOOL)_isim_shouldBegin {
    id<UIGestureRecognizerDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(gestureRecognizerShouldBegin:)] && ![d gestureRecognizerShouldBegin:self]) return NO;
    return self.view ? [self.view gestureRecognizerShouldBegin:self] : YES;
}
@end

/* ================= UIScreenEdgePanGestureRecognizer ================= */
@implementation UIScreenEdgePanGestureRecognizer { BOOL _ignoring; }
/* a pan that only starts from within 20 pt of one of `edges` of the screen */
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event {
    if (phase == UITouchPhaseBegan) {
        UIWindow *w = self.view.window; CGPoint p = [touch locationInView:nil]; CGSize s = w.bounds.size; const CGFloat m = 20;
        p = [w convertPoint:p toView:nil];
        _ignoring = !(((_edges & UIRectEdgeLeft) && p.x <= m) || ((_edges & UIRectEdgeRight) && p.x >= s.width - m) ||
                      ((_edges & UIRectEdgeTop) && p.y <= m) || ((_edges & UIRectEdgeBottom) && p.y >= s.height - m));
    }
    if (_ignoring) { if (phase == UITouchPhaseEnded) _ignoring = NO; return; }
    [super _isim_touch:touch phase:phase event:event];
}
@end

/* ================= hardware keyboard ================= */
NSString *const UIKeyInputUpArrow = @"UIKeyInputUpArrow";
NSString *const UIKeyInputDownArrow = @"UIKeyInputDownArrow";
NSString *const UIKeyInputLeftArrow = @"UIKeyInputLeftArrow";
NSString *const UIKeyInputRightArrow = @"UIKeyInputRightArrow";
NSString *const UIKeyInputEscape = @"UIKeyInputEscape";
NSString *const UIKeyInputPageUp = @"UIKeyInputPageUp";
NSString *const UIKeyInputPageDown = @"UIKeyInputPageDown";
NSString *const UIKeyInputHome = @"UIKeyInputHome";
NSString *const UIKeyInputEnd = @"UIKeyInputEnd";
NSString *const UIKeyInputDelete = @"UIKeyInputDelete";

@interface UIKey ()
@property (nonatomic, readwrite, copy) NSString *characters, *charactersIgnoringModifiers;
@property (nonatomic, readwrite) UIKeyModifierFlags modifierFlags;
@property (nonatomic, readwrite) UIKeyboardHIDUsage keyCode;
@end
@implementation UIKey
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSString *)description { return [NSString stringWithFormat:@"<UIKey %@ code %ld mods %lx>", _charactersIgnoringModifiers, (long)_keyCode, (long)_modifierFlags]; }
@end
@interface UIPress ()
@property (nonatomic, readwrite) NSTimeInterval timestamp;
@property (nonatomic, readwrite) UIPressPhase phase;
@property (nonatomic, readwrite) UIPressType type;
@property (nonatomic, readwrite, strong) UIKey *key;
@end
@implementation UIPress
- (CGFloat)force { return _phase == UIPressPhaseEnded ? 0 : 1; }
@end
@interface UIPressesEvent ()
@property (nonatomic, strong) NSSet<UIPress *> *isimPresses;
@property (nonatomic) UIEventType isimType;
@property (nonatomic) UIEventSubtype isimSubtype;
@end
@implementation UIPressesEvent
- (NSSet<UIPress *> *)allPresses { return _isimPresses ?: [NSSet set]; }
- (UIEventType)type { return UIEventTypePresses; }
@end
@interface __IsimMotionEvent : UIEvent
@end
@implementation __IsimMotionEvent
- (UIEventType)type { return UIEventTypeMotion; }
- (UIEventSubtype)subtype { return UIEventSubtypeMotionShake; }
- (NSTimeInterval)timestamp { return isim_time(); }
@end

@implementation UIKeyCommand
+ (instancetype)keyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)flags action:(SEL)action {
    UIKeyCommand *c = [self new]; c->_input = [input copy]; c->_modifierFlags = flags; c->_action = action; c->_title = @""; return c;
}
+ (instancetype)commandWithTitle:(NSString *)title image:(UIImage *)image action:(SEL)action input:(NSString *)input modifierFlags:(UIKeyModifierFlags)flags propertyList:(id)plist {
    UIKeyCommand *c = [self keyCommandWithInput:input modifierFlags:flags action:action]; c.title = title ?: @""; c->_propertyList = plist; return c;
}
- (id)copyWithZone:(NSZone *)z { return self; }
@end

@implementation UIResponder (UIKeyboardAndMotion)
- (NSArray<UIKeyCommand *> *)keyCommands { return nil; }
- (void)pressesBegan:(NSSet *)p withEvent:(UIPressesEvent *)e { [self.nextResponder pressesBegan:p withEvent:e]; }
- (void)pressesChanged:(NSSet *)p withEvent:(UIPressesEvent *)e { [self.nextResponder pressesChanged:p withEvent:e]; }
- (void)pressesEnded:(NSSet *)p withEvent:(UIPressesEvent *)e { [self.nextResponder pressesEnded:p withEvent:e]; }
- (void)pressesCancelled:(NSSet *)p withEvent:(UIPressesEvent *)e { [self.nextResponder pressesCancelled:p withEvent:e]; }
- (void)motionBegan:(UIEventSubtype)m withEvent:(UIEvent *)e { [self.nextResponder motionBegan:m withEvent:e]; }
- (void)motionEnded:(UIEventSubtype)m withEvent:(UIEvent *)e { [self.nextResponder motionEnded:m withEvent:e]; }
- (void)motionCancelled:(UIEventSubtype)m withEvent:(UIEvent *)e { [self.nextResponder motionCancelled:m withEvent:e]; }
- (id)targetForAction:(SEL)action withSender:(id)sender {
    for (UIResponder *r = self; r; r = r.nextResponder) if ([r canPerformAction:action withSender:sender]) return r;
    return nil;
}
@end

static const char kKeyCommands = 0;
@implementation UIViewController (UIKeyCommands)
- (void)addKeyCommand:(UIKeyCommand *)c {
    NSMutableArray *a = objc_getAssociatedObject(self, &kKeyCommands);
    if (!a) { a = [NSMutableArray array]; objc_setAssociatedObject(self, &kKeyCommands, a, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    [a addObject:c];
}
- (void)removeKeyCommand:(UIKeyCommand *)c { [objc_getAssociatedObject(self, &kKeyCommands) removeObject:c]; }
- (NSArray<UIKeyCommand *> *)keyCommands { return objc_getAssociatedObject(self, &kKeyCommands); }
@end

/* where key and motion events go without a first responder: the visible view controller (presented, then the
   navigation/tab container's visible child) of the key window */
static UIViewController *visible_controller(UIViewController *vc) {
    while (vc) {
        if (vc.presentedViewController) { vc = vc.presentedViewController; continue; }
        if ([vc isKindOfClass:[UINavigationController class]] && ((UINavigationController *)vc).topViewController) { vc = ((UINavigationController *)vc).topViewController; continue; }
        if ([vc isKindOfClass:[UITabBarController class]] && ((UITabBarController *)vc).selectedViewController) { vc = ((UITabBarController *)vc).selectedViewController; continue; }
        break;
    }
    return vc;
}
static UIResponder *focus_responder(void) {
    UIResponder *fr = isim_ui_first_responder();
    if (fr) return fr;
    UIWindow *w = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
    UIViewController *vc = visible_controller(w.rootViewController);
    return vc ?: (UIResponder *)w;
}

static UIKeyModifierFlags held_mods;
static UIKeyModifierFlags mods_from_host(int sdl) {
    UIKeyModifierFlags m = 0;
    if (sdl & 0x0003) m |= UIKeyModifierShift;
    if (sdl & 0x00c0) m |= UIKeyModifierControl;
    if (sdl & 0x0300) m |= UIKeyModifierAlternate;
    if (sdl & 0x0c00) m |= UIKeyModifierCommand;
    if (sdl & 0x2000) m |= UIKeyModifierAlphaShift;
    return m;
}
static UIKeyModifierFlags mod_for_usage(int hid) {
    switch (hid) {
    case 0xE0: case 0xE4: return UIKeyModifierControl;
    case 0xE1: case 0xE5: return UIKeyModifierShift;
    case 0xE2: case 0xE6: return UIKeyModifierAlternate;
    case 0xE3: case 0xE7: return UIKeyModifierCommand;
    default: return 0;
    }
}
static NSString *special_input(int hid) {
    switch (hid) {
    case 0x52: return UIKeyInputUpArrow; case 0x51: return UIKeyInputDownArrow; case 0x50: return UIKeyInputLeftArrow; case 0x4F: return UIKeyInputRightArrow;
    case 0x29: return UIKeyInputEscape; case 0x4B: return UIKeyInputPageUp; case 0x4E: return UIKeyInputPageDown; case 0x4A: return UIKeyInputHome;
    case 0x4D: return UIKeyInputEnd; case 0x4C: return UIKeyInputDelete; case 0x28: return @"\r"; case 0x2B: return @"\t"; case 0x2C: return @" "; case 0x2A: return @"\b";
    default: return nil;
    }
}

static NSMutableDictionary<NSNumber *, UIPress *> *active_presses;
/* returns YES when a key command consumed the key (it then does not type into a text field) */
BOOL isim_ui_hardware_key(int hid, int keycode, int hostmods, BOOL down) {
    if (hid <= 0) return NO;
    UIKeyModifierFlags mflag = mod_for_usage(hid);
    if (mflag) { if (down) held_mods |= mflag; else held_mods &= ~mflag; }
    UIKeyModifierFlags mods = held_mods | mods_from_host(hostmods);
    NSString *base = special_input(hid);
    if (!base) {
        if (keycode >= 32 && keycode < 127) base = [NSString stringWithFormat:@"%c", (char)keycode];
        else if (hid >= 0x04 && hid <= 0x1D) base = [NSString stringWithFormat:@"%c", (char)('a' + hid - 4)];
        else if (hid >= 0x1E && hid <= 0x27) base = hid == 0x27 ? @"0" : [NSString stringWithFormat:@"%c", (char)('1' + hid - 0x1E)];
        else base = @"";
    }
    UIKey *key = [UIKey new];
    key.keyCode = hid; key.modifierFlags = mods; key.charactersIgnoringModifiers = base;
    key.characters = (mods & (UIKeyModifierShift | UIKeyModifierAlphaShift)) && base.length == 1 ? base.uppercaseString : base;
    UIPress *press = [UIPress new];
    press.timestamp = isim_time(); press.key = key; press.phase = down ? UIPressPhaseBegan : UIPressPhaseEnded;
    press.type = hid == 0x52 ? UIPressTypeUpArrow : hid == 0x51 ? UIPressTypeDownArrow : hid == 0x50 ? UIPressTypeLeftArrow : hid == 0x4F ? UIPressTypeRightArrow
               : hid == 0x28 ? UIPressTypeSelect : hid == 0x29 ? UIPressTypeMenu : (UIPressType)-1;
    if (!active_presses) active_presses = [NSMutableDictionary dictionary];
    UIResponder *start = focus_responder();
    /* key commands first (key down, modifiers themselves never match) */
    BOOL consumed = NO;
    if (down && !mflag) {
        UIKeyModifierFlags cmpMask = UIKeyModifierShift | UIKeyModifierControl | UIKeyModifierAlternate | UIKeyModifierCommand;
        for (UIResponder *r = start; r && !consumed; r = r.nextResponder) {
            for (UIKeyCommand *c in r.keyCommands) {
                if (!c.action || !c.input) continue;
                BOOL inputMatch = [c.input caseInsensitiveCompare:base] == NSOrderedSame || [c.input isEqualToString:key.characters];
                if (!inputMatch || (c.modifierFlags & cmpMask) != (mods & cmpMask)) continue;
                id target = [start targetForAction:c.action withSender:c];
                if (!target) continue;
                ((void (*)(id, SEL, id))[target methodForSelector:c.action])(target, c.action, c);
                consumed = YES; break;
            }
        }
    }
    UIPressesEvent *e = [UIPressesEvent new];
    if (down) {
        active_presses[@(hid)] = press;
        e.isimPresses = [NSSet setWithArray:active_presses.allValues];
        if (!consumed) [start pressesBegan:[NSSet setWithObject:press] withEvent:e];
    } else {
        [active_presses removeObjectForKey:@(hid)];
        e.isimPresses = [NSSet setWithObject:press];
        [start pressesEnded:[NSSet setWithObject:press] withEvent:e];
    }
    return consumed;
}

void isim_ui_shake(void) {
    UIResponder *r = focus_responder();
    __IsimMotionEvent *e = [__IsimMotionEvent new];
    [r motionBegan:UIEventSubtypeMotionShake withEvent:e];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [focus_responder() motionEnded:UIEventSubtypeMotionShake withEvent:e];
    });
}
