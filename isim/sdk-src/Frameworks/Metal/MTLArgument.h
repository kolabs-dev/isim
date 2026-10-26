#pragma once
#import <Metal/MTLDefines.h>
typedef NS_ENUM(NSUInteger, MTLDataType) {
    MTLDataTypeNone = 0, MTLDataTypeStruct = 1, MTLDataTypeArray = 2,
    MTLDataTypeFloat = 3, MTLDataTypeFloat2 = 4, MTLDataTypeFloat3 = 5, MTLDataTypeFloat4 = 6,
    MTLDataTypeFloat2x2 = 7, MTLDataTypeFloat2x3 = 8, MTLDataTypeFloat2x4 = 9, MTLDataTypeFloat3x2 = 10, MTLDataTypeFloat3x3 = 11,
    MTLDataTypeFloat3x4 = 12, MTLDataTypeFloat4x2 = 13, MTLDataTypeFloat4x3 = 14, MTLDataTypeFloat4x4 = 15,
    MTLDataTypeHalf = 16, MTLDataTypeHalf2 = 17, MTLDataTypeHalf3 = 18, MTLDataTypeHalf4 = 19,
    MTLDataTypeHalf2x2 = 20, MTLDataTypeHalf2x3 = 21, MTLDataTypeHalf2x4 = 22, MTLDataTypeHalf3x2 = 23, MTLDataTypeHalf3x3 = 24,
    MTLDataTypeHalf3x4 = 25, MTLDataTypeHalf4x2 = 26, MTLDataTypeHalf4x3 = 27, MTLDataTypeHalf4x4 = 28,
    MTLDataTypeInt = 29, MTLDataTypeInt2 = 30, MTLDataTypeInt3 = 31, MTLDataTypeInt4 = 32,
    MTLDataTypeUInt = 33, MTLDataTypeUInt2 = 34, MTLDataTypeUInt3 = 35, MTLDataTypeUInt4 = 36,
    MTLDataTypeShort = 37, MTLDataTypeShort2 = 38, MTLDataTypeShort3 = 39, MTLDataTypeShort4 = 40,
    MTLDataTypeUShort = 41, MTLDataTypeUShort2 = 42, MTLDataTypeUShort3 = 43, MTLDataTypeUShort4 = 44,
    MTLDataTypeChar = 45, MTLDataTypeChar2 = 46, MTLDataTypeChar3 = 47, MTLDataTypeChar4 = 48,
    MTLDataTypeUChar = 49, MTLDataTypeUChar2 = 50, MTLDataTypeUChar3 = 51, MTLDataTypeUChar4 = 52,
    MTLDataTypeBool = 53, MTLDataTypeBool2 = 54, MTLDataTypeBool3 = 55, MTLDataTypeBool4 = 56,
    MTLDataTypeTexture = 58, MTLDataTypeSampler = 59, MTLDataTypePointer = 60,
    MTLDataTypeLong = 81, MTLDataTypeLong2 = 82, MTLDataTypeLong3 = 83, MTLDataTypeLong4 = 84,
    MTLDataTypeULong = 85, MTLDataTypeULong2 = 86, MTLDataTypeULong3 = 87, MTLDataTypeULong4 = 88,
};
typedef NS_ENUM(NSUInteger, MTLBindingAccess) { MTLBindingAccessReadOnly = 0, MTLBindingAccessReadWrite = 1, MTLBindingAccessWriteOnly = 2 };
