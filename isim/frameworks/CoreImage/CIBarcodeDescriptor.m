// isim Core Image barcode descriptors: a symbol's error-corrected codewords and its parameters; CIBarcodeGenerator
// draws them (CIFiltersGenerator.m). PDF417 payloads hold each codeword (0...928) as a big-endian 16-bit value; Aztec
// payloads hold the codeword bits (data then check words) packed MSB first.
#import "CIInternal.h"

@implementation CIBarcodeDescriptor
+ (BOOL)supportsSecureCoding { return YES; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [super init]; }
@end

@implementation CIQRCodeDescriptor
+ (instancetype)descriptorWithPayload:(NSData *)p symbolVersion:(NSInteger)v maskPattern:(uint8_t)m errorCorrectionLevel:(CIQRCodeErrorCorrectionLevel)l {
    return [[self alloc] initWithPayload:p symbolVersion:v maskPattern:m errorCorrectionLevel:l];
}
- (instancetype)initWithPayload:(NSData *)p symbolVersion:(NSInteger)v maskPattern:(uint8_t)m errorCorrectionLevel:(CIQRCodeErrorCorrectionLevel)l {
    if (!p.length || v < 1 || v > 40 || m > 7 || (l != 'L' && l != 'M' && l != 'Q' && l != 'H')) return nil;
    if ((self = [super init])) { _errorCorrectedPayload = [p copy]; _symbolVersion = v; _maskPattern = m; _errorCorrectionLevel = l; }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:_errorCorrectedPayload forKey:@"payload"]; [c encodeInteger:_symbolVersion forKey:@"version"];
    [c encodeInteger:_maskPattern forKey:@"mask"]; [c encodeInteger:_errorCorrectionLevel forKey:@"level"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    return [self initWithPayload:[c decodeObjectOfClass:[NSData class] forKey:@"payload"] symbolVersion:[c decodeIntegerForKey:@"version"]
                     maskPattern:(uint8_t)[c decodeIntegerForKey:@"mask"] errorCorrectionLevel:[c decodeIntegerForKey:@"level"]];
}
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[CIQRCodeDescriptor class]]) return NO;
    CIQRCodeDescriptor *d = o;
    return [d.errorCorrectedPayload isEqual:_errorCorrectedPayload] && d.symbolVersion == _symbolVersion && d.maskPattern == _maskPattern && d.errorCorrectionLevel == _errorCorrectionLevel;
}
- (NSUInteger)hash { return _errorCorrectedPayload.hash ^ (NSUInteger)_symbolVersion; }
- (NSString *)description { return [NSString stringWithFormat:@"<CIQRCodeDescriptor: %p> version %ld mask %d level %c, %lu codewords", self, (long)_symbolVersion, _maskPattern, (char)_errorCorrectionLevel, (unsigned long)_errorCorrectedPayload.length]; }
@end

@implementation CIAztecCodeDescriptor
+ (instancetype)descriptorWithPayload:(NSData *)p isCompact:(BOOL)c layerCount:(NSInteger)l dataCodewordCount:(NSInteger)d {
    return [[self alloc] initWithPayload:p isCompact:c layerCount:l dataCodewordCount:d];
}
- (instancetype)initWithPayload:(NSData *)p isCompact:(BOOL)c layerCount:(NSInteger)l dataCodewordCount:(NSInteger)d {
    if (!p.length || l < 1 || l > (c ? 4 : 32) || d < 1 || d > (c ? 64 : 2048)) return nil;
    if ((self = [super init])) { _errorCorrectedPayload = [p copy]; _isCompact = c; _layerCount = l; _dataCodewordCount = d; }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:_errorCorrectedPayload forKey:@"payload"]; [c encodeBool:_isCompact forKey:@"compact"];
    [c encodeInteger:_layerCount forKey:@"layers"]; [c encodeInteger:_dataCodewordCount forKey:@"data"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    return [self initWithPayload:[c decodeObjectOfClass:[NSData class] forKey:@"payload"] isCompact:[c decodeBoolForKey:@"compact"]
                      layerCount:[c decodeIntegerForKey:@"layers"] dataCodewordCount:[c decodeIntegerForKey:@"data"]];
}
@end

@implementation CIPDF417CodeDescriptor
+ (instancetype)descriptorWithPayload:(NSData *)p isCompact:(BOOL)c rowCount:(NSInteger)r columnCount:(NSInteger)k {
    return [[self alloc] initWithPayload:p isCompact:c rowCount:r columnCount:k];
}
- (instancetype)initWithPayload:(NSData *)p isCompact:(BOOL)c rowCount:(NSInteger)r columnCount:(NSInteger)k {
    if (!p.length || r < 3 || r > 90 || k < 1 || k > 30) return nil;
    if ((self = [super init])) { _errorCorrectedPayload = [p copy]; _isCompact = c; _rowCount = r; _columnCount = k; }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:_errorCorrectedPayload forKey:@"payload"]; [c encodeBool:_isCompact forKey:@"compact"];
    [c encodeInteger:_rowCount forKey:@"rows"]; [c encodeInteger:_columnCount forKey:@"columns"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    return [self initWithPayload:[c decodeObjectOfClass:[NSData class] forKey:@"payload"] isCompact:[c decodeBoolForKey:@"compact"]
                        rowCount:[c decodeIntegerForKey:@"rows"] columnCount:[c decodeIntegerForKey:@"columns"]];
}
@end

@implementation CIDataMatrixCodeDescriptor
+ (instancetype)descriptorWithPayload:(NSData *)p rowCount:(NSInteger)r columnCount:(NSInteger)c eccVersion:(CIDataMatrixCodeECCVersion)v {
    return [[self alloc] initWithPayload:p rowCount:r columnCount:c eccVersion:v];
}
- (instancetype)initWithPayload:(NSData *)p rowCount:(NSInteger)r columnCount:(NSInteger)c eccVersion:(CIDataMatrixCodeECCVersion)v {
    if (!p.length || r < 8 || r > 144 || c < 10 || c > 144) return nil;
    if ((self = [super init])) { _errorCorrectedPayload = [p copy]; _rowCount = r; _columnCount = c; _eccVersion = v; }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:_errorCorrectedPayload forKey:@"payload"]; [c encodeInteger:_rowCount forKey:@"rows"];
    [c encodeInteger:_columnCount forKey:@"columns"]; [c encodeInteger:_eccVersion forKey:@"ecc"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    return [self initWithPayload:[c decodeObjectOfClass:[NSData class] forKey:@"payload"] rowCount:[c decodeIntegerForKey:@"rows"]
                     columnCount:[c decodeIntegerForKey:@"columns"] eccVersion:[c decodeIntegerForKey:@"ecc"]];
}
@end
