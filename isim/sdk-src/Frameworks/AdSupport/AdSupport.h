#pragma once
/* isim AdSupport for Objective-C: the class is the AdSupport Swift overlay's (AdSupport.framework re-exports
   libswiftAdSupport.dylib). Swift uses the overlay; this header is hidden from Swift. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
#import <AdSupport/ASIdentifierManager.h>
#else
@class ASIdentifierManager;
#endif
