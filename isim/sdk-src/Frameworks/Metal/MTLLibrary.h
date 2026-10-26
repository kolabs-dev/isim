#pragma once
#import <Metal/MTLDefines.h>
#import <Metal/MTLArgument.h>
#import <Metal/MTLFunctionConstantValues.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLDevice;
typedef NS_ENUM(NSUInteger, MTLFunctionType) {
    MTLFunctionTypeVertex = 1, MTLFunctionTypeFragment = 2, MTLFunctionTypeKernel = 3, MTLFunctionTypeVisible = 5,
    MTLFunctionTypeIntersection = 6, MTLFunctionTypeMesh = 7, MTLFunctionTypeObject = 8,
};
typedef NS_ENUM(NSUInteger, MTLLanguageVersion) {
    MTLLanguageVersion1_0 NS_SWIFT_NAME(version1_0) = (1 << 16), MTLLanguageVersion1_1 NS_SWIFT_NAME(version1_1) = (1 << 16) + 1,
    MTLLanguageVersion1_2 NS_SWIFT_NAME(version1_2) = (1 << 16) + 2,
    MTLLanguageVersion2_0 NS_SWIFT_NAME(version2_0) = (2 << 16), MTLLanguageVersion2_1 NS_SWIFT_NAME(version2_1) = (2 << 16) + 1,
    MTLLanguageVersion2_2 NS_SWIFT_NAME(version2_2) = (2 << 16) + 2, MTLLanguageVersion2_3 NS_SWIFT_NAME(version2_3) = (2 << 16) + 3,
    MTLLanguageVersion2_4 NS_SWIFT_NAME(version2_4) = (2 << 16) + 4,
    MTLLanguageVersion3_0 NS_SWIFT_NAME(version3_0) = (3 << 16), MTLLanguageVersion3_1 NS_SWIFT_NAME(version3_1) = (3 << 16) + 1,
    MTLLanguageVersion3_2 NS_SWIFT_NAME(version3_2) = (3 << 16) + 2,
};
typedef NS_ENUM(NSInteger, MTLLibraryType) { MTLLibraryTypeExecutable = 0, MTLLibraryTypeDynamic = 1 };
typedef NS_ENUM(NSInteger, MTLLibraryOptimizationLevel) { MTLLibraryOptimizationLevelDefault = 0, MTLLibraryOptimizationLevelSize = 1 };
typedef NS_ENUM(NSInteger, MTLMathMode) { MTLMathModeSafe = 0, MTLMathModeRelaxed = 1, MTLMathModeFast = 2 };
typedef NS_ENUM(NSInteger, MTLMathFloatingPointFunctions) { MTLMathFloatingPointFunctionsFast = 0, MTLMathFloatingPointFunctionsPrecise = 1 };
typedef NS_OPTIONS(NSUInteger, MTLFunctionOptions) { MTLFunctionOptionNone = 0, MTLFunctionOptionCompileToBinary = 1 };

MTL_EXTERN NSErrorDomain const MTLLibraryErrorDomain;
#if !defined(__swift__)   /* Swift: the MTLLibraryError struct of the Metal overlay */
typedef MTL_ERROR_ENUM(NSUInteger, MTLLibraryError, MTLLibraryErrorDomain) {
    MTLLibraryErrorUnsupported = 1, MTLLibraryErrorInternal = 2, MTLLibraryErrorCompileFailure = 3, MTLLibraryErrorCompileWarning = 4,
    MTLLibraryErrorFunctionNotFound = 5, MTLLibraryErrorFileNotFound = 6,
};
#endif

/* a [[function_constant(n)]] declaration */
@interface MTLFunctionConstant : NSObject
@property (readonly) NSString *name;
@property (readonly) MTLDataType type;
@property (readonly) NSUInteger index;
@property (readonly) BOOL required;
@end

@interface MTLCompileOptions : NSObject <NSCopying>
@property (nullable, readwrite, copy, nonatomic) NSDictionary<NSString *, NSObject *> *preprocessorMacros;
@property (readwrite, nonatomic) BOOL fastMathEnabled;
@property (readwrite, nonatomic) MTLMathMode mathMode;
@property (readwrite, nonatomic) MTLMathFloatingPointFunctions mathFloatingPointFunctions;
@property (readwrite, nonatomic) MTLLanguageVersion languageVersion;
@property (readwrite, nonatomic) MTLLibraryType libraryType;
@property (nullable, readwrite, copy, nonatomic) NSString *installName;
@property (readwrite, nonatomic) BOOL preserveInvariance;
@property (readwrite, nonatomic) MTLLibraryOptimizationLevel optimizationLevel;
@property (readwrite, nonatomic) BOOL enableLogging;
@end

@interface MTLFunctionDescriptor : NSObject <NSCopying>
+ (MTLFunctionDescriptor *)functionDescriptor;
@property (nullable, copy, nonatomic) NSString *name;
@property (nullable, copy, nonatomic) NSString *specializedName;
@property (nullable, copy, nonatomic) MTLFunctionConstantValues *constantValues;
@property (nonatomic) MTLFunctionOptions options;
@end

@protocol MTLFunction <NSObject>
@property (nullable, copy, atomic) NSString *label;
@property (readonly) id<MTLDevice> device;
@property (readonly) MTLFunctionType functionType;
@property (readonly) NSString *name;
@property (readonly) NSDictionary<NSString *, MTLFunctionConstant *> *functionConstantsDictionary;
@property (readonly) MTLFunctionOptions options;
@end

@protocol MTLLibrary <NSObject>
@property (nullable, copy, atomic) NSString *label;
@property (readonly) id<MTLDevice> device;
@property (readonly) NSArray<NSString *> *functionNames;
@property (readonly) MTLLibraryType type;
@property (readonly, nullable) NSString *installName;
- (nullable id<MTLFunction>)newFunctionWithName:(NSString *)functionName NS_SWIFT_NAME(makeFunction(name:));
- (nullable id<MTLFunction>)newFunctionWithName:(NSString *)name constantValues:(MTLFunctionConstantValues *)constantValues error:(NSError **)error
    NS_SWIFT_NAME(makeFunction(name:constantValues:));
- (void)newFunctionWithName:(NSString *)name constantValues:(MTLFunctionConstantValues *)constantValues
          completionHandler:(void (^)(id<MTLFunction> _Nullable function, NSError * _Nullable error))completionHandler
    NS_SWIFT_NAME(makeFunction(name:constantValues:completionHandler:));
- (nullable id<MTLFunction>)newFunctionWithDescriptor:(MTLFunctionDescriptor *)descriptor error:(NSError **)error
    NS_SWIFT_NAME(makeFunction(descriptor:));
@end
NS_ASSUME_NONNULL_END
