/* isim Foundation (ARC): NSXMLParser. Adapted: the host's libxml2 SAX parser reads the whole document
   (isim_xml_sax, host_xml.c), and its callbacks, recorded with their line and column, are replayed to the delegate
   with Apple's naming rules (shouldProcessNamespaces, shouldReportNamespacePrefixes). Parsing stops at the first
   error, or when the delegate calls abortParsing. External entities are never loaded from the network. */
#import <Foundation/Foundation.h>
#include <isim_host.h>
#include <stdlib.h>
#include <string.h>

NSErrorDomain const NSXMLParserErrorDomain = @"NSXMLParserErrorDomain";

@implementation NSXMLParser {
    NSData *_data;
    NSInputStream *_stream;
    __unsafe_unretained id<NSXMLParserDelegate> _delegate;
    NSError *_parserError;
    NSInteger _line, _column;
    BOOL _parsing, _aborted;
}
@synthesize delegate = _delegate, parserError = _parserError;
- (NSInteger)lineNumber { return _line; }
- (NSInteger)columnNumber { return _column; }

- (instancetype)init { return [self initWithData:[NSData data]]; }
- (instancetype)initWithData:(NSData *)data {
    if ((self = [super init])) { _data = [data copy] ?: [NSData data]; _line = 1; }
    return self;
}
- (instancetype)initWithContentsOfURL:(NSURL *)url {
    NSData *d = [NSData dataWithContentsOfURL:url];
    return d ? [self initWithData:d] : nil;
}
- (instancetype)initWithStream:(NSInputStream *)stream {
    if ((self = [self initWithData:[NSData data]])) _stream = stream;
    return self;
}
- (NSString *)publicID { return nil; }
- (NSString *)systemID { return nil; }
- (void)abortParsing { if (_parsing) _aborted = YES; }

/* the stream's bytes, read to its end */
- (NSData *)readStream {
    NSMutableData *all = [NSMutableData data];
    if (_stream.streamStatus == NSStreamStatusNotOpen) [_stream open];
    uint8_t buf[16384];
    NSInteger n;
    while ((n = [_stream read:buf maxLength:sizeof buf]) > 0) [all appendBytes:buf length:(NSUInteger)n];
    [_stream close];
    return all;
}

static NSString *str(const char *s, size_t n) {
    return [[NSString alloc] initWithBytes:s length:n encoding:NSUTF8StringEncoding] ?: @"";
}
static NSString *qualified(NSString *prefix, NSString *local) { return prefix.length ? [NSString stringWithFormat:@"%@:%@", prefix, local] : local; }
static NSString *orNil(NSString *s) { return s.length ? s : nil; }

- (void)fail:(NSInteger)code message:(NSString *)message tell:(BOOL)tell {
    _parserError = [NSError errorWithDomain:NSXMLParserErrorDomain code:code userInfo:@{
        @"NSXMLParserErrorLineNumber": @(_line), @"NSXMLParserErrorColumn": @(_column),
        @"NSXMLParserErrorMessage": message ?: @"" }];
    if (tell && [_delegate respondsToSelector:@selector(parser:parseErrorOccurred:)]) [_delegate parser:self parseErrorOccurred:_parserError];
}

- (BOOL)parse {
    if (_parsing) return NO;
    _parsing = YES; _aborted = NO; _parserError = nil;
    NSData *xml = _stream ? [self readStream] : _data;
    int flags = (_shouldResolveExternalEntities || _externalEntityResolvingPolicy != NSXMLParserResolveExternalEntitiesNever) ? 1 : 0;
    long cap = (long)xml.length * 2 + 4096;
    char *buf = malloc((size_t)cap);
    long n = isim_xml_sax(xml.bytes ?: "", (long)xml.length, flags, buf, cap);
    if (n >= cap) { free(buf); cap = n + 1; buf = malloc((size_t)cap); n = isim_xml_sax(xml.bytes ?: "", (long)xml.length, flags, buf, cap); }
    BOOL ok;
    if (n < 0) { [self fail:NSXMLParserInternalError message:@"libxml2 is not installed on the host" tell:YES]; ok = NO; }
    else ok = [self replay:buf length:(size_t)n];
    free(buf);
    _parsing = NO;
    return ok;
}

/* the records of host_xml.c, replayed to the delegate */
- (BOOL)replay:(const char *)buf length:(size_t)len {
    id<NSXMLParserDelegate> d = _delegate;
    BOOL ns = _shouldProcessNamespaces, prefixes = _shouldReportNamespacePrefixes;
    NSMutableArray<NSArray<NSString *> *> *declared = [NSMutableArray array];     /* the prefixes each open element maps */
    const char *p = buf, *end = buf + len;
    while (p < end && !_aborted) {
        const char *rec_end = memchr(p, '\x1e', (size_t)(end - p));
        if (!rec_end) break;
        char type = *p;
        NSMutableArray<NSString *> *f = [NSMutableArray array];
        for (const char *q = p + 1; q <= rec_end;) {
            const char *sep = q;
            while (sep < rec_end && *sep != '\x1f') sep++;
            [f addObject:str(q, (size_t)(sep - q))];
            q = sep + 1;
        }
        p = rec_end + 1;
        if (f.count < 2) continue;
        _line = f[0].integerValue; _column = f[1].integerValue;
        NSUInteger i = 2;
#define F(k) (i + (k) < f.count ? f[i + (k)] : @"")
        switch (type) {
        case 'D': if ([d respondsToSelector:@selector(parserDidStartDocument:)]) [d parserDidStartDocument:self]; break;
        case 'd': if ([d respondsToSelector:@selector(parserDidEndDocument:)]) [d parserDidEndDocument:self]; break;
        case 'S': {
            NSString *local = F(0), *prefix = F(1), *uri = F(2);
            NSInteger nns = F(3).integerValue;
            i += 4;
            NSMutableDictionary<NSString *, NSString *> *attrs = [NSMutableDictionary dictionary];
            NSMutableArray<NSString *> *mapped = [NSMutableArray array];
            for (NSInteger k = 0; k < nns; k++, i += 2) {
                NSString *pre = F(0), *u = F(1);
                [mapped addObject:pre];
                if (!ns) attrs[pre.length ? [@"xmlns:" stringByAppendingString:pre] : @"xmlns"] = u;
                if (prefixes && [d respondsToSelector:@selector(parser:didStartMappingPrefix:toURI:)]) [d parser:self didStartMappingPrefix:pre toURI:u];
                if (_aborted) break;
            }
            [declared addObject:mapped];
            NSInteger natt = F(0).integerValue;
            i += 1;
            for (NSInteger k = 0; k < natt; k++, i += 4) attrs[qualified(F(1), F(0))] = F(3);
            if (_aborted) break;
            NSString *qname = qualified(prefix, local);
            if ([d respondsToSelector:@selector(parser:didStartElement:namespaceURI:qualifiedName:attributes:)])
                [d parser:self didStartElement:ns ? local : qname namespaceURI:ns ? orNil(uri) : nil qualifiedName:ns ? qname : nil attributes:attrs];
            break;
        }
        case 'E': {
            NSString *local = F(0), *qname = qualified(F(1), F(0));
            if ([d respondsToSelector:@selector(parser:didEndElement:namespaceURI:qualifiedName:)])
                [d parser:self didEndElement:ns ? local : qname namespaceURI:ns ? orNil(F(2)) : nil qualifiedName:ns ? qname : nil];
            NSArray<NSString *> *mapped = declared.lastObject;
            if (declared.count) [declared removeLastObject];
            if (prefixes && [d respondsToSelector:@selector(parser:didEndMappingPrefix:)])
                for (NSString *pre in mapped) { if (_aborted) break; [d parser:self didEndMappingPrefix:pre]; }
            break;
        }
        case 'T': if ([d respondsToSelector:@selector(parser:foundCharacters:)]) [d parser:self foundCharacters:F(0)]; break;
        case 'A':
            if ([d respondsToSelector:@selector(parser:foundCDATA:)]) [d parser:self foundCDATA:[F(0) dataUsingEncoding:NSUTF8StringEncoding]];
            break;
        case 'C': if ([d respondsToSelector:@selector(parser:foundComment:)]) [d parser:self foundComment:F(0)]; break;
        case 'P':
            if ([d respondsToSelector:@selector(parser:foundProcessingInstructionWithTarget:data:)])
                [d parser:self foundProcessingInstructionWithTarget:F(0) data:F(1)];
            break;
        case 'L':
            if ([d respondsToSelector:@selector(parser:foundElementDeclarationWithName:model:)]) [d parser:self foundElementDeclarationWithName:F(0) model:F(1)];
            break;
        case 'B':
            if ([d respondsToSelector:@selector(parser:foundAttributeDeclarationWithName:forElement:type:defaultValue:)])
                [d parser:self foundAttributeDeclarationWithName:F(1) forElement:F(0) type:orNil(F(2)) defaultValue:orNil(F(3))];
            break;
        case 'N':
            if ([d respondsToSelector:@selector(parser:foundNotationDeclarationWithName:publicID:systemID:)])
                [d parser:self foundNotationDeclarationWithName:F(0) publicID:orNil(F(1)) systemID:orNil(F(2))];
            break;
        case 'U':
            if ([d respondsToSelector:@selector(parser:foundUnparsedEntityDeclarationWithName:publicID:systemID:notationName:)])
                [d parser:self foundUnparsedEntityDeclarationWithName:F(0) publicID:orNil(F(1)) systemID:orNil(F(2)) notationName:orNil(F(3))];
            break;
        case 'I':
            if ([d respondsToSelector:@selector(parser:foundInternalEntityDeclarationWithName:value:)])
                [d parser:self foundInternalEntityDeclarationWithName:F(0) value:F(1)];
            break;
        case 'J':
            if ([d respondsToSelector:@selector(parser:foundExternalEntityDeclarationWithName:publicID:systemID:)])
                [d parser:self foundExternalEntityDeclarationWithName:F(0) publicID:orNil(F(1)) systemID:orNil(F(2))];
            break;
        case 'X':
            [self fail:F(0).integerValue message:F(1) tell:YES];
            return NO;
        }
#undef F
    }
    if (_aborted) { [self fail:NSXMLParserDelegateAbortedParseError message:@"the delegate aborted the parse" tell:NO]; return NO; }
    return YES;
}
@end
