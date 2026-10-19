/* Configuration states, cell and supplementary registrations and window scene placements for Objective-C (issue #235).
 * Swift apps use the UIKit overlay's structs and generic registrations; these are Apple's Objective-C classes. The
 * cells run -_isim_runConfigurationUpdate before their next layout when their state changes (UICollectionView.m,
 * UITableView.m): -updateConfigurationUsingState: (empty by default: the override point), then the
 * configurationUpdateHandler with the same state, as UIKit does. */
#import "UIKitPrivate.h"
#import <UIKit/UIConfigurationState.h>
#import <objc/runtime.h>
/* setNeedsUpdateConfiguration is the cells' own (UITableView.m) */
#pragma clang diagnostic ignored "-Wincomplete-implementation"

/* ================= states ================= */
@implementation UIViewConfigurationState { NSMutableDictionary *_custom; }
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithTraitCollection:(UITraitCollection *)traitCollection {
    if ((self = [super init])) { _traitCollection = traitCollection ?: UITraitCollection.currentTraitCollection; _custom = [NSMutableDictionary dictionary]; }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [self initWithTraitCollection:UITraitCollection.currentTraitCollection])) {
        _disabled = [coder decodeBoolForKey:@"disabled"]; _highlighted = [coder decodeBoolForKey:@"highlighted"];
        _selected = [coder decodeBoolForKey:@"selected"]; _focused = [coder decodeBoolForKey:@"focused"]; _pinned = [coder decodeBoolForKey:@"pinned"];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeBool:_disabled forKey:@"disabled"]; [coder encodeBool:_highlighted forKey:@"highlighted"];
    [coder encodeBool:_selected forKey:@"selected"]; [coder encodeBool:_focused forKey:@"focused"]; [coder encodeBool:_pinned forKey:@"pinned"];
}
- (id)copyWithZone:(NSZone *)zone {
    UIViewConfigurationState *c = [[[self class] allocWithZone:zone] initWithTraitCollection:_traitCollection];
    c->_disabled = _disabled; c->_highlighted = _highlighted; c->_selected = _selected; c->_focused = _focused; c->_pinned = _pinned;
    c->_custom = [_custom mutableCopy];
    return c;
}
- (id)customStateForKey:(UIConfigurationStateCustomKey)key { return _custom[key]; }
- (void)setCustomState:(id)state forKey:(UIConfigurationStateCustomKey)key { if (state) _custom[key] = state; else [_custom removeObjectForKey:key]; }
- (id)objectForKeyedSubscript:(UIConfigurationStateCustomKey)key { return _custom[key]; }
- (void)setObject:(id)obj forKeyedSubscript:(UIConfigurationStateCustomKey)key { [self setCustomState:obj forKey:key]; }
- (NSDictionary *)_isim_custom { return [_custom copy]; }
- (void)_isim_setCustom:(NSDictionary *)custom { _custom = [custom mutableCopy] ?: [NSMutableDictionary dictionary]; }
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[UIViewConfigurationState class]]) return NO;
    UIViewConfigurationState *s = o;
    return s.disabled == _disabled && s.highlighted == _highlighted && s.selected == _selected && s.focused == _focused && s.pinned == _pinned &&
           [s._isim_custom isEqualToDictionary:_custom];
}
- (NSUInteger)hash { return (_disabled << 0) | (_highlighted << 1) | (_selected << 2) | (_focused << 3) | (_pinned << 4) | (_custom.count << 5); }
- (NSString *)_isim_flags {
    NSMutableArray *f = [NSMutableArray array];
    if (_disabled) [f addObject:@"disabled"]; if (_highlighted) [f addObject:@"highlighted"]; if (_selected) [f addObject:@"selected"];
    if (_focused) [f addObject:@"focused"]; if (_pinned) [f addObject:@"pinned"];
    return [f componentsJoinedByString:@", "];
}
- (NSString *)description { return [NSString stringWithFormat:@"<%@: %p; %@>", NSStringFromClass([self class]), self, self._isim_flags]; }
@end

@implementation UICellConfigurationState
- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        _editing = [coder decodeBoolForKey:@"editing"]; _expanded = [coder decodeBoolForKey:@"expanded"]; _swiped = [coder decodeBoolForKey:@"swiped"];
        _reordering = [coder decodeBoolForKey:@"reordering"]; _cellDragState = [coder decodeIntegerForKey:@"drag"]; _cellDropState = [coder decodeIntegerForKey:@"drop"];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeBool:_editing forKey:@"editing"]; [coder encodeBool:_expanded forKey:@"expanded"]; [coder encodeBool:_swiped forKey:@"swiped"];
    [coder encodeBool:_reordering forKey:@"reordering"]; [coder encodeInteger:_cellDragState forKey:@"drag"]; [coder encodeInteger:_cellDropState forKey:@"drop"];
}
- (id)copyWithZone:(NSZone *)zone {
    UICellConfigurationState *c = [super copyWithZone:zone];
    c->_editing = _editing; c->_expanded = _expanded; c->_swiped = _swiped; c->_reordering = _reordering;
    c->_cellDragState = _cellDragState; c->_cellDropState = _cellDropState;
    return c;
}
- (BOOL)isEqual:(id)o {
    if (![super isEqual:o] || ![o isKindOfClass:[UICellConfigurationState class]]) return NO;
    UICellConfigurationState *s = o;
    return s.editing == _editing && s.expanded == _expanded && s.swiped == _swiped && s.reordering == _reordering &&
           s.cellDragState == _cellDragState && s.cellDropState == _cellDropState;
}
- (NSString *)_isim_flags {
    NSMutableArray *f = [NSMutableArray arrayWithObject:[super _isim_flags]];
    if (_editing) [f addObject:@"editing"]; if (_expanded) [f addObject:@"expanded"]; if (_swiped) [f addObject:@"swiped"];
    if (_reordering) [f addObject:@"reordering"];
    return [f componentsJoinedByString:@", "];
}
@end

/* the state a cell is in, for -configurationState and isim_ui_content_configuration_for_state */
UICellConfigurationState *isim_ui_cell_state(UIView *cell, BOOL selected, BOOL highlighted, BOOL editing, BOOL swiped, BOOL expanded) {
    UICellConfigurationState *s = [[UICellConfigurationState alloc] initWithTraitCollection:cell.traitCollection];
    s.selected = selected; s.highlighted = highlighted; s.editing = editing; s.swiped = swiped; s.expanded = expanded;
    s.disabled = !cell.userInteractionEnabled;
    return s;
}

/* configurations an Objective-C app re-derives itself keep their values; the list and background ones have no
   state-dependent styling of their own in isim yet */
@implementation UIListContentConfiguration (UIConfigurationStateUpdates)
- (instancetype)updatedConfigurationForState:(id<UIConfigurationState>)state { return [self copy]; }
@end
@implementation UIBackgroundConfiguration (UIConfigurationStateUpdates)
- (instancetype)updatedConfigurationForState:(id<UIConfigurationState>)state { return [self copy]; }
@end

/* ================= the cells ================= */
static char kUpdateHandler;
@interface UICollectionViewCell (IsimStates)
- (BOOL)_isim_expandedState;
- (BOOL)_isim_swipedState;
@property (nonatomic, weak) UICollectionView *_isim_cv;
@end
@implementation UICollectionViewCell (UIConfigurationState)
- (UICellConfigurationState *)configurationState {
    return isim_ui_cell_state(self, self.selected, self.highlighted, self._isim_cv.isEditing, [self _isim_swipedState], [self _isim_expandedState]);
}
- (void)updateConfigurationUsingState:(UICellConfigurationState *)state {}
- (void)_isim_runConfigurationUpdate {
    UICellConfigurationState *state = self.configurationState;
    [self updateConfigurationUsingState:state];
    UICollectionViewCellConfigurationUpdateHandler h = objc_getAssociatedObject(self, &kUpdateHandler);
    if (h) h(self, state);
}
- (UICollectionViewCellConfigurationUpdateHandler)configurationUpdateHandler { return objc_getAssociatedObject(self, &kUpdateHandler); }
- (void)setConfigurationUpdateHandler:(UICollectionViewCellConfigurationUpdateHandler)h {
    objc_setAssociatedObject(self, &kUpdateHandler, h, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self setNeedsUpdateConfiguration];
}
- (UIBackgroundConfiguration *)defaultBackgroundConfiguration {
    return [self isKindOfClass:[UICollectionViewListCell class]] ? [UIBackgroundConfiguration listGroupedCellConfiguration] : [UIBackgroundConfiguration clearConfiguration];
}
@end

@interface UITableViewCell (IsimStates)
@property (nonatomic) CGFloat _isim_swipe;
@end
@implementation UITableViewCell (UIConfigurationState)
- (UICellConfigurationState *)configurationState {
    return isim_ui_cell_state(self, self.selected, self.highlighted, self.editing, self._isim_swipe != 0, NO);
}
- (void)updateConfigurationUsingState:(UICellConfigurationState *)state {}
- (void)_isim_runConfigurationUpdate {
    UICellConfigurationState *state = self.configurationState;
    [self updateConfigurationUsingState:state];
    UITableViewCellConfigurationUpdateHandler h = objc_getAssociatedObject(self, &kUpdateHandler);
    if (h) h(self, state);
}
- (UITableViewCellConfigurationUpdateHandler)configurationUpdateHandler { return objc_getAssociatedObject(self, &kUpdateHandler); }
- (void)setConfigurationUpdateHandler:(UITableViewCellConfigurationUpdateHandler)h {
    objc_setAssociatedObject(self, &kUpdateHandler, h, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self setNeedsUpdateConfiguration];
}
@end

@implementation UITableViewHeaderFooterView (UIConfigurationState)
- (UIViewConfigurationState *)configurationState {
    UIViewConfigurationState *s = [[UIViewConfigurationState alloc] initWithTraitCollection:self.traitCollection];
    s.disabled = !self.userInteractionEnabled;
    return s;
}
- (void)updateConfigurationUsingState:(UIViewConfigurationState *)state {}
- (void)_isim_runConfigurationUpdate {
    UIViewConfigurationState *state = self.configurationState;
    [self updateConfigurationUsingState:state];
    UITableViewHeaderFooterViewConfigurationUpdateHandler h = objc_getAssociatedObject(self, &kUpdateHandler);
    if (h) h(self, state);
}
- (UITableViewHeaderFooterViewConfigurationUpdateHandler)configurationUpdateHandler { return objc_getAssociatedObject(self, &kUpdateHandler); }
- (void)setConfigurationUpdateHandler:(UITableViewHeaderFooterViewConfigurationUpdateHandler)h {
    objc_setAssociatedObject(self, &kUpdateHandler, h, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self setNeedsUpdateConfiguration];
}
@end

/* ================= registrations ================= */
static NSString *registration_id(id registration) { return [NSString stringWithFormat:@"_isim.registration.%p", registration]; }

@implementation UICollectionViewCellRegistration
+ (instancetype)registrationWithCellClass:(Class)cellClass configurationHandler:(UICollectionViewCellRegistrationConfigurationHandler)handler {
    UICollectionViewCellRegistration *r = [self new];
    r->_cellClass = cellClass; r->_configurationHandler = [handler copy];
    return r;
}
+ (instancetype)registrationWithCellNib:(UINib *)cellNib configurationHandler:(UICollectionViewCellRegistrationConfigurationHandler)handler {
    UICollectionViewCellRegistration *r = [self new];
    r->_cellNib = cellNib; r->_configurationHandler = [handler copy];
    return r;
}
@end

@implementation UICollectionViewSupplementaryRegistration
+ (instancetype)registrationWithSupplementaryClass:(Class)cls elementKind:(NSString *)kind
                              configurationHandler:(UICollectionViewSupplementaryRegistrationConfigurationHandler)handler {
    UICollectionViewSupplementaryRegistration *r = [self new];
    r->_supplementaryClass = cls; r->_elementKind = [kind copy]; r->_configurationHandler = [handler copy];
    return r;
}
+ (instancetype)registrationWithSupplementaryNib:(UINib *)nib elementKind:(NSString *)kind
                            configurationHandler:(UICollectionViewSupplementaryRegistrationConfigurationHandler)handler {
    UICollectionViewSupplementaryRegistration *r = [self new];
    r->_supplementaryNib = nib; r->_elementKind = [kind copy]; r->_configurationHandler = [handler copy];
    return r;
}
@end

static char kRegistered;
@implementation UICollectionView (UICollectionViewRegistrations)
/* each registration registers its class (or nib) once per collection view, under its own reuse identifier */
- (BOOL)_isim_registerOnce:(NSString *)rid {
    NSMutableSet *done = objc_getAssociatedObject(self, &kRegistered);
    if (!done) { done = [NSMutableSet set]; objc_setAssociatedObject(self, &kRegistered, done, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    if ([done containsObject:rid]) return NO;
    [done addObject:rid];
    return YES;
}
- (__kindof UICollectionViewCell *)dequeueConfiguredReusableCellWithRegistration:(UICollectionViewCellRegistration *)registration
                                                                    forIndexPath:(NSIndexPath *)indexPath item:(id)item {
    NSString *rid = registration_id(registration);
    if ([self _isim_registerOnce:rid]) {
        if (registration.cellNib) [self registerNib:registration.cellNib forCellWithReuseIdentifier:rid];
        else [self registerClass:registration.cellClass forCellWithReuseIdentifier:rid];
    }
    UICollectionViewCell *cell = [self dequeueReusableCellWithReuseIdentifier:rid forIndexPath:indexPath];
    registration.configurationHandler(cell, indexPath, item);
    return cell;
}
- (__kindof UICollectionReusableView *)dequeueConfiguredReusableSupplementaryViewWithRegistration:(UICollectionViewSupplementaryRegistration *)registration
                                                                                     forIndexPath:(NSIndexPath *)indexPath {
    NSString *rid = registration_id(registration);
    if ([self _isim_registerOnce:rid]) {
        if (registration.supplementaryNib) [self registerNib:registration.supplementaryNib forSupplementaryViewOfKind:registration.elementKind withReuseIdentifier:rid];
        else [self registerClass:registration.supplementaryClass forSupplementaryViewOfKind:registration.elementKind withReuseIdentifier:rid];
    }
    UICollectionReusableView *view = [self dequeueReusableSupplementaryViewOfKind:registration.elementKind withReuseIdentifier:rid forIndexPath:indexPath];
    registration.configurationHandler(view, registration.elementKind, indexPath);
    return view;
}
@end

/* ================= window scene placements ================= */
@implementation UIWindowScenePlacement
- (instancetype)_isim_init { return [super init]; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (BOOL)isEqual:(id)o { return [o class] == [self class]; }
- (NSUInteger)hash { return [NSStringFromClass([self class]) hash]; }
@end
@implementation UIWindowSceneStandardPlacement
+ (instancetype)standardPlacement { return [[self alloc] _isim_init]; }
@end
@implementation UIWindowSceneProminentPlacement
+ (instancetype)prominentPlacement { return [[self alloc] _isim_init]; }
@end
/* isim: the placement is the presentation style, as in the Swift overlay (prominent: the whole screen; standard: side by side) */
@implementation UIWindowSceneActivationRequestOptions (UIWindowScenePlacement)
- (UIWindowScenePlacement *)placement {
    switch (self.preferredPresentationStyle) {
    case UIWindowScenePresentationStyleProminent: return [UIWindowSceneProminentPlacement prominentPlacement];
    case UIWindowScenePresentationStyleStandard: return [UIWindowSceneStandardPlacement standardPlacement];
    default: return nil;
    }
}
- (void)setPlacement:(UIWindowScenePlacement *)placement {
    self.preferredPresentationStyle = [placement isKindOfClass:[UIWindowSceneProminentPlacement class]] ? UIWindowScenePresentationStyleProminent
        : [placement isKindOfClass:[UIWindowSceneStandardPlacement class]] ? UIWindowScenePresentationStyleStandard : UIWindowScenePresentationStyleAutomatic;
}
@end
