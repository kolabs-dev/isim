#pragma once
/* isim: the forward declaration of CloudKit's CKShareMetadata that UIKit's headers use (UIApplicationDelegate's and
 * UIWindowSceneDelegate's userDidAcceptCloudKitShareWithMetadata:, UISceneConnectionOptions.cloudKitShareMetadata).
 * Swift resolves a forward-declared class only to a top-level class of the overlay of the Clang module that declares it:
 * this module's overlay (_CKShareMetadata.swiftmodule), which CloudKit names CKShare.Metadata. Objective-C apps get
 * the full interface from <CloudKit/CKShare.h>. */
#ifdef __OBJC__
@class CKShareMetadata;
#endif
