#!/usr/bin/env python3
"""Checks an ISIM_AUDIO_TAP capture (raw float32 little-endian stereo, 48 kHz) for a balance: `left` = the left channel
carries sound and the right is (nearly) silent; `right` the reverse; `both` = both channels carry sound."""
import array, math, sys

path, want = sys.argv[1], sys.argv[2]
a = array.array('f')
with open(path, 'rb') as f:
    a.frombytes(f.read())
l, r = a[0::2], a[1::2]
def rms(x): return math.sqrt(sum(v * v for v in x) / len(x)) if len(x) else 0.0
L, R = rms(l), rms(r)
print(f"tap {len(l) / 48000:.2f} s, rms left {L:.3f} right {R:.3f}")
ok = {'left': L > 0.05 and R < 0.01, 'right': R > 0.05 and L < 0.01, 'both': L > 0.05 and R > 0.05}[want]
sys.exit(0 if ok else 1)
