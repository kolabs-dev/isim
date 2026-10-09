#pragma once
#import <Foundation/NSObjCRuntime.h>
/* NSCocoaErrorDomain error codes (file and property-list errors) */
enum : NSInteger {
    NSFileNoSuchFileError = 4, NSFileLockingError = 255,
    NSFileReadUnknownError = 256, NSFileReadNoPermissionError = 257, NSFileReadInvalidFileNameError = 258,
    NSFileReadCorruptFileError = 259, NSFileReadNoSuchFileError = 260, NSFileReadInapplicableStringEncodingError = 261,
    NSFileReadUnsupportedSchemeError = 262, NSFileReadTooLargeError = 263, NSFileReadUnknownStringEncodingError = 264,
    NSFileWriteUnknownError = 512, NSFileWriteNoPermissionError = 513, NSFileWriteInvalidFileNameError = 514,
    NSFileWriteFileExistsError = 516, NSFileWriteInapplicableStringEncodingError = 517, NSFileWriteUnsupportedSchemeError = 518,
    NSFileWriteOutOfSpaceError = 640, NSFileWriteVolumeReadOnlyError = 642,
    NSFileManagerUnmountUnknownError = 768, NSFileManagerUnmountBusyError = 769,
    NSKeyValueValidationError = 1024, NSFormattingError = 2048, NSUserCancelledError = 3072, NSFeatureUnsupportedError = 3328,
    NSFileErrorMinimum = 0, NSFileErrorMaximum = 1023,
    NSPropertyListReadCorruptError = 3840, NSPropertyListReadUnknownVersionError = 3841, NSPropertyListReadStreamError = 3842,
    NSPropertyListWriteStreamError = 3851, NSPropertyListWriteInvalidError = 3852,
    NSPropertyListErrorMinimum = 3840, NSPropertyListErrorMaximum = 4095,
};
