// SpriteKit from Objective-C (SpriteKitObjCTest.app, issue #618): #import <SpriteKit/SpriteKit.h>, -framework SpriteKit.
// An SKView presents an SKScene subclass whose overrides (didMoveToView:, update:, didSimulatePhysics, didChangeSize:,
// touchesBegan:withEvent:) run from isim's frame loop; an SKSpriteNode subclass with its own touch handling; sprites,
// labels and shape nodes; actions (sequence, group, repeat, runBlock:, customAction, named keys, completion blocks);
// physics bodies with an SKPhysicsContactDelegate; an SKSceneDelegate; constraints; textures from pixel data; and a
// transition to a second scene. Results go to the log ("SpriteKitObjC: ...").
#import <UIKit/UIKit.h>
#import <SpriteKit/SpriteKit.h>
#import <Metal/Metal.h>
#import <CoreImage/CoreImage.h>

static void say(NSString *s) { NSLog(@"SpriteKitObjC: %@", s); }

enum { BallCategory = 1, GroundCategory = 2 };

// An Objective-C subclass of SKSpriteNode: its own touch handling and a property.
@interface Button : SKSpriteNode
@property (nonatomic) NSInteger taps;
@property (nonatomic, copy) void (^onTap)(Button *);
@end

@implementation Button
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.taps++;
    CGPoint p = [touches.anyObject locationInNode:self];
    say([NSString stringWithFormat:@"button %@ tapped %ld inside %d", self.name, (long)self.taps,
         fabs(p.x) <= self.size.width / 2 && fabs(p.y) <= self.size.height / 2]);
    if (self.onTap) self.onTap(self);
}
@end

@interface SecondScene : SKScene
@end

@implementation SecondScene
- (void)didMoveToView:(SKView *)view {
    say([NSString stringWithFormat:@"second scene %@ size %.0fx%.0f", NSStringFromClass([self class]), self.size.width, self.size.height]);
    say(@"done");
}
@end

@interface GameScene : SKScene <SKPhysicsContactDelegate, SKSceneDelegate>
@property (nonatomic) NSInteger frames;
@property (nonatomic) NSInteger delegateFrames;
@property (nonatomic) BOOL simulated;
@property (nonatomic) BOOL contacted;
@property (nonatomic) BOOL reported;
@property (nonatomic, strong) SKLabelNode *label;
@end

@implementation GameScene

- (void)sceneDidLoad {
    say(@"sceneDidLoad");
}

- (void)didMoveToView:(SKView *)view {
    say([NSString stringWithFormat:@"didMoveToView %@ size %.0fx%.0f scale %ld", NSStringFromClass([view class]),
         self.size.width, self.size.height, (long)self.scaleMode]);
    self.backgroundColor = [UIColor colorWithRed:0.1 green:0.2 blue:0.4 alpha:1];
    self.anchorPoint = CGPointZero;

    // A sprite from a texture built from pixel data, and a colored sprite.
    uint8_t px[4 * 4 * 4];
    for (int i = 0; i < 16; i++) { px[i * 4] = 255; px[i * 4 + 1] = 128; px[i * 4 + 2] = 0; px[i * 4 + 3] = 255; }
    SKTexture *tex = [SKTexture textureWithData:[NSData dataWithBytes:px length:sizeof px] size:CGSizeMake(4, 4)];
    tex.filteringMode = SKTextureFilteringNearest;
    SKSpriteNode *tile = [SKSpriteNode spriteNodeWithTexture:tex size:CGSizeMake(80, 80)];
    tile.name = @"tile";
    tile.position = CGPointMake(80, 700);
    [self addChild:tile];
    say([NSString stringWithFormat:@"texture %.0fx%.0f filtering %ld sprite %.0fx%.0f", tex.size.width, tex.size.height,
         (long)tex.filteringMode, tile.size.width, tile.size.height]);

    // A label and shape nodes.
    self.label = [SKLabelNode labelNodeWithText:@"Hello ObjC"];
    self.label.fontSize = 32;
    self.label.fontColor = UIColor.whiteColor;
    self.label.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    self.label.position = CGPointMake(self.size.width / 2, self.size.height - 120);
    self.label.name = @"title";
    [self addChild:self.label];
    SKShapeNode *ring = [SKShapeNode shapeNodeWithCircleOfRadius:40];
    ring.fillColor = UIColor.greenColor;
    ring.strokeColor = UIColor.whiteColor;
    ring.lineWidth = 4;
    ring.position = CGPointMake(self.size.width - 80, 700);
    ring.name = @"ring";
    [self addChild:ring];
    SKShapeNode *box = [SKShapeNode shapeNodeWithRectOfSize:CGSizeMake(60, 30) cornerRadius:6];
    box.fillColor = UIColor.redColor;
    [ring addChild:box];
    say([NSString stringWithFormat:@"label %@ font %.0f align %ld ring children %lu named %@", self.label.text,
         self.label.fontSize, (long)self.label.horizontalAlignmentMode, (unsigned long)ring.children.count,
         [self childNodeWithName:@"ring"].name]);

    // Actions.
    SKAction *move = [SKAction moveByX:0 y:-100 duration:0.2];
    SKAction *spin = [SKAction rotateByAngle:M_PI duration:0.2];
    __block NSInteger blocks = 0;
    SKAction *seq = [SKAction sequence:@[[SKAction group:@[move, spin]],
                                         [SKAction repeatAction:[SKAction runBlock:^{ blocks++; }] count:3],
                                         [SKAction customActionWithDuration:0.1 actionBlock:^(SKNode *node, CGFloat t) {}]]];
    [tile runAction:seq completion:^{
        say([NSString stringWithFormat:@"actions done y %.0f blocks %ld", tile.position.y, (long)blocks]);
    }];
    [ring runAction:[SKAction repeatActionForever:[SKAction rotateByAngle:1 duration:1]] withKey:@"spin"];
    say([NSString stringWithFormat:@"action key %d duration %.1f timing %ld", [ring actionForKey:@"spin"] != nil, seq.duration,
         (long)move.timingMode]);

    // Physics: a ball falls onto an edge.
    self.physicsWorld.gravity = CGVectorMake(0, -9.8);
    self.physicsWorld.contactDelegate = self;
    SKSpriteNode *ball = [SKSpriteNode spriteNodeWithColor:UIColor.yellowColor size:CGSizeMake(30, 30)];
    ball.name = @"ball";
    ball.position = CGPointMake(self.size.width / 2, 400);
    ball.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:15];
    ball.physicsBody.categoryBitMask = BallCategory;
    ball.physicsBody.contactTestBitMask = GroundCategory;
    ball.physicsBody.restitution = 0.2;
    [self addChild:ball];
    SKNode *ground = [SKNode node];
    ground.name = @"ground";
    ground.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointMake(0, 200) toPoint:CGPointMake(self.size.width, 200)];
    ground.physicsBody.categoryBitMask = GroundCategory;
    [self addChild:ground];
    say([NSString stringWithFormat:@"physics gravity %.1f ball dynamic %d ground dynamic %d", self.physicsWorld.gravity.dy,
         ball.physicsBody.dynamic, ground.physicsBody.dynamic]);

    // A constraint keeps the label in a range.
    SKConstraint *c = [SKConstraint positionX:[SKRange rangeWithLowerLimit:100 upperLimit:150]];
    self.label.constraints = @[c];

    // The button, an Objective-C SKSpriteNode subclass.
    Button *button = [Button spriteNodeWithColor:UIColor.blueColor size:CGSizeMake(160, 80)];
    button.name = @"go";
    button.userInteractionEnabled = YES;
    button.position = CGPointMake(self.size.width / 2, 100);
    __weak GameScene *weakSelf = self;
    button.onTap = ^(Button *b) {
        SecondScene *next = [SecondScene sceneWithSize:weakSelf.size];
        [weakSelf.view presentScene:next transition:[SKTransition fadeWithDuration:0.2]];
    };
    [self addChild:button];
    say([NSString stringWithFormat:@"button class %@ is sprite %d", NSStringFromClass([button class]),
         [button isKindOfClass:[SKSpriteNode class]]]);
}

- (void)update:(NSTimeInterval)currentTime {
    self.frames++;
    if (!self.reported && self.frames >= 30 && self.contacted && self.delegateFrames > 0) {
        self.reported = YES;
        say([NSString stringWithFormat:@"frames ok simulated %d delegate %d", self.simulated, self.delegateFrames > 0]);
        say(@"ready");
    }
}

- (void)didSimulatePhysics {
    self.simulated = YES;
}

- (void)didFinishUpdateForScene:(SKScene *)scene {
    self.delegateFrames++;
}

- (void)didBeginContact:(SKPhysicsContact *)contact {
    if (self.contacted) return;
    self.contacted = YES;
    NSString *a = contact.bodyA.node.name, *b = contact.bodyB.node.name;
    NSArray *names = [@[a ?: @"?", b ?: @"?"] sortedArrayUsingSelector:@selector(compare:)];
    say([NSString stringWithFormat:@"contact %@", [names componentsJoinedByString:@"+"]]);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint p = [touches.anyObject locationInNode:self];
    SKNode *hit = [self nodeAtPoint:p];
    say([NSString stringWithFormat:@"scene touch hit %@", hit.name ?: NSStringFromClass([hit class])]);
}

@end

// issue #395: SKRenderer into a Metal texture, intersectsNode:, focusBehavior, setNormalTexture:, a filtered texture
static void moreChecks(void) {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    id<MTLCommandQueue> queue = [device newCommandQueue];
    SKScene *scene = [SKScene sceneWithSize:CGSizeMake(16, 16)];
    scene.backgroundColor = [UIColor greenColor];
    SKRenderer *r = [SKRenderer rendererWithDevice:device];
    r.scene = scene;
    [r updateAtTime:1];
    MTLTextureDescriptor *td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:16 height:16 mipmapped:NO];
    td.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    id<MTLTexture> tex = [device newTextureWithDescriptor:td];
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = tex;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(1, 0, 0, 1);
    id<MTLCommandBuffer> cb = [queue commandBuffer];
    [r renderWithViewport:CGRectMake(0, 0, 16, 16) commandBuffer:cb renderPassDescriptor:pass];
    [cb commit];
    [cb waitUntilCompleted];
    uint8_t px[4];
    [tex getBytes:px bytesPerRow:16 * 4 fromRegion:MTLRegionMake2D(8, 8, 1, 1) mipmapLevel:0];
    say([NSString stringWithFormat:@"renderer rgba %d,%d,%d", px[0], px[1], px[2]]);

    SKSpriteNode *a = [SKSpriteNode spriteNodeWithColor:[UIColor redColor] size:CGSizeMake(10, 10)];
    SKSpriteNode *b = [SKSpriteNode spriteNodeWithColor:[UIColor redColor] size:CGSizeMake(10, 10)];
    b.position = CGPointMake(5, 5);
    BOOL near = [a intersectsNode:b];
    b.position = CGPointMake(50, 50);
    a.focusBehavior = SKNodeFocusBehaviorFocusable;
    [a runAction:[SKAction setNormalTexture:[SKTexture textureWithImage:[UIImage new]] resize:NO]];
    say([NSString stringWithFormat:@"intersects %d apart %d focus %ld version %d", near, ![a intersectsNode:b],
         (long)a.focusBehavior, SKVIEW_AVAILABLE + PHYSICSKIT_MINUS_GL_IMPORTS]);
    uint8_t white[4 * 4 * 4];
    memset(white, 255, sizeof white);
    SKTexture *t = [SKTexture textureWithData:[NSData dataWithBytes:white length:sizeof white] size:CGSizeMake(4, 4)];
    SKTexture *inverted = [t textureByApplyingCIFilter:[CIFilter filterWithName:@"CIColorInvert"]];
    say([NSString stringWithFormat:@"filtered texture %.0fx%.0f class %@", inverted.size.width, inverted.size.height,
         NSStringFromClass([inverted class])]);
}

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *vc = [UIViewController new];
    SKView *view = [[SKView alloc] initWithFrame:self.window.bounds];
    view.ignoresSiblingOrder = YES;
    vc.view = view;
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    GameScene *scene = [GameScene sceneWithSize:view.bounds.size];
    scene.scaleMode = SKSceneScaleModeResizeFill;
    scene.delegate = scene;
    say([NSString stringWithFormat:@"scene class %@ is scene %d", NSStringFromClass([scene class]), [scene isKindOfClass:[SKScene class]]]);
    [view presentScene:scene];
    moreChecks();
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
