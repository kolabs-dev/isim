/* isim UIKit private interfaces for input and accessibility (multi-touch, hover, text editing, drag and drop,
 * VoiceOver). Not part of the SDK. */
#pragma once
#import "UIKitPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* ---- touches (UIApplication.m) ---- */
@interface UITouch (IsimInput)
- (void)_isim_setFinger:(int)finger;          /* 0 first finger, 1 second finger */
- (void)_isim_setPencilForce:(double)force altitude:(double)altitude azimuth:(double)azimuth;   /* an Apple Pencil touch */
- (int)_isim_finger;
- (void)_isim_setStationary;
@end
@interface UIEvent (IsimInput)
- (instancetype)initWithIsimTouches:(NSSet<UITouch *> *)touches;
@end
@interface UIGestureRecognizer (IsimInput)
- (BOOL)_isim_acceptsExtraTouches;            /* gets the second finger too */
- (void)_isim_beginTouchSequence;             /* a new touch sequence starts (no finger is down) */
- (CGPoint)_isim_centroidInView:(nullable UIView *)v;
@end
NSSet<UITouch *> *isim_ui_active_touches(void);
/* touch filters run before normal delivery (VoiceOver, drag sessions); a filter returning YES consumes the event */
typedef BOOL (^IsimTouchFilter)(const struct isim_event *ev);
void isim_ui_add_touch_filter(IsimTouchFilter filter);
BOOL isim_ui_touch_filtered(const struct isim_event *ev);

/* ---- pointer (UIHover.m) ---- */
void isim_ui_hover(double x, double y, BOOL exited);

/* ---- text input (UITextInput.m) ---- */
void isim_ui_text_editing(NSString *markedText, int cursor, int length);   /* host IME composition */
/* a text view/field adopting isim's shared editing behaviour (selection gestures, edit menu, arrows) */
@protocol IsimEditableText <UITextInput>
- (NSString *)_isim_plainText;
- (NSRange)_isim_selectedRange;
- (void)_isim_setSelectedRange:(NSRange)r;
- (void)_isim_replaceRange:(NSRange)r withText:(NSString *)text;   /* through the delegate; selection after the insertion */
- (CGRect)_isim_caretRectForIndex:(NSUInteger)index;               /* in the view */
- (NSUInteger)_isim_indexAtPoint:(CGPoint)p;                        /* in the view */
- (NSArray<NSValue *> *)_isim_selectionRectsForRange:(NSRange)r;    /* CGRects in the view */
- (BOOL)_isim_isEditable;
@end
/* shared helpers used by UITextField / UITextView */
BOOL isim_ui_text_handle_key(id<IsimEditableText> view, int hid, int mods);   /* arrows, shift-select, cmd shortcuts */
void isim_ui_text_draw_selection(id<IsimEditableText> view);                   /* highlight + handles (in the view's coordinates) */
void isim_ui_text_touch(id<IsimEditableText> view, UITouch *touch, UITouchPhase phase);
void isim_ui_text_did_end_editing(id<IsimEditableText> view);
void isim_ui_text_selection_changed(id<IsimEditableText> view);
NSRange isim_ui_marked_range(id view);                                          /* NSNotFound location if none */
void isim_ui_set_marked_range(id view, NSRange r);

/* ---- keyboard (UIKeyboard.m / UIKeyboardLayouts.m) ---- */
NSString *isim_ui_keyboard_current_language(void);   /* "en_US", "pt_BR", "emoji", or a keyboard extension id */
void isim_ui_keyboard_suggestions_changed(void);
id _Nullable isim_ui_keyboard_target(void);           /* the text input the keyboard is shown for */
BOOL isim_ui_keyboard_dictating(void);
void isim_ui_keyboard_set_dictating(BOOL on);
void isim_ui_keyboard_responder_check(void);           /* show the keyboard again for the first responder (after Scribble) */

/* ---- text services (UITextServices.m) ---- */
@interface __IsimAutoFillSuggestion : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *subtitle, *symbol;
@property (nonatomic, copy) void (^action)(void);
@end
NSArray<__IsimAutoFillSuggestion *> *isim_ui_autofill_suggestions(id target);   /* QuickType bar: passwords, codes */
BOOL isim_ui_autofill_strong(id field);                 /* holds an AutoFill strong password (drawn yellow) */
void isim_ui_autofill_field_leaving(UIView<IsimEditableText> *field);
void isim_ui_text_service(NSString *command);          /* script `dictate`, `scribble`, `sms` */
extern BOOL isim_ui_scribble_focusing;                 /* Scribble focuses a field: no on-screen keyboard */
@class UITextView;
NSArray<NSTextCheckingResult *> *isim_ui_detect_items(NSString *text, NSUInteger dataDetectorTypes);
BOOL isim_ui_text_item_tap(UITextView *tv, NSTextCheckingResult *r);
BOOL isim_ui_text_item_menu(UITextView *tv, NSTextCheckingResult *r, CGRect windowRect);

/* ---- accessibility (UIAccessibilityRuntime.m) ---- */
void isim_ui_voiceover_command(NSString *command);
void isim_ui_accessibility_reload_settings(void);
NSString *_Nullable isim_ui_accessibility_dump(UIView *v);    /* " ax=..." for `dump` */
CGFloat isim_ui_content_size_multiplier(void);               /* Dynamic Type (Settings > Accessibility > Larger Text) */
NSString *isim_ui_content_size_category(void);

/* ---- drag and drop (UIDragDrop.m) ---- */
BOOL isim_ui_drag_in_progress(void);

NS_ASSUME_NONNULL_END
