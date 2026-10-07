/* isim Foundation: NSExtensionContext / NSExtensionItem (ARC).
 * The host (UIKit's UIActivityViewController for Share and Action extensions) creates the context with the input items
 * and a request handler (isim-private -initISIMWithInputItems:handler:); completeRequest / cancelRequest call it
 * once on the main queue. */
#import <Foundation/Foundation.h>

NSString * const NSExtensionItemAttributedTitleKey = @"NSExtensionItemAttributedTitleKey";
NSString * const NSExtensionItemAttributedContentTextKey = @"NSExtensionItemAttributedContentTextKey";
NSString * const NSExtensionItemAttachmentsKey = @"NSExtensionItemAttachmentsKey";
NSString * const NSExtensionItemsAndErrorsKey = @"NSExtensionItemsAndErrorsKey";
NSString * const NSExtensionJavaScriptPreprocessingResultsKey = @"NSExtensionJavaScriptPreprocessingResultsKey";
NSString * const NSExtensionJavaScriptFinalizeArgumentKey = @"NSExtensionJavaScriptFinalizeArgumentKey";
NSString * const NSExtensionHostWillEnterForegroundNotification = @"NSExtensionHostWillEnterForegroundNotification";
NSString * const NSExtensionHostDidEnterBackgroundNotification = @"NSExtensionHostDidEnterBackgroundNotification";
NSString * const NSExtensionHostWillResignActiveNotification = @"NSExtensionHostWillResignActiveNotification";
NSString * const NSExtensionHostDidBecomeActiveNotification = @"NSExtensionHostDidBecomeActiveNotification";

@implementation NSExtensionItem
- (id)copyWithZone:(NSZone *)zone {
    NSExtensionItem *c = [[NSExtensionItem alloc] init];
    c.attributedTitle = self.attributedTitle; c.attributedContentText = self.attributedContentText;
    c.attachments = self.attachments; c.userInfo = self.userInfo;
    return c;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"<NSExtensionItem: title %@, text %@, %lu attachment(s)>", self.attributedTitle.string ?: @"(null)",
            self.attributedContentText.string ?: @"(null)", (unsigned long)self.attachments.count];
}
@end

typedef void (^ISIMExtensionRequestHandler)(NSArray *returnedItems, NSError *error, BOOL completed);
@implementation NSExtensionContext { NSArray *_items; ISIMExtensionRequestHandler _handler; BOOL _done; }
- (instancetype)initISIMWithInputItems:(NSArray *)items handler:(ISIMExtensionRequestHandler)handler {
    if ((self = [super init])) { _items = [items copy] ?: @[]; _handler = [handler copy]; }
    return self;
}
- (NSArray *)inputItems { return _items ?: @[]; }
- (void)_isim_finish:(NSArray *)items error:(NSError *)error completed:(BOOL)completed then:(void (^)(BOOL))after {
    if (_done) { NSLog(@"isim: the extension request was already completed"); return; }
    _done = YES;
    ISIMExtensionRequestHandler h = _handler; _handler = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (h) h(items ?: @[], error, completed);
        if (after) after(NO);
    });
}
- (void)completeRequestReturningItems:(NSArray *)items completionHandler:(void (^)(BOOL))completionHandler {
    NSLog(@"isim: extension request completed (%lu returned item(s))", (unsigned long)items.count);
    [self _isim_finish:items error:nil completed:YES then:completionHandler];
}
- (void)cancelRequestWithError:(NSError *)error {
    NSLog(@"isim: extension request cancelled (%@ %ld)", error.domain, (long)error.code);
    [self _isim_finish:nil error:error completed:NO then:nil];
}
- (void)openURL:(NSURL *)URL completionHandler:(void (^)(BOOL))completionHandler {
    NSLog(@"isim: extension openURL %@ refused (extensions hosted in an app cannot open URLs)", URL.absoluteString);
    if (completionHandler) dispatch_async(dispatch_get_main_queue(), ^{ completionHandler(NO); });
}
@end
