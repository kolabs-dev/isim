// isim GameKit for Objective-C: the C constants (the values the GameKit Swift overlay uses), and Apple's setters where
// the overlay's Bool properties are named isX (Swift's Objective-C setter is setIsX:).
#import <GameKit/GameKit.h>
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"   // the categories implement what the header declares on the classes

NSString * const GKErrorDomain = @"GKErrorDomain";
NSString * const GKSessionErrorDomain = @"com.apple.gamekit.GKSessionErrorDomain";
NSString * const GKVoiceChatServiceErrorDomain = @"com.apple.gamekit.GKVoiceChatServiceErrorDomain";
NSString * const GKPlayerIDNoLongerAvailable = @"PlayerIDNoLongerAvailable";
NSTimeInterval GKTurnTimeoutDefault = 604800;
NSTimeInterval GKTurnTimeoutNone = 31449600;
NSTimeInterval GKExchangeTimeoutDefault = 86400;
NSTimeInterval GKExchangeTimeoutNone = 31449600;

@interface NSObject (ISIMGameKit)
- (void)setIsActive:(BOOL)v;
- (void)setIsFocused:(BOOL)v;
- (void)setIsHosted:(BOOL)v;
@end

@implementation GKAccessPoint (ISIMSetters)
- (void)setActive:(BOOL)v { [self setIsActive:v]; }
- (void)setFocused:(BOOL)v { [self setIsFocused:v]; }
@end
@implementation GKVoiceChat (ISIMSetters)
- (void)setActive:(BOOL)v { [self setIsActive:v]; }
@end
@implementation GKMatchmakerViewController (ISIMSetters)
- (void)setHosted:(BOOL)v { [self setIsHosted:v]; }
@end
