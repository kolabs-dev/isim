#pragma once
#import <UniformTypeIdentifiers/UTDefines.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* the kinds of tag a type has: filename extensions and MIME types */
UT_EXPORT NSString *const UTTagClassFilenameExtension API_AVAILABLE(ios(14.0));
UT_EXPORT NSString *const UTTagClassMIMEType API_AVAILABLE(ios(14.0));
NS_ASSUME_NONNULL_END
#endif
