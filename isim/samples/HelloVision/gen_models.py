#!/usr/bin/env python3
"""Writes small Core ML model specs (.mlmodel, the protobuf format published with coremltools) for the HelloVision
sample, without coremltools: a GLM regressor (y = 2*x1 + 3*x2 + 1), a GLM classifier (cat/dog, logistic) and a
neural-network spec with no layers (isim describes it but cannot run it). Usage: gen_models.py OUTDIR"""
import os, struct, sys


def varint(n):
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        out.append(b | (0x80 if n else 0))
        if not n:
            return bytes(out)


def key(field, wire): return varint(field << 3 | wire)
def vint(field, n): return key(field, 0) + varint(n)
def ld(field, payload): return key(field, 2) + varint(len(payload)) + payload
def s(field, text): return ld(field, text.encode())
def doubles(field, xs): return ld(field, b''.join(struct.pack('<d', x) for x in xs))   # packed repeated double


def feature(name, ftype, desc=''):
    return s(1, name) + (s(2, desc) if desc else b'') + ld(3, ftype)


DOUBLE = ld(2, b'')                     # FeatureType.doubleType
STRING = ld(3, b'')                     # FeatureType.stringType
def multiarray(shape, dtype=65600):     # FeatureType.multiArrayType (DOUBLE)
    return ld(5, b''.join(vint(1, d) for d in shape) + vint(2, dtype))
DICT_STRING = ld(6, ld(2, b''))         # FeatureType.dictionaryType { stringKeyType }
METADATA = lambda text: ld(100, s(1, text) + s(2, '1.0') + s(3, 'isim sample') + s(4, 'Apache-2.0'))


def regressor():
    desc = ld(1, feature('x1', DOUBLE)) + ld(1, feature('x2', DOUBLE)) + ld(10, feature('y', DOUBLE, 'the prediction')) + s(11, 'y') \
        + METADATA('y = 2 x1 + 3 x2 + 1')
    glm = ld(1, doubles(1, [2.0, 3.0])) + doubles(2, [1.0])
    return vint(1, 1) + ld(2, desc) + ld(300, glm)


def classifier():
    desc = ld(1, feature('features', multiarray([2]))) + ld(10, feature('label', STRING)) + ld(10, feature('labelProbability', DICT_STRING)) \
        + s(11, 'label') + s(12, 'labelProbability') + METADATA('cat or dog from two numbers')
    glm = ld(1, doubles(1, [1.0, -1.0])) + doubles(2, [0.0]) + vint(3, 0) + vint(4, 0) + ld(100, s(1, 'cat') + s(1, 'dog'))
    return vint(1, 1) + ld(2, desc) + ld(400, glm)


def neural():
    desc = ld(1, feature('image', ld(4, vint(1, 224) + vint(2, 224)))) + ld(10, feature('scores', multiarray([10], 65568))) \
        + METADATA('an image model isim cannot run')
    return vint(1, 4) + ld(2, desc) + ld(500, b'')


out = sys.argv[1]
os.makedirs(out, exist_ok=True)
for name, spec in (('Regressor', regressor()), ('Classifier', classifier()), ('Neural', neural())):
    with open(os.path.join(out, name + '.mlmodel'), 'wb') as f:
        f.write(spec)
# a stand-in for a model compiled by Xcode (Apple's format: no spec inside)
os.makedirs(os.path.join(out, 'XcodeCompiled.mlmodelc'), exist_ok=True)
with open(os.path.join(out, 'XcodeCompiled.mlmodelc', 'coremldata.bin'), 'wb') as f:
    f.write(b'\0' * 64)
