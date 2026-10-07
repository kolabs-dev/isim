// isim MapKit: the offline basemap.
//
// isim has no map data service. The map shows, in this order of preference:
//  1. raster tiles from a local slippy-map cache, if one exists: $ISIM_MAP_TILES or $ISIM_DATA/Library/Maps/Tiles,
//     laid out as {z}/{x}/{y}.png (e.g. tiles you exported yourself; isim never downloads tiles);
//  2. otherwise a styled offline basemap: land-coloured background, a latitude/longitude graticule with
//     coordinate labels, and labels for a small built-in list of world cities and landmarks (no coastlines, roads
//     or water). The bottom-left corner says which one is shown.
import UIKit

struct _MKPlace { let name: String; let lat: Double; let lon: Double; let rank: Int }

enum _MKBasemap {
    /// world cities (rank 1 = capitals/megacities shown first) and the Simulator's preset places
    static let places: [_MKPlace] = [
        _MKPlace(name: "San Francisco", lat: 37.7749, lon: -122.4194, rank: 1), _MKPlace(name: "Cupertino", lat: 37.3230, lon: -122.0322, rank: 2),
        _MKPlace(name: "San Jose", lat: 37.3382, lon: -121.8863, rank: 2), _MKPlace(name: "Oakland", lat: 37.8044, lon: -122.2712, rank: 3),
        _MKPlace(name: "Palo Alto", lat: 37.4419, lon: -122.1430, rank: 3), _MKPlace(name: "Sunnyvale", lat: 37.3688, lon: -122.0363, rank: 3),
        _MKPlace(name: "Mountain View", lat: 37.3861, lon: -122.0839, rank: 3), _MKPlace(name: "Santa Clara", lat: 37.3541, lon: -121.9552, rank: 3),
        _MKPlace(name: "Los Angeles", lat: 34.0522, lon: -118.2437, rank: 1), _MKPlace(name: "Seattle", lat: 47.6062, lon: -122.3321, rank: 1),
        _MKPlace(name: "New York", lat: 40.7128, lon: -74.0060, rank: 1), _MKPlace(name: "Chicago", lat: 41.8781, lon: -87.6298, rank: 1),
        _MKPlace(name: "Mexico City", lat: 19.4326, lon: -99.1332, rank: 1), _MKPlace(name: "Toronto", lat: 43.6532, lon: -79.3832, rank: 1),
        _MKPlace(name: "Honolulu", lat: 21.3069, lon: -157.8583, rank: 2), _MKPlace(name: "São Paulo", lat: -23.5505, lon: -46.6333, rank: 1),
        _MKPlace(name: "Rio de Janeiro", lat: -22.9068, lon: -43.1729, rank: 1), _MKPlace(name: "Buenos Aires", lat: -34.6037, lon: -58.3816, rank: 1),
        _MKPlace(name: "Lima", lat: -12.0464, lon: -77.0428, rank: 1), _MKPlace(name: "Bogotá", lat: 4.7110, lon: -74.0721, rank: 1),
        _MKPlace(name: "London", lat: 51.5074, lon: -0.1278, rank: 1), _MKPlace(name: "Paris", lat: 48.8566, lon: 2.3522, rank: 1),
        _MKPlace(name: "Berlin", lat: 52.5200, lon: 13.4050, rank: 1), _MKPlace(name: "Madrid", lat: 40.4168, lon: -3.7038, rank: 1),
        _MKPlace(name: "Lisbon", lat: 38.7223, lon: -9.1393, rank: 1), _MKPlace(name: "Rome", lat: 41.9028, lon: 12.4964, rank: 1),
        _MKPlace(name: "Moscow", lat: 55.7558, lon: 37.6173, rank: 1), _MKPlace(name: "Istanbul", lat: 41.0082, lon: 28.9784, rank: 1),
        _MKPlace(name: "Cairo", lat: 30.0444, lon: 31.2357, rank: 1), _MKPlace(name: "Lagos", lat: 6.5244, lon: 3.3792, rank: 1),
        _MKPlace(name: "Nairobi", lat: -1.2921, lon: 36.8219, rank: 1), _MKPlace(name: "Johannesburg", lat: -26.2041, lon: 28.0473, rank: 1),
        _MKPlace(name: "Dubai", lat: 25.2048, lon: 55.2708, rank: 1), _MKPlace(name: "Mumbai", lat: 19.0760, lon: 72.8777, rank: 1),
        _MKPlace(name: "Delhi", lat: 28.7041, lon: 77.1025, rank: 1), _MKPlace(name: "Beijing", lat: 39.9042, lon: 116.4074, rank: 1),
        _MKPlace(name: "Shanghai", lat: 31.2304, lon: 121.4737, rank: 1), _MKPlace(name: "Hong Kong", lat: 22.3193, lon: 114.1694, rank: 1),
        _MKPlace(name: "Singapore", lat: 1.3521, lon: 103.8198, rank: 1), _MKPlace(name: "Seoul", lat: 37.5665, lon: 126.9780, rank: 1),
        _MKPlace(name: "Tokyo", lat: 35.6762, lon: 139.6503, rank: 1), _MKPlace(name: "Sydney", lat: -33.8688, lon: 151.2093, rank: 1),
        _MKPlace(name: "Melbourne", lat: -37.8136, lon: 144.9631, rank: 1), _MKPlace(name: "Auckland", lat: -36.8485, lon: 174.7633, rank: 1),
        _MKPlace(name: "Apple Park", lat: 37.3349, lon: -122.00902, rank: 4), _MKPlace(name: "Golden Gate Bridge", lat: 37.819929, lon: -122.478255, rank: 4),
        _MKPlace(name: "Union Square", lat: 37.787994, lon: -122.407437, rank: 4), _MKPlace(name: "Times Square", lat: 40.7580, lon: -73.9855, rank: 4),
        _MKPlace(name: "Eiffel Tower", lat: 48.858370, lon: 2.294481, rank: 4), _MKPlace(name: "Trafalgar Square", lat: 51.508039, lon: -0.128069, rank: 4),
        _MKPlace(name: "Brandenburg Gate", lat: 52.516275, lon: 13.377704, rank: 4), _MKPlace(name: "Sydney Opera House", lat: -33.856784, lon: 151.215297, rank: 4),
        _MKPlace(name: "Shibuya Crossing", lat: 35.659482, lon: 139.700556, rank: 4),
    ]

    struct Style {
        let land: UIColor, grid: UIColor, gridMajor: UIColor, label: UIColor, halo: UIColor, dot: UIColor
    }
    static func style(_ type: MKMapType, dark: Bool) -> Style {
        switch type {
        case .satellite, .satelliteFlyover, .hybrid, .hybridFlyover:
            return Style(land: UIColor(red: 0.20, green: 0.27, blue: 0.20, alpha: 1), grid: UIColor(white: 1, alpha: 0.10), gridMajor: UIColor(white: 1, alpha: 0.22),
                         label: .white, halo: UIColor(white: 0, alpha: 0.6), dot: .white)
        case .mutedStandard:
            return dark ? Style(land: UIColor(white: 0.16, alpha: 1), grid: UIColor(white: 1, alpha: 0.05), gridMajor: UIColor(white: 1, alpha: 0.10),
                                label: UIColor(white: 0.6, alpha: 1), halo: UIColor(white: 0.1, alpha: 1), dot: UIColor(white: 0.6, alpha: 1))
                        : Style(land: UIColor(red: 0.96, green: 0.96, blue: 0.95, alpha: 1), grid: UIColor(white: 0, alpha: 0.04), gridMajor: UIColor(white: 0, alpha: 0.08),
                                label: UIColor(white: 0.45, alpha: 1), halo: .white, dot: UIColor(white: 0.5, alpha: 1))
        default:
            return dark ? Style(land: UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1), grid: UIColor(white: 1, alpha: 0.07), gridMajor: UIColor(white: 1, alpha: 0.14),
                                label: UIColor(white: 0.85, alpha: 1), halo: UIColor(white: 0.1, alpha: 1), dot: UIColor(white: 0.8, alpha: 1))
                        : Style(land: UIColor(red: 0.973, green: 0.961, blue: 0.937, alpha: 1), grid: UIColor(red: 0.88, green: 0.86, blue: 0.82, alpha: 1),
                                gridMajor: UIColor(red: 0.80, green: 0.78, blue: 0.74, alpha: 1), label: UIColor(white: 0.25, alpha: 1), halo: .white,
                                dot: UIColor(white: 0.35, alpha: 1))
        }
    }

    // MARK: tile cache
    static let tileDir: String? = {
        let env = ProcessInfo.processInfo.environment
        var cands: [String] = []
        if let t = env["ISIM_MAP_TILES"], !t.isEmpty { cands.append(t) }
        if let d = env["ISIM_DATA"], !d.isEmpty { cands.append((d as NSString).appendingPathComponent("Library/Maps/Tiles")) }
        return cands.first { var dir: ObjCBool = false; return FileManager.default.fileExists(atPath: $0, isDirectory: &dir) && dir.boolValue }
    }()
    nonisolated(unsafe) static var tileCache: [String: UIImage] = [:]
    nonisolated(unsafe) static var tileMissing: Set<String> = []
    static func cachedTile(_ p: MKTileOverlayPath) -> UIImage? {
        guard let dir = tileDir else { return nil }
        let key = "\(p.z)/\(p.x)/\(p.y)"
        if let i = tileCache[key] { return i }
        if tileMissing.contains(key) { return nil }
        for ext in ["png", "jpg", "jpeg", "webp"] {
            let f = (dir as NSString).appendingPathComponent(key + "." + ext)
            if let img = UIImage(contentsOfFile: f) { tileCache[key] = img; return img }
        }
        tileMissing.insert(key)
        return nil
    }
    static var usesTiles: Bool { tileDir != nil }

    // MARK: drawing
    /// draws the basemap for `visible` (map points) into `rect` (view points); scale = map points per view point
    static func draw(visible: MKMapRect, scale: Double, rect: CGRect, type: MKMapType, dark: Bool, showsLabels: Bool, toView: (MKMapPoint) -> CGPoint) {
        let st = style(type, dark: dark)
        st.land.setFill()
        UIBezierPath(rect: rect).fill()
        if usesTiles {
            _MKTiles.draw(visible: visible, scale: CGFloat(scale), toView: toView, minZ: 0, maxZ: 19, alpha: 1) { cachedTile($0) }
        }
        drawGraticule(visible: visible, scale: scale, rect: rect, st: st, toView: toView, labels: !usesTiles)
        if showsLabels && !usesTiles { drawPlaces(visible: visible, scale: scale, rect: rect, st: st, toView: toView) }
    }

    static func drawGraticule(visible: MKMapRect, scale: Double, rect: CGRect, st: Style, toView: (MKMapPoint) -> CGPoint, labels: Bool) {
        let nw = MKMapPoint(x: visible.minX, y: visible.minY).coordinate, se = MKMapPoint(x: visible.maxX, y: visible.maxY).coordinate
        let lonSpan = max(1e-9, se.longitude - nw.longitude)
        let steps: [Double] = [30, 15, 10, 5, 2, 1, 0.5, 0.2, 0.1, 0.05, 0.02, 0.01, 0.005, 0.002, 0.001, 0.0005, 0.0002, 0.0001]
        let wantLines = Double(rect.width) / 110
        let step = steps.first { lonSpan / $0 >= wantLines * 0.6 } ?? steps.last!
        let major = step * 5
        func isMajor(_ v: Double) -> Bool { abs((v / major).rounded() * major - v) < step * 0.01 }
        let font = UIFont.systemFont(ofSize: 10, weight: .medium)
        func fmt(_ v: Double, _ pos: String, _ neg: String) -> String {
            let decimals = step >= 1 ? 0 : step >= 0.1 ? 1 : step >= 0.01 ? 2 : step >= 0.001 ? 3 : 4
            return String(format: "%.\(decimals)f°%@", abs(v), v >= 0 ? pos : neg)
        }
        // meridians
        var lon = (nw.longitude / step).rounded(.down) * step
        while lon <= se.longitude + step {
            let x = toView(MKMapPoint(CLLocationCoordinate2D(latitude: 0, longitude: lon))).x
            if x >= rect.minX - 1 && x <= rect.maxX + 1 {
                (isMajor(lon) || abs(lon) < 1e-9 ? st.gridMajor : st.grid).setFill()
                UIBezierPath(rect: CGRect(x: x - 0.25, y: rect.minY, width: 0.5, height: rect.height)).fill()
                if labels { _text(fmt(lon, "E", "W"), at: CGPoint(x: x + 3, y: rect.maxY - 30), font: font, color: st.label.withAlphaComponent(0.55), halo: nil) }
            }
            lon += step
        }
        // parallels (latitude step chosen for similar on-screen spacing)
        let latSpan = max(1e-9, nw.latitude - se.latitude)
        let lstep = steps.first { latSpan / $0 >= Double(rect.height) / 110 * 0.6 } ?? step
        var lat = (se.latitude / lstep).rounded(.down) * lstep
        while lat <= nw.latitude + lstep {
            let y = toView(MKMapPoint(CLLocationCoordinate2D(latitude: lat, longitude: nw.longitude))).y
            if y >= rect.minY - 1 && y <= rect.maxY + 1 {
                (abs((lat / (lstep * 5)).rounded() * lstep * 5 - lat) < lstep * 0.01 || abs(lat) < 1e-9 ? st.gridMajor : st.grid).setFill()
                UIBezierPath(rect: CGRect(x: rect.minX, y: y - 0.25, width: rect.width, height: 0.5)).fill()
                if labels { _text(fmt(lat, "N", "S"), at: CGPoint(x: rect.minX + 4, y: y + 2), font: font, color: st.label.withAlphaComponent(0.55), halo: nil) }
            }
            lat += lstep
        }
    }

    static func drawPlaces(visible: MKMapRect, scale: Double, rect: CGRect, st: Style, toView: (MKMapPoint) -> CGPoint) {
        // map points per view point: world ~ 1.1e6 at full zoom-out; landmarks only when zoomed in to a city
        let maxRank = scale > 20_000 ? 1 : scale > 2_000 ? 2 : scale > 200 ? 3 : 4
        var taken: [CGRect] = []
        for p in places.sorted(by: { $0.rank < $1.rank }) where p.rank <= maxRank {
            let mp = MKMapPoint(CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon))
            guard visible.insetBy(dx: -visible.width * 0.05, dy: -visible.height * 0.05).contains(mp) else { continue }
            let c = toView(mp)
            let font = UIFont.systemFont(ofSize: p.rank == 1 ? 13 : p.rank == 4 ? 11 : 12, weight: p.rank == 1 ? .semibold : .medium)
            let size = (p.name as NSString).size(withAttributes: [.font: font])
            let box = CGRect(x: c.x - size.width / 2, y: c.y + 4, width: size.width, height: size.height).insetBy(dx: -4, dy: -2)
            if taken.contains(where: { $0.intersects(box) }) { continue }
            taken.append(box)
            st.dot.setFill()
            UIBezierPath(ovalIn: CGRect(x: c.x - 2.5, y: c.y - 2.5, width: 5, height: 5)).fill()
            _text(p.name, at: CGPoint(x: c.x - size.width / 2, y: c.y + 4), font: font, color: st.label, halo: st.halo)
        }
    }

    static func _text(_ s: String, at p: CGPoint, font: UIFont, color: UIColor, halo: UIColor?) {
        let ns = s as NSString
        if let halo {
            for (dx, dy) in [(-1.0, 0.0), (1.0, 0.0), (0.0, -1.0), (0.0, 1.0)] {
                ns.draw(at: CGPoint(x: p.x + dx, y: p.y + dy), withAttributes: [.font: font, .foregroundColor: halo])
            }
        }
        ns.draw(at: p, withAttributes: [.font: font, .foregroundColor: color])
    }
}
