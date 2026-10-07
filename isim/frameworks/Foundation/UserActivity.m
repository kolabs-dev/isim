/* NSUserActivity (isim): a value object for universal links and app-to-app activities. Becoming current
 * is recorded only (no Handoff, Spotlight or Siri predictions on isim). */
#import <Foundation/Foundation.h>

NSString * const NSUserActivityTypeBrowsingWeb = @"NSUserActivityTypeBrowsingWeb";

@implementation NSUserActivity
- (instancetype)initWithActivityType:(NSString *)activityType {
    if ((self = [super init])) { _activityType = [activityType copy]; _keywords = [NSSet set]; _eligibleForHandoff = YES; }
    return self;
}
- (instancetype)init { return [self initWithActivityType:@"NSUserActivityTypeDefault"]; }
- (void)addUserInfoEntriesFromDictionary:(NSDictionary *)d {
    NSMutableDictionary *m = _userInfo ? [_userInfo mutableCopy] : [NSMutableDictionary dictionary];
    [m addEntriesFromDictionary:d];
    _userInfo = [m copy];
}
- (void)becomeCurrent {}
- (void)resignCurrent {}
- (void)invalidate {}
- (NSString *)description { return [NSString stringWithFormat:@"<NSUserActivity %p type=%@ url=%@>", self, _activityType, _webpageURL]; }
@end
