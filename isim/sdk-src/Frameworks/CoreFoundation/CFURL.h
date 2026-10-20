#pragma once
/* isim SDK (self-authored, Apple's declarations and values): CFURL, toll-free bridged with NSURL (CFURLRef is the
 * NSURL), implemented over Foundation's NSURL. */
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFData.h>
#include <CoreFoundation/CFString.h>

__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
/* Boolean parameters and results are C bool here (the same one-byte ABI) so Swift sees Bool, as with Apple's SDK (#523) */

typedef CF_ENUM(CFIndex, CFURLPathStyle) {
    kCFURLPOSIXPathStyle = 0,
    kCFURLHFSPathStyle = 1,
    kCFURLWindowsPathStyle = 2
};

CF_EXPORT CFTypeID CFURLGetTypeID(void);
CF_EXPORT CFURLRef CFURLCreateWithString(CFAllocatorRef allocator, CFStringRef URLString, CFURLRef baseURL);
CF_EXPORT CFURLRef CFURLCreateWithBytes(CFAllocatorRef allocator, const UInt8 *URLBytes, CFIndex length, CFStringEncoding encoding, CFURLRef baseURL);
CF_EXPORT CFURLRef CFURLCreateAbsoluteURLWithBytes(CFAllocatorRef alloc, const UInt8 *relativeURLBytes, CFIndex length, CFStringEncoding encoding,
                                                   CFURLRef baseURL, bool useCompatibilityMode);
CF_EXPORT CFURLRef CFURLCreateWithFileSystemPath(CFAllocatorRef allocator, CFStringRef filePath, CFURLPathStyle pathStyle, bool isDirectory);
CF_EXPORT CFURLRef CFURLCreateWithFileSystemPathRelativeToBase(CFAllocatorRef allocator, CFStringRef filePath, CFURLPathStyle pathStyle,
                                                               bool isDirectory, CFURLRef baseURL);
CF_EXPORT CFURLRef CFURLCreateFromFileSystemRepresentation(CFAllocatorRef allocator, const UInt8 *buffer, CFIndex bufLen, bool isDirectory);
CF_EXPORT bool CFURLGetFileSystemRepresentation(CFURLRef url, bool resolveAgainstBase, UInt8 *buffer, CFIndex maxBufLen);
CF_EXPORT CFDataRef CFURLCreateData(CFAllocatorRef allocator, CFURLRef url, CFStringEncoding encoding, bool escapeWhitespace);
CF_EXPORT CFURLRef CFURLCopyAbsoluteURL(CFURLRef relativeURL);
CF_EXPORT CFStringRef CFURLGetString(CFURLRef anURL);
CF_EXPORT CFURLRef CFURLGetBaseURL(CFURLRef anURL);
CF_EXPORT bool CFURLCanBeDecomposed(CFURLRef anURL);
CF_EXPORT CFStringRef CFURLCopyScheme(CFURLRef anURL);
CF_EXPORT CFStringRef CFURLCopyNetLocation(CFURLRef anURL);
CF_EXPORT CFStringRef CFURLCopyPath(CFURLRef anURL);
CF_EXPORT CFStringRef CFURLCopyStrictPath(CFURLRef anURL, bool *isAbsolute);
CF_EXPORT CFStringRef CFURLCopyFileSystemPath(CFURLRef anURL, CFURLPathStyle pathStyle);
CF_EXPORT bool CFURLHasDirectoryPath(CFURLRef anURL);
CF_EXPORT CFStringRef CFURLCopyResourceSpecifier(CFURLRef anURL);
CF_EXPORT CFStringRef CFURLCopyHostName(CFURLRef anURL);
CF_EXPORT SInt32 CFURLGetPortNumber(CFURLRef anURL);
CF_EXPORT CFStringRef CFURLCopyUserName(CFURLRef anURL);
CF_EXPORT CFStringRef CFURLCopyPassword(CFURLRef anURL);
CF_EXPORT CFStringRef CFURLCopyQueryString(CFURLRef anURL, CFStringRef charactersToLeaveEscaped);
CF_EXPORT CFStringRef CFURLCopyFragment(CFURLRef anURL, CFStringRef charactersToLeaveEscaped);
CF_EXPORT CFStringRef CFURLCopyLastPathComponent(CFURLRef url);
CF_EXPORT CFStringRef CFURLCopyPathExtension(CFURLRef url);
CF_EXPORT CFURLRef CFURLCreateCopyAppendingPathComponent(CFAllocatorRef allocator, CFURLRef url, CFStringRef pathComponent, bool isDirectory);
CF_EXPORT CFURLRef CFURLCreateCopyDeletingLastPathComponent(CFAllocatorRef allocator, CFURLRef url);
CF_EXPORT CFURLRef CFURLCreateCopyAppendingPathExtension(CFAllocatorRef allocator, CFURLRef url, CFStringRef extension);
CF_EXPORT CFURLRef CFURLCreateCopyDeletingPathExtension(CFAllocatorRef allocator, CFURLRef url);
CF_EXPORT CFStringRef CFURLCreateStringByReplacingPercentEscapes(CFAllocatorRef allocator, CFStringRef originalString, CFStringRef charactersToLeaveEscaped);
CF_EXPORT bool CFURLResourceIsReachable(CFURLRef resourceURL, CFErrorRef *error);
CF_EXPORT CFURLRef CFURLCreateFilePathURL(CFAllocatorRef allocator, CFURLRef url, CFErrorRef *error);
CF_EXPORT CFURLRef CFURLCreateFileReferenceURL(CFAllocatorRef allocator, CFURLRef url, CFErrorRef *error);

#pragma clang arc_cf_code_audited end
__END_DECLS
