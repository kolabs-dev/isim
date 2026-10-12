/* Printing extras (UIPrinting.h): rendering quality, the printable rect's older name, formatters that need the main
 * thread, printer destinations and print service extensions (isim runs no print service extensions; the cutter
 * behavior is asked of roll printers only, and the isim Printer is a document printer). */
#import "UIKitPrivate.h"

@implementation UIViewPrintFormatter (UIPrintingExtras)
- (BOOL)requiresMainThread { return YES; }
@end
@implementation UIMarkupTextPrintFormatter (UIPrintingExtras)
- (BOOL)requiresMainThread { return YES; }
@end

@implementation UIPrinterDestination
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithURL:(NSURL *)url { if ((self = [super init])) _URL = [url copy]; return self; }
- (instancetype)initWithCoder:(NSCoder *)c {
    NSURL *u = [c decodeObjectOfClass:[NSURL class] forKey:@"URL"];
    if (!u || !(self = [self initWithURL:u])) return nil;
    _displayName = [c decodeObjectOfClass:[NSString class] forKey:@"displayName"];
    _txtRecord = [c decodeObjectOfClass:[NSData class] forKey:@"txtRecord"];
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:_URL forKey:@"URL"]; [c encodeObject:_displayName forKey:@"displayName"]; [c encodeObject:_txtRecord forKey:@"txtRecord"];
}
@end
@implementation UIPrintServiceExtension
- (NSArray<UIPrinterDestination *> *)printerDestinationsForPrintInfo:(UIPrintInfo *)info { return @[]; }
@end
