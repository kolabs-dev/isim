#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSData, NSError;
typedef NS_OPTIONS(NSUInteger, NSPropertyListMutabilityOptions) {
    NSPropertyListImmutable NS_SWIFT_NAME(immutable) = 0, NSPropertyListMutableContainers NS_SWIFT_NAME(mutableContainers) = 1,
    NSPropertyListMutableContainersAndLeaves NS_SWIFT_NAME(mutableContainersAndLeaves) = 2
} NS_SWIFT_NAME(PropertyListSerialization.MutabilityOptions);
typedef NS_ENUM(NSUInteger, NSPropertyListFormat) {
    NSPropertyListOpenStepFormat NS_SWIFT_NAME(openStep) = 1, NSPropertyListXMLFormat_v1_0 NS_SWIFT_NAME(xml) = 100,
    NSPropertyListBinaryFormat_v1_0 NS_SWIFT_NAME(binary) = 200
} NS_SWIFT_NAME(PropertyListSerialization.PropertyListFormat);
typedef NSPropertyListMutabilityOptions NSPropertyListReadOptions NS_SWIFT_NAME(PropertyListSerialization.ReadOptions);
typedef NSUInteger NSPropertyListWriteOptions NS_SWIFT_NAME(PropertyListSerialization.WriteOptions);
/* isim: XML and binary (bplist00) read/write; OpenStep (ASCII) read only, like Apple */
@interface NSPropertyListSerialization : NSObject
+ (BOOL)propertyList:(id)plist isValidForFormat:(NSPropertyListFormat)format;
+ (nullable NSData *)dataWithPropertyList:(id)plist format:(NSPropertyListFormat)format options:(NSPropertyListWriteOptions)opt error:(out NSError **)error NS_SWIFT_NAME(data(fromPropertyList:format:options:));
+ (nullable id)propertyListWithData:(NSData *)data options:(NSPropertyListReadOptions)opt format:(nullable NSPropertyListFormat *)format error:(out NSError **)error NS_SWIFT_NAME(propertyList(from:options:format:));
@end
NS_ASSUME_NONNULL_END
