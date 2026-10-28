#pragma once
/* isim SpriteKit for Objective-C: the classes are the SpriteKit Swift overlay's (SpriteKit.framework re-exports
 * libswiftSpriteKit.dylib): scenes, nodes, actions, textures, physics, particles, tile maps and transitions, drawn by
 * isim's own 2D renderer. Swift uses the overlay; these declarations are hidden from Swift. Objective-C subclasses (an
 * SKScene or SKSpriteNode subclass) work: isim's runtime gives them Swift class metadata. An Objective-C override is
 * reached by Objective-C messages, UIKit's callbacks and the scene callbacks SpriteKit makes (update:, didMoveToView:,
 * didEvaluateActions, didSimulatePhysics, didApplyConstraints, didFinishUpdate, willMoveFromView:, didChangeSize:,
 * sceneDidLoad); SpriteKit's own Swift code calls the inherited implementation of other overridden members. */
#import <SpriteKit/SpriteKitBase.h>
#import <SpriteKit/SKTexture.h>
#import <SpriteKit/SKTextureAtlas.h>
#import <SpriteKit/SKShader.h>
#import <SpriteKit/SKAction.h>
#import <SpriteKit/SKNode.h>
#import <SpriteKit/SKSpriteNode.h>
#import <SpriteKit/SKLabelNode.h>
#import <SpriteKit/SKShapeNode.h>
#import <SpriteKit/SKScene.h>
#import <SpriteKit/SKTransition.h>
#import <SpriteKit/SKView.h>
#import <SpriteKit/SKEmitterNode.h>
#import <SpriteKit/SKNodes.h>
#import <SpriteKit/SKPhysics.h>
#import <SpriteKit/SKConstraint.h>
#import <SpriteKit/SKTileMapNode.h>
#import <SpriteKit/SKRenderer.h>
