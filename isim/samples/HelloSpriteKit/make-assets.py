#!/usr/bin/env python3
"""Generates HelloSpriteKit's resources into an app bundle (no binary files in the repo):
Hero.atlas (texture atlas folder, 1x and 2x frames), spark.png, pop.wav, and two SpriteKit archives in the
NSKeyedArchiver binary plist layout: Spark.sks (particle emitter) and Menu.sks (a scene with a label and a sprite).
The archives use SpriteKit's public property names as keys (isim's reader also accepts underscore-prefixed keys)."""
import math
import os
import plistlib
import struct
import sys
import wave
import zlib


def png(path, w, h, pixel):
    rows = b''.join(b'\x00' + b''.join(bytes(pixel(x, y)) for x in range(w)) for y in range(h))
    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + \
        chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(data)


def hero_frame(frame, scale):
    """a round creature whose eye looks in four directions (one per frame)"""
    s = 32 * scale
    ex, ey = [(0.62, 0.38), (0.62, 0.5), (0.5, 0.62), (0.38, 0.5)][frame]
    def px(x, y):
        u, v = (x + 0.5) / s, (y + 0.5) / s
        d = math.hypot(u - 0.5, v - 0.5)
        if d > 0.46:
            return (0, 0, 0, 0)
        if math.hypot(u - ex, v - ey) < 0.1:
            return (20, 20, 40, 255)
        return (255, 200 - frame * 30, 40 + frame * 40, 255)
    return s, px


class Archive:
    """NSKeyedArchiver layout: $objects[0] = "$null", objects reference each other by UID"""
    def __init__(self):
        self.objects = ['$null']
        self.class_uids = {}

    def add(self, value):
        self.objects.append(value)
        return plistlib.UID(len(self.objects) - 1)

    def cls(self, chain):
        if chain[0] not in self.class_uids:
            self.class_uids[chain[0]] = self.add({'$classname': chain[0], '$classes': chain})
        return self.class_uids[chain[0]]

    def string(self, s):
        return self.add(s)

    def obj(self, chain, fields):
        d = dict(fields)
        uid = self.add(d)          # reserve the slot first: children may reference it
        d['$class'] = self.cls(chain)
        return uid

    def array(self, uids):
        return self.obj(['NSArray', 'NSObject'], {'NS.objects': list(uids)})

    def color(self, r, g, b, a=1.0):
        return self.obj(['UIColor', 'NSObject'], {'UIRed': r, 'UIGreen': g, 'UIBlue': b, 'UIAlpha': a, 'UIColorComponentCount': 4})

    def write(self, path, root):
        top = {'$archiver': 'NSKeyedArchiver', '$version': 100000, '$top': {'root': root}, '$objects': self.objects}
        with open(path, 'wb') as f:
            plistlib.dump(top, f, fmt=plistlib.FMT_BINARY)


NODE = ['SKNode', 'UIResponder', 'NSObject']


def spark_sks(path):
    a = Archive()
    tex = a.obj(['SKTexture', 'NSObject'], {'imageName': a.string('spark')})
    colors = a.array([a.color(1, 0.95, 0.5), a.color(1, 0.45, 0.1), a.color(0.8, 0.1, 0.05, 0)])
    times = a.array([a.add(0.0), a.add(0.4), a.add(1.0)])
    seq = a.obj(['SKKeyframeSequence', 'NSObject'], {'keyframeValues': colors, 'keyframeTimes': times, 'interpolationMode': 1})
    root = a.obj(['SKEmitterNode'] + NODE, {
        'name': a.string('spark'),
        'particleTexture': tex, 'particleBirthRate': 400.0, 'numParticlesToEmit': 80, 'particleLifetime': 0.7,
        'particleLifetimeRange': 0.3, 'particleSpeed': 160.0, 'particleSpeedRange': 80.0, 'emissionAngle': 1.5708,
        'emissionAngleRange': 6.2832, 'yAcceleration': -200.0, 'particleAlpha': 1.0, 'particleAlphaSpeed': -1.2,
        'particleScale': 0.5, 'particleScaleRange': 0.3, 'particleScaleSpeed': -0.4, 'particleColorBlendFactor': 1.0,
        'particleColor': a.color(1, 0.8, 0.3), 'particleColorSequence': seq, 'particleBlendMode': 1,
        'particlePositionRange': a.string('{8, 8}'),
    })
    a.write(path, root)


def menu_sks(path):
    a = Archive()
    title = a.obj(['SKLabelNode'] + NODE, {'name': a.string('title'), 'text': a.string('Hello SpriteKit'),
                                           'fontName': a.string('Helvetica-Bold'), 'fontSize': 34.0,
                                           'fontColor': a.color(1, 1, 1), 'position': a.string('{0, 120}')})
    logo = a.obj(['SKSpriteNode'] + NODE, {'name': a.string('logo'), 'color': a.color(0.35, 0.75, 1),
                                            'size': a.string('{140, 14}'), 'position': a.string('{0, 90}'), 'zRotation': 0.0})
    scene = a.obj(['SKScene', 'SKEffectNode'] + NODE, {'name': a.string('menu'), 'size': a.string('{390, 844}'),
                                                       'anchorPoint': a.string('{0.5, 0.5}'),
                                                       'backgroundColor': a.color(0.08, 0.1, 0.2),
                                                       'children': a.array([title, logo])})
    a.write(path, scene)


def pop_wav(path):
    rate, dur = 44100, 0.12
    n = int(rate * dur)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(b''.join(struct.pack('<h', int(12000 * math.sin(2 * math.pi * 660 * i / rate) * (1 - i / n))) for i in range(n)))


def main(app):
    atlas = os.path.join(app, 'Hero.atlas')
    os.makedirs(atlas, exist_ok=True)
    for frame in range(4):
        for scale, suffix in ((1, ''), (2, '@2x')):
            s, px = hero_frame(frame, scale)
            png(os.path.join(atlas, f'hero_{frame + 1}{suffix}.png'), s, s, px)
    def spark(x, y):
        d = math.hypot(x - 7.5, y - 7.5) / 8
        return (255, 255, 255, max(0, int(255 * (1 - d) ** 1.5)) if d < 1 else 0)
    png(os.path.join(app, 'spark.png'), 16, 16, spark)
    pop_wav(os.path.join(app, 'pop.wav'))
    spark_sks(os.path.join(app, 'Spark.sks'))
    menu_sks(os.path.join(app, 'Menu.sks'))


if __name__ == '__main__':
    main(sys.argv[1])
