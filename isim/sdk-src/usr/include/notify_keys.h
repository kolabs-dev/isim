#pragma once
/* isim SDK (Apple's values): the names of the system's Darwin notifications (isim's system does not post them yet;
 * apps can register for them and post them). */
#define kNotifyASLDBUpdate "com.apple.system.logdb"
#define kNotifyClockSet "com.apple.system.clock_set"
#define kNotifyDSCacheInvalidation "com.apple.system.DirectoryService.InvalidateCache"
#define kNotifyDSCacheInvalidationGroup "com.apple.system.DirectoryService.InvalidateCache.group"
#define kNotifyDSCacheInvalidationHost "com.apple.system.DirectoryService.InvalidateCache.host"
#define kNotifyDSCacheInvalidationService "com.apple.system.DirectoryService.InvalidateCache.service"
#define kNotifyDSCacheInvalidationUser "com.apple.system.DirectoryService.InvalidateCache.user"
#define kNotifySCHostNameChange "com.apple.system.hostname"
#define kNotifySCNetworkChange "com.apple.system.config.network_change"
#define kNotifyTimeZoneChange "com.apple.system.timezone"
#define kNotifyVFSLowDiskSpace "com.apple.system.lowdiskspace"
#define kNotifyVFSLowDiskSpaceOtherFS "com.apple.system.lowdiskspace.user"
#define kNotifyVFSLowDiskSpaceRootFS "com.apple.system.lowdiskspace.system"
#define kNotifyVFSMount "com.apple.system.kernel.mount"
#define kNotifyVFSUnmount "com.apple.system.kernel.unmount"
#define kNotifyVFSUpdate "com.apple.system.kernel.mountupdate"
