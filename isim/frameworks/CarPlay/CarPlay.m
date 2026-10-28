// isim CarPlay for Objective-C: the C constants and functions (the classes and protocols are the CarPlay Swift overlay's).
#import <CarPlay/CarPlay.h>

NSString * const CarPlayErrorDomain = @"CarPlayErrorDomain";
NSUInteger const CPMaximumNumberOfGridImages = 8;
NSUInteger const CPGridTemplateMaximumItems = 8;
CGSize const CPMaximumListSectionImageSize = { 88, 88 };
CGSize const CPMaximumMessageItemImageSize = { 40, 40 };
CGSize const CPMaximumMessageItemLeadingDetailTextImageSize = { 20, 20 };
CGSize const CPNowPlayingButtonMaximumImageSize = { 40, 40 };
CGSize const CPButtonMaximumImageSize = { 40, 40 };
NSTimeInterval const CPNavigationAlertMinimumDuration = 5;
UISceneSessionRole const CPTemplateApplicationSceneSessionRoleApplication = @"CPTemplateApplicationSceneSessionRoleApplication";
UISceneSessionRole const CPTemplateApplicationDashboardSceneSessionRoleApplication = @"CPTemplateApplicationDashboardSceneSessionRoleApplication";
UISceneSessionRole const CPTemplateApplicationInstrumentClusterSceneSessionRoleApplication = @"CPTemplateApplicationInstrumentClusterSceneSessionRoleApplication";

static NSString *pick(NSUInteger i, NSArray<NSString *> *names, NSString *kind) {
    return i < names.count ? names[i] : [NSString stringWithFormat:@"%@(%lu)", kind, (unsigned long)i];
}
NSString *NSStringFromCPManeuverType(CPManeuverType type) {
    static NSArray *names;
    if (!names) {
        NSMutableArray *a = [@[@"NoTurn", @"LeftTurn", @"RightTurn", @"StraightAhead", @"UTurn", @"FollowRoad", @"EnterRoundabout", @"ExitRoundabout",
                               @"OffRamp", @"OnRamp", @"ArriveEndOfNavigation", @"StartRoute", @"ArriveAtDestination", @"KeepLeft", @"KeepRight",
                               @"Enter_Ferry", @"ExitFerry", @"ChangeFerry", @"StartRouteWithUTurn", @"UTurnAtRoundabout", @"LeftTurnAtEnd",
                               @"RightTurnAtEnd", @"HighwayOffRampLeft", @"HighwayOffRampRight", @"ArriveAtDestinationLeft",
                               @"ArriveAtDestinationRight", @"UTurnWhenPossible", @"ArriveEndOfDirections"] mutableCopy];
        for (int i = 1; i <= 19; i++) [a addObject:[NSString stringWithFormat:@"RoundaboutExit%d", i]];
        [a addObjectsFromArray:@[@"SharpLeftTurn", @"SharpRightTurn", @"SlightLeftTurn", @"SlightRightTurn", @"ChangeHighway", @"ChangeHighwayLeft", @"ChangeHighwayRight"]];
        names = [a copy];
    }
    return [@"CPManeuverType" stringByAppendingString:pick(type, names, @"")];
}
NSString *NSStringFromCPJunctionType(CPJunctionType type) { return pick(type, @[@"CPJunctionTypeIntersection", @"CPJunctionTypeRoundabout"], @"CPJunctionType"); }
NSString *NSStringFromCPTrafficSide(CPTrafficSide side) { return pick(side, @[@"CPTrafficSideRight", @"CPTrafficSideLeft"], @"CPTrafficSide"); }
NSString *NSStringFromCPLaneStatus(CPLaneStatus status) {
    return pick((NSUInteger)status, @[@"CPLaneStatusNotGood", @"CPLaneStatusGood", @"CPLaneStatusPreferred"], @"CPLaneStatus");
}
NSString *NSStringFromCPRerouteReason(CPRerouteReason reason) {
    return pick((NSUInteger)reason, @[@"CPRerouteReasonUnknown", @"CPRerouteReasonMissedTurn", @"CPRerouteReasonOffline", @"CPRerouteReasonAlternateRoute",
                                      @"CPRerouteReasonWaypointModified", @"CPRerouteReasonMandated"], @"CPRerouteReason");
}
