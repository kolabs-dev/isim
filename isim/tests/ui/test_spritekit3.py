"""HelloSpriteKit3: the SpriteKit that needs pixels or real time (issue #19). Every page runs Checks.swift, which reads
pixels back through SKTexture.cgImage() / SKView.texture(from:): texture data variants, sprite atlases from an asset
catalog, noise and normal-map textures, 9-slice sprites, SKLightNode lighting and shadows, SKShader programs (run as
Core Image kernels), shape caps / fill textures, SKEffectNode Core Image filters. The physics page checks concave and
texture bodies, continuous collision detection, joints, every field type, fields on particles, sampleFields, physics
actions, contacts, the camera and positional SKAudioNode; the nodes page inverse kinematics, constraints, tile maps
(automapping, isometric and hexagonal layouts), SKReferenceNode and the statistics overlay; the transition page an
SKTransition(ciFilter:)."""
import re

from isimtest import rgb

CHECKS = [   # Checks.swift, on every page
    "sk3 texture data bottom [255, 0, 0, 255] top [0, 0, 255, 255] flipped bottom [0, 0, 255, 255] "
    "strided bottom [255, 0, 0, 255] top [0, 255, 0, 255]",
    'sk3 sprite atlas ["monster-green", "monster-red"] red [230, 40, 40, 255] by name [40, 200, 60, 255] size (16.0, 16.0)',
    "sk3 texture cgImage 2x2 sub 2x1 [0, 0, 255, 255]",
    "sk3 noise gray true smoother true unit true up true",
    "sk3 normal map left true right true top true middle true",
    "sk3 texture(from:) size 60x60 red [255, 0, 0, 255] blue [0, 0, 255, 255] crop 20x20 [255, 0, 0, 255]",
    "sk3 nine slice size 180x60 edge [25, 76, 230, 255] past border [230, 230, 243, 255] plain [25, 76, 230, 255]",
    "sk3 lighting near true unlit [255, 255, 255, 255] shadow true normals true",
    "sk3 shader gradient left true right true top true default×uniform [51, 255, 102, 255] attribute [255, 128, 0, 255] "
    "matrix [0, 255, 0, 255] bad source draws plain [255, 128, 0, 255]",
    "sk3 shapes stroke start true end true fill center true fill texture [255, 128, 0, 255] [255, 255, 255, 255] "
    "caps butt 00 round 10 square 11",
    "sk3 effects blur soft edge true invert [0, 255, 255, 255] disabled [255, 0, 0, 255] shader [0, 0, 255, 255]",
]

PHYSICS = [
    "sk3 physics concave area 3150.0 ball inside true",
    "sk3 physics texture body area 2700.0 transparent corner empty true opaque part solid true",
    "sk3 physics precise stopped true",
    "sk3 physics joints fixed kept true fell true sliding on axis true within limits true pin reaction true up true "
    "spring moved true limit true",
    "sk3 physics fields linear true radial true spring true drag true vortex true velocity true noise true "
    "turbulence true electric true magnetic true custom true region true",
    "sk3 physics particles pushed true wide true",
    "sk3 physics sampleFields 0.0 -3.0 with electric 2.0 -3.0",
    "sk3 physics actions impulse true force true torque true angular impulse true mass 3.0 charge 2.0 strength 5.0 "
    "falloff 2.0",
    "sk3 audio positional frames true",
    "sk3 audio positional playing true engine true left louder true",
    "sk3 audio panned frames true",
    "sk3 audio panned right louder true pan 1.0 volume 0.5 rate 1.5 obstruction -20.0 occlusion -10.0 reverb 0.3",
    "sk3 physics contacts true camera true contains true set true",
]

NODES = [
    "sk3 nodes ik reached true limited true short true followed true",
    "sk3 nodes constraints distance true oriented true positionX true",
    "sk3 nodes tiles grid center top corner after center - drawn true",
    "sk3 nodes tiles iso true size 160x80 pointy true flat true hex inner edge inner edge",
    "sk3 nodes reference name true url ref children 2",
    "sk3 nodes objc extension true true",
]


def missing(log, lines):
    return [l for l in lines if l not in log]


def test_spritekit3_pixels(launch):
    app = launch("HelloSpriteKit3", env={"HELLOSK3_PAGE": "light"})
    app.wait_log(r"sk3 checks done", timeout=120)
    assert not missing(app.log, CHECKS), f"missing: {missing(app.log, CHECKS)}"
    assert re.search(r"sk3 texture\(from: scene\) \d+x\d+", app.log), "texture(from: scene)"


def test_spritekit3_physics(launch):
    app = launch("HelloSpriteKit3", env={"HELLOSK3_PAGE": "physics"})
    app.wait_log(r"sk3 physics done", timeout=120)
    assert not missing(app.log, PHYSICS), f"missing: {missing(app.log, PHYSICS)}"
    # SKView.showsFields (orange arrows on a grid) and showsPhysics (light cyan body outlines)
    img = app.screenshot("physics")
    px, (w, h) = img.load(), img.size
    arrows = sum(1 for y in range(0, h) for x in range(0, w) if px[x, y][0] > 180 and 90 < px[x, y][1] < 170 and px[x, y][2] < 100)
    outlines = sum(1 for y in range(0, h) for x in range(0, w) if 70 < px[x, y][0] < 140 and px[x, y][1] > 190 and px[x, y][2] > 220)
    assert arrows > 1000, f"showsFields draws the field arrows ({arrows} px)"
    assert outlines > 200, f"showsPhysics outlines the bodies ({outlines} px)"


def test_spritekit3_nodes(launch):
    app = launch("HelloSpriteKit3", env={"HELLOSK3_PAGE": "nodes"})
    app.wait_log(r"sk3 nodes done", timeout=120)
    assert not missing(app.log, NODES), f"missing: {missing(app.log, NODES)}"
    # the statistics overlay: a dark plate with white text at the bottom right
    img = app.screenshot("nodes")
    w, h = img.size
    plate = [rgb(img, x, y) for x in range(w - 150, w - 8, 2) for y in range(h - 60, h - 4, 2)]
    assert any(min(c) > 200 for c in plate), "statistics text drawn at the bottom right"


def test_spritekit3_transition(launch):
    app = launch("HelloSpriteKit3", env={"HELLOSK3_PAGE": "transition"})
    app.wait_log(r"sk3 transition started")

    def mixed(img):     # CIDissolveTransition part-way: red and blue at once
        c = rgb(img, img.size[0] // 2, img.size[1] // 2)
        return c[0] > 60 and c[2] > 60 and c[0] < 220 and c[2] < 220

    def blue(img):
        c = rgb(img, img.size[0] // 2, img.size[1] // 2)
        return c[2] > 200 and c[0] < 40

    app.shot_during(mixed, blue, "a dissolve frame mixing the red and the blue scene")
    app.wait_shot(blue, "the blue scene after the transition", timeout=30)
