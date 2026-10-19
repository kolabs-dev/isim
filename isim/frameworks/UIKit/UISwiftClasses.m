/* isim UIKit (ARC): Objective-C classes and members that UIKit's Swift overlay defines (drag and drop, spring loading,
 * paste configurations). Their headers mark the classes objc_runtime_visible, so Objective-C code finds them with
 * objc_lookUpClass instead of a linker symbol; an app without Swift has not loaded the overlay, so the first lookup of
 * one of these names, or the first message of one of these selectors to a responder (a table view's dragDelegate, a
 * text view's textDropDelegate, ...), loads it (libswiftUIKit and the Swift runtime), as Foundation does. */
#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <string.h>

static objc_hook_getClass previous_hook;
static const char *const swift_classes[] = {
    "UIDragItem", "UIDragPreview", "UIDragPreviewParameters", "UITargetedDragPreview", "UIDropProposal", "UIDragInteraction",
    "UIDropInteraction", "UITableViewDropProposal", "UICollectionViewDropProposal", "UITextDropProposal", "UISpringLoadedInteraction",
    "UIPasteConfiguration",
};
static const char *const swift_selectors[] = {
    "dragDelegate", "setDragDelegate:", "dropDelegate", "setDropDelegate:", "dragInteractionEnabled", "setDragInteractionEnabled:",
    "hasActiveDrag", "textDropDelegate", "setTextDropDelegate:", "textDropInteraction", "isTextDropActive",
    "pasteConfiguration", "setPasteConfiguration:", "pasteItemProviders:", "canPasteItemProviders:",
};

static BOOL load_overlay(void) {
    static dispatch_once_t once;
    static BOOL loaded;
    dispatch_once(&once, ^{
        loaded = dlopen("/usr/lib/swift/libswiftUIKit.dylib", RTLD_NOW | RTLD_GLOBAL) != NULL;
        if (!loaded) NSLog(@"isim: UIKit could not load its Swift overlay for drag and drop: %s", dlerror());
    });
    return loaded;
}

static BOOL lazy_swift_class(const char *name, Class _Nullable *outClass) {
    if (previous_hook(name, outClass)) return YES;
    for (size_t i = 0; i < sizeof swift_classes / sizeof *swift_classes; i++)
        if (!strcmp(name, swift_classes[i])) {
            if (!load_overlay()) return NO;
            return previous_hook(name, outClass);      /* registered by the overlay's image now */
        }
    return NO;
}

__attribute__((constructor)) static void install_swift_class_hook(void) {
    objc_setHook_getClass(lazy_swift_class, &previous_hook);
}

@implementation UIResponder (IsimSwiftMembers)
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    const char *name = sel_getName(sel);
    for (size_t i = 0; i < sizeof swift_selectors / sizeof *swift_selectors; i++)
        if (!strcmp(name, swift_selectors[i]))
            return load_overlay() && class_getInstanceMethod(self, sel) != NULL;   /* the overlay's extension added it */
    return [super resolveInstanceMethod:sel];
}
@end
