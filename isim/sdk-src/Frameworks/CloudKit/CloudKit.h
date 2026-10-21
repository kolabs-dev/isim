#pragma once
/* isim CloudKit for Objective-C: the classes are the CloudKit Swift overlay's (CloudKit.framework re-exports
 * libswiftCloudKit.dylib), a LOCAL CloudKit: no iCloud, no sync, no Apple servers. Containers, databases, records,
 * zones, queries, operations, subscriptions, shares and change tokens behave like CloudKit's against a store in the
 * device data, so an app's logic (conflicts, paging, change fetching) runs and can be tested. Swift uses the overlay;
 * these declarations are hidden from Swift. The classes are not subclassable from Objective-C, and CKOperation is not an
 * NSOperation (add operations to a container or database). */
#import <CloudKit/CKDefines.h>
#import <CloudKit/CKError.h>
#import <CloudKit/CKRecord.h>
#import <CloudKit/CKQuery.h>
#import <CloudKit/CKContainer.h>
#import <CloudKit/CKOperation.h>
#import <CloudKit/CKSubscription.h>
#import <CloudKit/CKShare.h>
#import <CloudKit/CKSyncEngine.h>
