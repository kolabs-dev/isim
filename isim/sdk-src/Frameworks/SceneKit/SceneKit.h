#pragma once
/* isim SceneKit for Objective-C: the classes are the SceneKit Swift overlay's (SceneKit.framework re-exports
 * libswiftSceneKit.dylib): the scene graph, SceneKit's vectors and matrices (C structs and functions here), geometry,
 * materials, lights, cameras, actions, animations, constraints, physics, hit tests, SCNView and SCNRenderer, drawn with
 * isim's Metal on the CPU (#330). Swift uses the overlay; these declarations are hidden from Swift. The classes are not
 * subclassable from Objective-C. */
#import <SceneKit/SceneKitTypes.h>
#import <SceneKit/SCNNode.h>
#import <SceneKit/SCNScene.h>
#import <SceneKit/SCNSceneRenderer.h>
#import <SceneKit/SCNView.h>
#import <SceneKit/SCNGeometry.h>
#import <SceneKit/SCNParametricGeometry.h>
#import <SceneKit/SCNMaterial.h>
#import <SceneKit/SCNLight.h>
#import <SceneKit/SCNCamera.h>
#import <SceneKit/SCNAction.h>
#import <SceneKit/SCNAnimation.h>
#import <SceneKit/SCNConstraint.h>
#import <SceneKit/SCNPhysics.h>
#import <SceneKit/SCNHitTest.h>
#import <SceneKit/SCNRenderer.h>
