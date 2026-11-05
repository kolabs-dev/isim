#pragma once
/* isim AudioToolbox for Objective-C: Audio Unit version 3 (Apple's AUAudioUnit.h, AUParameters.h and
 * AUAudioUnitImplementation.h). The classes are the AudioToolbox Swift overlay's (swift/overlays/AudioToolbox/
 * AUAudioUnit.swift); the members that take AVAudioFormat or UIViewController are AVFoundation's
 * (AVFoundation/AUAudioUnitFormats.swift) and need AVFoundation loaded. The block types and enums are those of
 * <_AudioToolboxTypes/AudioToolboxDecls.h>. Hidden from Swift, which uses the AudioToolbox module. */
#include <AudioToolbox/AudioToolboxBase.h>
#include <AudioToolbox/AudioComponent.h>
#if !defined(__swift__) && defined(__OBJC__)
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@class AVAudioFormat, UIViewController, AUAudioUnitBusArray, AUAudioUnitBus, AUAudioUnitPreset, AUParameterTree, AUParameter, AUParameterNode;
@protocol AUMessageChannel;

/* ---- AUParameters.h ---- */
typedef void (^AUImplementorValueObserver)(AUParameter *param, AUValue value);
typedef AUValue (^AUImplementorValueProvider)(AUParameter *param);
typedef NSString *_Nonnull (^AUImplementorStringFromValueCallback)(AUParameter *param, const AUValue *_Nullable value);
typedef AUValue (^AUImplementorValueFromStringCallback)(AUParameter *param, NSString *string);
typedef NSString *_Nonnull (^AUImplementorDisplayNameWithLengthCallback)(AUParameterNode *node, NSInteger desiredLength);

@interface AUParameterNode : NSObject <NSSecureCoding>
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSString *keyPath;
@property (nonatomic, readonly, copy) NSString *displayName;
- (NSString *)displayNameWithLength:(NSInteger)maximumLength;
- (AUParameterObserverToken)tokenByAddingParameterObserver:(AUParameterObserver)observer;
- (AUParameterObserverToken)tokenByAddingParameterRecordingObserver:(AUParameterRecordingObserver)observer;
- (AUParameterObserverToken)tokenByAddingParameterAutomationObserver:(AUParameterAutomationObserver)observer;
- (void)removeParameterObserver:(AUParameterObserverToken)token;
@property (nonatomic, copy) AUImplementorValueObserver implementorValueObserver;
@property (nonatomic, copy) AUImplementorValueProvider implementorValueProvider;
@property (nonatomic, copy) AUImplementorStringFromValueCallback implementorStringFromValueCallback;
@property (nonatomic, copy) AUImplementorValueFromStringCallback implementorValueFromStringCallback;
@property (nonatomic, copy) AUImplementorDisplayNameWithLengthCallback implementorDisplayNameWithLengthCallback;
@end

@interface AUParameterGroup : AUParameterNode <NSSecureCoding>
@property (nonatomic, readonly) NSArray<AUParameterNode *> *children;
@property (nonatomic, readonly) NSArray<AUParameter *> *allParameters;
@end

@interface AUParameterTree : AUParameterGroup <NSSecureCoding>
- (nullable AUParameter *)parameterWithAddress:(AUParameterAddress)address;
- (nullable AUParameter *)parameterWithID:(AudioUnitParameterID)paramID scope:(AudioUnitScope)scope element:(AudioUnitElement)element;
+ (AUParameter *)createParameterWithIdentifier:(NSString *)identifier name:(NSString *)name address:(AUParameterAddress)address
                                           min:(AUValue)min max:(AUValue)max unit:(AudioUnitParameterUnit)unit unitName:(nullable NSString *)unitName
                                         flags:(AudioUnitParameterOptions)flags valueStrings:(nullable NSArray<NSString *> *)valueStrings
                           dependentParameters:(nullable NSArray<NSNumber *> *)dependentParameters;
+ (AUParameterGroup *)createGroupWithIdentifier:(NSString *)identifier name:(NSString *)name children:(NSArray<AUParameterNode *> *)children;
+ (AUParameterGroup *)createGroupTemplate:(NSArray<AUParameterNode *> *)children;
+ (AUParameterGroup *)createGroupFromTemplate:(AUParameterGroup *)templateGroup identifier:(NSString *)identifier name:(NSString *)name
                                addressOffset:(AUParameterAddress)addressOffset;
+ (AUParameterTree *)createTreeWithChildren:(NSArray<AUParameterNode *> *)children;
@end

@interface AUParameter : AUParameterNode <NSSecureCoding>
@property (nonatomic, readonly) AUValue minValue;
@property (nonatomic, readonly) AUValue maxValue;
@property (nonatomic, readonly) AudioUnitParameterUnit unit;
@property (nonatomic, readonly, copy, nullable) NSString *unitName;
@property (nonatomic, readonly) AudioUnitParameterOptions flags;
@property (nonatomic, readonly) AUParameterAddress address;
@property (nonatomic, readonly, copy, nullable) NSArray<NSString *> *valueStrings;
@property (nonatomic, readonly, copy, nullable) NSArray<NSNumber *> *dependentParameters;
@property (nonatomic) AUValue value;
- (void)setValue:(AUValue)value originator:(AUParameterObserverToken _Nullable)originator;
- (void)setValue:(AUValue)value originator:(AUParameterObserverToken _Nullable)originator atHostTime:(uint64_t)hostTime;
- (void)setValue:(AUValue)value originator:(AUParameterObserverToken _Nullable)originator atHostTime:(uint64_t)hostTime
       eventType:(AUParameterAutomationEventType)eventType;
- (NSString *)stringFromValue:(const AUValue *_Nullable)value;
- (AUValue)valueFromString:(NSString *)string;
@end

/* ---- AUAudioUnit.h ---- */
@interface AUAudioUnitPreset : NSObject <NSSecureCoding>
@property (nonatomic) NSInteger number;
@property (nonatomic, copy) NSString *name;
@end

@interface AUAudioUnitViewConfiguration : NSObject <NSSecureCoding>
- (instancetype)initWithWidth:(CGFloat)width height:(CGFloat)height hostHasController:(BOOL)hostHasController;
@property (nonatomic, readonly) CGFloat width;
@property (nonatomic, readonly) CGFloat height;
@property (nonatomic, readonly) BOOL hostHasController;
@end

@interface AUAudioUnit : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription
                                              options:(AudioComponentInstantiationOptions)options error:(NSError **)outError;
- (nullable instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription error:(NSError **)outError;
+ (void)instantiateWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options
                          completionHandler:(void (^)(AUAudioUnit *_Nullable audioUnit, NSError *_Nullable error))completionHandler;
+ (void)registerSubclass:(Class)cls asComponentDescription:(AudioComponentDescription)componentDescription name:(NSString *)name
                 version:(UInt32)version;
@property (nonatomic, readonly) AudioComponentDescription componentDescription;
@property (nonatomic, readonly) AudioComponent component;
@property (nonatomic, readonly, copy, nullable) NSString *componentName;
@property (nonatomic, readonly, copy, nullable) NSString *audioUnitName;
@property (nonatomic, readonly, copy, nullable) NSString *manufacturerName;
@property (nonatomic, readonly, copy, nullable) NSString *audioUnitShortName;
@property (nonatomic, readonly) UInt32 componentVersion;
- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError;
- (void)deallocateRenderResources;
@property (nonatomic, readonly) BOOL renderResourcesAllocated;
- (void)reset;
@property (nonatomic, readonly) AUAudioUnitBusArray *inputBusses;
@property (nonatomic, readonly) AUAudioUnitBusArray *outputBusses;
@property (nonatomic, readonly) AURenderBlock renderBlock;
@property (nonatomic, readonly) AUScheduleParameterBlock scheduleParameterBlock;
- (NSInteger)tokenByAddingRenderObserver:(AURenderObserver)observer;
- (void)removeRenderObserver:(NSInteger)token;
@property (nonatomic) AUAudioFrameCount maximumFramesToRender;
@property (nonatomic, nullable) AUParameterTree *parameterTree;
- (NSArray<NSNumber *> *)parametersForOverviewWithCount:(NSInteger)count;
@property (nonatomic, readonly) BOOL allParameterValues;
@property (nonatomic, readonly, getter=isMusicDeviceOrEffect) BOOL musicDeviceOrEffect;
@property (nonatomic, readonly) NSInteger virtualMIDICableCount;
@property (nonatomic, readonly, nullable) AUScheduleMIDIEventBlock scheduleMIDIEventBlock;
@property (nonatomic, readonly, nullable) AUMIDIEventListBlock scheduleMIDIEventListBlock;
@property (nonatomic, readonly, copy, nullable) NSArray<NSString *> *MIDIOutputNames;
@property (nonatomic, readonly) BOOL providesUserInterface;
@property (nonatomic, copy, nullable) AUMIDIOutputEventBlock MIDIOutputEventBlock;
@property (nonatomic, copy, nullable) AUMIDIEventListBlock MIDIOutputEventListBlock;
@property (nonatomic) NSInteger MIDIOutputBufferSizeHint;
@property (nonatomic, readonly) MIDIProtocolID AudioUnitMIDIProtocol;
@property (nonatomic) MIDIProtocolID hostMIDIProtocol;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *fullState;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *fullStateForDocument;
@property (nonatomic, readonly, copy, nullable) NSArray<AUAudioUnitPreset *> *factoryPresets;
@property (nonatomic, readonly, copy) NSArray<AUAudioUnitPreset *> *userPresets;
- (BOOL)saveUserPreset:(AUAudioUnitPreset *)userPreset error:(NSError **)outError;
- (BOOL)deleteUserPreset:(AUAudioUnitPreset *)userPreset error:(NSError **)outError;
- (nullable NSDictionary<NSString *, id> *)presetStateFor:(AUAudioUnitPreset *)userPreset error:(NSError **)outError;
@property (nonatomic, readonly) BOOL supportsUserPresets;
@property (nonatomic, retain, nullable) AUAudioUnitPreset *currentPreset;
@property (nonatomic, readonly) NSTimeInterval latency;
@property (nonatomic, readonly) NSTimeInterval tailTime;
@property (nonatomic) NSInteger renderQuality;
@property (nonatomic) BOOL shouldBypassEffect;
@property (nonatomic, readonly) BOOL canProcessInPlace;
@property (nonatomic, getter=isRenderingOffline) BOOL renderingOffline;
@property (nonatomic, readonly, copy, nullable) NSArray<NSNumber *> *channelCapabilities;
@property (nonatomic, copy, nullable) AUHostMusicalContextBlock musicalContextBlock;
@property (nonatomic, copy, nullable) AUHostTransportStateBlock transportStateBlock;
@property (nonatomic, copy, nullable) NSString *contextName;
@property (nonatomic, readonly) BOOL supportsMPE;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *channelMap;
@property (nonatomic, readonly, copy) NSArray *migrateFromPlugin;
- (NSIndexSet *)supportedViewConfigurations:(NSArray<AUAudioUnitViewConfiguration *> *)availableViewConfigurations;
- (void)selectViewConfiguration:(AUAudioUnitViewConfiguration *)viewConfiguration;
- (id<AUMessageChannel>)messageChannelFor:(NSString *)channelName;
/* AVFoundation's (AUAudioUnitFormats.swift) */
- (BOOL)shouldChangeToFormat:(AVAudioFormat *)format forBus:(AUAudioUnitBus *)bus;
- (void)requestViewControllerWithCompletionHandler:(void (^)(UIViewController *_Nullable viewController))completionHandler;
@end

/* input and output units (AUAudioInputOutputUnit) */
@interface AUAudioUnit (AUAudioInputOutputUnit)
@property (nonatomic, readonly) BOOL canPerformInput;
@property (nonatomic, readonly) BOOL canPerformOutput;
@property (nonatomic, getter=isInputEnabled) BOOL inputEnabled;
@property (nonatomic, getter=isOutputEnabled) BOOL outputEnabled;
@property (nonatomic, copy, nullable) AURenderPullInputBlock outputProvider;
@property (nonatomic, copy, nullable) AUInputHandler inputHandler;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
- (BOOL)startHardwareAndReturnError:(NSError **)outError;
- (void)stopHardware;
@end

/* ---- AUAudioUnitImplementation.h: what a subclass provides ---- */
@interface AUAudioUnit (AUAudioUnitImplementation)
+ (void)registerSubclass:(Class)cls asComponentDescription:(AudioComponentDescription)componentDescription name:(NSString *)name
                 version:(UInt32)version;
@property (nonatomic, readonly) AUInternalRenderBlock internalRenderBlock;
- (void)setRenderResourcesAllocated:(BOOL)flag;
@end

@interface AUAudioUnitBusArray : NSObject <NSFastEnumeration>
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithAudioUnit:(AUAudioUnit *)owner busType:(AUAudioUnitBusType)busType busses:(NSArray<AUAudioUnitBus *> *)busArray;
- (instancetype)initWithAudioUnit:(AUAudioUnit *)owner busType:(AUAudioUnitBusType)busType;
@property (nonatomic, readonly) NSUInteger count;
- (AUAudioUnitBus *)objectAtIndexedSubscript:(NSUInteger)index;
@property (nonatomic, readonly, getter=isCountChangeable) BOOL countChangeable;
- (BOOL)setBusCount:(NSUInteger)count error:(NSError **)outError;
- (void)addObserverToAllBusses:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options
                       context:(void *_Nullable)context;
- (void)removeObserverFromAllBusses:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *_Nullable)context;
@property (nonatomic, readonly, assign) AUAudioUnit *ownerAudioUnit;
@property (nonatomic, readonly) AUAudioUnitBusType busType;
- (void)replaceBusses:(NSArray<AUAudioUnitBus *> *)busArray;
@end

@interface AUAudioUnitBus : NSObject
- (nullable instancetype)initWithFormat:(AVAudioFormat *)format error:(NSError **)outError;   /* AVFoundation's */
@property (nonatomic, readonly) AVAudioFormat *format;                               /* AVFoundation's */
- (BOOL)setFormat:(AVAudioFormat *)format error:(NSError **)outError;                           /* AVFoundation's */
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, readonly) NSUInteger index;
@property (nonatomic, readonly) AUAudioUnitBusType busType;
@property (nonatomic, readonly, assign) AUAudioUnit *ownerAudioUnit;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *supportedChannelLayoutTags;
@property (nonatomic) NSTimeInterval contextPresentationLatency;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *supportedChannelCounts;
@property (nonatomic) AUAudioChannelCount maximumChannelCount;
@property (nonatomic) BOOL shouldAllocateBuffer;
@end

@interface AUAudioUnitV2Bridge : AUAudioUnit
@property (nonatomic, readonly) AudioUnit audioUnit;
@end

@protocol AUAudioUnitFactory <NSExtensionRequestHandling>
- (nullable AUAudioUnit *)createAudioUnitWithComponentDescription:(AudioComponentDescription)desc error:(NSError **)error;
@end

@protocol AUMessageChannel
@optional
- (NSDictionary *)callAudioUnit:(NSDictionary *)message;
@property (nonatomic, copy, nullable) CallHostBlock callHostBlock;
@end

@interface AUHeadTrackingBinauralRenderer : AUAudioUnit
@property (nonatomic, readonly) BOOL isHeadTracking;
@property (nonatomic, copy, nullable) NSString *deviceUID;
@property (nonatomic) BOOL isDisabled;
@end

NS_ASSUME_NONNULL_END
#endif
