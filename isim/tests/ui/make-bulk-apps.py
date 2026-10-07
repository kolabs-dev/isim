#!/usr/bin/env python3
"""Install N copies of a built app under different bundle ids and names ("App 01" ... ) on an isim device
(<data>/Applications), for home-screen tests with many apps. Usage: make-bulk-apps.py DATA APP N [FIRST]"""
import os, plistlib, shutil, sys

data, src, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
first = int(sys.argv[4]) if len(sys.argv) > 4 else 1
apps = os.path.join(data, 'Applications')
os.makedirs(apps, exist_ok=True)
for i in range(first, first + n):
    dst = os.path.join(apps, f'Bulk{i:02d}.app')
    shutil.rmtree(dst, ignore_errors=True)
    shutil.copytree(src, dst, symlinks=True)
    p = os.path.join(dst, 'Info.plist')
    with open(p, 'rb') as f:
        info = plistlib.load(f)
    info['CFBundleIdentifier'] = f'dev.isim.bulk.app{i:02d}'
    info['CFBundleDisplayName'] = info['CFBundleName'] = f'App {i:02d}'
    with open(p, 'wb') as f:
        plistlib.dump(info, f)
print(f'installed {n} apps')
