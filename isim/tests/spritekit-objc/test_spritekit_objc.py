"""SpriteKit from Objective-C (SpriteKitObjCTest.app, issue #618): #import <SpriteKit/SpriteKit.h> over isim's SpriteKit.
An SKScene subclass whose overrides run from the frame loop (sceneDidLoad, didMoveToView:, update:, didSimulatePhysics),
an SKSceneDelegate, an SKSpriteNode subclass with its own touches, a texture from pixel data, labels and shape nodes,
actions with a completion block and a key, physics bodies with an SKPhysicsContactDelegate, a constraint, scene touches
with locationInNode: and nodeAtPoint:, and a transition to a second Objective-C scene."""
from isimtest import need_apps, near, rgb


def test_spritekit_objc(launch):
    need_apps("SpriteKitObjCTest")
    app = launch("SpriteKitObjCTest")
    p = "SpriteKitObjC: "
    app.wait_log(p + r"sceneDidLoad")
    app.wait_log(p + r"scene class GameScene is scene 1")
    app.wait_log(p + r"didMoveToView SKView size 402x874 scale 3")
    app.wait_log(p + r"texture 4x4 filtering 0 sprite 80x80")
    app.wait_log(p + r"label Hello ObjC font 32 align 0 ring children 1 named ring")
    app.wait_log(p + r"action key 1 duration 0\.3 timing 0")
    app.wait_log(p + r"physics gravity -9\.8 ball dynamic 1 ground dynamic 0")
    app.wait_log(p + r"button class Button is sprite 1")
    app.wait_log(p + r"actions done y 600 blocks 3")
    app.wait_log(p + r"contact ball\+ground")
    app.wait_log(p + r"frames ok simulated 1 delegate 1")
    app.wait_log(p + r"ready")
    # the scene draws: its background, the texture-made tile (orange), the green ring and the blue button
    app.wait_shot(lambda s: near(rgb(s, 200, 400), (26, 51, 102), 8) and near(rgb(s, 80, 274), (255, 128, 0), 8)
                  and near(rgb(s, 201, 774), (0, 0, 255), 8), "scene drawn")
    app.tap(30, 30)                                                    # the scene itself (no node there)
    app.wait_log(p + r"scene touch hit GameScene")
    app.tap(80, 274)                                                   # the tile: a plain node, the scene gets the touch
    app.wait_log(p + r"scene touch hit tile")
    app.tap(201, 774)                                                  # the Button subclass: user interaction enabled
    app.wait_log(p + r"button go tapped 1 inside 1")
    app.wait_log(p + r"second scene SecondScene size 402x874")
    app.wait_log(p + r"done")
    assert app.quit() == 0
