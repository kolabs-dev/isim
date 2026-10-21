#pragma once
/* isim SceneKit for Objective-C: the classes are the SceneKit Swift overlay's (SceneKit.framework re-exports
 * libswiftSceneKit.dylib): the scene graph, SceneKit's vectors and matrices (C structs and functions here) and SCNView
 * with its render loop. Stub: nothing is drawn yet (#330). Swift uses the overlay; these declarations are hidden from
 * Swift. The classes are not subclassable from Objective-C. */
#import <SceneKit/SceneKitTypes.h>
#import <SceneKit/SCNNode.h>
#import <SceneKit/SCNScene.h>
#import <SceneKit/SCNSceneRenderer.h>
#import <SceneKit/SCNView.h>
