#pragma once
/* isim SceneKit: SCNGeometry, its sources (per-vertex data) and elements (how vertices are joined) (issue #330). */
#import <SceneKit/SceneKitTypes.h>
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class SCNMaterial, SCNGeometrySource, SCNGeometryElement;
typedef NSString *SCNGeometrySourceSemantic NS_TYPED_ENUM;
SCN_EXPORT SCNGeometrySourceSemantic const SCNGeometrySourceSemanticVertex;
SCN_EXPORT SCNGeometrySourceSemantic const SCNGeometrySourceSemanticNormal;
SCN_EXPORT SCNGeometrySourceSemantic const SCNGeometrySourceSemanticColor;
SCN_EXPORT SCNGeometrySourceSemantic const SCNGeometrySourceSemanticTexcoord;
SCN_EXPORT SCNGeometrySourceSemantic const SCNGeometrySourceSemanticTangent;
SCN_EXPORT SCNGeometrySourceSemantic const SCNGeometrySourceSemanticVertexCrease;
SCN_EXPORT SCNGeometrySourceSemantic const SCNGeometrySourceSemanticEdgeCrease;
SCN_EXPORT SCNGeometrySourceSemantic const SCNGeometrySourceSemanticBoneWeights;
SCN_EXPORT SCNGeometrySourceSemantic const SCNGeometrySourceSemanticBoneIndices;
typedef NS_ENUM(NSInteger, SCNGeometryPrimitiveType) {
    SCNGeometryPrimitiveTypeTriangles = 0, SCNGeometryPrimitiveTypeTriangleStrip = 1, SCNGeometryPrimitiveTypeLine = 2,
    SCNGeometryPrimitiveTypePoint = 3, SCNGeometryPrimitiveTypePolygon = 4
};
@protocol SCNBoundingVolume <NSObject>
- (BOOL)getBoundingBoxMin:(nullable SCNVector3 *)min max:(nullable SCNVector3 *)max;
- (void)setBoundingBoxMin:(nullable SCNVector3 *)min max:(nullable SCNVector3 *)max;
@end

@interface SCNGeometry : NSObject <NSCopying, NSSecureCoding, SCNBoundingVolume>
+ (instancetype)geometry;
+ (instancetype)geometryWithSources:(NSArray<SCNGeometrySource *> *)sources elements:(nullable NSArray<SCNGeometryElement *> *)elements;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, copy) NSArray<SCNMaterial *> *materials;
@property (nonatomic, retain, nullable) SCNMaterial *firstMaterial;
@property (nonatomic, readonly) NSArray<SCNGeometrySource *> *geometrySources;
@property (nonatomic, readonly) NSArray<SCNGeometryElement *> *geometryElements;
@property (nonatomic, readonly) NSInteger geometryElementCount;
@property (nonatomic) NSUInteger subdivisionLevel;
- (nullable SCNMaterial *)materialWithName:(NSString *)name;
- (void)insertMaterial:(SCNMaterial *)material atIndex:(NSUInteger)index;
- (void)removeMaterialAtIndex:(NSUInteger)index;
- (void)replaceMaterialAtIndex:(NSUInteger)index withMaterial:(SCNMaterial *)material;
- (NSArray<SCNGeometrySource *> *)geometrySourcesForSemantic:(SCNGeometrySourceSemantic)semantic;
- (SCNGeometryElement *)geometryElementAtIndex:(NSInteger)elementIndex;
@end

@interface SCNGeometrySource : NSObject <NSSecureCoding>
+ (instancetype)geometrySourceWithData:(NSData *)data semantic:(SCNGeometrySourceSemantic)semantic vectorCount:(NSInteger)vectorCount
                       floatComponents:(BOOL)floatComponents componentsPerVector:(NSInteger)componentsPerVector
                     bytesPerComponent:(NSInteger)bytesPerComponent dataOffset:(NSInteger)offset dataStride:(NSInteger)stride;
+ (instancetype)geometrySourceWithVertices:(const SCNVector3 *)vertices count:(NSInteger)count;
+ (instancetype)geometrySourceWithNormals:(const SCNVector3 *)normals count:(NSInteger)count;
+ (instancetype)geometrySourceWithTextureCoordinates:(const CGPoint *)texcoord count:(NSInteger)count;
@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) SCNGeometrySourceSemantic semantic;
@property (nonatomic, readonly) NSInteger vectorCount;
@property (nonatomic, readonly) BOOL floatComponents;
@property (nonatomic, readonly) NSInteger componentsPerVector;
@property (nonatomic, readonly) NSInteger bytesPerComponent;
@property (nonatomic, readonly) NSInteger dataOffset;
@property (nonatomic, readonly) NSInteger dataStride;
@end

@interface SCNGeometryElement : NSObject <NSSecureCoding>
+ (instancetype)geometryElementWithData:(nullable NSData *)data primitiveType:(SCNGeometryPrimitiveType)primitiveType
                         primitiveCount:(NSInteger)primitiveCount bytesPerIndex:(NSInteger)bytesPerIndex;
@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) SCNGeometryPrimitiveType primitiveType;
@property (nonatomic, readonly) NSInteger primitiveCount;
@property (nonatomic, readonly) NSInteger bytesPerIndex;
@property (nonatomic) NSRange primitiveRange;
@property (nonatomic) CGFloat pointSize;
@property (nonatomic) CGFloat minimumPointScreenSpaceRadius;
@property (nonatomic) CGFloat maximumPointScreenSpaceRadius;
@end
NS_ASSUME_NONNULL_END
#endif
