#pragma once
/* isim CloudKit: the CKSyncEngine enums for Objective-C. CKSyncEngine itself is Swift-only on isim (its Objective-C
 * classes are not implemented). The raw values follow the order of Apple's cases (proposed). */
#import <CloudKit/CKDefines.h>
#if !defined(__swift__)
typedef NS_ENUM(NSInteger, CKSyncEngineEventType) {
    CKSyncEngineEventTypeStateUpdate = 0, CKSyncEngineEventTypeAccountChange, CKSyncEngineEventTypeFetchedDatabaseChanges,
    CKSyncEngineEventTypeFetchedRecordZoneChanges, CKSyncEngineEventTypeSentDatabaseChanges, CKSyncEngineEventTypeSentRecordZoneChanges,
    CKSyncEngineEventTypeWillFetchChanges, CKSyncEngineEventTypeWillFetchRecordZoneChanges, CKSyncEngineEventTypeDidFetchRecordZoneChanges,
    CKSyncEngineEventTypeDidFetchChanges, CKSyncEngineEventTypeWillSendChanges, CKSyncEngineEventTypeDidSendChanges
};
typedef NS_ENUM(NSInteger, CKSyncEngineAccountChangeType) {
    CKSyncEngineAccountChangeTypeSignIn = 0, CKSyncEngineAccountChangeTypeSignOut, CKSyncEngineAccountChangeTypeSwitchAccounts
};
typedef NS_ENUM(NSInteger, CKSyncEngineZoneDeletionReason) {
    CKSyncEngineZoneDeletionReasonDeleted = 0, CKSyncEngineZoneDeletionReasonPurged, CKSyncEngineZoneDeletionReasonEncryptedDataReset
};
typedef NS_ENUM(NSInteger, CKSyncEngineSyncReason) { CKSyncEngineSyncReasonScheduled = 0, CKSyncEngineSyncReasonManual };
typedef NS_ENUM(NSInteger, CKSyncEnginePendingRecordZoneChangeType) {
    CKSyncEnginePendingRecordZoneChangeTypeSaveRecord = 0, CKSyncEnginePendingRecordZoneChangeTypeDeleteRecord
};
typedef NS_ENUM(NSInteger, CKSyncEnginePendingDatabaseChangeType) {
    CKSyncEnginePendingDatabaseChangeTypeSaveZone = 0, CKSyncEnginePendingDatabaseChangeTypeDeleteZone
};
#endif
