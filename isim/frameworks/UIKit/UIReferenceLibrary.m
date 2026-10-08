/* UIReferenceLibraryViewController: the dictionary sheet. Adapted: isim has no dictionaries of its own (Apple's are
 * licensed for its platforms and downloaded on demand, so the Simulator also starts without them); definitions come
 * from the host's WordNet (`wn TERM -over`, run with system()) when it is installed (unverified), otherwise none are found. */
#import "UIKitPrivate.h"
#import <UIKit/UIReferenceLibraryViewController.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

/* the host WordNet overview of a term, or nil */
static NSString *wordnet_definition(NSString *term) {
    if (!term.length || term.length > 64) return nil;
    static int has = -1;
    if (has < 0) has = access("/usr/bin/wn", X_OK) == 0 || access("/usr/local/bin/wn", X_OK) == 0;
    if (!has) return nil;
    NSMutableString *safe = [NSMutableString string];        /* letters, digits, spaces, apostrophes, hyphens */
    for (NSUInteger i = 0; i < term.length; i++) {
        unichar c = [term characterAtIndex:i];
        if (c < 128 && (isalnum(c) || c == ' ' || c == '-' || c == '\'')) [safe appendFormat:@"%C", (unichar)(c == ' ' ? '_' : c)];
        else return nil;
    }
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"isim-wn-%@.txt", NSUUID.UUID.UUIDString]];
    NSString *cmd = [NSString stringWithFormat:@"wn '%@' -over > '%@' 2>/dev/null", [safe stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"], tmp];
    system(cmd.UTF8String);
    NSData *out = [NSData dataWithContentsOfFile:tmp] ?: [NSData data];
    [NSFileManager.defaultManager removeItemAtPath:tmp error:NULL];
    NSString *s = [[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding];
    s = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return s.length ? s : nil;
}

@implementation UIReferenceLibraryViewController { NSString *_term; NSString *_definition; }
+ (BOOL)dictionaryHasDefinitionForTerm:(NSString *)term { return wordnet_definition(term) != nil; }
- (instancetype)initWithTerm:(NSString *)term {
    if ((self = [super initWithNibName:nil bundle:nil])) { _term = [term copy] ?: @""; self.modalPresentationStyle = UIModalPresentationPageSheet; }
    return self;
}
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b { return [self initWithTerm:@""]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithTerm:@""]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    _definition = wordnet_definition(_term);
    UINavigationBar *bar = [UINavigationBar new];
    bar.tag = 10;
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:_definition ? _term : @"Dictionary"];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(isimDone)];
    done.accessibilityIdentifier = @"dict-done";
    item.rightBarButtonItem = done;
    if (!_definition) {
        UIBarButtonItem *manage = [[UIBarButtonItem alloc] initWithTitle:@"Manage" style:UIBarButtonItemStylePlain target:self action:@selector(isimManage)];
        manage.accessibilityIdentifier = @"dict-manage";
        item.leftBarButtonItem = manage;
    }
    bar.items = @[item];
    [self.view addSubview:bar];
    if (_definition) {
        UITextView *tv = [UITextView new];
        tv.editable = NO; tv.tag = 11; tv.accessibilityIdentifier = @"dict-definition";
        tv.font = [UIFont systemFontOfSize:17];
        tv.text = _definition;
        tv.textContainerInset = UIEdgeInsetsMake(16, 12, 16, 12);
        [self.view addSubview:tv];
    } else {
        UILabel *l = [UILabel new];
        l.tag = 11; l.accessibilityIdentifier = @"dict-none";
        l.text = @"No definition found.";
        l.textColor = UIColor.secondaryLabelColor; l.textAlignment = NSTextAlignmentCenter;
        [self.view addSubview:l];
    }
    NSLog(@"isim UIKit: dictionary for “%@”: %@", _term, _definition ? @"WordNet definition" : @"no definition found");
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    [self.view viewWithTag:10].frame = CGRectMake(0, 0, b.size.width, 56);
    [self.view viewWithTag:11].frame = _definition ? CGRectMake(0, 56, b.size.width, b.size.height - 56) : CGRectMake(20, b.size.height / 3, b.size.width - 40, 30);
}
/* iOS lists the dictionaries to download here; isim has none */
- (void)isimManage {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Dictionaries"
                                                               message:@"No dictionaries are available on this device." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)isimDone { [self.presentingViewController dismissViewControllerAnimated:YES completion:nil]; }
@end
