// isim WebKit: web archives for WKWebView.createWebArchiveData.
//
// WebKitGTK saves a page as MHTML (multipart/related: the page, then each resource with its Content-Location);
// this turns it into Apple's .webarchive, a binary property list:
//   { WebMainResource: { WebResourceData, WebResourceMIMEType, WebResourceTextEncodingName, WebResourceURL, WebResourceFrameName },
//     WebSubresources: [ { WebResourceData, WebResourceMIMEType, WebResourceURL }, ... ] }
import Foundation

struct _WKMHTMLPart { var headers: [String: String]; var body: Data }

/// the parts of an MHTML document, bodies decoded (base64, quoted-printable, binary)
func _wkMHTMLParts(_ mhtml: Data) -> [_WKMHTMLPart] {
    let bytes = [UInt8](mhtml)
    func find(_ needle: [UInt8], from: Int) -> Int? {
        guard !needle.isEmpty, bytes.count >= needle.count, from <= bytes.count - needle.count else { return nil }
        var i = from
        while i <= bytes.count - needle.count {
            if bytes[i] == needle[0] && Array(bytes[i..<i + needle.count]) == needle { return i }
            i += 1
        }
        return nil
    }
    // the boundary from the top-level Content-Type
    guard let bi = find(Array("boundary=".utf8), from: 0) else { return [] }
    var j = bi + 9, boundary: [UInt8] = []
    if j < bytes.count && bytes[j] == 34 /* " */ { j += 1; while j < bytes.count && bytes[j] != 34 { boundary.append(bytes[j]); j += 1 } }
    else { while j < bytes.count && ![10, 13, 59, 32].contains(bytes[j]) { boundary.append(bytes[j]); j += 1 } }
    guard !boundary.isEmpty else { return [] }
    let delim = Array("--".utf8) + boundary
    var parts: [_WKMHTMLPart] = []
    var pos = find(delim, from: j)
    while let start = pos {
        var p = start + delim.count
        if p + 1 < bytes.count && bytes[p] == 45 && bytes[p + 1] == 45 { break }          /* the closing --boundary-- */
        while p < bytes.count && (bytes[p] == 13 || bytes[p] == 10) { if bytes[p] == 10 { p += 1; break }; p += 1 }
        let next = find(delim, from: p) ?? bytes.count
        // headers end at the first empty line
        var hEnd = p, bodyStart = p
        while hEnd < next {
            if bytes[hEnd] == 10 && hEnd + 1 < next && bytes[hEnd + 1] == 10 { bodyStart = hEnd + 2; break }
            if bytes[hEnd] == 10 && hEnd + 2 < next && bytes[hEnd + 1] == 13 && bytes[hEnd + 2] == 10 { bodyStart = hEnd + 3; break }
            hEnd += 1
        }
        var headers: [String: String] = [:]
        for line in String(decoding: bytes[p..<hEnd], as: UTF8.self).split(whereSeparator: { $0.isNewline }) {
            if let i = line.firstIndex(of: ":") { headers[line[..<i].lowercased()] = line[line.index(after: i)...].trimmingCharacters(in: .whitespaces) }
        }
        var bodyEnd = next
        while bodyEnd > bodyStart && (bytes[bodyEnd - 1] == 10 || bytes[bodyEnd - 1] == 13) { bodyEnd -= 1 }
        let raw = bodyStart <= bodyEnd ? Array(bytes[bodyStart..<bodyEnd]) : []
        let enc = (headers["content-transfer-encoding"] ?? "").lowercased()
        let data: Data
        if enc == "base64" { data = Data(base64Encoded: String(decoding: raw.filter { ![10, 13, 32, 9].contains($0) }, as: UTF8.self)) ?? Data() }
        else if enc == "quoted-printable" { data = _wkQuotedPrintable(String(decoding: raw, as: UTF8.self)) }
        else { data = Data(raw) }
        parts.append(_WKMHTMLPart(headers: headers, body: data))
        pos = next < bytes.count ? next : nil
    }
    return parts
}

func _wkQuotedPrintable(_ s: String) -> Data {
    var out = [UInt8](), bytes = [UInt8](s.utf8), i = 0
    func hex(_ c: UInt8) -> UInt8? {
        switch c { case 48...57: return c - 48; case 65...70: return c - 55; case 97...102: return c - 87; default: return nil }
    }
    while i < bytes.count {
        let c = bytes[i]
        if c == 61 /* = */ {
            if i + 1 < bytes.count && bytes[i + 1] == 13 && i + 2 < bytes.count && bytes[i + 2] == 10 { i += 3; continue }   /* soft break */
            if i + 1 < bytes.count && bytes[i + 1] == 10 { i += 2; continue }
            if i + 2 < bytes.count, let h = hex(bytes[i + 1]), let l = hex(bytes[i + 2]) { out.append(h << 4 | l); i += 3; continue }
        }
        out.append(c); i += 1
    }
    return Data(out)
}

func _wkWebArchive(fromMHTML mhtml: Data, mainURL: URL?) -> Data? {
    let parts = _wkMHTMLParts(mhtml)
    guard let main = parts.first else { return nil }
    func resource(_ p: _WKMHTMLPart, fallbackURL: String) -> [String: Any] {
        let ct = p.headers["content-type"] ?? "application/octet-stream"
        let mime = String(ct.split(separator: ";").first ?? "").trimmingCharacters(in: .whitespaces)
        var r: [String: Any] = ["WebResourceData": p.body, "WebResourceMIMEType": mime,
                                "WebResourceURL": p.headers["content-location"] ?? fallbackURL]
        if let cs = ct.range(of: "charset=", options: .caseInsensitive) {
            r["WebResourceTextEncodingName"] = ct[cs.upperBound...].prefix { $0 != ";" }.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
        }
        return r
    }
    var m = resource(main, fallbackURL: mainURL?.absoluteString ?? "about:blank")
    m["WebResourceFrameName"] = ""
    if m["WebResourceTextEncodingName"] == nil { m["WebResourceTextEncodingName"] = "UTF-8" }
    var archive: [String: Any] = ["WebMainResource": m]
    let subs = parts.dropFirst().map { resource($0, fallbackURL: "") }.filter { !(($0["WebResourceURL"] as? String) ?? "").isEmpty }
    if !subs.isEmpty { archive["WebSubresources"] = subs }
    do { return try PropertyListSerialization.data(fromPropertyList: archive, format: .binary, options: 0) }
    catch { print("isim: web archive: \(error)"); return nil }
}
