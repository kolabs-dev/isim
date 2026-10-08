"""SpriteKit + GameplayKit + GameController (HelloSpriteKit): a menu scene decoded from an .sks archive, a doorway
transition, physics (gravity, ramp, contacts with sensors and boxes, joints, fields), particles from an .sks emitter
and from code, a texture atlas, sounds, GKStateMachine, GKGridGraph pathfinding, seeded random sources, the hardware
keyboard (GCKeyboard via keydown/keyup) and a GCVirtualController button. Port of tests/ui/spritekit.sh."""
import re

from isimtest import near, rgb


def test_spritekit(launch):
    app = launch("HelloSpriteKit")
    app.wait_log(r"menu size ")
    menu = app.wait_shot(lambda s: near(rgb(s, 130, 477), (51, 153, 255), 6), "menu: shape node fill color")
    app.tap(201, 477)
    app.wait_log(r"menu: play tapped")
    app.wait_log(r"game size ")
    app.wait_log(r"controller connected")
    app.wait_log(r"ball after 1s")                                     # game time 1 s: push the ball now
    app.send("keydown right")
    app.sleep(0.2)                                                     # the key is held (it pushes the ball)
    app.send("keyup right")
    app.tap(310, 794)                                                  # the virtual controller's A button
    app.wait_log(r"virtual A released")
    app.wait_log(r"win scene shown", timeout=20)
    win = app.wait_shot(lambda s: near(rgb(s, 30, 300), (12, 63, 38), 6), "win: scene background")
    for line in (r"lab: pendulum", r"hero reached the end of the path", r"ball after 1s", r"agent: chaser"):
        app.wait_log(line)
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    def has(s):
        return s in log

    assert has("menu loaded from sks: title=Hello SpriteKit logo=true"), \
        "scene decoded from Menu.sks (sceneDidLoad sees children)"
    assert has("menu size 402x874"), "SpriteView: resizeFill size before didMove"
    assert has("menu: play tapped -> doorway transition") and has("game size 402x874"), \
        "doorway transition presents the game scene"
    assert has("state ready") and has("state playing (from ReadyState)") and has("state won"), \
        "GKStateMachine ready -> playing -> won"
    assert has("atlas Hero: 4 textures hero_1.png,hero_2.png,hero_3.png,hero_4.png") and \
        has("hero texture size 32x32"), "texture atlas (.atlas folder, @2x frames)"
    assert has("path 16 nodes: (0,0) (1,0)") and has("hero reached the end of the path"), "GKGridGraph path around a wall"
    ball = re.search(r"ball after 1s: y=([0-9]+) \(start 581\) moving=true", log)
    assert ball and int(ball.group(1)) < 560, "gravity moves the ball"
    assert has("contact ball-coin") and has("coin collected (3)"), "contacts: sensor coins (passed through)"
    assert has("contact ball-box"), "contacts: ball hits the box"
    assert has("contact ball-goal"), "contacts: goal sensor"
    lab = re.search(r"lab: pendulum ([0-9]+) \(60\) swung=([a-z]+) rope ([0-9]+) \(<=32\) spring ([0-9]+) "
                    r"speck ([0-9]+)", log)
    assert lab, "lab report"
    pendulum, swung, rope, spring, speck = int(lab[1]), lab[2], int(lab[3]), int(lab[4]), int(lab[5])
    assert 57 <= pendulum <= 63 and swung == "yes", "pin joint keeps the pendulum length"
    assert rope <= 34, "limit joint (rope) holds"
    assert 30 < spring < 80, "spring joint stretches under gravity"
    assert speck < 40, "radial gravity field pulls a body"
    assert has("spark emitter from sks: birthRate=400 toEmit=80 texture=true colorSequence=3"), \
        "emitter decoded from Spark.sks"
    assert not re.search(r"no sound file|cannot play", log), "sounds found and decoded"
    assert has("mt19937 first 3499211612") and has("shuffled d6 covers 1...6: true") and \
        has("arc4 reproducible: true") and has("shuffle keeps elements: true"), "GameplayKit random sources"
    assert has("entity: node component hero, back link true, agents 1"), "GKEntity/GKSKNodeComponent/SKNode.entity"
    assert has("agent: chaser moved toward target: true"), "GKAgent2D seeks with a GKBehavior"
    assert has("keyboard connected") and has("key right down") and has("key right up"), \
        "GCKeyboard: host key presses and releases"
    assert has("controller connected: Virtual Controller extended=true") and has("virtual A pressed") and \
        has("virtual A released"), "GCVirtualController connects and its A button works"
    assert has("presenting win scene (push)") and has("win scene shown, coins 3"), "push transition to the win scene"
    assert near(rgb(menu, 130, 477), (51, 153, 255), 6), "menu: shape node fill color"
    assert near(rgb(menu, 380, 820), (20, 25, 51), 6), "menu: scene background"
    assert near(rgb(win, 30, 300), (12, 63, 38), 6), "win: scene background"
