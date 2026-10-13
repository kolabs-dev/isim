#!/usr/bin/env python3
"""make-land.py NE_LAND.geojson OUT.bin: the offline basemap's land shapes (MapKit Basemap.swift) from Natural Earth's
land polygons (public domain, https://www.naturalearthdata.com). Format: "ISLAND1", ring count (u32), then per ring:
point count (u32), bounding box (4 x i32, 1e-5 degrees: minLat minLon maxLat maxLon), then the points as zig-zag
varint deltas of (lat, lon) in 1e-5 degrees."""
import json, struct, sys

def varint(n):
    n = (n << 1) ^ (n >> 63)
    out = bytearray()
    while True:
        b = n & 0x7F; n >>= 7
        out.append(b | (0x80 if n else 0))
        if not n: return bytes(out)

def main(src, dst):
    rings = []
    for f in json.load(open(src))["features"]:
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        for poly in polys:
            for ring in poly:                       # outer ring and holes (lakes cut out of land) alike: even-odd fill
                pts = [(round(lat * 1e5), round(lon * 1e5)) for lon, lat in ring]
                if len(pts) >= 3: rings.append(pts)
    out = bytearray(b"ISLAND1" + struct.pack("<I", len(rings)))
    total = 0
    for pts in rings:
        lats = [p[0] for p in pts]; lons = [p[1] for p in pts]
        out += struct.pack("<I4i", len(pts), min(lats), min(lons), max(lats), max(lons))
        plat = plon = 0
        for la, lo in pts:
            out += varint(la - plat) + varint(lo - plon); plat, plon = la, lo
        total += len(pts)
    open(dst, "wb").write(out)
    print(f"{dst}: {len(rings)} rings, {total} points, {len(out)} bytes")

if __name__ == "__main__":
    main(*sys.argv[1:3])
