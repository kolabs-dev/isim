// isim Foundation: AttributedString(markdown:), a self-contained CommonMark + GFM parser.
// Blocks (full syntax): paragraphs, ATX/setext headings, fenced and indented code, block quotes, bullet and
// ordered lists (nested), thematic breaks, GFM tables -> presentationIntent (innermost component first,
// identities numbered in document order). As with Apple's parser, block text is concatenated without
// separators; use presentationIntent to lay blocks out. Inlines: emphasis, strong, ~~strikethrough~~,
// `code`, links, autolinks, images (alt text + imageURL), escapes, entities, hard/soft breaks.
// Not supported: reference-style links, raw HTML interpretation, extended attributes ^[text](key: value).

extension AttributedString {
  public struct MarkdownParsingOptions: Hashable, Sendable {
    public enum InterpretedSyntax: Hashable, Sendable { case full, inlineOnly, inlineOnlyPreservingWhitespace }
    public enum FailurePolicy: Hashable, Sendable { case throwError, returnPartiallyParsedIfPossible }
    public var allowsExtendedAttributes: Bool
    public var interpretedSyntax: InterpretedSyntax
    public var failurePolicy: FailurePolicy
    public var languageCode: String?
    public var appliesSourcePositionAttributes: Bool
    public init(allowsExtendedAttributes: Bool = false, interpretedSyntax: InterpretedSyntax = .full,
                failurePolicy: FailurePolicy = .throwError, languageCode: String? = nil, appliesSourcePositionAttributes: Bool = false) {
      self.allowsExtendedAttributes = allowsExtendedAttributes; self.interpretedSyntax = interpretedSyntax
      self.failurePolicy = failurePolicy; self.languageCode = languageCode; self.appliesSourcePositionAttributes = appliesSourcePositionAttributes
    }
  }

  public init(markdown: String, options: MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
    var r = _MDRenderer(baseURL: baseURL, mode: options.interpretedSyntax)
    switch options.interpretedSyntax {
    case .full:
      r.render(_MDBlockParser.parse(_MDBlockParser.lines(markdown)), parent: nil)
    case .inlineOnly:
      let text = markdown.split(separator: "\n", omittingEmptySubsequences: false)
        .map { $0.drop(while: { $0 == " " || $0 == "\t" }) }.joined(separator: "\n")
      r.inline(text.trimmingCharacters(in: .whitespacesAndNewlines), AttributeContainer())
    case .inlineOnlyPreservingWhitespace:
      r.inline(markdown, AttributeContainer())
    }
    var out = r.out
    if let lang = options.languageCode { out.languageIdentifier = lang }
    self = out
  }
  public init(markdown: Data, options: MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
    try self.init(markdown: String(decoding: markdown, as: UTF8.self), options: options, baseURL: baseURL)
  }
}

indirect enum _MDBlock {
  case paragraph(String)
  case heading(Int, String)
  case code(String?, String)
  case quote([_MDBlock])
  case list(ordered: Bool, items: [[_MDBlock]])
  case rule
  case table(aligns: [PresentationIntent.TableColumn.Alignment], header: [String], rows: [[String]])
}

enum _MDBlockParser {
  static func lines(_ s: String) -> [String] {
    s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
      .split(separator: "\n", omittingEmptySubsequences: false).map { $0.replacingOccurrences(of: "\t", with: "    ") }
  }
  static func indent(_ l: String) -> Int { l.prefix(while: { $0 == " " }).count }
  static func isBlank(_ l: String) -> Bool { l.allSatisfy { $0 == " " } }
  static func dropIndent(_ l: String, _ n: Int) -> String { String(l.dropFirst(min(n, indent(l)))) }

  struct Marker { var ordered: Bool; var delim: Character; var width: Int; var content: String }
  static func listMarker(_ l: String) -> Marker? {
    let ind = indent(l)
    guard ind < 4 else { return nil }
    let rest = Array(l.dropFirst(ind))
    var k = 0, ordered = false, delim: Character = "-"
    if let f = rest.first, "-*+".contains(f) { delim = f; k = 1 }
    else {
      while k < rest.count, k < 9, rest[k].isASCII, rest[k].isNumber { k += 1 }
      guard k > 0, k < rest.count, rest[k] == "." || rest[k] == ")" else { return nil }
      ordered = true; delim = rest[k]; k += 1
    }
    if k < rest.count && rest[k] != " " { return nil }
    var spaces = 0
    while k + spaces < rest.count, rest[k + spaces] == " " { spaces += 1 }
    let content = String(rest[min(rest.count, k + spaces)...])
    if spaces > 4 || content.isEmpty { spaces = 1 }
    return Marker(ordered: ordered, delim: delim, width: ind + k + spaces, content: content.isEmpty ? "" : String(rest[(k + spaces)...]))
  }
  static func isRule(_ t: String) -> Bool {
    let chars = t.filter { $0 != " " }
    guard chars.count >= 3, let c = chars.first, "-*_".contains(c) else { return false }
    return chars.allSatisfy { $0 == c }
  }
  static func fence(_ t: String) -> (Character, Int, String)? {
    guard let c = t.first, c == "`" || c == "~" else { return nil }
    let n = t.prefix(while: { $0 == c }).count
    guard n >= 3 else { return nil }
    let info = t.dropFirst(n).trimmingCharacters(in: .whitespaces)
    if c == "`" && info.contains("`") { return nil }
    return (c, n, info)
  }
  static func heading(_ t: String) -> (Int, String)? {
    let n = t.prefix(while: { $0 == "#" }).count
    guard (1...6).contains(n), t.count == n || t.dropFirst(n).first == " " else { return nil }
    var text = t.dropFirst(n).trimmingCharacters(in: .whitespaces)
    let trailing = text.reversed().prefix(while: { $0 == "#" }).count
    if trailing > 0 {
      let head = text.dropLast(trailing)
      if head.isEmpty || head.last == " " { text = head.trimmingCharacters(in: .whitespaces) }
    }
    return (n, text)
  }
  static func tableCells(_ l: String) -> [String] {
    var t = l.trimmingCharacters(in: .whitespaces)
    if t.hasPrefix("|") { t.removeFirst() }
    if t.hasSuffix("|") && !t.hasSuffix("\\|") { t.removeLast() }
    var cells: [String] = [], cur = "", esc = false
    for ch in t {
      if esc { if ch != "|" { cur.append("\\") }; cur.append(ch); esc = false; continue }
      if ch == "\\" { esc = true; continue }
      if ch == "|" { cells.append(cur.trimmingCharacters(in: .whitespaces)); cur = ""; continue }
      cur.append(ch)
    }
    if esc { cur.append("\\") }
    cells.append(cur.trimmingCharacters(in: .whitespaces))
    return cells
  }
  static func delimiterRow(_ l: String) -> [PresentationIntent.TableColumn.Alignment]? {
    guard l.contains("-") else { return nil }
    var aligns: [PresentationIntent.TableColumn.Alignment] = []
    for c in tableCells(l) {
      guard !c.isEmpty, c.allSatisfy({ $0 == "-" || $0 == ":" }), c.contains("-") else { return nil }
      let l = c.hasPrefix(":"), r = c.hasSuffix(":")
      aligns.append(l && r ? .center : r ? .right : .left)
    }
    return aligns
  }
  /// Would this line start a block other than a paragraph (so it cannot be a lazy continuation)?
  static func startsBlock(_ l: String) -> Bool {
    let t = l.trimmingCharacters(in: .whitespaces)
    return indent(l) < 4 && (t.hasPrefix(">") || heading(t) != nil || fence(t) != nil || isRule(t) || listMarker(l) != nil)
  }

  static func parse(_ lines: [String]) -> [_MDBlock] {
    var blocks: [_MDBlock] = [], para: [String] = [], i = 0
    func flush() {
      if !para.isEmpty { blocks.append(.paragraph(para.joined(separator: "\n").trimmingCharacters(in: .whitespaces))) }
      para = []
    }
    while i < lines.count {
      let line = lines[i], ind = indent(line)
      let t = String(line.dropFirst(ind))
      if isBlank(line) { flush(); i += 1; continue }
      if ind >= 4 {
        if !para.isEmpty { para.append(t); i += 1; continue }   // lazy paragraph continuation
        var code: [String] = []
        while i < lines.count, isBlank(lines[i]) || indent(lines[i]) >= 4 { code.append(dropIndent(lines[i], 4)); i += 1 }
        while code.last.map(isBlank) == true { code.removeLast() }
        blocks.append(.code(nil, code.joined(separator: "\n") + "\n"))
        continue
      }
      if let (c, n, info) = fence(t) {
        flush(); i += 1
        var code: [String] = []
        while i < lines.count {
          let ct = lines[i].trimmingCharacters(in: .whitespaces)
          if indent(lines[i]) < 4, ct.first == c, ct.prefix(while: { $0 == c }).count >= n, ct.allSatisfy({ $0 == c }) { i += 1; break }
          code.append(dropIndent(lines[i], ind)); i += 1
        }
        blocks.append(.code(info.isEmpty ? nil : String(info.split(separator: " ").first!), code.isEmpty ? "" : code.joined(separator: "\n") + "\n"))
        continue
      }
      if let (level, text) = heading(t) { flush(); blocks.append(.heading(level, text)); i += 1; continue }
      if !para.isEmpty, t.trimmingCharacters(in: .whitespaces).allSatisfy({ $0 == "=" }) {
        blocks.append(.heading(1, para.joined(separator: "\n").trimmingCharacters(in: .whitespaces))); para = []; i += 1; continue
      }
      if !para.isEmpty, t.trimmingCharacters(in: .whitespaces).allSatisfy({ $0 == "-" }) {
        blocks.append(.heading(2, para.joined(separator: "\n").trimmingCharacters(in: .whitespaces))); para = []; i += 1; continue
      }
      if isRule(t) { flush(); blocks.append(.rule); i += 1; continue }
      if t.hasPrefix(">") {
        flush()
        var inner: [String] = []
        while i < lines.count {
          let l = lines[i], lt = l.trimmingCharacters(in: .whitespaces)
          if indent(l) < 4, lt.hasPrefix(">") {
            var rest = lt.dropFirst()
            if rest.first == " " { rest = rest.dropFirst() }
            inner.append(String(rest)); i += 1
          } else if !isBlank(l), let last = inner.last, !isBlank(last), !startsBlock(l) {
            inner.append(lt); i += 1   // lazy continuation
          } else { break }
        }
        blocks.append(.quote(parse(inner)))
        continue
      }
      if let m = listMarker(line), para.isEmpty || (!m.content.isEmpty && (!m.ordered || m.content.first != nil)) {
        flush()
        let (block, next) = parseList(lines, i, m)
        blocks.append(block); i = next
        continue
      }
      if para.isEmpty, line.contains("|"), i + 1 < lines.count, let aligns = delimiterRow(lines[i + 1]), tableCells(line).count == aligns.count {
        let header = tableCells(line)
        i += 2
        var rows: [[String]] = []
        while i < lines.count, !isBlank(lines[i]), !startsBlock(lines[i]) {
          var cells = tableCells(lines[i])
          if cells.count < aligns.count { cells += Array(repeating: "", count: aligns.count - cells.count) }
          rows.append(Array(cells.prefix(aligns.count))); i += 1
        }
        blocks.append(.table(aligns: aligns, header: header, rows: rows))
        continue
      }
      para.append(t); i += 1
    }
    flush()
    return blocks
  }

  static func parseList(_ lines: [String], _ start: Int, _ first: Marker) -> (_MDBlock, Int) {
    var items: [[String]] = [], cur: [String] = [first.content], width = first.width, i = start + 1
    var sawBlank = false
    while i < lines.count {
      let l = lines[i]
      if isBlank(l) { cur.append(""); sawBlank = true; i += 1; continue }
      if indent(l) >= width { cur.append(String(l.dropFirst(width))); sawBlank = false; i += 1; continue }
      if let m = listMarker(l), m.ordered == first.ordered, m.delim == first.delim {
        items.append(cur); cur = [m.content]; width = m.width; sawBlank = false; i += 1; continue
      }
      if !sawBlank, !startsBlock(l) { cur.append(l.trimmingCharacters(in: .whitespaces)); i += 1; continue }   // lazy continuation
      break
    }
    items.append(cur)
    // trailing blank lines belong after the list
    while i > start, isBlank(lines[i - 1]), let last = items.last?.last, isBlank(last) {
      items[items.count - 1].removeLast(); i -= 1
    }
    return (.list(ordered: first.ordered, items: items.map { parse($0) }), i)
  }
}

struct _MDRenderer {
  var out = AttributedString()
  var nextIdentity = 1
  let baseURL: URL?
  let mode: AttributedString.MarkdownParsingOptions.InterpretedSyntax
  init(baseURL: URL?, mode: AttributedString.MarkdownParsingOptions.InterpretedSyntax) { self.baseURL = baseURL; self.mode = mode }

  mutating func identity() -> Int { defer { nextIdentity += 1 }; return nextIdentity }
  mutating func render(_ blocks: [_MDBlock], parent: PresentationIntent?) {
    for b in blocks {
      switch b {
      case .paragraph(let text):
        var c = AttributeContainer(); c.presentationIntent = PresentationIntent(.paragraph, identity: identity(), parent: parent)
        inline(text, c)
      case .heading(let level, let text):
        var c = AttributeContainer(); c.presentationIntent = PresentationIntent(.header(level: level), identity: identity(), parent: parent)
        inline(text, c)
      case .code(let lang, let text):
        var c = AttributeContainer(); c.presentationIntent = PresentationIntent(.codeBlock(languageHint: lang), identity: identity(), parent: parent)
        out.append(AttributedString(text, attributes: c))
      case .quote(let inner):
        render(inner, parent: PresentationIntent(.blockQuote, identity: identity(), parent: parent))
      case .list(let ordered, let items):
        let list = PresentationIntent(ordered ? .orderedList : .unorderedList, identity: identity(), parent: parent)
        for (k, item) in items.enumerated() {
          render(item, parent: PresentationIntent(.listItem(ordinal: k + 1), identity: identity(), parent: list))
        }
      case .rule:
        var c = AttributeContainer(); c.presentationIntent = PresentationIntent(.thematicBreak, identity: identity(), parent: parent)
        _ = c   // a thematic break has no text to carry it
      case .table(let aligns, let header, let rows):
        let table = PresentationIntent(.table(columns: aligns.map { PresentationIntent.TableColumn(alignment: $0) }), identity: identity(), parent: parent)
        let headerRow = PresentationIntent(.tableHeaderRow, identity: identity(), parent: table)
        for (col, cell) in header.enumerated() {
          var c = AttributeContainer(); c.presentationIntent = PresentationIntent(.tableCell(columnIndex: col), identity: identity(), parent: headerRow)
          inline(cell, c)
        }
        for (r, row) in rows.enumerated() {
          let rowIntent = PresentationIntent(.tableRow(rowIndex: r + 1), identity: identity(), parent: table)
          for (col, cell) in row.enumerated() {
            var c = AttributeContainer(); c.presentationIntent = PresentationIntent(.tableCell(columnIndex: col), identity: identity(), parent: rowIntent)
            inline(cell, c)
          }
        }
      }
    }
  }

  mutating func inline(_ text: String, _ base: AttributeContainer) {
    var parser = _MDInlineParser(Array(text), preserveWhitespace: mode == .inlineOnlyPreservingWhitespace)
    let nodes = parser.parse()
    emit(nodes, base)
  }
  mutating func emit(_ nodes: [_MDInline], _ attrs: AttributeContainer) {
    func with(_ flag: InlinePresentationIntent) -> AttributeContainer {
      var a = attrs; a.inlinePresentationIntent = (attrs.inlinePresentationIntent ?? []).union(flag); return a
    }
    for n in nodes {
      switch n {
      case .text(let s): if !s.isEmpty { out.append(AttributedString(s, attributes: attrs)) }
      case .code(let s): out.append(AttributedString(s, attributes: with(.code)))
      case .softBreak: out.append(AttributedString(" ", attributes: with(.softBreak)))
      case .lineBreak: out.append(AttributedString("\n", attributes: with(.lineBreak)))
      case .emph(let inner): emit(inner, with(.emphasized))
      case .strong(let inner): emit(inner, with(.stronglyEmphasized))
      case .strike(let inner): emit(inner, with(.strikethrough))
      case .link(let dest, let inner):
        var a = attrs
        if let u = URL(string: dest, relativeTo: baseURL) ?? dest.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed).flatMap({ URL(string: $0, relativeTo: baseURL) }) { a.link = u }
        emit(inner, a)
      case .image(let dest, let inner):
        var a = attrs
        if let u = URL(string: dest, relativeTo: baseURL) { a.imageURL = u }
        emit(inner, a)
      }
    }
  }
}

indirect enum _MDInline {
  case text(String), code(String), softBreak, lineBreak
  case emph([_MDInline]), strong([_MDInline]), strike([_MDInline])
  case link(String, [_MDInline]), image(String, [_MDInline])
}

struct _MDInlineParser {
  enum Item {
    case node(_MDInline)
    case delim(Character, Int, canOpen: Bool, canClose: Bool)
    case bracket(image: Bool, active: Bool)
  }
  let c: [Character]
  let preserve: Bool
  var items: [Item] = []
  init(_ c: [Character], preserveWhitespace: Bool) { self.c = c; preserve = preserveWhitespace }

  static func isPunct(_ ch: Character) -> Bool { ch.isPunctuation || ch.isSymbol }
  mutating func text(_ s: String) {
    if case .node(.text(let t))? = items.last { items[items.count - 1] = .node(.text(t + s)) } else { items.append(.node(.text(s))) }
  }

  mutating func parse() -> [_MDInline] {
    var i = 0
    while i < c.count {
      let ch = c[i]
      switch ch {
      case "\\":
        if i + 1 < c.count, c[i + 1] == "\n" { items.append(.node(.lineBreak)); i += 2; skipLeadingSpaces(&i); continue }
        if i + 1 < c.count, c[i + 1].isASCII, _MDInlineParser.isPunct(c[i + 1]) { text(String(c[i + 1])); i += 2; continue }
        text("\\"); i += 1
      case "`":
        var n = 0
        while i + n < c.count, c[i + n] == "`" { n += 1 }
        var j = i + n, found = -1
        while j < c.count {
          if c[j] == "`" {
            var m = 0
            while j + m < c.count, c[j + m] == "`" { m += 1 }
            if m == n { found = j; break }
            j += m
          } else { j += 1 }
        }
        if found < 0 { text(String(repeating: "`", count: n)); i += n; continue }
        var code = String(c[(i + n)..<found]).replacingOccurrences(of: "\n", with: " ")
        if code.count >= 2, code.first == " ", code.last == " ", !code.allSatisfy({ $0 == " " }) { code = String(code.dropFirst().dropLast()) }
        items.append(.node(.code(code))); i = found + n
      case "*", "_", "~":
        var n = 0
        while i + n < c.count, c[i + n] == ch { n += 1 }
        let before: Character = i > 0 ? c[i - 1] : " ", after: Character = i + n < c.count ? c[i + n] : " "
        let left = !after.isWhitespace && (!_MDInlineParser.isPunct(after) || before.isWhitespace || _MDInlineParser.isPunct(before))
        let right = !before.isWhitespace && (!_MDInlineParser.isPunct(before) || after.isWhitespace || _MDInlineParser.isPunct(after))
        var canOpen = left, canClose = right
        if ch == "_" { canOpen = left && (!right || _MDInlineParser.isPunct(before)); canClose = right && (!left || _MDInlineParser.isPunct(after)) }
        if ch == "~" && n > 2 { text(String(repeating: "~", count: n)); i += n; continue }
        items.append(.delim(ch, n, canOpen: canOpen, canClose: canClose)); i += n
      case "!" where i + 1 < c.count && c[i + 1] == "[":
        items.append(.bracket(image: true, active: true)); i += 2
      case "[":
        items.append(.bracket(image: false, active: true)); i += 1
      case "]":
        i += 1
        guard let b = items.lastIndex(where: { if case .bracket = $0 { return true }; return false }),
              case .bracket(let isImage, let active) = items[b] else { text("]"); continue }
        if active, let (dest, next) = linkDestination(i) {
          var inner = Array(items[(b + 1)...])
          _MDInlineParser.processEmphasis(&inner, 0)
          let nodes = _MDInlineParser.nodes(inner)
          items.removeSubrange(b...)
          items.append(.node(isImage ? .image(dest, nodes) : .link(dest, nodes)))
          if !isImage {   // no links inside links
            for k in items.indices { if case .bracket(false, _) = items[k] { items[k] = .bracket(image: false, active: false) } }
          }
          i = next
        } else {
          items[b] = .node(.text(isImage ? "![" : "["))
          text("]")
        }
      case "<":
        if let (url, label, next) = autolink(i) { items.append(.node(.link(url, [.text(label)]))); i = next } else { text("<"); i += 1 }
      case "&":
        if let (s, next) = entity(i) { text(s); i = next } else { text("&"); i += 1 }
      case "\n":
        if preserve { text("\n"); i += 1; continue }
        var trailing = 0
        if case .node(.text(let t))? = items.last {
          trailing = t.reversed().prefix(while: { $0 == " " }).count
          items[items.count - 1] = .node(.text(String(t.dropLast(trailing))))
        }
        items.append(.node(trailing >= 2 ? .lineBreak : .softBreak))
        i += 1
        skipLeadingSpaces(&i)
      default:
        var j = i
        while j < c.count, !"\\`*_~![]<&\n".contains(c[j]) { j += 1 }
        if j == i { j += 1 }
        text(String(c[i..<j])); i = j
      }
    }
    _MDInlineParser.processEmphasis(&items, 0)
    var result = _MDInlineParser.nodes(items)
    if !preserve, case .text(let t)? = result.last {   // trailing spaces at the end of a block are dropped
      let trimmed = String(t.reversed().drop(while: { $0 == " " }).reversed())
      result[result.count - 1] = .text(trimmed)
    }
    return result
  }
  func skipLeadingSpaces(_ i: inout Int) { if !preserve { while i < c.count, c[i] == " " { i += 1 } } }

  /// Parses `(destination "title")` at `i`; returns the destination and the index after `)`.
  func linkDestination(_ start: Int) -> (String, Int)? {
    var i = start
    guard i < c.count, c[i] == "(" else { return nil }
    i += 1
    while i < c.count, c[i] == " " || c[i] == "\n" { i += 1 }
    var dest = ""
    if i < c.count, c[i] == "<" {
      i += 1
      while i < c.count, c[i] != ">", c[i] != "\n" { dest.append(c[i]); i += 1 }
      guard i < c.count, c[i] == ">" else { return nil }
      i += 1
    } else {
      var depth = 0
      while i < c.count, !c[i].isWhitespace {
        if c[i] == "\\", i + 1 < c.count, _MDInlineParser.isPunct(c[i + 1]) { dest.append(c[i + 1]); i += 2; continue }
        if c[i] == "(" { depth += 1 } else if c[i] == ")" { if depth == 0 { break }; depth -= 1 }
        dest.append(c[i]); i += 1
      }
    }
    while i < c.count, c[i] == " " || c[i] == "\n" { i += 1 }
    if i < c.count, c[i] == "\"" || c[i] == "'" || c[i] == "(" {   // optional title, ignored
      let close: Character = c[i] == "(" ? ")" : c[i]
      i += 1
      while i < c.count, c[i] != close { i += 1 }
      guard i < c.count else { return nil }
      i += 1
      while i < c.count, c[i] == " " || c[i] == "\n" { i += 1 }
    }
    guard i < c.count, c[i] == ")" else { return nil }
    return (dest, i + 1)
  }
  func autolink(_ start: Int) -> (String, String, Int)? {
    var j = start + 1, body = ""
    while j < c.count, c[j] != ">", c[j] != "<", !c[j].isWhitespace { body.append(c[j]); j += 1 }
    guard j < c.count, c[j] == ">", !body.isEmpty else { return nil }
    if let colon = body.firstIndex(of: ":") {
      let scheme = body[..<colon]
      if (2...32).contains(scheme.count), scheme.first!.isLetter, scheme.allSatisfy({ $0.isLetter || $0.isNumber || "+.-".contains($0) }) { return (body, body, j + 1) }
    }
    if body.contains("@"), !body.contains("/") { return ("mailto:" + body, body, j + 1) }
    return nil
  }
  func entity(_ start: Int) -> (String, Int)? {
    var j = start + 1, name = ""
    while j < c.count, c[j] != ";", name.count < 32, c[j].isLetter || c[j].isNumber || c[j] == "#" { name.append(c[j]); j += 1 }
    guard j < c.count, c[j] == ";", !name.isEmpty else { return nil }
    let named: [String: String] = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{A0}", "copy": "©",
                                   "reg": "®", "trade": "™", "hellip": "…", "mdash": "—", "ndash": "–", "euro": "€", "laquo": "«", "raquo": "»"]
    if let s = named[name] { return (s, j + 1) }
    if name.hasPrefix("#") {
      let digits = name.dropFirst()
      let v = digits.first == "x" || digits.first == "X" ? UInt32(digits.dropFirst(), radix: 16) : UInt32(digits)
      if let v = v, let u = Unicode.Scalar(v == 0 ? 0xFFFD : v) { return (String(Character(u)), j + 1) }
    }
    return nil
  }

  static func processEmphasis(_ items: inout [Item], _ bottom: Int) {
    var closer = bottom
    while closer < items.count {
      guard case .delim(let ch, let cnt, let cOpen, true) = items[closer], cnt > 0 else { closer += 1; continue }
      var opener = closer - 1, found = false
      while opener >= bottom {
        if case .delim(ch, let ocnt, true, let oClose) = items[opener], ocnt > 0 {
          let ruleOf3 = ch != "~" && (cOpen || oClose) && (ocnt + cnt) % 3 == 0 && !(ocnt % 3 == 0 && cnt % 3 == 0)
          let tildeMismatch = ch == "~" && ocnt != cnt
          if !ruleOf3 && !tildeMismatch { found = true; break }
        }
        opener -= 1
      }
      if !found { closer += 1; continue }
      guard case .delim(_, let ocnt, let oOpen, let oClose) = items[opener] else { closer += 1; continue }
      let use = ch == "~" ? cnt : (cnt >= 2 && ocnt >= 2 ? 2 : 1)
      let inner = nodes(Array(items[(opener + 1)..<closer]))
      let wrapped: _MDInline = ch == "~" ? .strike(inner) : use == 2 ? .strong(inner) : .emph(inner)
      items.replaceSubrange((opener + 1)..<closer, with: [.node(wrapped)])
      closer = opener + 2
      items[opener] = .delim(ch, ocnt - use, canOpen: oOpen, canClose: oClose)
      items[closer] = .delim(ch, cnt - use, canOpen: cOpen, canClose: true)
      if ocnt - use == 0 { items.remove(at: opener); closer -= 1 }
      if cnt - use == 0 { items.remove(at: closer) }
    }
  }
  static func nodes(_ items: [Item]) -> [_MDInline] {
    var out: [_MDInline] = []
    func add(_ s: String) {
      if case .text(let t)? = out.last { out[out.count - 1] = .text(t + s) } else { out.append(.text(s)) }
    }
    for it in items {
      switch it {
      case .node(.text(let s)): add(s)
      case .node(let n): out.append(n)
      case .delim(let ch, let n, _, _): if n > 0 { add(String(repeating: ch, count: n)) }
      case .bracket(let image, _): add(image ? "![" : "[")
      }
    }
    return out
  }
}
