// ARKit and SceneKit from Objective-C (ARSceneObjCTest.app, issue #560): #import <ARKit/ARKit.h> and <SceneKit/SceneKit.h>,
// -framework ARKit -framework SceneKit. SceneKit: the scene graph, node transforms (SCNVector3 / SCNMatrix4 and simd),
// the matrix functions, NSValue's additions and SCNView's render loop calling an Objective-C delegate. ARKit: the
// configurations (unsupported, as in the Simulator), anchors and raycast queries with simd values, a session whose run
// fails through its Objective-C delegate, an ARSCNView and an ARSKView whose delegates get their sessions' failures too, and the coaching
// overlay. Results go to the log ("ARSceneObjC: ...").
#import <UIKit/UIKit.h>
#import <SceneKit/SceneKit.h>
#import <ARKit/ARKit.h>
#import <SpriteKit/SpriteKit.h>
#include <math.h>

static void say(NSString *s) { NSLog(@"ARSceneObjC: %@", s); }
static BOOL near(float a, float b) { return fabsf(a - b) < 1e-4f; }

@interface TestViewController : UIViewController <SCNSceneRendererDelegate, ARSessionDelegate, ARSCNViewDelegate, ARSKViewDelegate>
@property (nonatomic, strong) SCNView *scnView;
@property (nonatomic, strong) ARSession *session;
@property (nonatomic, strong) ARSCNView *arView;
@property (nonatomic, strong) ARSKView *skView;
@property (nonatomic) int frames;
@end

@implementation TestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [self sceneGraph];
    [self matrices];
    [self arValues];
    [self arSession];
    [self renderLoop];
}

- (void)sceneGraph {
    SCNScene *scene = [SCNScene scene];
    SCNNode *parent = [SCNNode node], *child = [SCNNode node];
    parent.name = @"parent";
    child.name = @"child";
    [scene.rootNode addChildNode:parent];
    [parent addChildNode:child];
    parent.position = SCNVector3Make(1, 2, 3);
    parent.scale = SCNVector3Make(2, 2, 2);
    child.position = SCNVector3Make(1, 0, 0);
    SCNVector3 w = child.worldPosition;
    SCNVector3 back = [scene.rootNode convertPosition:w toNode:parent];
    SCNNode *found = [scene.rootNode childNodeWithName:@"child" recursively:YES];
    __block int count = 0;
    [scene.rootNode enumerateHierarchyUsingBlock:^(SCNNode *n, BOOL *stop) { count++; }];
    child.hidden = YES;
    SCNNode *copy = [parent clone];
    say([NSString stringWithFormat:@"graph found %@ parent %@ world %.0f,%.0f,%.0f back %.0f,%.0f,%.0f nodes %d hidden %d clone %@ children %lu",
         found.name, child.parentNode.name, w.x, w.y, w.z, back.x, back.y, back.z, count, child.isHidden, copy.name, (unsigned long)copy.childNodes.count]);
    parent.eulerAngles = SCNVector3Make(0, (float)M_PI_2, 0);
    SCNMatrix4 t = parent.transform;
    simd_float3 sp = child.simdPosition;
    say([NSString stringWithFormat:@"transform m41 %.0f m42 %.0f m43 %.0f m11 %.1f m13 %.1f simd %.0f,%.0f,%.0f euler y %.2f", t.m41, t.m42, t.m43,
         t.m11, t.m13, sp.x, sp.y, sp.z, parent.eulerAngles.y]);
    scene.paused = YES;
    say([NSString stringWithFormat:@"scene paused %d named %@", scene.isPaused, [SCNScene sceneNamed:@"missing.scn"] ? @"loaded" : @"nil"]);
}

- (void)matrices {
    SCNMatrix4 tr = SCNMatrix4MakeTranslation(1, 2, 3), sc = SCNMatrix4MakeScale(2, 2, 2);
    SCNMatrix4 m = SCNMatrix4Mult(sc, tr);                      // scale, then translate
    SCNMatrix4 inv = SCNMatrix4Invert(m);
    SCNMatrix4 id = SCNMatrix4Mult(m, inv);
    SCNMatrix4 rot = SCNMatrix4MakeRotation((float)M_PI_2, 0, 0, 1);
    SCNVector3 v = SCNVector3Make(1, 2, 3);
    NSValue *boxed = [NSValue valueWithSCNVector3:v];
    simd_float4x4 s = SCNMatrix4ToMat4(tr);
    say([NSString stringWithFormat:@"matrix m11 %.0f m41 %.0f identity %d inverse m41 %.1f rotation m12 %.0f m21 %.0f equal %d boxed %d simd %.0f zero %d",
         m.m11, m.m41, SCNMatrix4IsIdentity(id) || (near(id.m11, 1) && near(id.m41, 0)), inv.m41, rot.m12, rot.m21,
         SCNVector3EqualToVector3(v, SCNVector3Make(1, 2, 3)), SCNVector3EqualToVector3(boxed.SCNVector3Value, v), s.columns[3].y,
         SCNVector3EqualToVector3(SCNVector3Zero, SCNVector3Make(0, 0, 0))]);
}

- (void)arValues {
    ARWorldTrackingConfiguration *c = [[ARWorldTrackingConfiguration alloc] init];
    c.planeDetection = ARPlaneDetectionHorizontal | ARPlaneDetectionVertical;
    c.worldAlignment = ARWorldAlignmentGravityAndHeading;
    c.lightEstimationEnabled = NO;
    c.autoFocusEnabled = NO;
    say([NSString stringWithFormat:@"configuration supported world %d face %d image %d planes %lu alignment %ld light %d focus %d semantics %d",
         ARWorldTrackingConfiguration.isSupported, ARFaceTrackingConfiguration.isSupported, ARImageTrackingConfiguration.isSupported,
         (unsigned long)c.planeDetection, (long)c.worldAlignment, c.isLightEstimationEnabled, c.isAutoFocusEnabled,
         [ARWorldTrackingConfiguration supportsFrameSemantics:ARFrameSemanticSceneDepth]]);
    simd_float4x4 t = matrix_identity_float4x4;
    t.columns[3] = (simd_float4){0.5f, 0, -1, 1};
    ARAnchor *a = [[ARAnchor alloc] initWithName:@"marker" transform:t];
    ARAnchor *copy = [a copy];
    simd_float3 o = {0, 0, 0}, d = {0, 0, -1};
    ARRaycastQuery *q = [[ARRaycastQuery alloc] initWithOrigin:o direction:d allowingTarget:ARRaycastTargetEstimatedPlane alignment:ARRaycastTargetAlignmentHorizontal];
    say([NSString stringWithFormat:@"anchor %@ x %.1f z %.1f copy %d query dir z %.0f target %ld alignment %ld", a.name, a.transform.columns[3].x,
         a.transform.columns[3].z, [copy.identifier isEqual:a.identifier], q.direction.z, (long)q.target, (long)q.targetAlignment]);
}

- (void)arSession {
    self.session = [[ARSession alloc] init];
    self.session.delegate = self;
    [self.session runWithConfiguration:[[ARWorldTrackingConfiguration alloc] init] options:ARSessionRunOptionResetTracking];
    self.arView = [[ARSCNView alloc] initWithFrame:CGRectMake(0, 400, 200, 150)];
    self.arView.delegate = self;
    [self.view addSubview:self.arView];
    [self.arView.session runWithConfiguration:[[AROrientationTrackingConfiguration alloc] init]];
    ARCoachingOverlayView *coach = [[ARCoachingOverlayView alloc] initWithFrame:CGRectMake(0, 0, 200, 150)];
    coach.goal = ARCoachingGoalHorizontalPlane;
    coach.session = self.arView.session;
    [self.arView addSubview:coach];
    say([NSString stringWithFormat:@"ar view delegate %d session %d frame %@ coaching goal %ld", self.arView.delegate == self, self.arView.session != nil,
         self.session.currentFrame ? @"yes" : @"nil", (long)coach.goal]);
    // ARSKView (issue #618): an SKView subclass presenting a scene, with an Objective-C ARSKViewDelegate
    self.skView = [[ARSKView alloc] initWithFrame:CGRectMake(200, 400, 200, 150)];
    self.skView.delegate = self;
    [self.view addSubview:self.skView];
    [self.skView presentScene:[SKScene sceneWithSize:CGSizeMake(200, 150)]];
    [self.skView.session runWithConfiguration:[[ARWorldTrackingConfiguration alloc] init]];
    say([NSString stringWithFormat:@"sk view delegate %d is SKView %d scene %d", self.skView.delegate == self,
         [self.skView isKindOfClass:[SKView class]], self.skView.scene != nil]);
}

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
    BOOL view = session == self.arView.session;
    if (session == self.skView.session) view = NO;
    say([NSString stringWithFormat:@"%@ failed domain %@ code %ld unsupported %d", session == self.skView.session ? @"sk view session" : view ? @"view session" : @"session", error.domain, (long)error.code,
         [error.domain isEqualToString:ARErrorDomain] && error.code == ARErrorCodeUnsupportedConfiguration]);
}

- (void)renderLoop {
    SCNScene *scene = [SCNScene scene];
    self.scnView = [[SCNView alloc] initWithFrame:CGRectMake(0, 100, 200, 200) options:nil];
    self.scnView.scene = scene;
    self.scnView.delegate = self;
    self.scnView.preferredFramesPerSecond = 30;
    self.scnView.antialiasingMode = SCNAntialiasingModeMultisampling2X;
    [self.view addSubview:self.scnView];
    self.scnView.playing = YES;
    SCNVector3 p = [self.scnView projectPoint:SCNVector3Make(4, 5, 6)];
    say([NSString stringWithFormat:@"view playing %d delegate %d antialiasing %lu project %.0f,%.0f,%.0f", self.scnView.isPlaying, self.scnView.delegate == self,
         (unsigned long)self.scnView.antialiasingMode, p.x, p.y, p.z]);
}

- (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time {
    if (renderer != (id)self.scnView) return;
    if (++self.frames == 5) say([NSString stringWithFormat:@"render loop 5 frames scene time %d", renderer.sceneTime > 0]);
}
- (void)renderer:(id<SCNSceneRenderer>)renderer didRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time {
    if (renderer == (id)self.scnView && self.frames == 5) say(@"did render");
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
