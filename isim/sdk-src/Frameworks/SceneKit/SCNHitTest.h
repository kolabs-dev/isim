#pragma once
/* isim SceneKit: hit testing (issue #330): rays and segments against geometry's triangles. */
#import <SceneKit/SceneKitTypes.h>
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class SCNNode;
typedef NSString *SCNHitTestOption NS_TYPED_ENUM;
SCN_EXPORT SCNHitTestOption const SCNHitTestFirstFoundOnlyKey;
SCN_EXPORT SCNHitTestOption const SCNHitTestSortResultsKey;
SCN_EXPORT SCNHitTestOption const SCNHitTestClipToZRangeKey;
SCN_EXPORT SCNHitTestOption const SCNHitTestBackFaceCullingKey;
SCN_EXPORT SCNHitTestOption const SCNHitTestBoundingBoxOnlyKey;
SCN_EXPORT SCNHitTestOption const SCNHitTestIgnoreChildNodesKey;
SCN_EXPORT SCNHitTestOption const SCNHitTestRootNodeKey;
SCN_EXPORT SCNHitTestOption const SCNHitTestIgnoreHiddenNodesKey;
SCN_EXPORT SCNHitTestOption const SCNHitTestOptionCategoryBitMask;
SCN_EXPORT SCNHitTestOption const SCNHitTestOptionSearchMode;
typedef NS_ENUM(NSInteger, SCNHitTestSearchMode) { SCNHitTestSearchModeClosest = 0, SCNHitTestSearchModeAll = 1, SCNHitTestSearchModeAny = 2 };
@interface SCNHitTestResult : NSObject
@property (nonatomic, readonly) SCNNode *node;
@property (nonatomic, readonly) NSInteger geometryIndex, faceIndex;
@property (nonatomic, readonly) SCNVector3 localCoordinates, worldCoordinates, localNormal, worldNormal;
@property (nonatomic, readonly) SCNMatrix4 modelTransform;
@property (nonatomic, readonly, nullable) SCNNode *boneNode;
- (CGPoint)textureCoordinatesWithMappingChannel:(NSInteger)channel;
@end
NS_ASSUME_NONNULL_END
#endif
