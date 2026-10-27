// SceneKit's renderer from Objective-C (SceneKitObjCTest.app, issue #330): #import <SceneKit/SceneKit.h>,
// -framework SceneKit. Geometry from the class factories and from sources and elements, materials (lighting model names,
// double-sided), lights, a camera, an SCNView drawing them, picking (hitTest:options:, segments), actions with struct
// arguments, physics (gravity, velocity, a contact delegate), a look-at constraint, bounding boxes, and SCNRenderer drawing
// into an image. Results go to the log ("SceneKitObjC: ...").
#import <UIKit/UIKit.h>
#import <SceneKit/SceneKit.h>
#include <math.h>

static void say(NSString *s) { NSLog(@"SceneKitObjC: %@", s); }

@interface TestViewController : UIViewController <SCNSceneRendererDelegate, SCNPhysicsContactDelegate>
@property (nonatomic, strong) SCNView *scnView;
@property (nonatomic, strong) SCNNode *box, *ball;
@property (nonatomic) int frames, resetFrame;
@property (nonatomic) BOOL contact;
@end

@implementation TestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    SCNScene *scene = [SCNScene scene];
    scene.background.contents = [UIColor colorWithRed:0.2 green:0.2 blue:0.3 alpha:1];

    // geometry from the factories, with Apple's elements
    SCNBox *boxGeometry = [SCNBox boxWithWidth:1 height:1 length:1 chamferRadius:0];
    SCNMaterial *red = [SCNMaterial material];
    red.diffuse.contents = UIColor.redColor;
    red.lightingModelName = SCNLightingModelLambert;
    red.doubleSided = YES;
    boxGeometry.materials = @[red];
    self.box = [SCNNode nodeWithGeometry:boxGeometry];
    self.box.name = @"box";
    [scene.rootNode addChildNode:self.box];
    SCNVector3 lo, hi;
    BOOL has = [self.box getBoundingBoxMin:&lo max:&hi];
    say([NSString stringWithFormat:@"box elements %ld sources %lu bounds %d %.1f..%.1f model %@ double %d",
         (long)boxGeometry.geometryElementCount, (unsigned long)boxGeometry.geometrySources.count, has, lo.x, hi.x,
         red.lightingModelName, red.isDoubleSided]);

    // a triangle from sources and an element
    SCNVector3 v[3] = {{-1, 0, 0}, {1, 0, 0}, {0, 1, 0}};
    SCNVector3 n[3] = {{0, 0, 1}, {0, 0, 1}, {0, 0, 1}};
    uint16_t idx[3] = {0, 1, 2};
    SCNGeometrySource *vs = [SCNGeometrySource geometrySourceWithVertices:v count:3];
    SCNGeometrySource *ns = [SCNGeometrySource geometrySourceWithNormals:n count:3];
    SCNGeometryElement *el = [SCNGeometryElement geometryElementWithData:[NSData dataWithBytes:idx length:sizeof idx]
                                                           primitiveType:SCNGeometryPrimitiveTypeTriangles primitiveCount:1 bytesPerIndex:2];
    SCNGeometry *tri = [SCNGeometry geometryWithSources:@[vs, ns] elements:@[el]];
    SCNNode *triNode = [SCNNode nodeWithGeometry:tri];
    triNode.position = SCNVector3Make(0, 0, -3);
    [scene.rootNode addChildNode:triNode];
    say([NSString stringWithFormat:@"triangle semantic %@ vectors %ld float %d primitives %ld",
         [tri geometrySourcesForSemantic:SCNGeometrySourceSemanticVertex].firstObject.semantic, (long)vs.vectorCount, vs.floatComponents,
         (long)el.primitiveCount]);

    // lights and a camera aimed by a constraint
    SCNNode *light = [SCNNode node];
    light.light = [SCNLight light];
    light.light.type = SCNLightTypeOmni;
    light.position = SCNVector3Make(2, 3, 4);
    [scene.rootNode addChildNode:light];
    SCNNode *ambient = [SCNNode node];
    ambient.light = [SCNLight light];
    ambient.light.type = SCNLightTypeAmbient;
    ambient.light.intensity = 300;
    [scene.rootNode addChildNode:ambient];
    SCNNode *camera = [SCNNode node];
    camera.camera = [SCNCamera camera];
    camera.camera.fieldOfView = 50;
    camera.position = SCNVector3Make(0, 1, 5);
    camera.constraints = @[[SCNLookAtConstraint lookAtConstraintWithTarget:self.box]];
    [scene.rootNode addChildNode:camera];
    say([NSString stringWithFormat:@"light %@ camera fov %.0f near %.0f", light.light.type, camera.camera.fieldOfView, camera.camera.zNear]);

    // physics: a ball falling on a static floor
    SCNNode *floor = [SCNNode nodeWithGeometry:[SCNFloor floor]];
    floor.name = @"floor";
    floor.position = SCNVector3Make(0, -0.5, 0);
    floor.physicsBody = [SCNPhysicsBody bodyWithType:SCNPhysicsBodyTypeStatic
                                               shape:[SCNPhysicsShape shapeWithGeometry:[SCNBox boxWithWidth:50 height:0.01 length:50 chamferRadius:0] options:nil]];
    [scene.rootNode addChildNode:floor];
    self.ball = [SCNNode nodeWithGeometry:[SCNSphere sphereWithRadius:0.2]];
    self.ball.name = @"ball";
    self.ball.position = SCNVector3Make(2, 2, 0);
    self.ball.physicsBody = [SCNPhysicsBody dynamicBody];
    self.ball.physicsBody.contactTestBitMask = SCNPhysicsCollisionCategoryStatic;
    self.ball.physicsBody.velocity = SCNVector3Make(0, 1, 0);
    [scene.rootNode addChildNode:self.ball];
    scene.physicsWorld.contactDelegate = self;
    scene.physicsWorld.gravity = SCNVector3Make(0, -12, 0);
    say([NSString stringWithFormat:@"physics gravity %.0f velocity %.0f dynamic %d", scene.physicsWorld.gravity.y,
         self.ball.physicsBody.velocity.y, self.ball.physicsBody.type == SCNPhysicsBodyTypeDynamic]);

    // actions with struct arguments
    SCNAction *move = [SCNAction moveBy:SCNVector3Make(0, 0, -1) duration:0.2];
    [triNode runAction:[SCNAction sequence:@[move, [SCNAction waitForDuration:0.1]]] forKey:@"move" completionHandler:^{
        say([NSString stringWithFormat:@"action done z %.1f", triNode.position.z]);
    }];
    [self.box runAction:[SCNAction repeatActionForever:[SCNAction rotateByX:0 y:M_PI z:0 duration:2]] forKey:@"spin"];
    say([NSString stringWithFormat:@"actions %@ has %d", [[self.box.actionKeys arrayByAddingObjectsFromArray:triNode.actionKeys]
                                                         componentsJoinedByString:@","], self.box.hasActions]);

    self.scnView = [[SCNView alloc] initWithFrame:CGRectMake(20, 120, 300, 300) options:nil];
    self.scnView.scene = scene;
    self.scnView.pointOfView = camera;
    self.scnView.delegate = self;
    self.scnView.accessibilityIdentifier = @"scene";
    [self.view addSubview:self.scnView];
}

- (void)renderer:(id<SCNSceneRenderer>)renderer didRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time {
    int frame = ++self.frames;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (frame == 3) {
            // stop the spin and face the box forward, however far a slow machine spun it; hit tests see the transforms
            // the renderer last drew (the presentation), so pick only once a frame drawn after the reset has rendered
            [self.box removeActionForKey:@"spin"];
            self.box.eulerAngles = SCNVector3Make(0, 0, 0);
            self.resetFrame = self.frames;
        } else if (self.resetFrame > 0 && frame == self.resetFrame + 1) {
            [self picking];
        }
    });
}

- (void)picking {
    SCNView *v = self.scnView;
    SCNVector3 p = [v projectPoint:SCNVector3Make(0, 0, 0)];
    NSArray<SCNHitTestResult *> *hits = [v hitTest:CGPointMake(p.x, p.y) options:@{SCNHitTestBackFaceCullingKey: @YES}];
    SCNHitTestResult *h = hits.firstObject;
    say([NSString stringWithFormat:@"hit %@ face %ld world z %.1f normal z %.0f", h.node.name, (long)h.faceIndex, h.worldCoordinates.z,
         h.worldNormal.z]);
    NSArray *seg = [self.box hitTestWithSegmentFromPoint:SCNVector3Make(0, 0, 5) toPoint:SCNVector3Make(0, 0, -5) options:nil];
    say([NSString stringWithFormat:@"segment hits %lu", (unsigned long)seg.count]);
    SCNRenderer *r = [SCNRenderer rendererWithDevice:v.device options:nil];
    r.scene = v.scene;
    r.pointOfView = v.pointOfView;
    UIImage *img = [r snapshotAtTime:0 withSize:CGSizeMake(40, 30) antialiasingMode:SCNAntialiasingModeNone];
    say([NSString stringWithFormat:@"renderer %.0fx%.0f device %d", img.size.width, img.size.height, v.device != nil]);
}

- (void)physicsWorld:(SCNPhysicsWorld *)world didBeginContact:(SCNPhysicsContact *)contact {
    if (self.contact) return;
    self.contact = YES;
    NSArray *names = [@[contact.nodeA.name ?: @"?", contact.nodeB.name ?: @"?"] sortedArrayUsingSelector:@selector(compare:)];
    say([NSString stringWithFormat:@"contact %@ normal %.0f", [names componentsJoinedByString:@" "], fabsf(contact.contactNormal.y)]);
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [TestViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
