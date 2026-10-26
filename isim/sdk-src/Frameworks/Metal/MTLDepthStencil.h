#pragma once
#import <Metal/MTLDefines.h>
#import <Metal/MTLTypes.h>
typedef NS_ENUM(NSUInteger, MTLCompareFunction) {
    MTLCompareFunctionNever = 0, MTLCompareFunctionLess = 1, MTLCompareFunctionEqual = 2, MTLCompareFunctionLessEqual = 3,
    MTLCompareFunctionGreater = 4, MTLCompareFunctionNotEqual = 5, MTLCompareFunctionGreaterEqual = 6, MTLCompareFunctionAlways = 7,
};
