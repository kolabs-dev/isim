/* isim Accessibility: AXCustomContent (ARC). isim's VoiceOver (UIKit) reads it from an element's
   accessibilityCustomContent (AXCustomContentProvider) or accessibilityCustomContentBlock. */
#import <Accessibility/Accessibility.h>

@implementation AXCustomContent
- (instancetype)initWithAttributedLabel:(NSAttributedString *)label attributedValue:(NSAttributedString *)value {
    if ((self = [super init])) { _attributedLabel = [label copy] ?: [NSAttributedString new]; _attributedValue = [value copy] ?: [NSAttributedString new]; }
    return self;
}
+ (instancetype)customContentWithLabel:(NSString *)label value:(NSString *)value {
    return [[self alloc] initWithAttributedLabel:[[NSAttributedString alloc] initWithString:label ?: @""] attributedValue:[[NSAttributedString alloc] initWithString:value ?: @""]];
}
+ (instancetype)customContentWithAttributedLabel:(NSAttributedString *)label attributedValue:(NSAttributedString *)value {
    return [[self alloc] initWithAttributedLabel:label attributedValue:value];
}
- (NSString *)label { return _attributedLabel.string; }
- (NSString *)value { return _attributedValue.string; }
- (id)copyWithZone:(NSZone *)zone {
    AXCustomContent *c = [[AXCustomContent alloc] initWithAttributedLabel:_attributedLabel attributedValue:_attributedValue];
    c.importance = _importance;
    return c;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_attributedLabel forKey:@"label"];
    [coder encodeObject:_attributedValue forKey:@"value"];
    [coder encodeInteger:(NSInteger)_importance forKey:@"importance"];
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    NSAttributedString *l = [coder decodeObjectOfClass:[NSAttributedString class] forKey:@"label"], *v = [coder decodeObjectOfClass:[NSAttributedString class] forKey:@"value"];
    if ((self = [self initWithAttributedLabel:l attributedValue:v])) _importance = (AXCustomContentImportance)[coder decodeIntegerForKey:@"importance"];
    return self;
}
- (NSString *)description { return [NSString stringWithFormat:@"<AXCustomContent %@: %@%@>", self.label, self.value, _importance == AXCustomContentImportanceHigh ? @" (high)" : @""]; }
@end
