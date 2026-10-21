// CoreHaptics and GameController from Objective-C (GamesObjCTest.app, issue #548): #import <CoreHaptics/CoreHaptics.h> and
// <GameController/GameController.h>, -framework CoreHaptics -framework GameController. Haptics: the device capability,
// patterns from events, parameter curves and a dictionary, players (plain and advanced, with their completion), the
// engine's finished handler and AHAP data. Game controllers: a snapshot gamepad's elements and handlers, the host
// keyboard (keyChangedHandler) and a GCVirtualController whose A button the test taps. Results go to the log
// ("GamesObjC: ...").
#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>
#import <GameController/GameController.h>

static void say(NSString *s) { NSLog(@"GamesObjC: %@", s); }

@interface TestViewController : UIViewController
@property (nonatomic, strong) CHHapticEngine *engine;
@property (nonatomic, strong) id<CHHapticAdvancedPatternPlayer> advanced;
@property (nonatomic, strong) GCVirtualController *virtualController;
@end

@implementation TestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [NSNotificationCenter.defaultCenter addObserverForName:GCKeyboardDidConnectNotification object:nil queue:NSOperationQueue.mainQueue
                                                usingBlock:^(NSNotification *n) { say(@"keyboard connected"); [self keyboard]; }];
    [NSNotificationCenter.defaultCenter addObserverForName:GCControllerDidConnectNotification object:nil queue:NSOperationQueue.mainQueue
                                                usingBlock:^(NSNotification *n) {
        GCController *c = n.object;
        say([NSString stringWithFormat:@"controller connected: %@ extended=%d category=%@", c.vendorName, c.extendedGamepad != nil, c.productCategory]);
    }];
    [self haptics];
    [self snapshot];
    [self virtualPad];
    if (GCKeyboard.coalescedKeyboard) [self keyboard];
}

- (void)haptics {
    id<CHHapticDeviceCapability> cap = [CHHapticEngine capabilitiesForHardware];
    id<CHHapticParameterAttributes> a = [cap attributesForEventParameter:CHHapticEventParameterIDAudioPan eventType:CHHapticEventTypeAudioContinuous error:nil];
    say([NSString stringWithFormat:@"capability haptics %d audio %d pan %.0f..%.0f", cap.supportsHaptics, cap.supportsAudio, a.minValue, a.maxValue]);

    NSError *err = nil;
    self.engine = [[CHHapticEngine alloc] initAndReturnError:&err];
    self.engine.stoppedHandler = ^(CHHapticEngineStoppedReason reason) { say([NSString stringWithFormat:@"engine stopped %ld", (long)reason]); };
    self.engine.resetHandler = ^{};
    BOOL started = [self.engine startAndReturnError:&err];
    CHHapticEventParameter *intensity = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:0.8];
    CHHapticEvent *tap = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient parameters:@[intensity] relativeTime:0];
    CHHapticEvent *hum = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeAudioContinuous parameters:@[] relativeTime:0.05 duration:0.2];
    CHHapticParameterCurve *fade = [[CHHapticParameterCurve alloc] initWithParameterID:CHHapticDynamicParameterIDAudioVolumeControl
        controlPoints:@[[[CHHapticParameterCurveControlPoint alloc] initWithRelativeTime:0 value:1],
                        [[CHHapticParameterCurveControlPoint alloc] initWithRelativeTime:0.2 value:0]] relativeTime:0];
    CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[tap, hum] parameterCurves:@[fade] error:&err];
    say([NSString stringWithFormat:@"engine started %d pattern %.2f events %@ %@ curve %@ points %lu", started, pattern.duration, tap.type, hum.type,
         fade.parameterID, (unsigned long)fade.controlPoints.count]);

    id<CHHapticPatternPlayer> player = [self.engine createPlayerWithPattern:pattern error:&err];
    BOOL ok = [player startAtTime:CHHapticTimeImmediate error:&err];
    say([NSString stringWithFormat:@"player started %d error %@", ok, err ? err.domain : @"none"]);

    NSDictionary *dict = @{ CHHapticPatternKeyPattern: @[ @{ CHHapticPatternKeyEvent: @{ CHHapticPatternKeyEventType: CHHapticEventTypeHapticTransient,
                                                                                         CHHapticPatternKeyTime: @0.0 } } ] };
    CHHapticPattern *fromDict = [[CHHapticPattern alloc] initWithDictionary:dict error:&err];
    NSDictionary *exported = [fromDict exportDictionaryAndReturnError:&err];
    say([NSString stringWithFormat:@"dictionary pattern %@ exported %lu events", fromDict ? @"yes" : @"no",
         (unsigned long)[exported[CHHapticPatternKeyPattern] count]]);
    CHHapticPattern *bad = [[CHHapticPattern alloc] initWithEvents:@[[[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient
        parameters:@[] relativeTime:-1]] parameters:@[] error:&err];
    say([NSString stringWithFormat:@"bad pattern %@ domain %@ code %ld", bad ? @"made" : @"refused", err.domain, (long)err.code]);
    err = nil;

    self.advanced = [self.engine createAdvancedPlayerWithPattern:pattern error:&err];
    self.advanced.playbackRate = 2;
    self.advanced.completionHandler = ^(NSError *e) {
        dispatch_async(dispatch_get_main_queue(), ^{ say([NSString stringWithFormat:@"advanced finished error %@", e ? e.domain : @"none"]); });
    };
    [self.engine notifyWhenPlayersFinished:^CHHapticEngineFinishedAction(NSError *e) {
        dispatch_async(dispatch_get_main_queue(), ^{ say(@"players finished"); });
        return CHHapticEngineFinishedActionLeaveEngineRunning;
    }];
    say([NSString stringWithFormat:@"advanced started %d rate %.0f", [self.advanced startAtTime:0 error:&err], self.advanced.playbackRate]);
    NSData *ahap = [@"{\"Pattern\":[{\"Event\":{\"EventType\":\"HapticTransient\",\"Time\":0}}]}" dataUsingEncoding:NSUTF8StringEncoding];
    say([NSString stringWithFormat:@"ahap played %d", [self.engine playPatternFromData:ahap error:&err]]);
}

/// a snapshot gamepad: its elements, a value set on a button, the handlers
- (void)snapshot {
    GCController *c = [GCController controllerWithExtendedGamepad];
    GCExtendedGamepad *gp = c.extendedGamepad;
    __block NSString *pressed = @"no";
    gp.buttonA.pressedChangedHandler = ^(GCControllerButtonInput *b, float value, BOOL down) { if (down) pressed = b.localizedName ?: @"?"; };
    __block float stickX = 0;
    gp.leftThumbstick.valueChangedHandler = ^(GCControllerDirectionPad *d, float x, float y) { stickX = x; };
    [gp.buttonA setValue:1];
    [gp.leftThumbstick setValueForXAxis:0.5 yAxis:-0.25];
    GCControllerElement *byName = gp[GCInputButtonA];
    c.playerIndex = GCControllerPlayerIndex2;
    say([NSString stringWithFormat:@"snapshot %d buttons %lu A %.0f pressed %@ stick %.2f,%.2f handler %.2f subscript %@ player %ld micro %@",
         c.isSnapshot, (unsigned long)gp.buttons.count, gp.buttonA.value, pressed, gp.leftThumbstick.xAxis.value, gp.leftThumbstick.yAxis.value,
         stickX, byName == gp.buttonA ? @"A" : @"?", (long)c.playerIndex, [GCController controllerWithMicroGamepad].microGamepad ? @"yes" : @"no"]);
}

- (void)virtualPad {
    GCVirtualControllerConfiguration *config = [[GCVirtualControllerConfiguration alloc] init];
    config.elements = [NSSet setWithObjects:GCInputButtonA, GCInputButtonB, GCInputLeftThumbstick, nil];
    self.virtualController = [GCVirtualController virtualControllerWithConfiguration:config];
    [self.virtualController connectWithReplyHandler:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            GCController *c = self.virtualController.controller;
            say([NSString stringWithFormat:@"virtual connected error %@ controller %@", error ? error.domain : @"none", c.vendorName]);
            c.extendedGamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput *b, float value, BOOL down) {
                say([NSString stringWithFormat:@"virtual A %@", down ? @"pressed" : @"released"]);
            };
        });
    }];
}

- (void)keyboard {
    static BOOL done = NO;
    if (done) return;
    GCKeyboardInput *kb = GCKeyboard.coalescedKeyboard.keyboardInput;
    if (!kb) return;
    done = YES;
    say([NSString stringWithFormat:@"keyboard %@ has right %d", GCKeyboard.coalescedKeyboard.productCategory, [kb buttonForKeyCode:GCKeyCodeRightArrow] != nil]);
    kb.keyChangedHandler = ^(GCKeyboardInput *k, GCControllerButtonInput *key, GCKeyCode code, BOOL down) {
        if (code == GCKeyCodeRightArrow) say([NSString stringWithFormat:@"key right %@ any %d", down ? @"down" : @"up", k.isAnyKeyPressed]);
    };
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[TestViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
