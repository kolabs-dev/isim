/* isim Foundation (ARC): NSUUID (bridged to Swift's UUID). */
#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

@implementation NSUUID { uuid_t _b; }
+ (instancetype)UUID { return [self new]; }
- (instancetype)init {
    if ((self = [super init])) {
        int fd = open("/dev/urandom", O_RDONLY);
        if (fd < 0 || read(fd, _b, 16) != 16) for (int i = 0; i < 16; i++) _b[i] = (unsigned char)arc4random();
        if (fd >= 0) close(fd);
        _b[6] = (_b[6] & 0x0F) | 0x40; _b[8] = (_b[8] & 0x3F) | 0x80;      /* version 4, RFC 4122 variant */
    }
    return self;
}
- (instancetype)initWithUUIDString:(NSString *)s {
    if (!(self = [super init])) return nil;
    const char *c = s.UTF8String;
    if (!c || strlen(c) != 36) return nil;
    int k = 0;
    for (int i = 0; i < 36; i++) {
        if (i == 8 || i == 13 || i == 18 || i == 23) { if (c[i] != '-') return nil; continue; }
        char h = c[i], l = c[i + 1];
        if (!isxdigit((unsigned char)h) || !isxdigit((unsigned char)l)) return nil;
        _b[k++] = (unsigned char)(((isdigit((unsigned char)h) ? h - '0' : (tolower(h) - 'a' + 10)) << 4) | (isdigit((unsigned char)l) ? l - '0' : (tolower(l) - 'a' + 10)));
        i++;
    }
    return self;
}
- (instancetype)initWithUUIDBytes:(const uuid_t)bytes { if ((self = [super init])) memcpy(_b, bytes, 16); return self; }
- (void)getUUIDBytes:(uuid_t)out { memcpy(out, _b, 16); }
- (NSString *)UUIDString {
    return [NSString stringWithFormat:@"%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
            _b[0], _b[1], _b[2], _b[3], _b[4], _b[5], _b[6], _b[7], _b[8], _b[9], _b[10], _b[11], _b[12], _b[13], _b[14], _b[15]];
}
- (NSComparisonResult)compare:(NSUUID *)o { uuid_t ob; [o getUUIDBytes:ob]; int r = memcmp(_b, ob, 16); return r < 0 ? NSOrderedAscending : r > 0 ? NSOrderedDescending : NSOrderedSame; }
- (BOOL)isEqual:(id)o { if (![o isKindOfClass:[NSUUID class]]) return NO; uuid_t ob; [o getUUIDBytes:ob]; return !memcmp(_b, ob, 16); }
- (NSUInteger)hash { NSUInteger h; memcpy(&h, _b, sizeof h); return h; }
- (id)copyWithZone:(NSZone *)z { return self; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeBytes:_b length:16 forKey:@"NS.uuidbytes"]; }
- (instancetype)initWithCoder:(NSCoder *)c { NSUInteger n = 0; const uint8_t *b = [c decodeBytesForKey:@"NS.uuidbytes" returnedLength:&n]; if (n != 16) return nil; return [self initWithUUIDBytes:b]; }
- (NSString *)description { return [NSString stringWithFormat:@"<__NSConcreteUUID %p> %@", self, self.UUIDString]; }
@end
