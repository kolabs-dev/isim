/* isim Foundation (ARC): NSURL resource values (getResourceValue:, resourceValuesForKeys:, setResourceValue:,
 * temporary values) and the per-file metadata store behind the values Linux cannot keep (isExcludedFromBackup,
 * isHidden, creation date, file protection; iCloud download state).
 * Adapted: file values come from lstat (a symbolic link's own values, like iOS) and access(2); volume values from
 * the statvfs of the file system holding the device data, described as iOS's data volume (APFS, case-sensitive,
 * encrypted, internal); content types from UniformTypeIdentifiers (a built-in table when it is not loaded); iCloud
 * values from the local ubiquity simulation (Ubiquity.m). Values are not cached between calls (iOS drops its cache
 * every run loop pass), so prefetching (includingPropertiesForKeys:) has nothing to keep. */
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>
#include <isim_host.h>
#include <objc/runtime.h>
#include "isim_foundation.h"

BOOL isim_is_package_path(NSString *path);

NSURLResourceKey const NSURLNameKey = @"NSURLNameKey", NSURLLocalizedNameKey = @"NSURLLocalizedNameKey", NSURLPathKey = @"_NSURLPathKey",
    NSURLParentDirectoryURLKey = @"NSURLParentDirectoryURLKey", NSURLIsRegularFileKey = @"NSURLIsRegularFileKey",
    NSURLIsDirectoryKey = @"NSURLIsDirectoryKey", NSURLIsSymbolicLinkKey = @"NSURLIsSymbolicLinkKey", NSURLIsPackageKey = @"NSURLIsPackageKey",
    NSURLIsHiddenKey = @"NSURLIsHiddenKey", NSURLIsReadableKey = @"NSURLIsReadableKey", NSURLIsWritableKey = @"NSURLIsWritableKey",
    NSURLIsExecutableKey = @"NSURLIsExecutableKey", NSURLFileResourceTypeKey = @"NSURLFileResourceTypeKey", NSURLFileSizeKey = @"NSURLFileSizeKey",
    NSURLTotalFileSizeKey = @"NSURLTotalFileSizeKey", NSURLFileAllocatedSizeKey = @"NSURLFileAllocatedSizeKey",
    NSURLTotalFileAllocatedSizeKey = @"NSURLTotalFileAllocatedSizeKey", NSURLLinkCountKey = @"NSURLLinkCountKey",
    NSURLCreationDateKey = @"NSURLCreationDateKey", NSURLContentModificationDateKey = @"NSURLContentModificationDateKey",
    NSURLContentAccessDateKey = @"NSURLContentAccessDateKey", NSURLAttributeModificationDateKey = @"NSURLAttributeModificationDateKey",
    /* files */
    NSURLIsExcludedFromBackupKey = @"NSURLIsExcludedFromBackupKey", NSURLFileProtectionKey = @"NSURLFileProtectionKey",
    NSURLTypeIdentifierKey = @"NSURLTypeIdentifierKey", NSURLContentTypeKey = @"NSURLContentTypeKey",
    NSURLLocalizedTypeDescriptionKey = @"NSURLLocalizedTypeDescriptionKey", NSURLAddedToDirectoryDateKey = @"NSURLAddedToDirectoryDateKey",
    NSURLDocumentIdentifierKey = @"NSURLDocumentIdentifierKey", NSURLGenerationIdentifierKey = @"NSURLGenerationIdentifierKey",
    NSURLFileResourceIdentifierKey = @"NSURLFileResourceIdentifierKey", NSURLFileIdentifierKey = @"NSURLFileIdentifierKey",
    NSURLFileContentIdentifierKey = @"NSURLFileContentIdentifierKey", NSURLPreferredIOBlockSizeKey = @"NSURLPreferredIOBlockSizeKey",
    NSURLIsVolumeKey = @"NSURLIsVolumeKey", NSURLIsSystemImmutableKey = @"NSURLIsSystemImmutableKey", NSURLIsUserImmutableKey = @"NSURLIsUserImmutableKey",
    NSURLHasHiddenExtensionKey = @"NSURLHasHiddenExtensionKey", NSURLCanonicalPathKey = @"NSURLCanonicalPathKey",
    NSURLIsAliasFileKey = @"NSURLIsAliasFileKey", NSURLIsMountTriggerKey = @"NSURLIsMountTriggerKey",
    NSURLMayShareFileContentKey = @"NSURLMayShareFileContentKey", NSURLMayHaveExtendedAttributesKey = @"NSURLMayHaveExtendedAttributesKey",
    NSURLIsPurgeableKey = @"NSURLIsPurgeableKey", NSURLIsSparseKey = @"NSURLIsSparseKey", NSURLDirectoryEntryCountKey = @"NSURLDirectoryEntryCountKey",
    /* volumes */
    NSURLVolumeURLKey = @"NSURLVolumeURLKey", NSURLVolumeIdentifierKey = @"NSURLVolumeIdentifierKey", NSURLVolumeNameKey = @"NSURLVolumeNameKey",
    NSURLVolumeLocalizedNameKey = @"NSURLVolumeLocalizedNameKey", NSURLVolumeUUIDStringKey = @"NSURLVolumeUUIDStringKey",
    NSURLVolumeCreationDateKey = @"NSURLVolumeCreationDateKey", NSURLVolumeLocalizedFormatDescriptionKey = @"NSURLVolumeLocalizedFormatDescriptionKey",
    NSURLVolumeTypeNameKey = @"NSURLVolumeTypeNameKey", NSURLVolumeSubtypeKey = @"NSURLVolumeSubtypeKey",
    NSURLVolumeTotalCapacityKey = @"NSURLVolumeTotalCapacityKey", NSURLVolumeAvailableCapacityKey = @"NSURLVolumeAvailableCapacityKey",
    NSURLVolumeAvailableCapacityForImportantUsageKey = @"NSURLVolumeAvailableCapacityForImportantUsageKey",
    NSURLVolumeAvailableCapacityForOpportunisticUsageKey = @"NSURLVolumeAvailableCapacityForOpportunisticUsageKey",
    NSURLVolumeResourceCountKey = @"NSURLVolumeResourceCountKey", NSURLVolumeMaximumFileSizeKey = @"NSURLVolumeMaximumFileSizeKey",
    NSURLVolumeIsReadOnlyKey = @"NSURLVolumeIsReadOnlyKey", NSURLVolumeIsLocalKey = @"NSURLVolumeIsLocalKey",
    NSURLVolumeIsInternalKey = @"NSURLVolumeIsInternalKey", NSURLVolumeIsRemovableKey = @"NSURLVolumeIsRemovableKey",
    NSURLVolumeIsEjectableKey = @"NSURLVolumeIsEjectableKey", NSURLVolumeIsRootFileSystemKey = @"NSURLVolumeIsRootFileSystemKey",
    NSURLVolumeIsEncryptedKey = @"NSURLVolumeIsEncryptedKey", NSURLVolumeIsBrowsableKey = @"NSURLVolumeIsBrowsableKey",
    NSURLVolumeIsAutomountedKey = @"NSURLVolumeIsAutomountedKey", NSURLVolumeIsJournalingKey = @"NSURLVolumeIsJournalingKey",
    NSURLVolumeSupportsPersistentIDsKey = @"NSURLVolumeSupportsPersistentIDsKey", NSURLVolumeSupportsSymbolicLinksKey = @"NSURLVolumeSupportsSymbolicLinksKey",
    NSURLVolumeSupportsHardLinksKey = @"NSURLVolumeSupportsHardLinksKey", NSURLVolumeSupportsJournalingKey = @"NSURLVolumeSupportsJournalingKey",
    NSURLVolumeSupportsSparseFilesKey = @"NSURLVolumeSupportsSparseFilesKey", NSURLVolumeSupportsZeroRunsKey = @"NSURLVolumeSupportsZeroRunsKey",
    NSURLVolumeSupportsCaseSensitiveNamesKey = @"NSURLVolumeSupportsCaseSensitiveNamesKey",
    NSURLVolumeSupportsCasePreservedNamesKey = @"NSURLVolumeSupportsCasePreservedNamesKey",
    NSURLVolumeSupportsRootDirectoryDatesKey = @"NSURLVolumeSupportsRootDirectoryDatesKey", NSURLVolumeSupportsVolumeSizesKey = @"NSURLVolumeSupportsVolumeSizesKey",
    NSURLVolumeSupportsRenamingKey = @"NSURLVolumeSupportsRenamingKey", NSURLVolumeSupportsAdvisoryFileLockingKey = @"NSURLVolumeSupportsAdvisoryFileLockingKey",
    NSURLVolumeSupportsExtendedSecurityKey = @"NSURLVolumeSupportsExtendedSecurityKey", NSURLVolumeSupportsCompressionKey = @"NSURLVolumeSupportsCompressionKey",
    NSURLVolumeSupportsFileCloningKey = @"NSURLVolumeSupportsFileCloningKey", NSURLVolumeSupportsSwapRenamingKey = @"NSURLVolumeSupportsSwapRenamingKey",
    NSURLVolumeSupportsExclusiveRenamingKey = @"NSURLVolumeSupportsExclusiveRenamingKey", NSURLVolumeSupportsImmutableFilesKey = @"NSURLVolumeSupportsImmutableFilesKey",
    NSURLVolumeSupportsAccessPermissionsKey = @"NSURLVolumeSupportsAccessPermissionsKey", NSURLVolumeSupportsFileProtectionKey = @"NSURLVolumeSupportsFileProtectionKey",
    /* iCloud */
    NSURLIsUbiquitousItemKey = @"NSURLIsUbiquitousItemKey", NSURLUbiquitousItemDownloadingStatusKey = @"NSURLUbiquitousItemDownloadingStatusKey",
    NSURLUbiquitousItemIsDownloadingKey = @"NSURLUbiquitousItemIsDownloadingKey", NSURLUbiquitousItemIsUploadedKey = @"NSURLUbiquitousItemIsUploadedKey",
    NSURLUbiquitousItemIsUploadingKey = @"NSURLUbiquitousItemIsUploadingKey", NSURLUbiquitousItemHasUnresolvedConflictsKey = @"NSURLUbiquitousItemHasUnresolvedConflictsKey",
    NSURLUbiquitousItemDownloadRequestedKey = @"NSURLUbiquitousItemDownloadRequestedKey",
    NSURLUbiquitousItemContainerDisplayNameKey = @"NSURLUbiquitousItemContainerDisplayNameKey", NSURLUbiquitousItemIsSharedKey = @"NSURLUbiquitousItemIsSharedKey",
    NSURLUbiquitousItemIsExcludedFromSyncKey = @"NSURLUbiquitousItemIsExcludedFromSyncKey",
    NSURLUbiquitousItemDownloadingErrorKey = @"NSURLUbiquitousItemDownloadingErrorKey", NSURLUbiquitousItemUploadingErrorKey = @"NSURLUbiquitousItemUploadingErrorKey";
NSURLFileResourceType const NSURLFileResourceTypeNamedPipe = @"NSURLFileResourceTypeNamedPipe",
    NSURLFileResourceTypeCharacterSpecial = @"NSURLFileResourceTypeCharacterSpecial", NSURLFileResourceTypeDirectory = @"NSURLFileResourceTypeDirectory",
    NSURLFileResourceTypeBlockSpecial = @"NSURLFileResourceTypeBlockSpecial", NSURLFileResourceTypeRegular = @"NSURLFileResourceTypeRegular",
    NSURLFileResourceTypeSymbolicLink = @"NSURLFileResourceTypeSymbolicLink", NSURLFileResourceTypeSocket = @"NSURLFileResourceTypeSocket",
    NSURLFileResourceTypeUnknown = @"NSURLFileResourceTypeUnknown";
NSURLUbiquitousItemDownloadingStatus const NSURLUbiquitousItemDownloadingStatusNotDownloaded = @"NSURLUbiquitousItemDownloadingStatusNotDownloaded",
    NSURLUbiquitousItemDownloadingStatusDownloaded = @"NSURLUbiquitousItemDownloadingStatusDownloaded",
    NSURLUbiquitousItemDownloadingStatusCurrent = @"NSURLUbiquitousItemDownloadingStatusCurrent";
NSURLFileProtectionType const NSURLFileProtectionNone = @"NSURLFileProtectionNone", NSURLFileProtectionComplete = @"NSURLFileProtectionComplete",
    NSURLFileProtectionCompleteUnlessOpen = @"NSURLFileProtectionCompleteUnlessOpen",
    NSURLFileProtectionCompleteUntilFirstUserAuthentication = @"NSURLFileProtectionCompleteUntilFirstUserAuthentication",
    NSURLFileProtectionCompleteWhenUserInactive = @"NSURLFileProtectionCompleteWhenUserInactive";

/* ---------------- the metadata store ($ISIM_DATA/Library/.isim-file-metadata.plist, by absolute path) ---------------- */
static NSString *meta_file(void) { return [isim_data_dir() stringByAppendingPathComponent:@"Library/.isim-file-metadata.plist"]; }
static NSMutableDictionary *meta_load(void) {
    return [NSMutableDictionary dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:meta_file()] ?: @{}];
}
id isim_file_meta(NSString *path, NSString *key) {
    if (!path.length) return nil;
    @synchronized ([NSURL class]) { return meta_load()[path.stringByStandardizingPath][key]; }
}
void isim_file_meta_set(NSString *path, NSString *key, id value) {
    if (!path.length) return;
    @synchronized ([NSURL class]) {
        NSMutableDictionary *d = meta_load();
        NSString *p = path.stringByStandardizingPath;
        NSMutableDictionary *entry = [d[p] mutableCopy] ?: [NSMutableDictionary dictionary];
        entry[key] = value;
        if (entry.count) d[p] = entry; else [d removeObjectForKey:p];
        [NSFileManager.defaultManager createDirectoryAtPath:meta_file().stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
        [d writeToFile:meta_file() atomically:YES];
    }
}
/* a file moved or removed takes its metadata along (or drops it) */
void isim_file_meta_move(NSString *from, NSString *to) {
    @synchronized ([NSURL class]) {
        NSMutableDictionary *d = meta_load();
        NSString *f = from.stringByStandardizingPath, *t = to.stringByStandardizingPath;
        BOOL changed = NO;
        for (NSString *k in d.allKeys) {
            if (![k isEqualToString:f] && ![k hasPrefix:[f stringByAppendingString:@"/"]]) continue;
            id v = d[k]; [d removeObjectForKey:k]; changed = YES;
            if (t) d[[t stringByAppendingString:[k substringFromIndex:f.length]]] = v;
        }
        if (changed) [d writeToFile:meta_file() atomically:YES];
    }
}

/* ---------------- content types ---------------- */
static NSString *type_for_extension(NSString *ext, BOOL dir, BOOL package) {
    if (dir) return package ? @"com.apple.package" : @"public.folder";
    static char *(*uti)(const char *);
    static BOOL looked;
    if (!looked) { uti = (char *(*)(const char *))dlsym(RTLD_DEFAULT, "isim_uti_type_for_extension"); looked = YES; }
    if (uti && ext.length) {
        char *s = uti(ext.lowercaseString.UTF8String);
        if (s) { NSString *r = @(s); free(s); return r; }
    }
    NSDictionary *builtin = @{ @"txt": @"public.plain-text", @"text": @"public.plain-text", @"md": @"net.daringfireball.markdown",
                               @"rtf": @"public.rtf", @"html": @"public.html", @"htm": @"public.html", @"xml": @"public.xml",
                               @"json": @"public.json", @"csv": @"public.comma-separated-values-text", @"png": @"public.png",
                               @"jpg": @"public.jpeg", @"jpeg": @"public.jpeg", @"heic": @"public.heic", @"gif": @"com.compuserve.gif",
                               @"tiff": @"public.tiff", @"pdf": @"com.adobe.pdf", @"zip": @"public.zip-archive", @"mp4": @"public.mpeg-4",
                               @"mov": @"com.apple.quicktime-movie", @"mp3": @"public.mp3", @"m4a": @"public.mpeg-4-audio",
                               @"wav": @"com.microsoft.waveform-audio", @"plist": @"com.apple.property-list", @"swift": @"public.swift-source",
                               @"vcf": @"public.vcard", @"svg": @"public.svg-image", @"webp": @"org.webmproject.webp" };
    return builtin[ext.lowercaseString] ?: @"public.data";
}
static NSString *type_description(NSString *type, NSString *ext) {
    NSDictionary *names = @{ @"public.folder": @"Folder", @"com.apple.package": @"Package", @"public.plain-text": @"Plain Text Document",
                             @"public.rtf": @"Rich Text Document", @"public.html": @"HTML text", @"public.xml": @"XML text",
                             @"public.json": @"JSON", @"public.comma-separated-values-text": @"comma-separated values",
                             @"public.png": @"PNG image", @"public.jpeg": @"JPEG image", @"public.heic": @"HEIF Image",
                             @"com.compuserve.gif": @"GIF image", @"public.tiff": @"TIFF image", @"com.adobe.pdf": @"PDF document",
                             @"public.zip-archive": @"ZIP archive", @"public.mpeg-4": @"MPEG-4 movie", @"com.apple.quicktime-movie": @"QuickTime movie",
                             @"public.mp3": @"MP3 audio", @"public.mpeg-4-audio": @"MPEG-4 audio", @"com.microsoft.waveform-audio": @"Waveform audio",
                             @"com.apple.property-list": @"property list", @"net.daringfireball.markdown": @"Markdown Document",
                             @"public.swift-source": @"Swift Source", @"public.vcard": @"vCard", @"public.svg-image": @"SVG image",
                             @"org.webmproject.webp": @"WebP image" };
    return names[type] ?: (ext.length ? [NSString stringWithFormat:@"%@ File", ext.uppercaseString] : @"Document");
}

/* ---------------- values ---------------- */
static NSDate *date_of(struct timespec t) { return [NSDate dateWithTimeIntervalSince1970:(double)t.tv_sec + t.tv_nsec / 1e9]; }
static NSString *volume_uuid(dev_t dev) {
    /* stable per device-data volume */
    unsigned long long h = 1469598103934665603ULL ^ (unsigned long long)dev;
    for (const char *c = isim_data_dir().UTF8String; *c; c++) h = (h ^ (unsigned char)*c) * 1099511628211ULL;
    return [NSString stringWithFormat:@"%08llX-%04llX-4%03llX-A%03llX-%012llX", h >> 32, (h >> 16) & 0xFFFF, h & 0xFFF, (h >> 20) & 0xFFF, (h * 2654435761ULL) & 0xFFFFFFFFFFFFULL];
}

@implementation NSURL (NSURLResourceValues)
- (NSMutableDictionary *)_isim_temporaryValues {
    NSMutableDictionary *d = objc_getAssociatedObject(self, "isim.temporaryResourceValues");
    if (!d) { d = [NSMutableDictionary dictionary]; objc_setAssociatedObject(self, "isim.temporaryResourceValues", d, OBJC_ASSOCIATION_RETAIN); }
    return d;
}
- (NSDictionary<NSURLResourceKey, id> *)resourceValuesForKeys:(NSArray<NSURLResourceKey> *)keys error:(NSError **)err {
    if (!self.isFileURL) {                              /* NSFileReadUnsupportedSchemeError */
        if (err) *err = [NSError errorWithDomain:NSCocoaErrorDomain code:262 userInfo:@{ NSURLErrorKey: self }];
        return nil;
    }
    NSString *p = self.path;
    struct stat st;
    if (lstat(p.UTF8String, &st) != 0) {
        int e = errno;
        if (err) *err = [NSError errorWithDomain:NSCocoaErrorDomain code:e == ENOENT || e == ENOTDIR ? 260 : e == EACCES ? 257 : 256
                                        userInfo:@{ @"NSFilePath": p, NSURLErrorKey: self, NSUnderlyingErrorKey: [NSError errorWithDomain:NSPOSIXErrorDomain code:e userInfo:nil] }];
        return nil;
    }
    mode_t type = st.st_mode & S_IFMT;
    BOOL dir = type == S_IFDIR, package = dir && isim_is_package_path(p);
    NSDictionary *meta = nil;
    NSDictionary *ubiquity = nil;
    BOOL volume = NO;
    for (NSURLResourceKey k in keys) {
        if ([k hasPrefix:@"NSURLVolume"]) volume = YES;
        if ([k hasPrefix:@"NSURLUbiquitous"] || [k isEqualToString:NSURLIsUbiquitousItemKey]) ubiquity = isim_ubiquity_item_status(p);
    }
    unsigned long long fs[4] = {0};
    if (volume) isim_fs_stats(p.UTF8String, fs);
    @synchronized ([NSURL class]) { meta = meta_load()[p.stringByStandardizingPath]; }
    NSDictionary *temporary = objc_getAssociatedObject(self, "isim.temporaryResourceValues");
    NSString *ext = p.pathExtension;
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (NSURLResourceKey k in keys) {
        id v = temporary[k];
        if (v) { out[k] = v; continue; }
        /* files */
        if ([k isEqualToString:NSURLNameKey] || [k isEqualToString:NSURLLocalizedNameKey]) v = p.lastPathComponent;
        else if ([k isEqualToString:NSURLPathKey] || [k isEqualToString:NSURLCanonicalPathKey]) v = [k isEqualToString:NSURLPathKey] ? p : p.stringByResolvingSymlinksInPath;
        else if ([k isEqualToString:NSURLParentDirectoryURLKey]) v = [p isEqualToString:@"/"] ? nil : [NSURL fileURLWithPath:p.stringByDeletingLastPathComponent isDirectory:YES];
        else if ([k isEqualToString:NSURLIsRegularFileKey]) v = @(type == S_IFREG);
        else if ([k isEqualToString:NSURLIsDirectoryKey]) v = @(dir);
        else if ([k isEqualToString:NSURLIsSymbolicLinkKey]) v = @(type == S_IFLNK);
        else if ([k isEqualToString:NSURLIsPackageKey]) v = @(package);
        else if ([k isEqualToString:NSURLIsHiddenKey]) v = @([p.lastPathComponent hasPrefix:@"."] || [meta[@"hidden"] boolValue]);
        else if ([k isEqualToString:NSURLIsReadableKey]) v = @(access(p.UTF8String, R_OK) == 0);
        else if ([k isEqualToString:NSURLIsWritableKey]) v = @(access(p.UTF8String, W_OK) == 0);
        else if ([k isEqualToString:NSURLIsExecutableKey]) v = @(access(p.UTF8String, X_OK) == 0);
        else if ([k isEqualToString:NSURLFileResourceTypeKey])
            v = type == S_IFREG ? NSURLFileResourceTypeRegular : dir ? NSURLFileResourceTypeDirectory : type == S_IFLNK ? NSURLFileResourceTypeSymbolicLink :
                type == S_IFIFO ? NSURLFileResourceTypeNamedPipe : type == S_IFCHR ? NSURLFileResourceTypeCharacterSpecial :
                type == S_IFBLK ? NSURLFileResourceTypeBlockSpecial : type == S_IFSOCK ? NSURLFileResourceTypeSocket : NSURLFileResourceTypeUnknown;
        else if ([k isEqualToString:NSURLFileSizeKey] || [k isEqualToString:NSURLTotalFileSizeKey]) v = dir ? nil : @((long long)st.st_size);
        else if ([k isEqualToString:NSURLFileAllocatedSizeKey] || [k isEqualToString:NSURLTotalFileAllocatedSizeKey]) v = dir ? nil : @((long long)st.st_blocks * 512);
        else if ([k isEqualToString:NSURLLinkCountKey]) v = @((long)st.st_nlink);
        else if ([k isEqualToString:NSURLCreationDateKey]) v = meta[@"creationDate"] ?: date_of(st.st_birthtimespec.tv_sec ? st.st_birthtimespec : st.st_mtimespec);
        else if ([k isEqualToString:NSURLContentModificationDateKey]) v = date_of(st.st_mtimespec);
        else if ([k isEqualToString:NSURLContentAccessDateKey]) v = date_of(st.st_atimespec);
        else if ([k isEqualToString:NSURLAttributeModificationDateKey]) v = date_of(st.st_ctimespec);
        else if ([k isEqualToString:NSURLAddedToDirectoryDateKey]) v = date_of(st.st_ctimespec);
        else if ([k isEqualToString:NSURLIsExcludedFromBackupKey]) v = @([meta[@"excludedFromBackup"] boolValue]);
        else if ([k isEqualToString:NSURLFileProtectionKey]) v = dir ? nil : meta[@"protection"] ?: NSURLFileProtectionCompleteUntilFirstUserAuthentication;
        else if ([k isEqualToString:NSURLTypeIdentifierKey] || [k isEqualToString:NSURLContentTypeKey]) v = type == S_IFLNK ? @"public.symlink" : type_for_extension(ext, dir, package);
        else if ([k isEqualToString:NSURLLocalizedTypeDescriptionKey]) v = type_description(type_for_extension(ext, dir, package), ext);
        else if ([k isEqualToString:NSURLDocumentIdentifierKey] || [k isEqualToString:NSURLFileIdentifierKey]) v = @((unsigned long long)st.st_ino);
        else if ([k isEqualToString:NSURLFileResourceIdentifierKey]) v = [NSString stringWithFormat:@"%llu:%llu", (unsigned long long)st.st_dev, (unsigned long long)st.st_ino];
        else if ([k isEqualToString:NSURLGenerationIdentifierKey]) v = dir ? nil : [NSString stringWithFormat:@"%lld.%ld:%lld", (long long)st.st_mtimespec.tv_sec, (long)st.st_mtimespec.tv_nsec, (long long)st.st_size];
        else if ([k isEqualToString:NSURLFileContentIdentifierKey]) v = dir ? nil : @((long long)st.st_ino);
        else if ([k isEqualToString:NSURLPreferredIOBlockSizeKey]) v = @((long)st.st_blksize);
        else if ([k isEqualToString:NSURLIsVolumeKey]) v = @([p isEqualToString:@"/"]);
        else if ([k isEqualToString:NSURLIsSystemImmutableKey] || [k isEqualToString:NSURLIsUserImmutableKey] || [k isEqualToString:NSURLIsAliasFileKey] ||
                 [k isEqualToString:NSURLIsMountTriggerKey] || [k isEqualToString:NSURLIsPurgeableKey] || [k isEqualToString:NSURLHasHiddenExtensionKey]) v = @NO;
        else if ([k isEqualToString:NSURLMayShareFileContentKey]) v = @(st.st_nlink > 1 && !dir);
        else if ([k isEqualToString:NSURLMayHaveExtendedAttributesKey]) v = @NO;
        else if ([k isEqualToString:NSURLIsSparseKey]) v = @(!dir && (long long)st.st_blocks * 512 < (long long)st.st_size);
        else if ([k isEqualToString:NSURLDirectoryEntryCountKey]) v = dir ? @([NSFileManager.defaultManager contentsOfDirectoryAtPath:p error:NULL].count) : nil;
        /* the data volume */
        else if ([k isEqualToString:NSURLVolumeURLKey]) v = [NSURL fileURLWithPath:isim_data_dir() isDirectory:YES];
        else if ([k isEqualToString:NSURLVolumeIdentifierKey]) v = @((unsigned long long)st.st_dev);
        else if ([k isEqualToString:NSURLVolumeNameKey] || [k isEqualToString:NSURLVolumeLocalizedNameKey]) v = @"Data";
        else if ([k isEqualToString:NSURLVolumeUUIDStringKey]) v = volume_uuid(st.st_dev);
        else if ([k isEqualToString:NSURLVolumeCreationDateKey]) { struct stat ds; v = stat(isim_data_dir().UTF8String, &ds) == 0 ? date_of(ds.st_ctimespec) : nil; }
        else if ([k isEqualToString:NSURLVolumeLocalizedFormatDescriptionKey]) v = @"APFS (Case-sensitive, Encrypted)";
        else if ([k isEqualToString:NSURLVolumeTypeNameKey]) v = @"apfs";
        else if ([k isEqualToString:NSURLVolumeSubtypeKey]) v = @1;
        else if ([k isEqualToString:NSURLVolumeTotalCapacityKey]) v = @((long long)fs[0]);
        else if ([k isEqualToString:NSURLVolumeAvailableCapacityKey]) v = @((long long)fs[1]);
        else if ([k isEqualToString:NSURLVolumeAvailableCapacityForImportantUsageKey] || [k isEqualToString:NSURLVolumeAvailableCapacityForOpportunisticUsageKey]) v = @((long long)fs[1]);
        else if ([k isEqualToString:NSURLVolumeResourceCountKey]) v = @((long long)(fs[2] - fs[3]));
        else if ([k isEqualToString:NSURLVolumeMaximumFileSizeKey]) v = @(LLONG_MAX);
        else if ([k isEqualToString:NSURLVolumeIsReadOnlyKey]) v = @(access(isim_data_dir().UTF8String, W_OK) != 0);
        else if ([k isEqualToString:NSURLVolumeIsRemovableKey] || [k isEqualToString:NSURLVolumeIsEjectableKey] || [k isEqualToString:NSURLVolumeIsRootFileSystemKey] ||
                 [k isEqualToString:NSURLVolumeIsAutomountedKey] || [k isEqualToString:NSURLVolumeSupportsZeroRunsKey] || [k isEqualToString:NSURLVolumeSupportsRenamingKey]) v = @NO;
        else if ([k hasPrefix:@"NSURLVolumeIs"] || [k hasPrefix:@"NSURLVolumeSupports"]) v = @YES;   /* local, internal, encrypted, journaled; APFS features */
        /* iCloud */
        else if ([k isEqualToString:NSURLIsUbiquitousItemKey]) v = @(ubiquity != nil);
        else if (ubiquity && [k isEqualToString:NSURLUbiquitousItemDownloadingStatusKey])
            v = [ubiquity[@"evicted"] boolValue] ? NSURLUbiquitousItemDownloadingStatusNotDownloaded : NSURLUbiquitousItemDownloadingStatusCurrent;
        else if (ubiquity && [k isEqualToString:NSURLUbiquitousItemIsDownloadingKey]) v = @([ubiquity[@"downloading"] boolValue]);
        else if (ubiquity && [k isEqualToString:NSURLUbiquitousItemDownloadRequestedKey]) v = @([ubiquity[@"downloading"] boolValue]);
        else if (ubiquity && [k isEqualToString:NSURLUbiquitousItemIsUploadedKey]) v = @YES;
        else if (ubiquity && ([k isEqualToString:NSURLUbiquitousItemIsUploadingKey] || [k isEqualToString:NSURLUbiquitousItemHasUnresolvedConflictsKey] ||
                              [k isEqualToString:NSURLUbiquitousItemIsSharedKey])) v = @NO;
        else if (ubiquity && [k isEqualToString:NSURLUbiquitousItemIsExcludedFromSyncKey]) v = @([ubiquity[@"excludedFromSync"] boolValue]);
        else if (ubiquity && [k isEqualToString:NSURLUbiquitousItemContainerDisplayNameKey]) v = ubiquity[@"displayName"];
        if (v) out[k] = v;
    }
    return [out copy];
}
- (BOOL)getResourceValue:(id *)value forKey:(NSURLResourceKey)key error:(NSError **)err {
    NSDictionary *d = key ? [self resourceValuesForKeys:@[key] error:err] : nil;
    *value = d[key];
    return d != nil;
}
/* the writable values: name (renames), dates, hidden, backup exclusion, file protection, iCloud sync exclusion */
- (BOOL)setResourceValue:(id)value forKey:(NSURLResourceKey)key error:(NSError **)err {
    return key ? [self setResourceValues:@{ key: value ?: [NSNull null] } error:err] : NO;
}
- (BOOL)setResourceValues:(NSDictionary<NSURLResourceKey, id> *)values error:(NSError **)err {
    if (!self.isFileURL) { if (err) *err = [NSError errorWithDomain:NSCocoaErrorDomain code:518 userInfo:@{ NSURLErrorKey: self }]; return NO; }
    NSString *p = self.path;
    struct stat st;
    if (lstat(p.UTF8String, &st) != 0) {
        if (err) *err = [NSError errorWithDomain:NSCocoaErrorDomain code:4 userInfo:@{ @"NSFilePath": p, NSURLErrorKey: self }];
        return NO;
    }
    for (NSURLResourceKey k in values) {
        id v = values[k] == [NSNull null] ? nil : values[k];
        if ([k isEqualToString:NSURLContentModificationDateKey] || [k isEqualToString:NSURLContentAccessDateKey]) {
            if (![v isKindOfClass:[NSDate class]]) continue;
            struct timespec ts[2] = { st.st_atimespec, st.st_mtimespec };
            double t = [v timeIntervalSince1970];
            struct timespec now = { (time_t)t, (long)((t - floor(t)) * 1e9) };
            ts[[k isEqualToString:NSURLContentAccessDateKey] ? 0 : 1] = now;
            struct timeval tv[2] = { { ts[0].tv_sec, (int)(ts[0].tv_nsec / 1000) }, { ts[1].tv_sec, (int)(ts[1].tv_nsec / 1000) } };
            utimes(p.UTF8String, tv);
        }
        else if ([k isEqualToString:NSURLCreationDateKey]) isim_file_meta_set(p, @"creationDate", [v isKindOfClass:[NSDate class]] ? v : nil);
        else if ([k isEqualToString:NSURLIsHiddenKey]) isim_file_meta_set(p, @"hidden", [v boolValue] ? @YES : nil);
        else if ([k isEqualToString:NSURLIsExcludedFromBackupKey]) isim_file_meta_set(p, @"excludedFromBackup", [v boolValue] ? @YES : nil);
        else if ([k isEqualToString:NSURLFileProtectionKey]) isim_file_meta_set(p, @"protection", [v isKindOfClass:[NSString class]] ? v : nil);
        else if ([k isEqualToString:NSURLUbiquitousItemIsExcludedFromSyncKey]) isim_file_meta_set(p, @"excludedFromSync", [v boolValue] ? @YES : nil);
    }
    /* the rename last: the other values apply to the file at its current path */
    id name = values[NSURLNameKey];
    if ([name isKindOfClass:[NSString class]] && ![name isEqualToString:p.lastPathComponent]) {
        NSString *to = [p.stringByDeletingLastPathComponent stringByAppendingPathComponent:name];
        if (![NSFileManager.defaultManager moveItemAtPath:p toPath:to error:err]) return NO;
    }
    return YES;
}
/* temporary values: kept on this URL object only, returned before the file's values */
- (void)setTemporaryResourceValue:(id)value forKey:(NSURLResourceKey)key {
    @synchronized (self) { if (value) [self _isim_temporaryValues][key] = value; else [[self _isim_temporaryValues] removeObjectForKey:key]; }
}
- (void)removeCachedResourceValueForKey:(NSURLResourceKey)key {
    @synchronized (self) { [objc_getAssociatedObject(self, "isim.temporaryResourceValues") removeObjectForKey:key]; }
}
- (void)removeAllCachedResourceValues {
    @synchronized (self) { [objc_getAssociatedObject(self, "isim.temporaryResourceValues") removeAllObjects]; }
}
/* the real path when the file exists (iOS also drops /private from /private/var paths; Linux has none) */
- (NSURL *)URLByResolvingSymlinksInPath {
    if (!self.isFileURL) return self;
    char buf[4096];
    return realpath(self.path.UTF8String, buf) ? [NSURL fileURLWithPath:@(buf) isDirectory:[self.absoluteString hasSuffix:@"/"]] : self;
}
@end
