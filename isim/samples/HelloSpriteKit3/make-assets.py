#!/usr/bin/env python3
"""Generates HelloSpriteKit3's resources into the app bundle (no binary files in the repo): tone.wav (a 440 Hz sine,
0.5 s, 16 kHz mono, for SKAudioNode) and Badge.sks, a SpriteKit archive in the NSKeyedArchiver binary plist layout: a
scene holding a green sprite named "badge" and a label named "caption", that the nodes page loads through
SKReferenceNode(fileNamed:) and SKReferenceNode(url:)."""
import math
import os
import plistlib
import struct
import sys
import wave

NODE = ['SKNode', 'UIResponder', 'NSObject']


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

    def obj(self, chain, fields):
        d = dict(fields)
        uid = self.add(d)
        d['$class'] = self.cls(chain)
        return uid

    def color(self, r, g, b, a=1.0):
        return self.obj(['UIColor', 'NSObject'], {'UIRed': r, 'UIGreen': g, 'UIBlue': b, 'UIAlpha': a, 'UIColorComponentCount': 4})

    def write(self, path, root):
        top = {'$archiver': 'NSKeyedArchiver', '$version': 100000, '$top': {'root': root}, '$objects': self.objects}
        with open(path, 'wb') as f:
            plistlib.dump(top, f, fmt=plistlib.FMT_BINARY)


def badge_sks(path):
    a = Archive()
    badge = a.obj(['SKSpriteNode'] + NODE, {'name': a.add('badge'), 'color': a.color(0.2, 0.8, 0.3),
                                             'size': a.add('{60, 60}'), 'position': a.add('{0, 0}')})
    caption = a.obj(['SKLabelNode'] + NODE, {'name': a.add('caption'), 'text': a.add('ref'), 'fontSize': 14.0,
                                              'fontColor': a.color(1, 1, 1), 'position': a.add('{0, -48}')})
    children = a.obj(['NSArray', 'NSObject'], {'NS.objects': [badge, caption]})
    scene = a.obj(['SKScene', 'SKEffectNode'] + NODE, {'name': a.add('badgeScene'), 'size': a.add('{120, 120}'),
                                                       'children': children})
    a.write(path, scene)


def tone_wav(path, rate=16000, seconds=0.5, hz=440):
    frames = b''.join(struct.pack('<h', int(12000 * math.sin(2 * math.pi * hz * i / rate))) for i in range(int(rate * seconds)))
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(frames)


if __name__ == '__main__':
    badge_sks(os.path.join(sys.argv[1], 'Badge.sks'))
    tone_wav(os.path.join(sys.argv[1], 'tone.wav'))
