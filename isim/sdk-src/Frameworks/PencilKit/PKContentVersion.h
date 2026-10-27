#pragma once
#import <Foundation/Foundation.h>
#define PENCILKIT_EXTERN extern __attribute__((visibility("default")))
NS_ASSUME_NONNULL_BEGIN
/* the PencilKit features a drawing, stroke or tool needs (newer inks need newer versions) */
typedef NS_ENUM(NSInteger, PKContentVersion) {
    PKContentVersion1 = 1,
    PKContentVersion2 = 2,
    PKContentVersion3 = 3,
    PKContentVersion4 = 4,
    PKContentVersion5 = 5,
    PKContentVersionLatest = PKContentVersion5
} API_AVAILABLE(ios(17.0));
NS_ASSUME_NONNULL_END
