// isim MapKit: coastlines for the offline basemap.
//
// The land shapes are Natural Earth's land polygons (public domain, https://www.naturalearthdata.com), converted by
// tools/make-land.py and installed in the SDK at usr/share/isim/maps/land-{50m,10m}.bin ($ISIM_ROOT is the SDK root).
// 1:50m is drawn when zoomed out, 1:10m (about 1 km detail) when zoomed in; closer than that the coast is that coarse.
// Lakes are holes in the land rings, so the land is filled with the even-odd rule. Without the files the map is plain land.
import UIKit

struct _MKLandRing { let points: [MKMapPoint]; let box: MKMapRect }

enum _MKLand {
    nonisolated(unsafe) static var sets: [String: [_MKLandRing]] = [:]

    static func path(_ name: String) -> String? {
        guard let root = ProcessInfo.processInfo.environment["ISIM_ROOT"], !root.isEmpty else { return nil }
        let p = (root as NSString).appendingPathComponent("usr/share/isim/maps/\(name).bin")
        return FileManager.default.fileExists(atPath: p) ? p : nil
    }
    static var available: Bool { path("land-50m") != nil }

    /// the rings of one resolution ("land-50m" or "land-10m"), decoded once
    static func rings(_ name: String) -> [_MKLandRing] {
        if let r = sets[name] { return r }
        var out: [_MKLandRing] = []
        if let p = path(name), let data = FileManager.default.contents(atPath: p) { out = decode(data) }
        sets[name] = out
        return out
    }

    static func decode(_ data: Data) -> [_MKLandRing] {
        let bytes = [UInt8](data)
        guard bytes.count > 11, String(decoding: bytes[0..<7], as: UTF8.self) == "ISLAND1" else { return [] }
        var i = 7
        func u32() -> UInt32 {
            guard i + 4 <= bytes.count else { i = bytes.count; return 0 }
            let v = UInt32(bytes[i]) | UInt32(bytes[i + 1]) << 8 | UInt32(bytes[i + 2]) << 16 | UInt32(bytes[i + 3]) << 24
            i += 4
            return v
        }
        func varint() -> Int64 {
            var shift: UInt64 = 0, n: UInt64 = 0
            while i < bytes.count {
                let b = bytes[i]; i += 1
                n |= UInt64(b & 0x7F) << shift
                if b & 0x80 == 0 { break }
                shift += 7
            }
            return Int64(bitPattern: n >> 1) ^ -Int64(bitPattern: n & 1)   /* zig-zag */
        }
        func point(_ lat: Int64, _ lon: Int64) -> MKMapPoint {
            MKMapPoint(CLLocationCoordinate2D(latitude: min(85.05, max(-85.05, Double(lat) * 1e-5)), longitude: Double(lon) * 1e-5))
        }
        let count = Int(u32())
        var rings: [_MKLandRing] = []
        rings.reserveCapacity(count)
        for _ in 0..<count where i < bytes.count {
            let n = Int(u32())
            let b = (0..<4).map { _ in Int64(Int32(bitPattern: u32())) }   /* minLat minLon maxLat maxLon */
            var pts: [MKMapPoint] = []
            pts.reserveCapacity(n)
            var lat: Int64 = 0, lon: Int64 = 0
            for _ in 0..<n { lat += varint(); lon += varint(); pts.append(point(lat, lon)) }
            let a = point(b[2], b[1]), z = point(b[0], b[3])   /* north-west and south-east corners */
            rings.append(_MKLandRing(points: pts, box: MKMapRect(x: a.x, y: a.y, width: z.x - a.x, height: z.y - a.y)))
        }
        return rings
    }

    /// fills the land seen in `visible` (map points); a map point p is drawn at ((p - origin) / scale) in view points.
    /// `rect` is the area drawn (view points): shapes are clipped to it, so far-off coasts never reach the rasteriser.
    static func draw(visible: MKMapRect, scale: Double, origin: MKMapPoint, rect: CGRect, color: UIColor) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let rings = rings(scale > 3000 ? "land-50m" : "land-10m")
        guard !rings.isEmpty else { return }
        let clip = rect.insetBy(dx: -4, dy: -4)
        let tol = scale * 0.6   /* points closer than about half a view point are dropped */
        let path = CGMutablePath()
        // the world repeats east and west: each copy in view
        let k0 = Int((visible.minX / _MKWorld).rounded(.down)), k1 = Int((visible.maxX / _MKWorld).rounded(.down))
        for k in k0...max(k0, k1) {
            let off = Double(k) * _MKWorld
            let local = visible.offsetBy(dx: -off, dy: 0)
            for r in rings where r.box.intersects(local) {
                // smaller than a view point: nothing to see
                if r.box.width < scale && r.box.height < scale { continue }
                var pts: [CGPoint] = []
                pts.reserveCapacity(min(r.points.count, 4096))
                var last = MKMapPoint(x: -1e18, y: -1e18)
                for p in r.points where abs(p.x - last.x) > tol || abs(p.y - last.y) > tol {
                    last = p
                    pts.append(CGPoint(x: (p.x + off - origin.x) / scale, y: (p.y - origin.y) / scale))
                }
                let c = clipped(pts, to: clip)
                guard c.count >= 3 else { continue }
                path.addLines(between: c)
                path.closeSubpath()
            }
        }
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setFillColor(color.cgColor)
        ctx.fillPath(using: .evenOdd)
        ctx.restoreGState()
    }

    /// Sutherland–Hodgman: a ring clipped to a rectangle (a ring cut in two keeps a zero-width seam along the edge,
    /// which fills nothing)
    static func clipped(_ ring: [CGPoint], to r: CGRect) -> [CGPoint] {
        if ring.allSatisfy({ r.contains($0) }) { return ring }
        var pts = ring
        let edges: [(CGPoint) -> Bool] = [{ $0.x >= r.minX }, { $0.x <= r.maxX }, { $0.y >= r.minY }, { $0.y <= r.maxY }]
        let cuts: [(CGPoint, CGPoint) -> CGPoint] = [
            { a, b in CGPoint(x: r.minX, y: a.y + (b.y - a.y) * (r.minX - a.x) / (b.x - a.x)) },
            { a, b in CGPoint(x: r.maxX, y: a.y + (b.y - a.y) * (r.maxX - a.x) / (b.x - a.x)) },
            { a, b in CGPoint(x: a.x + (b.x - a.x) * (r.minY - a.y) / (b.y - a.y), y: r.minY) },
            { a, b in CGPoint(x: a.x + (b.x - a.x) * (r.maxY - a.y) / (b.y - a.y), y: r.maxY) },
        ]
        for e in 0..<4 {
            guard let lastPt = pts.last else { break }
            var out: [CGPoint] = []
            out.reserveCapacity(pts.count + 4)
            var prev = lastPt, prevIn = edges[e](prev)
            for p in pts {
                let pIn = edges[e](p)
                if pIn { if !prevIn { out.append(cuts[e](prev, p)) }; out.append(p) }
                else if prevIn { out.append(cuts[e](prev, p)) }
                prev = p; prevIn = pIn
            }
            pts = out
        }
        return pts
    }
}
