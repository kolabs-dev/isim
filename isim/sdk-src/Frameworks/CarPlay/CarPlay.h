#pragma once
/* isim CarPlay (adapted): CarPlay apps' templates, drawn on a simulated CarPlay screen (the script command
   `carplay connect`; docs/SCRIPTING.md).

   The value types (enums, option sets, CPLocationCoordinate3D, the limits, the scene roles, the error domain) are
   declared here for Objective-C and Swift alike; the classes and protocols are the CarPlay Swift overlay's
   (CarPlay.framework re-exports libswiftCarPlay.dylib), so their declarations below are hidden from Swift, which uses
   the overlay. How the screen is drawn and driven: the overlay's Screen.swift and Views.swift. */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>
#if !defined(__swift__)
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#endif
NS_ASSUME_NONNULL_BEGIN

/* ---------------- errors, limits, scene roles ---------------- */
FOUNDATION_EXPORT NSString * const CarPlayErrorDomain;
FOUNDATION_EXPORT NSUInteger const CPMaximumNumberOfGridImages;
FOUNDATION_EXPORT NSUInteger const CPGridTemplateMaximumItems;
FOUNDATION_EXPORT CGSize const CPMaximumListSectionImageSize;
FOUNDATION_EXPORT CGSize const CPMaximumMessageItemImageSize;
FOUNDATION_EXPORT CGSize const CPMaximumMessageItemLeadingDetailTextImageSize;
FOUNDATION_EXPORT CGSize const CPNowPlayingButtonMaximumImageSize;
FOUNDATION_EXPORT CGSize const CPButtonMaximumImageSize;
FOUNDATION_EXPORT NSTimeInterval const CPNavigationAlertMinimumDuration;
UIKIT_EXTERN UISceneSessionRole const CPTemplateApplicationSceneSessionRoleApplication NS_SWIFT_NAME(carTemplateApplication);
UIKIT_EXTERN UISceneSessionRole const CPTemplateApplicationDashboardSceneSessionRoleApplication NS_SWIFT_NAME(carTemplateApplicationDashboard);
UIKIT_EXTERN UISceneSessionRole const CPTemplateApplicationInstrumentClusterSceneSessionRoleApplication NS_SWIFT_NAME(carTemplateApplicationInstrumentCluster);

/* ---------------- the session ---------------- */
typedef NS_OPTIONS(NSUInteger, CPContentStyle) {
    CPContentStyleLight = 1 << 0,
    CPContentStyleDark = 1 << 1,
};
typedef NS_OPTIONS(NSUInteger, CPLimitableUserInterface) {
    CPLimitableUserInterfaceKeyboard = 1 << 0,
    CPLimitableUserInterfaceLists = 1 << 1,
};
typedef NS_ENUM(NSUInteger, CPInstrumentClusterSetting) {
    CPInstrumentClusterSettingUnspecified = 0,
    CPInstrumentClusterSettingEnabled,
    CPInstrumentClusterSettingDisabled,
    CPInstrumentClusterSettingUserPreference,
};

/* ---------------- lists, buttons ---------------- */
typedef NS_ENUM(NSInteger, CPListItemAccessoryType) {
    CPListItemAccessoryTypeNone = 0,
    CPListItemAccessoryTypeDisclosureIndicator,
    CPListItemAccessoryTypeCloud,
};
typedef NS_ENUM(NSInteger, CPListItemPlayingIndicatorLocation) {
    CPListItemPlayingIndicatorLocationLeading = 0,
    CPListItemPlayingIndicatorLocationTrailing,
};
typedef NS_ENUM(NSInteger, CPAssistantCellActionType) {
    CPAssistantCellActionTypePlayMedia = 0,
    CPAssistantCellActionTypeStartCall,
};
typedef NS_ENUM(NSInteger, CPMessageLeadingItem) {
    CPMessageLeadingItemNone = 0,
    CPMessageLeadingItemPin,
    CPMessageLeadingItemStar,
};
typedef NS_ENUM(NSInteger, CPMessageTrailingItem) {
    CPMessageTrailingItemNone = 0,
    CPMessageTrailingItemMute,
};
typedef NS_ENUM(NSInteger, CPBarButtonStyle) {
    CPBarButtonStyleNone = 0,
    CPBarButtonStyleRounded,
};
typedef NS_ENUM(NSInteger, CPTextButtonStyle) {
    CPTextButtonStyleNormal = 0,
    CPTextButtonStyleCancel,
    CPTextButtonStyleConfirm,
};
typedef NS_ENUM(NSInteger, CPInformationTemplateLayout) {
    CPInformationTemplateLayoutLeading = 0,
    CPInformationTemplateLayoutTwoColumn,
};

/* ---------------- navigation ---------------- */
typedef NS_OPTIONS(NSInteger, CPPanDirection) {
    CPPanDirectionNone = 0,
    CPPanDirectionLeft = 1 << 0,
    CPPanDirectionRight = 1 << 1,
    CPPanDirectionUp = 1 << 2,
    CPPanDirectionDown = 1 << 3,
};
typedef NS_OPTIONS(NSInteger, CPManeuverDisplayStyle) {
    CPManeuverDisplayStyleDefault = 0,
    CPManeuverDisplayStyleLeadingSymbol = 1 << 0,
    CPManeuverDisplayStyleTrailingSymbol = 1 << 1,
    CPManeuverDisplayStyleSymbolOnly = 1 << 2,
    CPManeuverDisplayStyleInstructionOnly = 1 << 3,
};
typedef NS_ENUM(NSInteger, CPManeuverState) {
    CPManeuverStateContinue = 0,
    CPManeuverStateInitial,
    CPManeuverStatePrepare,
    CPManeuverStateExecute,
};
typedef NS_ENUM(NSUInteger, CPManeuverType) {
    CPManeuverTypeNoTurn = 0, CPManeuverTypeLeftTurn, CPManeuverTypeRightTurn, CPManeuverTypeStraightAhead, CPManeuverTypeUTurn,
    CPManeuverTypeFollowRoad, CPManeuverTypeEnterRoundabout, CPManeuverTypeExitRoundabout, CPManeuverTypeOffRamp, CPManeuverTypeOnRamp,
    CPManeuverTypeArriveEndOfNavigation, CPManeuverTypeStartRoute, CPManeuverTypeArriveAtDestination, CPManeuverTypeKeepLeft,
    CPManeuverTypeKeepRight, CPManeuverTypeEnter_Ferry, CPManeuverTypeExitFerry, CPManeuverTypeChangeFerry, CPManeuverTypeStartRouteWithUTurn,
    CPManeuverTypeUTurnAtRoundabout, CPManeuverTypeLeftTurnAtEnd, CPManeuverTypeRightTurnAtEnd, CPManeuverTypeHighwayOffRampLeft,
    CPManeuverTypeHighwayOffRampRight, CPManeuverTypeArriveAtDestinationLeft, CPManeuverTypeArriveAtDestinationRight,
    CPManeuverTypeUTurnWhenPossible, CPManeuverTypeArriveEndOfDirections,
    CPManeuverTypeRoundaboutExit1, CPManeuverTypeRoundaboutExit2, CPManeuverTypeRoundaboutExit3, CPManeuverTypeRoundaboutExit4,
    CPManeuverTypeRoundaboutExit5, CPManeuverTypeRoundaboutExit6, CPManeuverTypeRoundaboutExit7, CPManeuverTypeRoundaboutExit8,
    CPManeuverTypeRoundaboutExit9, CPManeuverTypeRoundaboutExit10, CPManeuverTypeRoundaboutExit11, CPManeuverTypeRoundaboutExit12,
    CPManeuverTypeRoundaboutExit13, CPManeuverTypeRoundaboutExit14, CPManeuverTypeRoundaboutExit15, CPManeuverTypeRoundaboutExit16,
    CPManeuverTypeRoundaboutExit17, CPManeuverTypeRoundaboutExit18, CPManeuverTypeRoundaboutExit19,
    CPManeuverTypeSharpLeftTurn, CPManeuverTypeSharpRightTurn, CPManeuverTypeSlightLeftTurn, CPManeuverTypeSlightRightTurn,
    CPManeuverTypeChangeHighway, CPManeuverTypeChangeHighwayLeft, CPManeuverTypeChangeHighwayRight,
};
typedef NS_ENUM(NSUInteger, CPJunctionType) {
    CPJunctionTypeIntersection = 0,
    CPJunctionTypeRoundabout,
};
typedef NS_ENUM(NSUInteger, CPTrafficSide) {
    CPTrafficSideRight = 0,
    CPTrafficSideLeft,
};
typedef NS_ENUM(NSInteger, CPLaneStatus) {
    CPLaneStatusNotGood = 0,
    CPLaneStatusGood,
    CPLaneStatusPreferred,
};
typedef NS_ENUM(NSUInteger, CPTimeRemainingColor) {
    CPTimeRemainingColorDefault = 0,
    CPTimeRemainingColorGreen,
    CPTimeRemainingColorOrange,
    CPTimeRemainingColorRed,
};
typedef NS_ENUM(NSUInteger, CPTripEstimateStyle) {
    CPTripEstimateStyleLight = 0,
    CPTripEstimateStyleDark,
};
typedef NS_ENUM(NSInteger, CPRerouteReason) {
    CPRerouteReasonUnknown = 0,
    CPRerouteReasonMissedTurn,
    CPRerouteReasonOffline,
    CPRerouteReasonAlternateRoute,
    CPRerouteReasonWaypointModified,
    CPRerouteReasonMandated,
};
typedef NS_ENUM(NSUInteger, CPRouteSource) {
    CPRouteSourceInactive = 0,
    CPRouteSourceiOSUnchanged,
    CPRouteSourceiOSRouteModified,
    CPRouteSourceiOSRouteDestinationsModified,
    CPRouteSourceiOSDestinationsOnly,
    CPRouteSourceVehicle,
};

typedef struct {
#if defined(__swift__)
    double latitude;
    double longitude;
    double altitude;
#else
    CLLocationDegrees latitude;
    CLLocationDegrees longitude;
    CLLocationDistance altitude;
#endif
} CPLocationCoordinate3D;

FOUNDATION_EXPORT NSString * _Null_unspecified NSStringFromCPManeuverType(CPManeuverType type);
FOUNDATION_EXPORT NSString * _Null_unspecified NSStringFromCPJunctionType(CPJunctionType type);
FOUNDATION_EXPORT NSString * _Null_unspecified NSStringFromCPTrafficSide(CPTrafficSide side);
FOUNDATION_EXPORT NSString * _Null_unspecified NSStringFromCPLaneStatus(CPLaneStatus status);
FOUNDATION_EXPORT NSString * _Null_unspecified NSStringFromCPRerouteReason(CPRerouteReason reason);

#if !defined(__swift__)
/* ================= the classes and protocols (the Swift overlay's) ================= */
@class CPTemplate, CPInterfaceController, CPWindow, CPTemplateApplicationScene, CPListItem, CPListTemplate, CPGridButton, CPTabBarTemplate,
    CPNowPlayingTemplate, CPNowPlayingButton, CPMapTemplate, CPTrip, CPRouteChoice, CPManeuver, CPNavigationAlert, CPNavigationSession,
    CPTravelEstimates, CPLaneGuidance, CPRouteSegment, CPNavigationWaypoint, CPMultiStopCardConfiguration, CPMapPanel, CPPointOfInterestTemplate,
    CPPointOfInterest, CPSearchTemplate, CPPlaybackConfiguration, CPThumbnailImage, CPDashboardController, CPInstrumentClusterController,
    CPRouteDetail, CPSportsOverlay, CPImageOverlay, CPNowPlayingMode, CPBarButton, CPAlertAction, CPSessionConfiguration,
    CPTemplateApplicationDashboardScene, CPTemplateApplicationInstrumentClusterScene, CPMapPanelItem;

typedef NS_ENUM(NSInteger, CPAssistantCellPosition) { CPAssistantCellPositionTop = 0, CPAssistantCellPositionBottom };
typedef NS_ENUM(NSInteger, CPAssistantCellVisibility) { CPAssistantCellVisibilityOff = 0, CPAssistantCellVisibilityWhileLimitedUIActive, CPAssistantCellVisibilityAlways };
typedef NS_ENUM(NSUInteger, CPAlertActionStyle) { CPAlertActionStyleDefault = 0, CPAlertActionStyleCancel, CPAlertActionStyleDestructive };
typedef NS_ENUM(NSUInteger, CPNavigationAlertDismissalContext) { CPNavigationAlertDismissalContextTimeout = 0, CPNavigationAlertDismissalContextUserDismissed, CPNavigationAlertDismissalContextSystemDismissed };
typedef NS_ENUM(NSUInteger, CPTripPauseReason) { CPTripPauseReasonArrived = 1, CPTripPauseReasonLoading, CPTripPauseReasonLocating, CPTripPauseReasonRerouting, CPTripPauseReasonProceedToRoute };
typedef NS_ENUM(NSInteger, CPPlaybackPresentation) { CPPlaybackPresentationNone = 0, CPPlaybackPresentationAudio, CPPlaybackPresentationVideo } API_AVAILABLE(ios(26.0));
typedef NS_ENUM(NSInteger, CPPlaybackAction) { CPPlaybackActionNone = 0, CPPlaybackActionPlay, CPPlaybackActionPause, CPPlaybackActionReplay } API_AVAILABLE(ios(26.0));
typedef NS_ENUM(NSInteger, CPImageOverlayAlignment) { CPImageOverlayAlignmentLeading = 0, CPImageOverlayAlignmentCenter, CPImageOverlayAlignmentTrailing } API_AVAILABLE(ios(26.0));
typedef NS_ENUM(NSInteger, CPListImageRowItemCondensedElementShape) { CPListImageRowItemCondensedElementShapeRoundedRectangle = 0, CPListImageRowItemCondensedElementShapeCircular } API_AVAILABLE(ios(26.0));
typedef NS_ENUM(NSInteger, CPListImageRowItemImageGridElementShape) { CPListImageRowItemImageGridElementShapeRoundedRectangle = 0, CPListImageRowItemImageGridElementShapeCircular } API_AVAILABLE(ios(26.0));
typedef NS_ENUM(NSInteger, CPChargingStationConnector) { CPChargingStationConnectorJ1772 = 0, CPChargingStationConnectorCCS1, CPChargingStationConnectorCCS2,
    CPChargingStationConnectorCHAdeMO, CPChargingStationConnectorMennekes, CPChargingStationConnectorGBTAC, CPChargingStationConnectorGBTDC,
    CPChargingStationConnectorNACSAC, CPChargingStationConnectorNACSDC } API_AVAILABLE(ios(26.0));

/* ---- images and buttons ---- */
@interface CPImageSet : NSObject <NSSecureCoding>
- (instancetype)initWithLightContentImage:(UIImage *)lightImage darkContentImage:(UIImage *)darkImage;
@property (nonatomic, readonly) UIImage *lightContentImage;
@property (nonatomic, readonly) UIImage *darkContentImage;
@end

typedef void (^CPBarButtonHandler)(CPBarButton *barButton);
@interface CPBarButton : NSObject <NSSecureCoding>
- (instancetype)initWithImage:(UIImage *)image handler:(nullable CPBarButtonHandler)handler;
- (instancetype)initWithTitle:(NSString *)title handler:(nullable CPBarButtonHandler)handler;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nullable, nonatomic, strong) UIImage *image;
@property (nullable, nonatomic, copy) NSString *title;
@property (nonatomic, assign) CPBarButtonStyle buttonStyle;
@end
@interface CPMessageComposeBarButton : CPBarButton
- (instancetype)init;
- (instancetype)initWithImage:(UIImage *)image;
@end

@protocol CPBarButtonProviding <NSObject>
@property (nonatomic, strong) NSArray<CPBarButton *> *leadingNavigationBarButtons;
@property (nonatomic, strong) NSArray<CPBarButton *> *trailingNavigationBarButtons;
@property (nonatomic, strong, nullable) CPBarButton *backButton;
@end

@interface CPButton : NSObject
- (instancetype)initWithImage:(UIImage *)image handler:(void (^ _Nullable)(__kindof CPButton *button))handler;
@property (nullable, nonatomic, strong) UIImage *image;
@property (nullable, nonatomic, copy) NSString *title;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@end
@interface CPTextButton : NSObject
- (instancetype)initWithTitle:(NSString *)title textStyle:(CPTextButtonStyle)textStyle handler:(void (^ _Nullable)(__kindof CPTextButton *contactButton))handler;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) CPTextButtonStyle textStyle;
@end

typedef void (^CPAlertActionHandler)(CPAlertAction *action);
@interface CPAlertAction : NSObject <NSSecureCoding>
- (instancetype)initWithTitle:(NSString *)title style:(CPAlertActionStyle)style handler:(CPAlertActionHandler)handler;
- (instancetype)initWithTitle:(NSString *)title color:(UIColor *)color handler:(CPAlertActionHandler)handler;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, assign, readonly) CPAlertActionStyle style;
@property (nonatomic, copy, readonly) CPAlertActionHandler handler;
@property (nonatomic, copy, readonly, nullable) UIColor *color;
@end

/* ---- templates ---- */
@interface CPTemplate : NSObject <NSSecureCoding>
@property (nullable, nonatomic, strong) id userInfo;
@property (nullable, nonatomic, copy) NSString *tabTitle;
@property (nullable, nonatomic, strong) UIImage *tabImage;
@property (nonatomic, assign) UITabBarSystemItem tabSystemItem;
@property (nonatomic, assign) BOOL showsTabBadge;
@end

@protocol CPListTemplateItem <NSObject>
@property (nullable, nonatomic, readonly, copy) NSString *text;
@property (nullable, nonatomic, strong) id userInfo;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@end
@protocol CPSelectableListItem <CPListTemplateItem>
@property (nullable, nonatomic, copy) void (^handler)(id<CPSelectableListItem> item, dispatch_block_t completionBlock);
@end
@protocol CPPlayableItem <NSObject>
@property (nullable, nonatomic, strong) CPPlaybackConfiguration *playbackConfiguration API_AVAILABLE(ios(26.0));
@end

@interface CPListItem : NSObject <CPSelectableListItem, CPPlayableItem>
- (instancetype)initWithText:(nullable NSString *)text detailText:(nullable NSString *)detailText image:(nullable UIImage *)image
              accessoryImage:(nullable UIImage *)accessoryImage accessoryType:(CPListItemAccessoryType)accessoryType;
- (instancetype)initWithText:(nullable NSString *)text detailText:(nullable NSString *)detailText image:(nullable UIImage *)image;
- (instancetype)initWithText:(nullable NSString *)text detailText:(nullable NSString *)detailText;
- (instancetype)initWithText:(nullable NSString *)text detailText:(nullable NSString *)detailText image:(nullable UIImage *)image showsDisclosureIndicator:(BOOL)showsDisclosureIndicator;
@property (nullable, nonatomic, readonly, copy) NSString *text;
@property (nullable, nonatomic, readonly, copy) NSString *detailText;
@property (nullable, nonatomic, readonly, strong) UIImage *image;
@property (nullable, nonatomic, readonly, strong) UIImage *accessoryImage;
@property (nonatomic, assign) CPListItemAccessoryType accessoryType;
@property (nonatomic, assign, getter=isExplicitContent) BOOL explicitContent;
@property (nonatomic, assign, getter=isPlaying) BOOL playing;
@property (nonatomic, assign) CPListItemPlayingIndicatorLocation playingIndicatorLocation;
@property (nonatomic, assign) CGFloat playbackProgress;
@property (nonatomic, readonly) BOOL showsDisclosureIndicator;
@property (nonatomic, assign) BOOL showsExplicitLabel;
@property (class, nonatomic, readonly) CGSize maximumImageSize;
- (void)setText:(NSString *)text;
- (void)setDetailText:(nullable NSString *)detailText;
- (void)setImage:(nullable UIImage *)image;
- (void)setAccessoryImage:(nullable UIImage *)accessoryImage;
@end

API_AVAILABLE(ios(26.0)) @interface CPListImageRowItemElement : NSObject
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nullable, nonatomic, copy) NSString *accessibilityLabel;
@property (class, nonatomic, readonly) CGSize maximumImageSize;
@end
API_AVAILABLE(ios(26.0)) @interface CPListImageRowItemGridElement : CPListImageRowItemElement
- (instancetype)initWithImage:(UIImage *)image;
@end
API_AVAILABLE(ios(26.0)) @interface CPListImageRowItemRowElement : CPListImageRowItemElement
- (instancetype)initWithImage:(UIImage *)image title:(nullable NSString *)title subtitle:(nullable NSString *)subtitle;
@property (nullable, nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) NSString *subtitle;
@end
API_AVAILABLE(ios(26.0)) @interface CPListImageRowItemCardElement : CPListImageRowItemElement <NSSecureCoding>
- (instancetype)initWithImage:(UIImage *)image showsImageFullHeight:(BOOL)showsImageFullHeight title:(nullable NSString *)title subtitle:(nullable NSString *)subtitle tintColor:(nullable UIColor *)tintColor;
- (instancetype)initWithThumbnail:(CPThumbnailImage *)thumbnail title:(nullable NSString *)title subtitle:(nullable NSString *)subtitle tintColor:(nullable UIColor *)tintColor;
@property (nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) NSString *subtitle;
@property (nullable, nonatomic, strong) UIColor *tintColor;
@property (nullable, nonatomic, readonly) CPThumbnailImage *thumbnail;
@property (nonatomic, readonly) BOOL showsImageFullHeight;
@property (class, nonatomic, readonly) CGSize maximumFullHeightImageSize;
@end
API_AVAILABLE(ios(26.0)) @interface CPListImageRowItemCondensedElement : CPListImageRowItemElement
- (instancetype)initWithImage:(UIImage *)image imageShape:(CPListImageRowItemCondensedElementShape)imageShape title:(NSString *)title subtitle:(nullable NSString *)subtitle accessorySymbolName:(nullable NSString *)accessorySymbolName;
@property (nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) NSString *subtitle;
@property (nullable, nonatomic, copy) NSString *accessorySymbolName;
@property (nonatomic, readonly) CPListImageRowItemCondensedElementShape imageShape;
@end
API_AVAILABLE(ios(26.0)) @interface CPListImageRowItemImageGridElement : CPListImageRowItemElement
- (instancetype)initWithImage:(UIImage *)image imageShape:(CPListImageRowItemImageGridElementShape)imageShape title:(NSString *)title accessorySymbolName:(nullable NSString *)accessorySymbolName;
@property (nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) NSString *accessorySymbolName;
@property (nonatomic, readonly) CPListImageRowItemImageGridElementShape imageShape;
@end

@interface CPListImageRowItem : NSObject <CPSelectableListItem>
- (instancetype)initWithText:(NSString *)text images:(NSArray<UIImage *> *)images;
- (instancetype)initWithText:(NSString *)text images:(NSArray<UIImage *> *)images imageTitles:(NSArray<NSString *> *)imageTitles;
- (instancetype)initWithText:(nullable NSString *)text cardElements:(NSArray<CPListImageRowItemCardElement *> *)elements allowsMultipleLines:(BOOL)allowsMultipleLines API_AVAILABLE(ios(26.0));
- (instancetype)initWithText:(nullable NSString *)text condensedElements:(NSArray<CPListImageRowItemCondensedElement *> *)elements allowsMultipleLines:(BOOL)allowsMultipleLines API_AVAILABLE(ios(26.0));
- (instancetype)initWithText:(nullable NSString *)text elements:(NSArray<CPListImageRowItemRowElement *> *)elements allowsMultipleLines:(BOOL)allowsMultipleLines API_AVAILABLE(ios(26.0));
- (instancetype)initWithText:(nullable NSString *)text gridElements:(NSArray<CPListImageRowItemGridElement *> *)elements allowsMultipleLines:(BOOL)allowsMultipleLines API_AVAILABLE(ios(26.0));
- (instancetype)initWithText:(nullable NSString *)text imageGridElements:(NSArray<CPListImageRowItemImageGridElement *> *)elements allowsMultipleLines:(BOOL)allowsMultipleLines API_AVAILABLE(ios(26.0));
@property (nullable, nonatomic, readonly, copy) NSString *text;
@property (nonatomic, readonly, strong) NSArray<UIImage *> *gridImages;
@property (nonatomic, copy) NSArray<NSString *> *imageTitles;
@property (nonatomic, copy) NSArray<CPListImageRowItemElement *> *elements API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly) BOOL allowsMultipleLines API_AVAILABLE(ios(26.0));
@property (nullable, nonatomic, copy) void (^listImageRowHandler)(CPListImageRowItem *item, NSInteger index, dispatch_block_t completionBlock);
@property (class, nonatomic, readonly) CGSize maximumImageSize;
- (void)updateImages:(NSArray<UIImage *> *)gridImages;
@end

@interface CPMessageListItemLeadingConfiguration : NSObject
- (instancetype)initWithLeadingItem:(CPMessageLeadingItem)leadingItem leadingImage:(nullable UIImage *)leadingImage unread:(BOOL)unread;
@property (nonatomic, readonly) CPMessageLeadingItem leadingItem;
@property (nullable, nonatomic, strong, readonly) UIImage *leadingImage;
@property (nonatomic, readonly, getter=isUnread) BOOL unread;
@end
@interface CPMessageListItemTrailingConfiguration : NSObject
- (instancetype)initWithTrailingItem:(CPMessageTrailingItem)trailingItem trailingImage:(nullable UIImage *)trailingImage;
@property (nonatomic, readonly) CPMessageTrailingItem trailingItem;
@property (nullable, nonatomic, strong, readonly) UIImage *trailingImage;
@end
@interface CPMessageListItem : NSObject <CPListTemplateItem>
- (instancetype)initWithConversationIdentifier:(NSString *)conversationIdentifier text:(NSString *)text leadingConfiguration:(CPMessageListItemLeadingConfiguration *)leadingConfiguration
                         trailingConfiguration:(nullable CPMessageListItemTrailingConfiguration *)trailingConfiguration detailText:(nullable NSString *)detailText trailingText:(nullable NSString *)trailingText;
- (instancetype)initWithFullName:(NSString *)fullName phoneOrEmailAddress:(NSString *)phoneOrEmailAddress leadingConfiguration:(CPMessageListItemLeadingConfiguration *)leadingConfiguration
           trailingConfiguration:(nullable CPMessageListItemTrailingConfiguration *)trailingConfiguration detailText:(nullable NSString *)detailText trailingText:(nullable NSString *)trailingText;
@property (nullable, nonatomic, copy) NSString *conversationIdentifier;
@property (nullable, nonatomic, copy) NSString *phoneOrEmailAddress;
@property (nullable, nonatomic, copy) NSString *text;
@property (nullable, nonatomic, copy) NSString *detailText;
@property (nullable, nonatomic, copy) NSString *trailingText;
@property (nonatomic, strong) CPMessageListItemLeadingConfiguration *leadingConfiguration;
@property (nullable, nonatomic, strong) CPMessageListItemTrailingConfiguration *trailingConfiguration;
@property (nullable, nonatomic, strong) UIImage *leadingDetailTextImage API_AVAILABLE(ios(18.4));
@end

@interface CPListSection : NSObject <NSSecureCoding>
- (instancetype)initWithItems:(NSArray<id<CPListTemplateItem>> *)items header:(NSString *)header headerSubtitle:(nullable NSString *)headerSubtitle
                  headerImage:(nullable UIImage *)headerImage headerButton:(nullable CPButton *)headerButton sectionIndexTitle:(nullable NSString *)sectionIndexTitle;
- (instancetype)initWithItems:(NSArray<id<CPListTemplateItem>> *)items header:(nullable NSString *)header sectionIndexTitle:(nullable NSString *)sectionIndexTitle;
- (instancetype)initWithItems:(NSArray<id<CPListTemplateItem>> *)items;
@property (nullable, nonatomic, readonly, copy) NSString *header;
@property (nullable, nonatomic, copy) NSString *headerSubtitle;
@property (nullable, nonatomic, strong) UIImage *headerImage;
@property (nullable, nonatomic, strong) CPButton *headerButton;
@property (nullable, nonatomic, readonly, copy) NSString *sectionIndexTitle;
@property (nonatomic, readonly, copy) NSArray<id<CPListTemplateItem>> *items;
- (NSUInteger)indexOfItem:(id<CPListTemplateItem>)item;
- (id<CPListTemplateItem>)itemAtIndex:(NSUInteger)index;
@end

@interface CPAssistantCellConfiguration : NSObject <NSSecureCoding>
- (instancetype)initWithPosition:(CPAssistantCellPosition)position visibility:(CPAssistantCellVisibility)visibility assistantAction:(CPAssistantCellActionType)assistantAction;
@property (nonatomic, readonly) CPAssistantCellPosition position;
@property (nonatomic, readonly) CPAssistantCellVisibility visibility;
@property (nonatomic, readonly) CPAssistantCellActionType assistantAction;
@end

@protocol CPListTemplateDelegate <NSObject>
- (void)listTemplate:(CPListTemplate *)listTemplate didSelectListItem:(CPListItem *)item completionHandler:(void (^)(void))completionHandler;
@end

API_AVAILABLE(ios(26.0)) @interface CPListTemplateDetailsHeader : NSObject <NSSecureCoding>
- (instancetype)initWithThumbnail:(CPThumbnailImage *)thumbnail title:(nullable NSString *)title subtitle:(nullable NSString *)subtitle actionButtons:(NSArray<CPButton *> *)actionButtons;
- (instancetype)initWithThumbnail:(CPThumbnailImage *)thumbnail title:(nullable NSString *)title subtitle:(nullable NSString *)subtitle bodyVariants:(NSArray<NSAttributedString *> *)bodyVariants actionButtons:(NSArray<CPButton *> *)actionButtons;
@property (nonatomic, strong) CPThumbnailImage *thumbnail;
@property (nullable, nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSArray<NSAttributedString *> *bodyVariants;
@property (nonatomic, copy) NSArray<CPButton *> *actionButtons;
@property (nonatomic, assign) BOOL wantsAdaptiveBackgroundStyle;
@property (class, nonatomic, readonly) NSInteger maximumActionButtonCount;
@property (class, nonatomic, readonly) CGSize maximumActionButtonSize;
@end

@interface CPListTemplate : CPTemplate <CPBarButtonProviding>
- (instancetype)initWithTitle:(nullable NSString *)title sections:(NSArray<CPListSection *> *)sections;
- (instancetype)initWithTitle:(nullable NSString *)title sections:(NSArray<CPListSection *> *)sections assistantCellConfiguration:(nullable CPAssistantCellConfiguration *)assistantCellConfiguration;
- (instancetype)initWithTitle:(nullable NSString *)title sections:(NSArray<CPListSection *> *)sections assistantCellConfiguration:(nullable CPAssistantCellConfiguration *)assistantCellConfiguration headerGridButtons:(nullable NSArray<CPGridButton *> *)headerGridButtons;
- (instancetype)initWithTitle:(nullable NSString *)title listHeader:(nullable CPListTemplateDetailsHeader *)listHeader sections:(NSArray<CPListSection *> *)sections assistantCellConfiguration:(nullable CPAssistantCellConfiguration *)assistantCellConfiguration API_AVAILABLE(ios(26.0));
@property (nullable, nonatomic, weak) id<CPListTemplateDelegate> delegate;
@property (nonatomic, readonly, copy) NSArray<CPListSection *> *sections;
@property (nullable, nonatomic, readonly, copy) NSString *title;
@property (nonatomic, copy) NSArray<NSString *> *emptyViewTitleVariants;
@property (nonatomic, copy) NSArray<NSString *> *emptyViewSubtitleVariants;
@property (nullable, nonatomic, strong) CPAssistantCellConfiguration *assistantCellConfiguration;
@property (nullable, nonatomic, copy) NSArray<CPGridButton *> *headerGridButtons;
@property (nullable, nonatomic, strong) CPListTemplateDetailsHeader *listHeader API_AVAILABLE(ios(26.0));
@property (nonatomic, assign) BOOL showsSpinnerWhileEmpty;
@property (class, nonatomic, readonly) NSUInteger maximumItemCount;
@property (class, nonatomic, readonly) NSUInteger maximumSectionCount;
@property (class, nonatomic, readonly) NSUInteger maximumHeaderGridButtonCount;
@property (class, nonatomic, readonly) CGSize maximumGridButtonImageSize;
@property (nonatomic, readonly) NSUInteger itemCount;
@property (nonatomic, readonly) NSUInteger sectionCount;
- (void)updateSections:(NSArray<CPListSection *> *)sections;
- (nullable NSIndexPath *)indexPathForItem:(id<CPListTemplateItem>)item;
@end

@interface CPMessageGridItemConfiguration : NSObject
- (instancetype)initWithConversationIdentifier:(NSString *)conversationIdentifier unread:(BOOL)unread;
@property (nonatomic, readonly, copy) NSString *conversationIdentifier;
@property (nonatomic, assign, getter=isUnread) BOOL unread;
@end
@interface CPGridButton : NSObject <NSSecureCoding>
- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants image:(UIImage *)image messageConfiguration:(nullable CPMessageGridItemConfiguration *)messageConfiguration handler:(void (^ _Nullable)(CPGridButton *barButton))handler;
- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants image:(UIImage *)image handler:(void (^ _Nullable)(CPGridButton *barButton))handler;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly) NSArray<NSString *> *titleVariants;
@property (nonatomic, readonly) UIImage *image;
@property (nullable, nonatomic, readonly) CPMessageGridItemConfiguration *messageConfiguration;
- (void)updateImage:(UIImage *)image;
- (void)updateTitleVariants:(NSArray<NSString *> *)titleVariants;
@end
@interface CPGridTemplate : CPTemplate <CPBarButtonProviding>
- (instancetype)initWithTitle:(nullable NSString *)title gridButtons:(NSArray<CPGridButton *> *)gridButtons;
@property (nonatomic, readonly) NSArray<CPGridButton *> *gridButtons;
@property (nonatomic, readonly) NSString *title;
@property (class, nonatomic, readonly) CGSize maximumGridButtonImageSize;
- (void)updateGridButtons:(NSArray<CPGridButton *> *)gridButtons;
- (void)updateTitle:(NSString *)title;
@end

@protocol CPTabBarTemplateDelegate <NSObject>
- (void)tabBarTemplate:(CPTabBarTemplate *)tabBarTemplate didSelectTemplate:(__kindof CPTemplate *)selectedTemplate;
@end
@interface CPTabBarTemplate : CPTemplate
- (instancetype)initWithTemplates:(NSArray<CPTemplate *> *)templates;
@property (nullable, nonatomic, weak) id<CPTabBarTemplateDelegate> delegate;
@property (nonatomic, readonly) NSArray<__kindof CPTemplate *> *templates;
@property (nullable, nonatomic, readonly) __kindof CPTemplate *selectedTemplate;
@property (class, nonatomic, readonly) NSInteger maximumTabCount;
- (void)updateTemplates:(NSArray<CPTemplate *> *)newTemplates;
- (void)selectTemplate:(CPTemplate *)newTemplate;
- (void)selectTemplateAtIndex:(NSInteger)index;
@end

/* ---- Now Playing ---- */
@interface CPNowPlayingButton : NSObject <NSSecureCoding>
- (instancetype)initWithHandler:(void (^ _Nullable)(__kindof CPNowPlayingButton *))handler;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nonatomic, assign, getter=isSelected) BOOL selected;
@end
@interface CPNowPlayingShuffleButton : CPNowPlayingButton
@end
@interface CPNowPlayingRepeatButton : CPNowPlayingButton
@end
@interface CPNowPlayingAddToLibraryButton : CPNowPlayingButton
@end
@interface CPNowPlayingMoreButton : CPNowPlayingButton
@end
@interface CPNowPlayingPlaybackRateButton : CPNowPlayingButton
@end
@interface CPNowPlayingImageButton : CPNowPlayingButton
- (instancetype)initWithImage:(UIImage *)image handler:(void (^ _Nullable)(__kindof CPNowPlayingButton *))handler;
@property (nullable, nonatomic, readonly) UIImage *image;
@end
@protocol CPNowPlayingTemplateObserver <NSObject>
@optional
- (void)nowPlayingTemplateUpNextButtonTapped:(CPNowPlayingTemplate *)nowPlayingTemplate;
- (void)nowPlayingTemplateAlbumArtistButtonTapped:(CPNowPlayingTemplate *)nowPlayingTemplate;
@end
@interface CPNowPlayingTemplate : CPTemplate
@property (class, nonatomic, readonly, strong) CPNowPlayingTemplate *sharedTemplate NS_SWIFT_NAME(shared);
@property (nonatomic, readonly, strong) NSArray<CPNowPlayingButton *> *nowPlayingButtons;
@property (nonatomic, assign, getter=isUpNextButtonEnabled) BOOL upNextButtonEnabled;
@property (nonatomic, copy) NSString *upNextTitle;
@property (nonatomic, assign, getter=isAlbumArtistButtonEnabled) BOOL albumArtistButtonEnabled;
@property (nonatomic, assign) BOOL allowsMiniPlayer;
@property (nullable, nonatomic, strong) CPNowPlayingMode *nowPlayingMode API_AVAILABLE(ios(26.0));
- (void)updateNowPlayingButtons:(NSArray<CPNowPlayingButton *> *)nowPlayingButtons;
- (void)addObserver:(id<CPNowPlayingTemplateObserver>)observer;
- (void)removeObserver:(id<CPNowPlayingTemplateObserver>)observer;
@end

API_AVAILABLE(ios(26.0)) @interface CPPlaybackConfiguration : NSObject <NSSecureCoding>
/* isim: its initializer and times (CMTime, a Swift struct in isim's CoreMedia) are Swift only */
@property (nonatomic, readonly) CPPlaybackPresentation preferredPresentation;
@property (nonatomic, readonly) CPPlaybackAction playbackAction;
@end
API_AVAILABLE(ios(26.0)) @interface CPImageOverlay : NSObject <NSSecureCoding>
- (instancetype)initWithImage:(UIImage *)image alignment:(CPImageOverlayAlignment)alignment;
- (instancetype)initWithText:(NSString *)text textColor:(UIColor *)textColor backgroundColor:(UIColor *)backgroundColor alignment:(CPImageOverlayAlignment)alignment;
@property (nonatomic, readonly) CPImageOverlayAlignment alignment;
@property (nullable, nonatomic, readonly) UIImage *image;
@property (nullable, nonatomic, readonly, copy) NSString *text;
@property (nullable, nonatomic, readonly) UIColor *textColor;
@property (nullable, nonatomic, readonly) UIColor *backgroundColor;
@end
API_AVAILABLE(ios(26.0)) @interface CPNowPlayingSportsTeamLogo : NSObject <NSSecureCoding>
- (instancetype)initWithTeamLogo:(UIImage *)teamLogo;
- (instancetype)initWithTeamInitials:(NSString *)teamInitials;
@property (nullable, nonatomic, readonly) UIImage *logo;
@property (nullable, nonatomic, readonly, copy) NSString *initials;
@end
API_AVAILABLE(ios(26.0)) @interface CPNowPlayingSportsTeam : NSObject <NSSecureCoding>
- (instancetype)initWithName:(NSString *)name logo:(CPNowPlayingSportsTeamLogo *)logo teamStandings:(nullable NSString *)teamStandings eventScore:(NSString *)eventScore possessionIndicator:(nullable UIImage *)possessionIndicator favorite:(BOOL)favorite;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly) CPNowPlayingSportsTeamLogo *logo;
@property (nullable, nonatomic, readonly, copy) NSString *teamStandings;
@property (nonatomic, readonly, copy) NSString *eventScore;
@property (nullable, nonatomic, readonly) UIImage *possessionIndicator;
@property (nonatomic, readonly, getter=isFavorite) BOOL favorite;
@end
API_AVAILABLE(ios(26.0)) @interface CPNowPlayingSportsClock : NSObject <NSSecureCoding>
- (instancetype)initWithElapsedTime:(NSTimeInterval)elapsedTime paused:(BOOL)paused;
- (instancetype)initWithTimeRemaining:(NSTimeInterval)timeRemaining paused:(BOOL)paused;
@property (nonatomic, readonly) NSTimeInterval timeValue;
@property (nonatomic, readonly) BOOL countsUp;
@property (nonatomic, readonly, getter=isPaused) BOOL paused;
@end
API_AVAILABLE(ios(26.0)) @interface CPNowPlayingSportsEventStatus : NSObject <NSSecureCoding>
- (instancetype)initWithEventStatusText:(nullable NSArray<NSString *> *)eventStatusText eventStatusImage:(nullable UIImage *)eventStatusImage eventClock:(nullable CPNowPlayingSportsClock *)eventClock;
@property (nullable, nonatomic, readonly, copy) NSArray<NSString *> *eventStatusText;
@property (nullable, nonatomic, readonly) UIImage *eventStatusImage;
@property (nullable, nonatomic, readonly) CPNowPlayingSportsClock *eventClock;
@end
API_AVAILABLE(ios(26.0)) @interface CPSportsOverlay : NSObject <NSSecureCoding>
- (instancetype)initWithLeftTeam:(CPNowPlayingSportsTeam *)leftTeam rightTeam:(CPNowPlayingSportsTeam *)rightTeam eventStatus:(nullable CPNowPlayingSportsEventStatus *)eventStatus;
@property (nonatomic, readonly) CPNowPlayingSportsTeam *leftTeam;
@property (nonatomic, readonly) CPNowPlayingSportsTeam *rightTeam;
@property (nullable, nonatomic, readonly) CPNowPlayingSportsEventStatus *eventStatus;
@end
API_AVAILABLE(ios(26.0)) @interface CPThumbnailImage : NSObject <NSSecureCoding>
- (instancetype)initWithImage:(UIImage *)image;
- (instancetype)initWithImage:(UIImage *)image imageOverlay:(nullable CPImageOverlay *)imageOverlay sportsOverlay:(nullable CPSportsOverlay *)sportsOverlay;
@property (nonatomic, strong) UIImage *image;
@property (nullable, nonatomic, strong) CPImageOverlay *imageOverlay;
@property (nullable, nonatomic, strong) CPSportsOverlay *sportsOverlay;
+ (CGSize)maximumImageSizeForAspectRatio:(CGFloat)aspectRatio;
@end
API_AVAILABLE(ios(26.0)) @interface CPNowPlayingMode : NSObject <NSSecureCoding>
@property (class, nonatomic, readonly) CPNowPlayingMode *defaultNowPlayingMode;
@end
API_AVAILABLE(ios(26.0)) @interface CPNowPlayingModeSports : CPNowPlayingMode
- (instancetype)initWithLeftTeam:(CPNowPlayingSportsTeam *)leftTeam rightTeam:(CPNowPlayingSportsTeam *)rightTeam eventStatus:(nullable CPNowPlayingSportsEventStatus *)eventStatus backgroundArtwork:(nullable UIImage *)backgroundArtwork;
@property (nonatomic, strong) CPNowPlayingSportsTeam *leftTeam;
@property (nonatomic, strong) CPNowPlayingSportsTeam *rightTeam;
@property (nullable, nonatomic, strong) CPNowPlayingSportsEventStatus *eventStatus;
@property (nullable, nonatomic, strong) UIImage *backgroundArtwork;
@end

/* ---- alerts, action sheets, information, points of interest, search, voice control, contacts ---- */
@interface CPAlertTemplate : CPTemplate
- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants actions:(NSArray<CPAlertAction *> *)actions;
@property (nonatomic, readonly, copy) NSArray<NSString *> *titleVariants;
@property (nonatomic, readonly, strong) NSArray<CPAlertAction *> *actions;
@property (class, nonatomic, readonly) NSUInteger maximumActionCount;
@end
@interface CPActionSheetTemplate : CPTemplate
- (instancetype)initWithTitle:(nullable NSString *)title message:(nullable NSString *)message actions:(NSArray<CPAlertAction *> *)actions;
@property (nullable, nonatomic, readonly, copy) NSString *title;
@property (nullable, nonatomic, readonly, copy) NSString *message;
@property (nonatomic, readonly, strong) NSArray<CPAlertAction *> *actions;
@end

@interface CPInformationItem : NSObject <NSSecureCoding>
- (instancetype)initWithTitle:(nullable NSString *)title detail:(nullable NSString *)detail;
@property (nullable, nonatomic, readonly, copy) NSString *title;
@property (nullable, nonatomic, readonly, copy) NSString *detail;
@end
@interface CPInformationRatingItem : CPInformationItem
- (instancetype)initWithRating:(nullable NSNumber *)rating maximumRating:(nullable NSNumber *)maximumRating title:(nullable NSString *)title detail:(nullable NSString *)detail;
@property (nullable, nonatomic, readonly) NSNumber *rating;
@property (nullable, nonatomic, readonly) NSNumber *maximumRating;
@end
@interface CPInformationTemplate : CPTemplate <CPBarButtonProviding>
- (instancetype)initWithTitle:(NSString *)title layout:(CPInformationTemplateLayout)layout items:(NSArray<CPInformationItem *> *)items actions:(NSArray<CPTextButton *> *)actions;
@property (nonatomic, readonly) CPInformationTemplateLayout layout;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray<CPInformationItem *> *items;
@property (nonatomic, copy) NSArray<CPTextButton *> *actions;
@end

@interface CPPointOfInterest : NSObject <NSSecureCoding>
- (instancetype)initWithLocation:(MKMapItem *)location title:(NSString *)title subtitle:(nullable NSString *)subtitle summary:(nullable NSString *)summary
                     detailTitle:(nullable NSString *)detailTitle detailSubtitle:(nullable NSString *)detailSubtitle detailSummary:(nullable NSString *)detailSummary
                        pinImage:(nullable UIImage *)pinImage selectedPinImage:(nullable UIImage *)selectedPinImage;
- (instancetype)initWithLocation:(MKMapItem *)location title:(NSString *)title subtitle:(nullable NSString *)subtitle summary:(nullable NSString *)summary
                     detailTitle:(nullable NSString *)detailTitle detailSubtitle:(nullable NSString *)detailSubtitle detailSummary:(nullable NSString *)detailSummary
                        pinImage:(nullable UIImage *)pinImage;
@property (nonatomic, strong) MKMapItem *location;
@property (nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) NSString *subtitle;
@property (nullable, nonatomic, copy) NSString *summary;
@property (nullable, nonatomic, copy) NSString *detailTitle;
@property (nullable, nonatomic, copy) NSString *detailSubtitle;
@property (nullable, nonatomic, copy) NSString *detailSummary;
@property (nullable, nonatomic, strong) UIImage *pinImage;
@property (nullable, nonatomic, strong) UIImage *selectedPinImage;
@property (nullable, nonatomic, strong) CPTextButton *primaryButton;
@property (nullable, nonatomic, strong) CPTextButton *secondaryButton;
@property (nullable, nonatomic, strong) id userInfo;
@property (class, nonatomic, readonly) CGSize pinImageSize;
@property (class, nonatomic, readonly) CGSize selectedPinImageSize;
@end
@interface CPPointOfInterestTemplate : CPTemplate <CPBarButtonProviding>
- (instancetype)initWithTitle:(NSString *)title pointsOfInterest:(NSArray<CPPointOfInterest *> *)pointsOfInterest selectedIndex:(NSInteger)selectedIndex;
/* isim: pointOfInterestDelegate (CPPointOfInterestTemplateDelegate, with an MKCoordinateRegion, a Swift struct in isim's
   MapKit) is Swift only */
@property (nonatomic, copy) NSString *title;
@property (nonatomic, readonly) NSArray<CPPointOfInterest *> *pointsOfInterest;
@property (nonatomic, assign) NSInteger selectedIndex;
- (void)setPointsOfInterest:(NSArray<CPPointOfInterest *> *)pointsOfInterest selectedIndex:(NSInteger)selectedIndex;
@end

@protocol CPSearchTemplateDelegate <NSObject>
- (void)searchTemplate:(CPSearchTemplate *)searchTemplate updatedSearchText:(NSString *)searchText completionHandler:(void (^)(NSArray<CPListItem *> *searchResults))completionHandler;
- (void)searchTemplate:(CPSearchTemplate *)searchTemplate selectedResult:(CPListItem *)item completionHandler:(void (^)(void))completionHandler;
@optional
- (void)searchTemplateSearchButtonPressed:(CPSearchTemplate *)searchTemplate;
@end
@interface CPSearchTemplate : CPTemplate <CPBarButtonProviding>
@property (nullable, nonatomic, weak) id<CPSearchTemplateDelegate> delegate;
@end

@interface CPVoiceControlState : NSObject <NSSecureCoding>
- (instancetype)initWithIdentifier:(NSString *)identifier titleVariants:(nullable NSArray<NSString *> *)titleVariants image:(nullable UIImage *)image repeats:(BOOL)repeats;
- (instancetype)initWithIdentifier:(NSString *)identifier titleVariants:(nullable NSArray<NSString *> *)titleVariants image:(nullable UIImage *)image backgroundImage:(nullable UIImage *)backgroundImage repeats:(BOOL)repeats;
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nullable, nonatomic, readonly, copy) NSArray<NSString *> *titleVariants;
@property (nullable, nonatomic, readonly) UIImage *image;
@property (nullable, nonatomic, readonly) UIImage *backgroundImage;
@property (nonatomic, readonly) BOOL repeats;
@property (nonatomic, copy) NSArray<CPButton *> *actionButtons;
@property (class, nonatomic, readonly) NSInteger maximumActionButtonCount;
@end
@interface CPVoiceControlTemplate : CPTemplate <CPBarButtonProviding>
- (instancetype)initWithVoiceControlStates:(NSArray<CPVoiceControlState *> *)voiceControlStates;
@property (nonatomic, readonly, copy) NSArray<CPVoiceControlState *> *voiceControlStates;
@property (nullable, nonatomic, readonly, copy) NSString *activeStateIdentifier;
- (void)activateVoiceControlStateWithIdentifier:(NSString *)identifier;
@end

@interface CPContactCallButton : CPButton
- (instancetype)initWithHandler:(void (^ _Nullable)(__kindof CPButton *))handler;
@end
@interface CPContactDirectionsButton : CPButton
- (instancetype)initWithHandler:(void (^ _Nullable)(__kindof CPButton *))handler;
@end
@interface CPContactMessageButton : CPButton
- (instancetype)initWithPhoneOrEmail:(NSString *)phoneOrEmail;
@property (nonatomic, readonly, copy) NSString *phoneOrEmail;
@end
@interface CPContact : NSObject <NSSecureCoding>
- (instancetype)initWithName:(NSString *)name image:(UIImage *)image;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) UIImage *image;
@property (nullable, nonatomic, copy) NSString *subtitle;
@property (nullable, nonatomic, copy) NSString *informativeText;
@property (nullable, nonatomic, strong) NSArray<CPButton *> *actions;
@end
@interface CPContactTemplate : CPTemplate <CPBarButtonProviding>
- (instancetype)initWithContact:(CPContact *)contact;
@property (nonatomic, strong) CPContact *contact;
@end

/* ---- navigation ---- */
@interface CPMapButton : NSObject <NSSecureCoding>
- (instancetype)initWithHandler:(void (^ _Nullable)(CPMapButton *mapButton))handler;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nonatomic, assign, getter=isHidden) BOOL hidden;
@property (nullable, nonatomic, strong) UIImage *image;
@property (nullable, nonatomic, strong) UIImage *focusedImage;
@end

@interface CPTravelEstimates : NSObject <NSSecureCoding>
- (instancetype)initWithDistanceRemaining:(NSMeasurement<NSUnitLength *> *)distance distanceRemainingToDisplay:(NSMeasurement<NSUnitLength *> *)distanceToDisplay timeRemaining:(NSTimeInterval)time;
- (instancetype)initWithDistanceRemaining:(NSMeasurement<NSUnitLength *> *)distance timeRemaining:(NSTimeInterval)time;
- (instancetype)initWithDistanceRemaining:(NSMeasurement<NSUnitLength *> *)distance distanceRemainingToDisplay:(NSMeasurement<NSUnitLength *> *)distanceToDisplay timeRemaining:(NSTimeInterval)time routeDetails:(NSArray<CPRouteDetail *> *)routeDetails API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly, copy) NSMeasurement<NSUnitLength *> *distanceRemaining;
@property (nonatomic, readonly, copy) NSMeasurement<NSUnitLength *> *distanceRemainingToDisplay;
@property (nonatomic, readonly, assign) NSTimeInterval timeRemaining;
@property (nonatomic, readonly, copy) NSArray<CPRouteDetail *> *routeDetails API_AVAILABLE(ios(26.0));
@end

@interface CPRouteChoice : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithSummaryVariants:(NSArray<NSString *> *)summaryVariants additionalInformationVariants:(NSArray<NSString *> *)additionalInformationVariants selectionSummaryVariants:(NSArray<NSString *> *)selectionSummaryVariants;
- (instancetype)initWithSummaryVariants:(NSArray<NSString *> *)summaryVariants additionalInformationVariants:(NSArray<NSString *> *)additionalInformationVariants selectionSummaryVariants:(NSArray<NSString *> *)selectionSummaryVariants travelEstimates:(nullable CPTravelEstimates *)travelEstimates API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly, copy) NSArray<NSString *> *summaryVariants;
@property (nullable, nonatomic, readonly, copy) NSArray<NSString *> *additionalInformationVariants;
@property (nullable, nonatomic, readonly, copy) NSArray<NSString *> *selectionSummaryVariants;
@property (nullable, nonatomic, readonly) CPTravelEstimates *travelEstimates API_AVAILABLE(ios(26.0));
@property (nullable, nonatomic, strong) id userInfo;
@end

API_AVAILABLE(ios(26.0)) @interface CPNavigationWaypoint : NSObject <NSSecureCoding>
- (instancetype)initWithCenterPoint:(CPLocationCoordinate3D)centerPoint locationThreshold:(nullable NSMeasurement<NSUnitLength *> *)locationThreshold name:(nullable NSString *)name
                            address:(nullable NSString *)address entryPoints:(nullable CPLocationCoordinate3D *)entryPoints entryPointsCount:(NSUInteger)entryPointsCount timeZone:(nullable NSTimeZone *)timeZone;
- (instancetype)initWithMapItem:(MKMapItem *)mapItem locationThreshold:(nullable NSMeasurement<NSUnitLength *> *)locationThreshold entryPoints:(nullable CPLocationCoordinate3D *)entryPoints entryPointsCount:(NSUInteger)entryPointsCount;
@property (nonatomic, readonly) CPLocationCoordinate3D centerPoint;
@property (nullable, nonatomic, readonly, copy) NSMeasurement<NSUnitLength *> *locationThreshold;
@property (nullable, nonatomic, readonly, copy) NSString *name;
@property (nullable, nonatomic, readonly, copy) NSString *address;
@property (nonatomic, readonly, copy) NSArray<NSString *> *nameVariants;
@property (nonatomic, readonly, copy) NSArray<NSString *> *addressVariants;
@property (nullable, nonatomic, readonly) CPLocationCoordinate3D *entryPoints;
@property (nonatomic, readonly) NSUInteger entryPointsCount;
@property (nullable, nonatomic, readonly, copy) NSTimeZone *timeZone;
@end

@interface CPTrip : NSObject <NSSecureCoding>
- (instancetype)initWithOrigin:(MKMapItem *)origin destination:(MKMapItem *)destination routeChoices:(NSArray<CPRouteChoice *> *)routeChoices;
- (instancetype)initWithOriginWaypoint:(CPNavigationWaypoint *)originWaypoint destinationWaypoint:(CPNavigationWaypoint *)destinationWaypoint routeChoices:(NSArray<CPRouteChoice *> *)routeChoices API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly, strong) MKMapItem *origin;
@property (nonatomic, readonly, strong) MKMapItem *destination;
@property (nonatomic, readonly, copy) NSArray<CPRouteChoice *> *routeChoices;
@property (nullable, nonatomic, copy) NSArray<NSString *> *destinationNameVariants;
@property (nullable, nonatomic, strong) id userInfo;
@property (nonatomic, readonly) CPNavigationWaypoint *originWaypoint API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly) CPNavigationWaypoint *destinationWaypoint API_AVAILABLE(ios(26.0));
@property (nonatomic, assign) BOOL hasShareableDestination API_AVAILABLE(ios(26.0));
@property (nonatomic, assign) BOOL routeSegmentsAvailableForRegion API_AVAILABLE(ios(26.0));
@end

@interface CPTripPreviewTextConfiguration : NSObject <NSSecureCoding>
- (instancetype)initWithStartButtonTitle:(nullable NSString *)startButtonTitle additionalRoutesButtonTitle:(nullable NSString *)additionalRoutesButtonTitle overviewButtonTitle:(nullable NSString *)overviewButtonTitle;
@property (nullable, nonatomic, readonly, copy) NSString *startButtonTitle;
@property (nullable, nonatomic, readonly, copy) NSString *additionalRoutesButtonTitle;
@property (nullable, nonatomic, readonly, copy) NSString *overviewButtonTitle;
@end

@interface CPLane : NSObject <NSCopying, NSSecureCoding>
- (instancetype)init;
- (instancetype)initWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles;
- (instancetype)initWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles highlightedAngle:(NSMeasurement<NSUnitAngle *> *)highlightedAngle isPreferred:(BOOL)preferred;
@property (nonatomic, readonly) CPLaneStatus status;
@property (nonatomic, readonly, copy) NSArray<NSMeasurement<NSUnitAngle *> *> *angles;
@property (nullable, nonatomic, readonly, copy) NSMeasurement<NSUnitAngle *> *highlightedAngle;
@property (nonatomic, readonly, copy) NSMeasurement<NSUnitAngle *> *primaryAngle;
@property (nonatomic, readonly, copy) NSArray<NSMeasurement<NSUnitAngle *> *> *secondaryAngles;
@end
@interface CPLaneGuidance : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, copy) NSArray<NSString *> *instructionVariants;
@property (nonatomic, copy) NSArray<CPLane *> *lanes;
@end

@interface CPManeuver : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, copy) NSArray<NSString *> *instructionVariants;
@property (nonatomic, copy) NSArray<NSString *> *dashboardInstructionVariants;
@property (nonatomic, copy) NSArray<NSString *> *notificationInstructionVariants;
@property (nonatomic, copy) NSArray<NSAttributedString *> *attributedInstructionVariants;
@property (nonatomic, copy) NSArray<NSAttributedString *> *dashboardAttributedInstructionVariants;
@property (nonatomic, copy) NSArray<NSAttributedString *> *notificationAttributedInstructionVariants;
@property (nullable, nonatomic, strong) CPTravelEstimates *initialTravelEstimates;
@property (nullable, nonatomic, strong) UIImage *symbolImage;
@property (nullable, nonatomic, strong) UIImage *dashboardSymbolImage;
@property (nullable, nonatomic, strong) UIImage *notificationSymbolImage;
@property (nullable, nonatomic, strong) CPImageSet *symbolSet;
@property (nullable, nonatomic, strong) UIImage *junctionImage;
@property (nullable, nonatomic, strong) UIImage *dashboardJunctionImage;
@property (nonatomic, assign) CPJunctionType junctionType API_AVAILABLE(ios(17.4));
@property (nullable, nonatomic, copy) NSMeasurement<NSUnitAngle *> *junctionExitAngle API_AVAILABLE(ios(17.4));
@property (nullable, nonatomic, copy) NSSet<NSMeasurement<NSUnitAngle *> *> *junctionElementAngles API_AVAILABLE(ios(17.4));
@property (nonatomic, assign) CPManeuverType maneuverType API_AVAILABLE(ios(17.4));
@property (nullable, nonatomic, copy) NSArray<NSString *> *roadFollowingManeuverVariants API_AVAILABLE(ios(17.4));
@property (nonatomic, copy) CPLaneGuidance *linkedLaneGuidance API_AVAILABLE(ios(17.4));
@property (nonatomic, copy) NSString *highwayExitLabel API_AVAILABLE(ios(17.4));
@property (nonatomic, assign) CPTrafficSide trafficSide API_AVAILABLE(ios(17.4));
@property (nullable, nonatomic, strong) UIColor *cardBackgroundColor API_AVAILABLE(ios(18.4));
@property (nullable, nonatomic, strong) id userInfo;
@end

@interface CPRouteInformation : NSObject
- (instancetype)initWithManeuvers:(NSArray<CPManeuver *> *)maneuvers laneGuidances:(NSArray<CPLaneGuidance *> *)laneGuidances currentManeuvers:(NSArray<CPManeuver *> *)currentManeuvers
              currentLaneGuidance:(CPLaneGuidance *)currentLaneGuidance tripTravelEstimates:(CPTravelEstimates *)tripTravelEstimates maneuverTravelEstimates:(CPTravelEstimates *)maneuverTravelEstimates API_AVAILABLE(ios(17.4));
@property (nonatomic, readonly, copy) NSArray<CPManeuver *> *maneuvers;
@property (nonatomic, readonly, copy) NSArray<CPLaneGuidance *> *laneGuidances;
@property (nonatomic, readonly, copy) NSArray<CPManeuver *> *currentManeuvers;
@property (nonatomic, readonly, copy) CPLaneGuidance *currentLaneGuidance;
@property (nonatomic, readonly, copy) CPTravelEstimates *tripTravelEstimates;
@property (nonatomic, readonly, copy) CPTravelEstimates *maneuverTravelEstimates;
@end

API_AVAILABLE(ios(26.0)) @interface CPRouteDetail : NSObject <NSSecureCoding>
- (instancetype)initWithSymbolName:(NSString *)symbolName value:(NSString *)value;
- (instancetype)initWithInfo:(NSString *)info;
- (instancetype)initWithWarning:(NSString *)warning;
- (instancetype)initWithParking:(NSString *)parking;
- (instancetype)initWithHOV:(NSString *)hov;
- (instancetype)initWithRating:(double)rating;
- (instancetype)initWithEcoScore:(double)ecoScore;
- (instancetype)initWithBatteryLevel:(double)batteryLevel;
- (instancetype)initWithTrafficLights:(NSInteger)trafficLights;
- (instancetype)initWithTollAmount:(double)tollAmount locale:(NSLocale *)locale;
- (instancetype)initWithCarbonFootprint:(NSMeasurement<NSUnitMass *> *)carbonFootprint;
- (instancetype)initWithEmissions:(NSMeasurement<NSUnitMass *> *)emissions;
- (instancetype)initWithFuelEnergy:(NSMeasurement<NSUnitEnergy *> *)fuelEnergy;
- (instancetype)initWithFuelLevel:(NSMeasurement<NSUnitVolume *> *)fuelLevel;
- (instancetype)initWithFuelMass:(NSMeasurement<NSUnitMass *> *)fuelMass;
- (instancetype)initWithKilowattHours:(NSMeasurement<NSUnitEnergy *> *)kilowattHours;
@property (nullable, nonatomic, strong) UIColor *symbolTintColor;
@end

API_AVAILABLE(ios(26.0)) @interface CPRouteSegment : NSObject
- (instancetype)initWithOrigin:(CPNavigationWaypoint *)origin destination:(CPNavigationWaypoint *)destination maneuvers:(NSArray<CPManeuver *> *)maneuvers
                 laneGuidances:(NSArray<CPLaneGuidance *> *)laneGuidances currentManeuvers:(NSArray<CPManeuver *> *)currentManeuvers currentLaneGuidance:(CPLaneGuidance *)currentLaneGuidance
           tripTravelEstimates:(CPTravelEstimates *)tripTravelEstimates maneuverTravelEstimates:(CPTravelEstimates *)maneuverTravelEstimates
                   coordinates:(nullable CPLocationCoordinate3D *)coordinates coordinatesCount:(NSInteger)coordinatesCount;
@property (nonatomic, readonly) NSUUID *identifier;
@property (nonatomic, readonly) CPNavigationWaypoint *origin;
@property (nonatomic, readonly) CPNavigationWaypoint *destination;
@property (nonatomic, readonly, copy) NSArray<CPManeuver *> *maneuvers;
@property (nonatomic, readonly, copy) NSArray<CPLaneGuidance *> *laneGuidances;
@property (nonatomic, readonly, copy) NSArray<CPManeuver *> *currentManeuvers;
@property (nonatomic, readonly) CPLaneGuidance *currentLaneGuidance;
@property (nonatomic, readonly) CPTravelEstimates *tripTravelEstimates;
@property (nonatomic, readonly) CPTravelEstimates *maneuverTravelEstimates;
@property (nullable, nonatomic, readonly) CPLocationCoordinate3D *coordinates;
@property (nonatomic, readonly) NSInteger coordinatesCount;
@end

API_AVAILABLE(ios(26.0)) @interface CPMapTemplateWaypoint : NSObject <NSSecureCoding>
- (instancetype)initWithWaypoint:(CPNavigationWaypoint *)waypoint travelEstimates:(CPTravelEstimates *)travelEstimates;
@property (nonatomic, readonly) CPNavigationWaypoint *waypoint;
@property (nonatomic, readonly) CPTravelEstimates *travelEstimates;
@end
API_AVAILABLE(ios(26.0)) @interface CPMultiStopCardConfiguration : NSObject <NSSecureCoding>
- (instancetype)initWithTitle:(nullable NSString *)title buttons:(NSArray<CPTextButton *> *)buttons;
- (instancetype)initWithTitle:(nullable NSString *)title buttons:(NSArray<CPTextButton *> *)buttons image:(nullable UIImage *)image;
@property (nullable, nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSArray<CPTextButton *> *buttons;
@property (nullable, nonatomic, readonly) UIImage *image;
@end
API_AVAILABLE(ios(26.0)) @interface CPChargingStationConnection : NSObject <NSSecureCoding>
- (instancetype)initWithConnector:(CPChargingStationConnector)connector voltage:(NSMeasurement<NSUnitElectricPotentialDifference *> *)voltage power:(NSMeasurement<NSUnitPower *> *)power;
@property (nonatomic, readonly) CPChargingStationConnector connector;
@property (nonatomic, readonly, copy) NSMeasurement<NSUnitElectricPotentialDifference *> *voltage;
@property (nonatomic, readonly, copy) NSMeasurement<NSUnitPower *> *power;
@end

API_AVAILABLE(ios(26.0)) @interface CPPanelButtonConfiguration : NSObject <NSSecureCoding>
- (instancetype)initWithPrimaryAction:(CPTextButton *)primaryAction secondaryAction:(nullable CPTextButton *)secondaryAction;
@property (nonatomic, readonly) CPTextButton *primaryAction;
@property (nullable, nonatomic, readonly) CPTextButton *secondaryAction;
@end
API_AVAILABLE(ios(26.0)) @interface CPPanelItem : NSObject <NSSecureCoding>
- (instancetype)initWithListItem:(CPListItem *)listItem;
- (instancetype)initWithGridButtons:(NSArray<CPGridButton *> *)gridButtons;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nonatomic, assign) BOOL showsBottomSeparator;
@property (nullable, nonatomic, strong) id userInfo;
@end
API_AVAILABLE(ios(26.0)) @interface CPPanel : CPTemplate
@property (nonatomic, assign) BOOL showsCloseButton;
@property (class, nonatomic, readonly) NSInteger maximumPanelItemsCount;
@end
typedef void (^CPMapPanelItemHandler)(CPMapPanelItem *item, dispatch_block_t completion);
API_AVAILABLE(ios(26.0)) @interface CPMapPanelItem : NSObject
- (instancetype)initWithTrip:(CPTrip *)trip handler:(nullable CPMapPanelItemHandler)handler;
- (instancetype)initWithRouteChoice:(CPRouteChoice *)routeChoice handler:(nullable CPMapPanelItemHandler)handler;
- (instancetype)initWithTravelEstimates:(CPTravelEstimates *)travelEstimates handler:(nullable CPMapPanelItemHandler)handler;
- (instancetype)initWithRouteDetails:(NSArray<CPRouteDetail *> *)routeDetails handler:(nullable CPMapPanelItemHandler)handler;
- (instancetype)initWithMapTemplateWaypoint:(CPMapTemplateWaypoint *)mapTemplateWaypoint image:(nullable UIImage *)image handler:(nullable CPMapPanelItemHandler)handler;
- (instancetype)initWithChargingStationConnection:(CPChargingStationConnection *)chargingStationConnection handler:(nullable CPMapPanelItemHandler)handler;
@end
API_AVAILABLE(ios(26.0)) @interface CPMapPanelSection : NSObject <NSSecureCoding>
- (instancetype)initWithTitle:(nullable NSString *)title items:(NSArray<CPMapPanelItem *> *)items;
@property (nullable, nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSArray<CPMapPanelItem *> *items;
@end
API_AVAILABLE(ios(26.0)) @interface CPMapPanelButtonConfiguration : CPPanelButtonConfiguration
- (instancetype)initWithPrimaryAction:(CPTextButton *)primaryAction secondaryButton:(nullable CPButton *)secondaryButton travelEstimates:(CPTravelEstimates *)travelEstimates;
@property (nullable, nonatomic, readonly) CPButton *secondaryButton;
@property (nullable, nonatomic, readonly) CPTravelEstimates *travelEstimates;
@end
@protocol CPMapPanelDelegate <NSObject>
@optional
- (void)panelDidShow:(CPMapPanel *)panel;
- (void)panelDidHide:(CPMapPanel *)panel;
@end
API_AVAILABLE(ios(26.0)) @interface CPMapPanel : CPPanel
- (instancetype)initWithTitle:(nullable NSString *)title sections:(NSArray<CPMapPanelSection *> *)sections buttonConfiguration:(nullable CPMapPanelButtonConfiguration *)buttonConfiguration;
@property (nullable, nonatomic, weak) id<CPMapPanelDelegate> delegate;
@property (nullable, nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray<CPMapPanelSection *> *sections;
@property (nullable, nonatomic, strong) CPMapPanelButtonConfiguration *buttonConfiguration;
@end

@interface CPNavigationAlert : NSObject <NSSecureCoding>
- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants subtitleVariants:(nullable NSArray<NSString *> *)subtitleVariants imageSet:(nullable CPImageSet *)imageSet
                        primaryAction:(CPAlertAction *)primaryAction secondaryAction:(nullable CPAlertAction *)secondaryAction duration:(NSTimeInterval)duration;
- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants subtitleVariants:(nullable NSArray<NSString *> *)subtitleVariants image:(nullable UIImage *)image
                        primaryAction:(CPAlertAction *)primaryAction secondaryAction:(nullable CPAlertAction *)secondaryAction duration:(NSTimeInterval)duration;
- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants subtitleVariants:(NSArray<NSString *> *)subtitleVariants avatarImage:(nullable UIImage *)avatarImage
                           alertImage:(nullable UIImage *)alertImage actions:(NSArray<CPAlertAction *> *)actions duration:(NSTimeInterval)duration API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly, copy) NSArray<NSString *> *titleVariants;
@property (nonatomic, readonly, copy) NSArray<NSString *> *subtitleVariants;
@property (nullable, nonatomic, readonly) UIImage *image;
@property (nullable, nonatomic, readonly, copy) CPImageSet *imageSet;
@property (nonatomic, readonly, strong) CPAlertAction *primaryAction;
@property (nullable, nonatomic, readonly, strong) CPAlertAction *secondaryAction;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly, copy) NSArray<CPAlertAction *> *actions API_AVAILABLE(ios(26.0));
@property (nullable, nonatomic, readonly) UIImage *avatarImage API_AVAILABLE(ios(26.0));
@property (nullable, nonatomic, readonly) UIImage *alertImage API_AVAILABLE(ios(26.0));
@property (nonatomic, assign) BOOL showsCloseButton API_AVAILABLE(ios(26.0));
@property (class, nonatomic, readonly) NSInteger maximumActionsCount;
@property (class, nonatomic, readonly) CGSize maximumAlertImageSize;
@property (class, nonatomic, readonly) CGSize maximumAvatarImageSize;
- (void)updateTitleVariants:(NSArray<NSString *> *)newTitleVariants subtitleVariants:(NSArray<NSString *> *)newSubtitleVariants;
- (void)updateTitleVariants:(NSArray<NSString *> *)newTitleVariants subtitleVariants:(NSArray<NSString *> *)newSubtitleVariants avatarImage:(nullable UIImage *)avatarImage
                 alertImage:(nullable UIImage *)alertImage actions:(NSArray<CPAlertAction *> *)actions duration:(NSTimeInterval)duration API_AVAILABLE(ios(26.0));
@end

@interface CPNavigationSession : NSObject
@property (nonatomic, readonly, strong) CPTrip *trip;
@property (nonatomic, copy) NSArray<CPManeuver *> *upcomingManeuvers;
@property (nonatomic, assign) CPManeuverState maneuverState API_AVAILABLE(ios(17.4));
@property (nonatomic, copy) NSArray<NSString *> *currentRoadNameVariants API_AVAILABLE(ios(17.4));
@property (nullable, nonatomic, copy) CPLaneGuidance *currentLaneGuidance API_AVAILABLE(ios(17.4));
@property (nonatomic, readonly, copy) NSArray<CPRouteSegment *> *routeSegments API_AVAILABLE(ios(26.0));
@property (nullable, nonatomic, readonly) CPRouteSegment *currentSegment API_AVAILABLE(ios(26.0));
@property (nonatomic, assign, getter=isRouteSharingEnabled) BOOL routeSharingEnabled API_AVAILABLE(ios(26.0));
@property (nonatomic, assign, getter=isRouteSharingSupported) BOOL routeSharingSupported API_AVAILABLE(ios(26.0));
@property (nullable, nonatomic, strong) CPMapPanel *optionsPanel API_AVAILABLE(ios(26.0));
- (void)updateEstimates:(CPTravelEstimates *)estimates forManeuver:(CPManeuver *)maneuver;
- (void)addManeuvers:(NSArray<CPManeuver *> *)maneuvers API_AVAILABLE(ios(17.4));
- (void)addLaneGuidances:(NSArray<CPLaneGuidance *> *)laneGuidances API_AVAILABLE(ios(17.4));
- (void)addRouteSegments:(NSArray<CPRouteSegment *> *)routeSegments API_AVAILABLE(ios(26.0));
- (void)pauseTripForReason:(CPTripPauseReason)reason description:(nullable NSString *)description;
- (void)pauseTripForReason:(CPTripPauseReason)reason description:(nullable NSString *)description turnCardColor:(nullable UIColor *)turnCardColor;
- (void)resumeTripWithUpdatedRouteInformation:(CPRouteInformation *)routeInformation API_AVAILABLE(ios(17.4));
- (void)resumeTripWithUpdatedRouteSegments:(NSArray<CPRouteSegment *> *)routeSegments currentSegment:(CPRouteSegment *)currentSegment rerouteReason:(CPRerouteReason)rerouteReason API_AVAILABLE(ios(26.0));
- (void)resumeNavigationWithUpdatedTrip:(CPTrip *)trip routeSegments:(NSArray<CPRouteSegment *> *)routeSegments currentSegment:(CPRouteSegment *)currentSegment rerouteReason:(CPRerouteReason)rerouteReason API_AVAILABLE(ios(26.0));
- (void)finishTrip;
- (void)cancelTrip;
@end

@protocol CPMapTemplateDelegate <NSObject>
@optional
- (BOOL)mapTemplateShouldProvideNavigationMetadata:(CPMapTemplate *)mapTemplate;
- (BOOL)mapTemplate:(CPMapTemplate *)mapTemplate shouldShowNotificationForManeuver:(CPManeuver *)maneuver;
- (BOOL)mapTemplate:(CPMapTemplate *)mapTemplate shouldUpdateNotificationForManeuver:(CPManeuver *)maneuver withTravelEstimates:(CPTravelEstimates *)travelEstimates;
- (BOOL)mapTemplate:(CPMapTemplate *)mapTemplate shouldShowNotificationForNavigationAlert:(CPNavigationAlert *)navigationAlert;
- (void)mapTemplateDidShowPanningInterface:(CPMapTemplate *)mapTemplate;
- (void)mapTemplateWillDismissPanningInterface:(CPMapTemplate *)mapTemplate;
- (void)mapTemplateDidDismissPanningInterface:(CPMapTemplate *)mapTemplate;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate panBeganWithDirection:(CPPanDirection)direction;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate panWithDirection:(CPPanDirection)direction;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate panEndedWithDirection:(CPPanDirection)direction;
- (void)mapTemplateDidBeginPanGesture:(CPMapTemplate *)mapTemplate;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didUpdatePanGestureWithTranslation:(CGPoint)translation velocity:(CGPoint)velocity;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didEndPanGestureWithVelocity:(CGPoint)velocity;
- (void)mapTemplateDidBeginZoomGesture:(CPMapTemplate *)mapTemplate;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didUpdateZoomGestureWithCenter:(CGPoint)center scale:(CGFloat)scale velocity:(CGFloat)velocity;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didEndZoomGestureWithVelocity:(CGFloat)velocity;
- (void)mapTemplateDidBeginPitchGesture:(CPMapTemplate *)mapTemplate;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate pitchWithCenter:(CGPoint)center;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate pitchEndedWithCenter:(CGPoint)center;
- (void)mapTemplateDidBeginRotationGesture:(CPMapTemplate *)mapTemplate;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didRotateWithCenter:(CGPoint)center rotation:(CGFloat)rotation velocity:(CGFloat)velocity;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate rotationDidEndWithVelocity:(CGFloat)velocity;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate willShowNavigationAlert:(CPNavigationAlert *)navigationAlert;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didShowNavigationAlert:(CPNavigationAlert *)navigationAlert;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate willDismissNavigationAlert:(CPNavigationAlert *)navigationAlert dismissalContext:(CPNavigationAlertDismissalContext)dismissalContext;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didDismissNavigationAlert:(CPNavigationAlert *)navigationAlert dismissalContext:(CPNavigationAlertDismissalContext)dismissalContext;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate selectedPreviewForTrip:(CPTrip *)trip usingRouteChoice:(CPRouteChoice *)routeChoice;
- (void)mapTemplate:(CPMapTemplate *)mapTemplate startedTrip:(CPTrip *)trip usingRouteChoice:(CPRouteChoice *)routeChoice;
- (void)mapTemplateDidCancelNavigation:(CPMapTemplate *)mapTemplate;
- (CPManeuverDisplayStyle)mapTemplate:(CPMapTemplate *)mapTemplate displayStyleForManeuver:(CPManeuver *)maneuver;
- (BOOL)mapTemplateShouldProvideRouteSharing:(CPMapTemplate *)mapTemplate API_AVAILABLE(ios(26.0));
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didUpdateRouteSharingEnabled:(BOOL)enabled API_AVAILABLE(ios(26.0));
- (void)mapTemplate:(CPMapTemplate *)mapTemplate willShareDestinationForTrip:(CPTrip *)trip API_AVAILABLE(ios(26.0));
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didShareDestinationForTrip:(CPTrip *)trip API_AVAILABLE(ios(26.0));
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didFailToShareDestinationForTrip:(CPTrip *)trip error:(NSError *)error API_AVAILABLE(ios(26.0));
- (BOOL)mapTemplateShouldProvideMultiStopRouting:(CPMapTemplate *)mapTemplate API_AVAILABLE(ios(26.0));
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didReceiveUpdatedRouteSource:(CPRouteSource)routeSource API_AVAILABLE(ios(26.0));
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didReceiveRequestForDestination:(CPNavigationWaypoint *)waypoint API_AVAILABLE(ios(26.0));
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didRequestToInsertWaypoint:(CPNavigationWaypoint *)waypoint intoSegment:(CPRouteSegment *)segment completion:(void (^)(CPTravelEstimates *))completion API_AVAILABLE(ios(26.0));
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didRequestToRemoveWaypoint:(CPNavigationWaypoint *)waypoint API_AVAILABLE(ios(26.0));
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didRequestToRemoveDestination:(CPNavigationWaypoint *)waypoint API_AVAILABLE(ios(26.0));
- (void)mapTemplate:(CPMapTemplate *)mapTemplate waypoint:(CPNavigationWaypoint *)waypoint accepted:(BOOL)accepted forSegment:(nullable CPRouteSegment *)segment API_AVAILABLE(ios(26.0));
- (void)mapTemplate:(CPMapTemplate *)mapTemplate didRequestMultiStopCardConfigurationWithCompletion:(void (^)(CPMultiStopCardConfiguration *))completion API_AVAILABLE(ios(26.0));
@end

@interface CPMapTemplate : CPTemplate <CPBarButtonProviding>
@property (nullable, nonatomic, weak) id<CPMapTemplateDelegate> mapDelegate;
@property (nonatomic, strong) UIColor *guidanceBackgroundColor;
@property (nonatomic, assign) CPTripEstimateStyle tripEstimateStyle;
@property (nonatomic, strong) NSArray<CPMapButton *> *mapButtons;
@property (nonatomic, assign) BOOL automaticallyHidesNavigationBar;
@property (nonatomic, assign) BOOL hidesButtonsWithNavigationBar;
@property (nullable, nonatomic, readonly) CPNavigationAlert *currentNavigationAlert;
@property (nonatomic, readonly, getter=isPanningInterfaceVisible) BOOL panningInterfaceVisible;
- (void)showTripPreviews:(NSArray<CPTrip *> *)tripPreviews textConfiguration:(nullable CPTripPreviewTextConfiguration *)textConfiguration;
- (void)showTripPreviews:(NSArray<CPTrip *> *)tripPreviews selectedTrip:(nullable CPTrip *)selectedTrip textConfiguration:(nullable CPTripPreviewTextConfiguration *)textConfiguration;
- (void)showRouteChoicesPreviewForTrip:(CPTrip *)tripPreview textConfiguration:(nullable CPTripPreviewTextConfiguration *)textConfiguration;
- (void)hideTripPreviews;
- (void)updateEstimates:(CPTravelEstimates *)estimates forTrip:(CPTrip *)trip;
- (void)updateTravelEstimates:(CPTravelEstimates *)estimates forTrip:(CPTrip *)trip withTimeRemainingColor:(CPTimeRemainingColor)timeRemainingColor;
- (CPNavigationSession *)startNavigationSessionForTrip:(CPTrip *)trip;
- (void)presentNavigationAlert:(CPNavigationAlert *)navigationAlert animated:(BOOL)animated;
- (void)dismissNavigationAlertAnimated:(BOOL)animated completion:(void (^)(BOOL dismissed))completion;
- (void)showPanningInterfaceAnimated:(BOOL)animated;
- (void)dismissPanningInterfaceAnimated:(BOOL)animated;
- (void)showPanel:(CPMapPanel *)panel completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion API_AVAILABLE(ios(26.0));
- (void)pushPanel:(CPMapPanel *)panel completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion API_AVAILABLE(ios(26.0));
- (void)popPanelWithCompletion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion API_AVAILABLE(ios(26.0));
- (void)hidePanelWithCompletion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion API_AVAILABLE(ios(26.0));
@end

/* ---- the session configuration, the scene, the window, the interface controller ---- */
@protocol CPSessionConfigurationDelegate <NSObject>
@optional
- (void)sessionConfiguration:(CPSessionConfiguration *)sessionConfiguration limitedUserInterfacesChanged:(CPLimitableUserInterface)limitedUserInterfaces;
- (void)sessionConfiguration:(CPSessionConfiguration *)sessionConfiguration contentStyleChanged:(CPContentStyle)contentStyle API_AVAILABLE(ios(26.0));
@end
@interface CPSessionConfiguration : NSObject
- (instancetype)initWithDelegate:(id<CPSessionConfigurationDelegate>)delegate;
@property (nullable, nonatomic, weak) id<CPSessionConfigurationDelegate> delegate;
@property (nonatomic, readonly) CPLimitableUserInterface limitedUserInterfaces;
@property (nonatomic, readonly) CPContentStyle contentStyle API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly) BOOL supportsVideoPlayback API_AVAILABLE(ios(26.0));
@end

@interface CPWindow : UIWindow
@property (nullable, nonatomic, weak, readonly) CPTemplateApplicationScene *templateApplicationScene;
@property (nonatomic, readonly) UILayoutGuide *mapButtonSafeAreaLayoutGuide;
@end

@protocol CPInterfaceControllerDelegate <NSObject>
@optional
- (void)templateWillAppear:(CPTemplate *)aTemplate animated:(BOOL)animated;
- (void)templateDidAppear:(CPTemplate *)aTemplate animated:(BOOL)animated;
- (void)templateWillDisappear:(CPTemplate *)aTemplate animated:(BOOL)animated;
- (void)templateDidDisappear:(CPTemplate *)aTemplate animated:(BOOL)animated;
@end
@interface CPInterfaceController : NSObject
@property (nullable, nonatomic, weak) id<CPInterfaceControllerDelegate> delegate;
@property (nonatomic, assign) BOOL prefersDarkUserInterfaceStyle;
@property (nonatomic, readonly) CPTemplate *rootTemplate;
@property (nullable, nonatomic, readonly) CPTemplate *topTemplate;
@property (nonatomic, readonly) NSArray<CPTemplate *> *templates;
@property (nullable, nonatomic, readonly) CPTemplate *presentedTemplate;
@property (nonatomic, readonly) UITraitCollection *carTraitCollection;
- (void)setRootTemplate:(CPTemplate *)rootTemplate animated:(BOOL)animated completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (void)pushTemplate:(CPTemplate *)templateToPush animated:(BOOL)animated completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (void)popTemplateAnimated:(BOOL)animated completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (void)popToRootTemplateAnimated:(BOOL)animated completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (void)popToTemplate:(CPTemplate *)targetTemplate animated:(BOOL)animated completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (void)presentTemplate:(CPTemplate *)templateToPresent animated:(BOOL)animated completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (void)dismissTemplateAnimated:(BOOL)animated completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;
- (void)showOverlayTemplate:(CPTemplate *)templateToShow animated:(BOOL)animated completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion API_AVAILABLE(ios(26.0));
- (void)hideOverlayTemplateAnimated:(BOOL)animated completion:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion API_AVAILABLE(ios(26.0));
- (void)setRootTemplate:(CPTemplate *)rootTemplate animated:(BOOL)animated;
- (void)pushTemplate:(CPTemplate *)templateToPush animated:(BOOL)animated;
- (void)popTemplateAnimated:(BOOL)animated;
- (void)popToRootTemplateAnimated:(BOOL)animated;
- (void)popToTemplate:(CPTemplate *)targetTemplate animated:(BOOL)animated;
- (void)presentTemplate:(CPTemplate *)templateToPresent animated:(BOOL)animated;
- (void)dismissTemplateAnimated:(BOOL)animated;
@end

@protocol CPTemplateApplicationSceneDelegate <UISceneDelegate>
@optional
- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene didConnectInterfaceController:(CPInterfaceController *)interfaceController;
- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene didDisconnectInterfaceController:(CPInterfaceController *)interfaceController;
- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene didConnectInterfaceController:(CPInterfaceController *)interfaceController toWindow:(CPWindow *)window;
- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene didDisconnectInterfaceController:(CPInterfaceController *)interfaceController fromWindow:(CPWindow *)window;
- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene didSelectNavigationAlert:(CPNavigationAlert *)navigationAlert;
- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene didSelectManeuver:(CPManeuver *)maneuver;
- (void)contentStyleDidChange:(UIUserInterfaceStyle)contentStyle;
@end
@interface CPTemplateApplicationScene : UIScene
@property (nullable, nonatomic, strong) id<CPTemplateApplicationSceneDelegate> delegate;
@property (nonatomic, readonly, strong) CPInterfaceController *interfaceController;
@property (nonatomic, readonly, strong) CPWindow *carWindow;
@property (nonatomic, readonly) UIUserInterfaceStyle contentStyle;
@end

@protocol CPApplicationDelegate <UIApplicationDelegate>
- (void)application:(UIApplication *)application didConnectCarInterfaceController:(CPInterfaceController *)interfaceController toWindow:(CPWindow *)window;
- (void)application:(UIApplication *)application didDisconnectCarInterfaceController:(CPInterfaceController *)interfaceController fromWindow:(CPWindow *)window;
@optional
- (void)application:(UIApplication *)application didSelectNavigationAlert:(CPNavigationAlert *)navigationAlert;
- (void)application:(UIApplication *)application didSelectManeuver:(CPManeuver *)maneuver;
@end

/* ---- the dashboard and the instrument cluster ---- */
@interface CPDashboardButton : NSObject <NSSecureCoding>
- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants subtitleVariants:(NSArray<NSString *> *)subtitleVariants image:(UIImage *)image handler:(void (^ _Nullable)(CPDashboardButton *barButton))handler;
@property (nonatomic, readonly, copy) NSArray<NSString *> *titleVariants;
@property (nonatomic, readonly, copy) NSArray<NSString *> *subtitleVariants;
@property (nonatomic, readonly) UIImage *image;
@end
@interface CPDashboardController : NSObject
@property (nonatomic, copy) NSArray<CPDashboardButton *> *shortcutButtons;
@end
@protocol CPTemplateApplicationDashboardSceneDelegate <UISceneDelegate>
@optional
- (void)templateApplicationDashboardScene:(CPTemplateApplicationDashboardScene *)templateApplicationDashboardScene didConnectDashboardController:(CPDashboardController *)dashboardController toWindow:(UIWindow *)window;
- (void)templateApplicationDashboardScene:(CPTemplateApplicationDashboardScene *)templateApplicationDashboardScene didDisconnectDashboardController:(CPDashboardController *)dashboardController fromWindow:(UIWindow *)window;
@end
@interface CPTemplateApplicationDashboardScene : UIScene
@property (nullable, nonatomic, strong) id<CPTemplateApplicationDashboardSceneDelegate> delegate;
@property (nonatomic, readonly, strong) CPDashboardController *dashboardController;
@property (nonatomic, readonly, strong) UIWindow *dashboardWindow;
@end

@protocol CPInstrumentClusterControllerDelegate <NSObject>
- (void)instrumentClusterControllerDidConnectWindow:(UIWindow *)instrumentClusterWindow;
- (void)instrumentClusterControllerDidDisconnectWindow:(UIWindow *)instrumentClusterWindow;
@optional
- (void)instrumentClusterControllerDidZoomIn:(CPInstrumentClusterController *)instrumentClusterController;
- (void)instrumentClusterControllerDidZoomOut:(CPInstrumentClusterController *)instrumentClusterController;
- (void)instrumentClusterController:(CPInstrumentClusterController *)instrumentClusterController didChangeCompassSetting:(CPInstrumentClusterSetting)compassSetting;
- (void)instrumentClusterController:(CPInstrumentClusterController *)instrumentClusterController didChangeSpeedLimitSetting:(CPInstrumentClusterSetting)speedLimitSetting;
@end
@interface CPInstrumentClusterController : NSObject
@property (nullable, nonatomic, weak) id<CPInstrumentClusterControllerDelegate> delegate;
@property (nullable, nonatomic, readonly, strong) UIWindow *instrumentClusterWindow;
@property (nonatomic, readonly) CPInstrumentClusterSetting speedLimitSetting;
@property (nonatomic, readonly) CPInstrumentClusterSetting compassSetting;
@property (nonatomic, copy) NSArray<NSString *> *inactiveDescriptionVariants;
@property (nonatomic, copy) NSArray<NSAttributedString *> *attributedInactiveDescriptionVariants;
@end
@protocol CPTemplateApplicationInstrumentClusterSceneDelegate <UISceneDelegate>
@optional
- (void)templateApplicationInstrumentClusterScene:(CPTemplateApplicationInstrumentClusterScene *)templateApplicationInstrumentClusterScene didConnectInstrumentClusterController:(CPInstrumentClusterController *)instrumentClusterController;
- (void)templateApplicationInstrumentClusterScene:(CPTemplateApplicationInstrumentClusterScene *)templateApplicationInstrumentClusterScene didDisconnectInstrumentClusterController:(CPInstrumentClusterController *)instrumentClusterController;
- (void)contentStyleDidChange:(UIUserInterfaceStyle)contentStyle;
@end
@interface CPTemplateApplicationInstrumentClusterScene : UIScene
@property (nullable, nonatomic, strong) id<CPTemplateApplicationInstrumentClusterSceneDelegate> delegate;
@property (nonatomic, readonly, strong) CPInstrumentClusterController *instrumentClusterController;
@property (nonatomic, readonly) UIUserInterfaceStyle contentStyle;
@end
#endif /* !__swift__ */

NS_ASSUME_NONNULL_END
