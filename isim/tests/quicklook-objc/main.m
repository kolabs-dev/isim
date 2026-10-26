// Quick Look Preview extension API from Objective-C (QuickLookObjCTest.app, issue #333): #import <QuickLook/QuickLook.h>,
// -framework QuickLook. A QLPreviewProvider subclass answers providePreviewForFileRequest:completionHandler: with
// QLPreviewReply's initializers (data of a UTType with an attachment, a drawing, a file URL); the replies' title,
// stringEncoding and attachments. Results go to the log ("QuickLookObjC: ...").
#import <UIKit/UIKit.h>
#import <QuickLook/QuickLook.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static void say(NSString *s) { NSLog(@"QuickLookObjC: %@", s); }

@interface NoteProvider : QLPreviewProvider <QLPreviewingController>
@end
@implementation NoteProvider
- (void)providePreviewForFileRequest:(QLFilePreviewRequest *)request completionHandler:(void (^)(QLPreviewReply *, NSError *))handler {
    handler([self replyForText:[NSString stringWithContentsOfURL:request.fileURL encoding:NSUTF8StringEncoding error:NULL]], nil);
}
- (QLPreviewReply *)replyForText:(NSString *)text {
    QLPreviewReply *reply = [[QLPreviewReply alloc] initWithDataOfContentType:UTTypeHTML contentSize:CGSizeMake(300, 400)
                                                            dataCreationBlock:^NSData *(QLPreviewReply *r, NSError **error) {
        return [[NSString stringWithFormat:@"<p>%@</p>", text] dataUsingEncoding:NSUTF8StringEncoding];
    }];
    reply.title = @"Note";
    reply.stringEncoding = NSUTF8StringEncoding;
    reply.attachments = @{ @"a.png": [[QLPreviewReplyAttachment alloc] initWithData:[NSData dataWithBytes:"x" length:1] contentType:UTTypePNG] };
    return reply;
}
@end

@interface TestViewController : UIViewController
@end
@implementation TestViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    NSURL *file = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"note.txt"]];
    [@"hello" writeToURL:file atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NoteProvider *p = [NoteProvider new];
    say([NSString stringWithFormat:@"provider handles requests %d", [p conformsToProtocol:@protocol(NSExtensionRequestHandling)]]);
    // (Quick Look makes the requests: providePreviewForFileRequest: is what HelloQuickLookExtensions' test drives)
    QLPreviewReply *reply = [p replyForText:@"hello"];
    QLPreviewReplyAttachment *a = reply.attachments[@"a.png"];
    say([NSString stringWithFormat:@"reply title %@ encoding utf8 %d attachment %@ %lu", reply.title, reply.stringEncoding == NSUTF8StringEncoding,
         a.contentType.identifier, (unsigned long)a.data.length]);
    QLPreviewReply *drawing = [[QLPreviewReply alloc] initWithContextSize:CGSizeMake(10, 10) isBitmap:YES drawingBlock:^BOOL(CGContextRef ctx, QLPreviewReply *r, NSError **error) {
        CGContextFillRect(ctx, CGRectMake(0, 0, 10, 10));
        return YES;
    }];
    QLPreviewReply *fileReply = [[QLPreviewReply alloc] initWithFileURL:file];
    say([NSString stringWithFormat:@"drawing %d file %d title '%@'", drawing != nil, fileReply != nil, fileReply.title]);
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [TestViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, @"AppDelegate"); }
}
