/* isim Foundation (ARC): NSFileWrapper — regular files, directories (packages) of named children, symbolic links;
 * read from disk (eagerly: NSFileWrapperReadingImmediate or not, isim reads the whole tree) and written back. */
#import <Foundation/Foundation.h>

@implementation NSFileWrapper {
    int _kind;                                         /* 0 regular file, 1 directory, 2 symbolic link */
    NSData *_contents;
    NSMutableDictionary<NSString *, NSFileWrapper *> *_children;
    NSURL *_link;
}
@synthesize preferredFilename = _preferredFilename, filename = _filename, fileAttributes = _fileAttributes;
- (instancetype)init { return [self initRegularFileWithContents:[NSData data]]; }
- (instancetype)initRegularFileWithContents:(NSData *)contents {
    if ((self = [super init])) { _kind = 0; _contents = [contents copy] ?: [NSData data]; _fileAttributes = @{}; }
    return self;
}
- (instancetype)initDirectoryWithFileWrappers:(NSDictionary<NSString *, NSFileWrapper *> *)children {
    if ((self = [super init])) {
        _kind = 1; _children = [NSMutableDictionary dictionary]; _fileAttributes = @{};
        for (NSString *name in children) {
            NSFileWrapper *c = children[name];
            if (!c.preferredFilename) c.preferredFilename = name;
            c.filename = name;
            _children[name] = c;
        }
    }
    return self;
}
- (instancetype)initSymbolicLinkWithDestinationURL:(NSURL *)url {
    if ((self = [super init])) { _kind = 2; _link = url; _fileAttributes = @{}; }
    return self;
}
- (instancetype)initWithURL:(NSURL *)url options:(NSFileWrapperReadingOptions)options error:(NSError **)outError {
    if ((self = [super init])) {
        _fileAttributes = @{};
        if (![self readFromURL:url options:options error:outError]) return nil;
        _filename = url.lastPathComponent; _preferredFilename = url.lastPathComponent;
    }
    return self;
}
- (BOOL)isRegularFile { return _kind == 0; }
- (BOOL)isDirectory { return _kind == 1; }
- (BOOL)isSymbolicLink { return _kind == 2; }
- (NSData *)regularFileContents { return _kind == 0 ? _contents : nil; }
- (NSURL *)symbolicLinkDestinationURL { return _kind == 2 ? _link : nil; }
- (NSDictionary<NSString *, NSFileWrapper *> *)fileWrappers { return _kind == 1 ? [_children copy] : nil; }

static NSError *wrapper_error(NSInteger code, NSURL *url) {
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:url ? @{NSURLErrorKey: url} : nil];
}
- (BOOL)readFromURL:(NSURL *)url options:(NSFileWrapperReadingOptions)options error:(NSError **)outError {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *path = url.path;
    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
    NSString *type = attrs[NSFileType];
    if (!attrs) { if (outError) *outError = wrapper_error(NSFileReadNoSuchFileError, url); return NO; }
    if ([type isEqual:NSFileTypeSymbolicLink]) {
        NSString *dest = [fm destinationOfSymbolicLinkAtPath:path error:nil];
        _kind = 2; _link = dest ? [NSURL fileURLWithPath:dest] : nil;
    } else if ([type isEqual:NSFileTypeDirectory]) {
        _kind = 1; _children = [NSMutableDictionary dictionary];
        for (NSString *name in [fm contentsOfDirectoryAtPath:path error:nil] ?: @[]) {
            NSFileWrapper *c = [[NSFileWrapper alloc] initWithURL:[url URLByAppendingPathComponent:name] options:options error:outError];
            if (!c) return NO;
            _children[name] = c;
        }
    } else {
        NSData *d = [NSData dataWithContentsOfURL:url options:0 error:outError];
        if (!d) return NO;
        _kind = 0; _contents = d;
    }
    _fileAttributes = attrs;
    return YES;
}
- (BOOL)matchesContentsOfURL:(NSURL *)url {
    NSFileWrapper *other = [[NSFileWrapper alloc] initWithURL:url options:0 error:nil];
    if (!other || other->_kind != _kind) return NO;
    if (_kind == 0) return [other->_contents isEqualToData:_contents];
    if (_kind == 2) return [other->_link.path isEqual:_link.path];
    if (![[NSSet setWithArray:other->_children.allKeys] isEqual:[NSSet setWithArray:_children.allKeys]]) return NO;
    for (NSString *k in _children) if (![_children[k] matchesContentsOfURL:[url URLByAppendingPathComponent:k]]) return NO;
    return YES;
}
- (BOOL)writeToURL:(NSURL *)url options:(NSFileWrapperWritingOptions)options originalContentsURL:(NSURL *)original error:(NSError **)outError {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *path = url.path;
    switch (_kind) {
    case 0:
        if (![_contents writeToURL:url options:(options & NSFileWrapperWritingAtomic) ? NSDataWritingAtomic : 0 error:outError]) return NO;
        break;
    case 2:
        [fm removeItemAtPath:path error:nil];
        if (![fm createSymbolicLinkAtPath:path withDestinationPath:_link.path error:outError]) return NO;
        break;
    default: {
        /* a directory: written next to the destination and moved over it when atomic */
        NSURL *target = url;
        BOOL atomic = (options & NSFileWrapperWritingAtomic) && [fm fileExistsAtPath:path];
        if (atomic) target = [[NSURL fileURLWithPath:path.stringByDeletingLastPathComponent] URLByAppendingPathComponent:[NSString stringWithFormat:@".%@.isim-new", url.lastPathComponent]];
        [fm removeItemAtURL:target error:nil];
        if (![fm createDirectoryAtURL:target withIntermediateDirectories:YES attributes:nil error:outError]) return NO;
        for (NSString *name in _children) {
            NSURL *childOriginal = original ? [original URLByAppendingPathComponent:name] : nil;
            if (![_children[name] writeToURL:[target URLByAppendingPathComponent:name] options:options & ~NSFileWrapperWritingAtomic originalContentsURL:childOriginal error:outError]) return NO;
        }
        if (atomic) {
            [fm removeItemAtURL:url error:nil];
            if (![fm moveItemAtURL:target toURL:url error:outError]) return NO;
        }
    }
    }
    if (options & NSFileWrapperWritingWithNameUpdating) _filename = url.lastPathComponent;
    return YES;
}
- (NSString *)_isimUniqueKey:(NSString *)name {
    NSString *base = name.length ? name : @"Untitled", *key = base;
    for (int i = 2; _children[key]; i++) {
        NSString *ext = base.pathExtension, *stem = base.stringByDeletingPathExtension;
        key = ext.length ? [NSString stringWithFormat:@"%@ %d.%@", stem, i, ext] : [NSString stringWithFormat:@"%@ %d", stem, i];
    }
    return key;
}
- (NSString *)addFileWrapper:(NSFileWrapper *)child {
    if (_kind != 1) [NSException raise:NSInternalInconsistencyException format:@"addFileWrapper: on a file wrapper that is not a directory"];
    NSString *key = [self _isimUniqueKey:child.preferredFilename ?: child.filename];
    child.filename = key;
    _children[key] = child;
    return key;
}
- (NSString *)addRegularFileWithContents:(NSData *)data preferredFilename:(NSString *)fileName {
    NSFileWrapper *c = [[NSFileWrapper alloc] initRegularFileWithContents:data];
    c.preferredFilename = fileName;
    return [self addFileWrapper:c];
}
- (void)removeFileWrapper:(NSFileWrapper *)child {
    NSString *k = [self keyForFileWrapper:child];
    if (k) [_children removeObjectForKey:k];
}
- (NSString *)keyForFileWrapper:(NSFileWrapper *)child {
    for (NSString *k in _children) if (_children[k] == child) return k;
    return nil;
}
/* the serialized form (issue #239: flattened RTFD, the pasteboard's file contents). Adapted: Apple doesn't document its
   layout, so isim writes its own: "rtfd" "isim", then the tree (a kind byte f / d / l, the name's length and bytes, then
   a file's length and contents, a directory's child count and children, a link's destination). It round-trips
   through isim; iOS's serialized data is not read. */
static void put32(NSMutableData *d, uint32_t v) { unsigned char b[4] = { v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, v >> 24 }; [d appendBytes:b length:4]; }
static void put_string(NSMutableData *d, NSString *s) { NSData *u = [s ?: @"" dataUsingEncoding:NSUTF8StringEncoding]; put32(d, (uint32_t)u.length); [d appendData:u]; }
static void serialize(NSFileWrapper *w, NSString *name, NSMutableData *d) {
    if (w.isDirectory) {
        [d appendBytes:"d" length:1]; put_string(d, name);
        NSDictionary *kids = w.fileWrappers;
        put32(d, (uint32_t)kids.count);
        for (NSString *k in [kids.allKeys sortedArrayUsingSelector:@selector(compare:)]) serialize(kids[k], k, d);
    } else if (w.isSymbolicLink) {
        [d appendBytes:"l" length:1]; put_string(d, name); put_string(d, w.symbolicLinkDestinationURL.path);
    } else {
        NSData *c = w.regularFileContents ?: [NSData data];
        [d appendBytes:"f" length:1]; put_string(d, name); put32(d, (uint32_t)c.length); [d appendData:c];
    }
}
typedef struct { const unsigned char *p, *end; BOOL bad; } Reader;
static uint32_t get32(Reader *r) {
    if (r->end - r->p < 4) { r->bad = YES; return 0; }
    uint32_t v = r->p[0] | r->p[1] << 8 | r->p[2] << 16 | (uint32_t)r->p[3] << 24; r->p += 4; return v;
}
static NSData *get_bytes(Reader *r, uint32_t n) {
    if ((uint64_t)(r->end - r->p) < n) { r->bad = YES; return nil; }
    NSData *d = [NSData dataWithBytes:r->p length:n]; r->p += n; return d;
}
static NSString *get_string(Reader *r) { NSData *d = get_bytes(r, get32(r)); return d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : nil; }
static NSFileWrapper *deserialize(Reader *r, NSString **name, int depth) {
    if (r->p >= r->end || depth > 64) { r->bad = YES; return nil; }
    unsigned char kind = *r->p++;
    *name = get_string(r);
    NSFileWrapper *w = nil;
    if (kind == 'f') w = [[NSFileWrapper alloc] initRegularFileWithContents:get_bytes(r, get32(r)) ?: [NSData data]];
    else if (kind == 'l') { NSString *dest = get_string(r); w = [[NSFileWrapper alloc] initSymbolicLinkWithDestinationURL:[NSURL fileURLWithPath:dest ?: @"/"]]; }
    else if (kind == 'd') {
        uint32_t n = get32(r);
        NSMutableDictionary *kids = [NSMutableDictionary dictionary];
        for (uint32_t i = 0; i < n && !r->bad; i++) {
            NSString *k = nil; NSFileWrapper *c = deserialize(r, &k, depth + 1);
            if (c && k.length) { c.preferredFilename = k; kids[k] = c; }
        }
        w = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:kids];
    } else r->bad = YES;
    if (r->bad) return nil;
    if ((*name).length) w.preferredFilename = *name;
    return w;
}
- (NSData *)serializedRepresentation {
    NSMutableData *d = [NSMutableData dataWithBytes:"rtfdisim" length:8];
    serialize(self, self.preferredFilename ?: @"", d);
    return d;
}
- (instancetype)initWithSerializedRepresentation:(NSData *)data {
    if (data.length < 8 || memcmp(data.bytes, "rtfdisim", 8)) return nil;
    Reader r = { (const unsigned char *)data.bytes + 8, (const unsigned char *)data.bytes + data.length, NO };
    NSString *name = nil;
    NSFileWrapper *w = deserialize(&r, &name, 0);
    return w;
}
@end
