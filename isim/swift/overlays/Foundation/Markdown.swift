// isim Foundation: AttributedString(markdown:), a self-contained CommonMark + GFM parser.
// Blocks (full syntax): paragraphs, ATX/setext headings, fenced and indented code, block quotes, bullet and
// ordered lists (nested), thematic breaks, GFM tables -> presentationIntent (innermost component first,
// identities numbered in document order). As with Apple's parser, block text is concatenated without
// separators; use presentationIntent to lay blocks out. Inlines: emphasis, strong, ~~strikethrough~~,
// `code`, links (inline and reference-style), autolinks, images (alt text + imageURL), escapes, entities,
// hard/soft breaks, extended attributes ^[text](key: value) (allowsExtendedAttributes; decoded by the scope's
// MarkdownDecodableAttributedStringKeys), source positions (appliesSourcePositionAttributes: each run's text,
// 1-based lines and UTF-8 columns; tabs count as 4 columns). Not supported: raw HTML interpretation.

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
    try self.init(markdown: markdown, scope: AttributeScopes.FoundationAttributes.self, options: options, baseURL: baseURL)
  }
  public init(markdown: Data, options: MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
    try self.init(markdown: String(decoding: markdown, as: UTF8.self), options: options, baseURL: baseURL)
  }
  public init<S: AttributeScope>(markdown: String, including scope: KeyPath<AttributeScopes, S.Type>, options: MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
    try self.init(markdown: markdown, scope: S.self, options: options, baseURL: baseURL)
  }
  public init<S: AttributeScope>(markdown: String, including scope: S.Type, options: MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
    try self.init(markdown: markdown, scope: S.self, options: options, baseURL: baseURL)
  }
  public init<S: AttributeScope>(markdown: Data, including scope: KeyPath<AttributeScopes, S.Type>, options: MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
    try self.init(markdown: String(decoding: markdown, as: UTF8.self), scope: S.self, options: options, baseURL: baseURL)
  }
  public init<S: AttributeScope>(markdown: Data, including scope: S.Type, options: MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
    try self.init(markdown: String(decoding: markdown, as: UTF8.self), scope: S.self, options: options, baseURL: baseURL)
  }
  init(markdown: String, scope: Any.Type, options: MarkdownParsingOptions, baseURL: URL?) throws {
    var r = _MDRenderer(baseURL: baseURL, options: options, scope: options.allowsExtendedAttributes ? AttributeScopeCodableConfiguration(scope) : nil)
    switch options.interpretedSyntax {
    case .full:
      let lines = _MDBlockParser.lines(markdown)
      var refs: [String: String] = [:]
      let blocks = _MDBlockParser.parse(lines, lines.indices.map { _MDSrc(line: $0 + 1, col: 1) }, &refs)
      r.refs = refs
      r.render(blocks, parent: nil)
    case .inlineOnly:
      let raw = markdown.split(separator: "\n", omittingEmptySubsequences: false)
      var src: [_MDSrc] = [], parts: [Substring] = []
      for (n, l) in raw.enumerated() {
        let body = l.drop(while: { $0 == " " || $0 == "\t" })
        parts.append(body); src.append(_MDSrc(line: n + 1, col: 1 + l.utf8.count - body.utf8.count))
      }
      let joined = parts.joined(separator: "\n")
      let lead = joined.prefix(while: { $0.isWhitespace || $0.isNewline }).count
      let text = joined.trimmingCharacters(in: .whitespacesAndNewlines)
      r.inline(text, AttributeContainer(), positions: _MDRenderer.positions(joined, src).dropFirst(lead).map { $0 })
    case .inlineOnlyPreservingWhitespace:
      let n = markdown.split(separator: "\n", omittingEmptySubsequences: false).count
      r.inline(markdown, AttributeContainer(), positions: _MDRenderer.positions(markdown, (0..<n).map { _MDSrc(line: $0 + 1, col: 1) }))
    }
    var out = r.out
    if let lang = options.languageCode { out.languageIdentifier = lang }
    self = out
  }
}

/// a source location: 1-based line, 1-based UTF-8 column
struct _MDSrc: Hashable {
  var line: Int, col: Int
  func adv(_ s: some StringProtocol) -> _MDSrc { _MDSrc(line: line, col: col + s.utf8.count) }
  func adv(_ n: Int) -> _MDSrc { _MDSrc(line: line, col: col + n) }
}

indirect enum _MDBlock {
  case paragraph(String, [_MDSrc])                 // the source of each of the text's lines
  case heading(Int, String, _MDSrc)
  case code(String?, String, [_MDSrc])
  case quote([_MDBlock])
  case list(ordered: Bool, items: [[_MDBlock]])
  case rule
  case table(aligns: [PresentationIntent.TableColumn.Alignment], header: [(String, _MDSrc)], rows: [[(String, _MDSrc)]])
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
  static func heading(_ t: String) -> (Int, String)? { headingWithOffset(t).map { ($0.0, $0.1) } }
  /// level, text and the text's offset (characters) in the line
  static func headingWithOffset(_ t: String) -> (Int, String, Int)? {
    let n = t.prefix(while: { $0 == "#" }).count
    guard (1...6).contains(n), t.count == n || t.dropFirst(n).first == " " else { return nil }
    let offset = n + t.dropFirst(n).prefix(while: { $0 == " " }).count
    var text = t.dropFirst(n).trimmingCharacters(in: .whitespaces)
    let trailing = text.reversed().prefix(while: { $0 == "#" }).count
    if trailing > 0 {
      let head = text.dropLast(trailing)
      if head.isEmpty || head.last == " " { text = head.trimmingCharacters(in: .whitespaces) }
    }
    return (n, text, offset)
  }
  static func tableCells(_ l: String) -> [String] { tableCellsWithOffsets(l).map(\.0) }
  /// cells with their offsets (UTF-8 bytes) in the line
  static func tableCellsWithOffsets(_ l: String) -> [(String, Int)] {
    var off = l.utf8.count - l.drop(while: { $0 == " " }).utf8.count
    var t = l.trimmingCharacters(in: .whitespaces)
    if t.hasPrefix("|") { t.removeFirst(); off += 1 }
    if t.hasSuffix("|") && !t.hasSuffix("\\|") { t.removeLast() }
    var cells: [(String, Int)] = [], cur = "", esc = false, start = off, pos = off
    func finish() {
      let lead = cur.prefix(while: { $0 == " " }).utf8.count
      cells.append((cur.trimmingCharacters(in: .whitespaces), start + lead))
    }
    for ch in t {
      defer { pos += ch.utf8.count }
      if esc { if ch != "|" { cur.append("\\") }; cur.append(ch); esc = false; continue }
      if ch == "\\" { esc = true; continue }
      if ch == "|" { finish(); cur = ""; start = pos + 1; continue }
      cur.append(ch)
    }
    if esc { cur.append("\\") }
    finish()
    return cells
  }
  /// a link reference definition: `[label]: destination "title"` (on one line)
  static func referenceDefinition(_ t: String) -> (String, String)? {
    guard t.hasPrefix("["), let close = t.firstIndex(of: "]"), t.index(after: close) < t.endIndex, t[t.index(after: close)] == ":" else { return nil }
    let label = t[t.index(after: t.startIndex)..<close]
    guard !label.trimmingCharacters(in: .whitespaces).isEmpty, !label.contains("[") else { return nil }
    let rest = t[t.index(close, offsetBy: 2)...].trimmingCharacters(in: .whitespaces)
    guard !rest.isEmpty else { return nil }
    var dest: String, after: Substring
    if rest.hasPrefix("<") {
      guard let gt = rest.firstIndex(of: ">") else { return nil }
      dest = String(rest[rest.index(after: rest.startIndex)..<gt]); after = rest[rest.index(after: gt)...]
    } else {
      let end = rest.firstIndex(where: { $0 == " " }) ?? rest.endIndex
      dest = String(rest[..<end]); after = rest[end...]
    }
    let title = after.trimmingCharacters(in: .whitespaces)
    if !title.isEmpty {
      guard let f = title.first, let l = title.last, title.count >= 2,
            (f == "\"" && l == "\"") || (f == "'" && l == "'") || (f == "(" && l == ")") else { return nil }
    }
    return (normalizeLabel(String(label)), dest)
  }
  static func normalizeLabel(_ s: String) -> String {
    s.lowercased().split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).joined(separator: " ")
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

  /// `src[i]`: where `lines[i]` starts in the source. Link reference definitions go to `refs` (first one wins).
  static func parse(_ lines: [String], _ src: [_MDSrc], _ refs: inout [String: String]) -> [_MDBlock] {
    var blocks: [_MDBlock] = [], para: [String] = [], paraSrc: [_MDSrc] = [], i = 0
    func flush() {
      if !para.isEmpty { blocks.append(.paragraph(para.joined(separator: "\n").trimmingCharacters(in: .whitespaces), paraSrc)) }
      para = []; paraSrc = []
    }
    func lead(_ l: String) -> Int { l.utf8.count - l.drop(while: { $0 == " " }).utf8.count }
    while i < lines.count {
      let line = lines[i], ind = indent(line)
      let t = String(line.dropFirst(ind)), tsrc = src[i].adv(ind)
      if isBlank(line) { flush(); i += 1; continue }
      if ind >= 4 {
        if !para.isEmpty { para.append(t); paraSrc.append(tsrc); i += 1; continue }   // lazy paragraph continuation
        var code: [String] = [], codeSrc: [_MDSrc] = []
        while i < lines.count, isBlank(lines[i]) || indent(lines[i]) >= 4 {
          code.append(dropIndent(lines[i], 4)); codeSrc.append(src[i].adv(min(4, indent(lines[i])))); i += 1
        }
        while code.last.map(isBlank) == true { code.removeLast(); codeSrc.removeLast() }
        blocks.append(.code(nil, code.joined(separator: "\n") + "\n", codeSrc))
        continue
      }
      if para.isEmpty, let (label, dest) = referenceDefinition(t) {
        if refs[label] == nil { refs[label] = dest }
        i += 1; continue
      }
      if let (c, n, info) = fence(t) {
        flush(); i += 1
        var code: [String] = [], codeSrc: [_MDSrc] = []
        while i < lines.count {
          let ct = lines[i].trimmingCharacters(in: .whitespaces)
          if indent(lines[i]) < 4, ct.first == c, ct.prefix(while: { $0 == c }).count >= n, ct.allSatisfy({ $0 == c }) { i += 1; break }
          code.append(dropIndent(lines[i], ind)); codeSrc.append(src[i].adv(min(ind, indent(lines[i])))); i += 1
        }
        blocks.append(.code(info.isEmpty ? nil : String(info.split(separator: " ").first!), code.isEmpty ? "" : code.joined(separator: "\n") + "\n", codeSrc))
        continue
      }
      if let (level, text, off) = headingWithOffset(t) { flush(); blocks.append(.heading(level, text, tsrc.adv(t.prefix(off)))); i += 1; continue }
      if !para.isEmpty, t.trimmingCharacters(in: .whitespaces).allSatisfy({ $0 == "=" }) {
        blocks.append(.heading(1, para.joined(separator: "\n").trimmingCharacters(in: .whitespaces), paraSrc[0])); para = []; paraSrc = []; i += 1; continue
      }
      if !para.isEmpty, t.trimmingCharacters(in: .whitespaces).allSatisfy({ $0 == "-" }) {
        blocks.append(.heading(2, para.joined(separator: "\n").trimmingCharacters(in: .whitespaces), paraSrc[0])); para = []; paraSrc = []; i += 1; continue
      }
      if isRule(t) { flush(); blocks.append(.rule); i += 1; continue }
      if t.hasPrefix(">") {
        flush()
        var inner: [String] = [], innerSrc: [_MDSrc] = []
        while i < lines.count {
          let l = lines[i], lt = l.trimmingCharacters(in: .whitespaces)
          if indent(l) < 4, lt.hasPrefix(">") {
            var rest = lt.dropFirst(), skip = lead(l) + 1
            if rest.first == " " { rest = rest.dropFirst(); skip += 1 }
            inner.append(String(rest)); innerSrc.append(src[i].adv(skip)); i += 1
          } else if !isBlank(l), let last = inner.last, !isBlank(last), !startsBlock(l) {
            inner.append(lt); innerSrc.append(src[i].adv(lead(l))); i += 1   // lazy continuation
          } else { break }
        }
        blocks.append(.quote(parse(inner, innerSrc, &refs)))
        continue
      }
      if let m = listMarker(line), para.isEmpty || (!m.content.isEmpty && (!m.ordered || m.content.first != nil)) {
        flush()
        let (block, next) = parseList(lines, src, i, m, &refs)
        blocks.append(block); i = next
        continue
      }
      if para.isEmpty, line.contains("|"), i + 1 < lines.count, let aligns = delimiterRow(lines[i + 1]), tableCells(line).count == aligns.count {
        let header = tableCellsWithOffsets(line).map { ($0.0, src[i].adv($0.1)) }
        i += 2
        var rows: [[(String, _MDSrc)]] = []
        while i < lines.count, !isBlank(lines[i]), !startsBlock(lines[i]) {
          var cells = tableCellsWithOffsets(lines[i]).map { ($0.0, src[i].adv($0.1)) }
          if cells.count < aligns.count { cells += Array(repeating: ("", src[i]), count: aligns.count - cells.count) }
          rows.append(Array(cells.prefix(aligns.count))); i += 1
        }
        blocks.append(.table(aligns: aligns, header: header, rows: rows))
        continue
      }
      para.append(t); paraSrc.append(tsrc); i += 1
    }
    flush()
    return blocks
  }

  static func parseList(_ lines: [String], _ src: [_MDSrc], _ start: Int, _ first: Marker, _ refs: inout [String: String]) -> (_MDBlock, Int) {
    var items: [([String], [_MDSrc])] = [], cur: [String] = [first.content], curSrc: [_MDSrc] = [src[start].adv(first.width)]
    var width = first.width, i = start + 1, sawBlank = false
    while i < lines.count {
      let l = lines[i]
      if isBlank(l) { cur.append(""); curSrc.append(src[i]); sawBlank = true; i += 1; continue }
      if indent(l) >= width { cur.append(String(l.dropFirst(width))); curSrc.append(src[i].adv(width)); sawBlank = false; i += 1; continue }
      if let m = listMarker(l), m.ordered == first.ordered, m.delim == first.delim {
        items.append((cur, curSrc)); cur = [m.content]; curSrc = [src[i].adv(m.width)]; width = m.width; sawBlank = false; i += 1; continue
      }
      if !sawBlank, !startsBlock(l) {   // lazy continuation
        cur.append(l.trimmingCharacters(in: .whitespaces)); curSrc.append(src[i].adv(indent(l))); i += 1; continue
      }
      break
    }
    items.append((cur, curSrc))
    // trailing blank lines belong after the list
    while i > start, isBlank(lines[i - 1]), let last = items.last?.0.last, isBlank(last) {
      items[items.count - 1].0.removeLast(); items[items.count - 1].1.removeLast(); i -= 1
    }
    return (.list(ordered: first.ordered, items: items.map { parse($0.0, $0.1, &refs) }), i)
  }
}

struct _MDRenderer {
  var out = AttributedString()
  var nextIdentity = 1
  let baseURL: URL?
  let mode: AttributedString.MarkdownParsingOptions.InterpretedSyntax
  let options: AttributedString.MarkdownParsingOptions
  let scope: AttributeScopeCodableConfiguration?      // extended attributes (nil: not interpreted)
  var refs: [String: String] = [:]
  var positions: [_MDSrc] = []                         // source of each character of the inline text being emitted
  init(baseURL: URL?, options: AttributedString.MarkdownParsingOptions, scope: AttributeScopeCodableConfiguration?) {
    self.baseURL = baseURL; self.options = options; self.mode = options.interpretedSyntax; self.scope = scope
  }

  /// the source of each character of `text`, whose lines start at `lineSrc`
  static func positions(_ text: String, _ lineSrc: [_MDSrc]) -> [_MDSrc] {
    var out: [_MDSrc] = [], line = 0
    var cur = lineSrc.first ?? _MDSrc(line: 1, col: 1)
    for ch in text {
      out.append(cur)
      if ch == "\n" { line += 1; cur = line < lineSrc.count ? lineSrc[line] : _MDSrc(line: cur.line + 1, col: 1) }
      else { cur = cur.adv(String(ch)) }
    }
    out.append(cur)
    return out
  }
  func sourcePosition(_ r: Range<Int>) -> AttributedString.MarkdownSourcePosition? {
    guard !positions.isEmpty, r.lowerBound < r.upperBound, r.upperBound <= positions.count - 1 else { return nil }
    let a = positions[r.lowerBound], z = positions[r.upperBound - 1], next = positions[r.upperBound]
    let endCol = next.line == z.line ? next.col - 1 : z.col   // the last byte of the last character
    return AttributedString.MarkdownSourcePosition(startLine: a.line, startColumn: a.col, endLine: z.line, endColumn: max(z.col, endCol))
  }

  mutating func identity() -> Int { defer { nextIdentity += 1 }; return nextIdentity }
  mutating func render(_ blocks: [_MDBlock], parent: PresentationIntent?) {
    for b in blocks {
      switch b {
      case .paragraph(let text, let src):
        var c = AttributeContainer(); c.presentationIntent = PresentationIntent(.paragraph, identity: identity(), parent: parent)
        inline(text, c, positions: _MDRenderer.positions(text, src))
      case .heading(let level, let text, let src):
        var c = AttributeContainer(); c.presentationIntent = PresentationIntent(.header(level: level), identity: identity(), parent: parent)
        inline(text, c, positions: _MDRenderer.positions(text, [src]))
      case .code(let lang, let text, let src):
        var c = AttributeContainer(); c.presentationIntent = PresentationIntent(.codeBlock(languageHint: lang), identity: identity(), parent: parent)
        if options.appliesSourcePositionAttributes, !text.isEmpty {
          positions = _MDRenderer.positions(text, src)
          c.markdownSourcePosition = sourcePosition(0..<max(1, text.count - 1))
        }
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
          inline(cell.0, c, positions: _MDRenderer.positions(cell.0, [cell.1]))
        }
        for (r, row) in rows.enumerated() {
          let rowIntent = PresentationIntent(.tableRow(rowIndex: r + 1), identity: identity(), parent: table)
          for (col, cell) in row.enumerated() {
            var c = AttributeContainer(); c.presentationIntent = PresentationIntent(.tableCell(columnIndex: col), identity: identity(), parent: rowIntent)
            inline(cell.0, c, positions: _MDRenderer.positions(cell.0, [cell.1]))
          }
        }
      }
    }
  }

  mutating func inline(_ text: String, _ base: AttributeContainer, positions: [_MDSrc]) {
    var parser = _MDInlineParser(Array(text), preserveWhitespace: mode == .inlineOnlyPreservingWhitespace, refs: refs, extended: scope != nil)
    let nodes = parser.parse()
    self.positions = options.appliesSourcePositionAttributes ? positions : []
    emit(nodes, base)
  }
  mutating func append(_ s: String, _ attrs: AttributeContainer, _ span: Range<Int>) {
    guard !s.isEmpty else { return }
    var a = attrs
    if options.appliesSourcePositionAttributes, let p = sourcePosition(span) { a.markdownSourcePosition = p }
    out.append(AttributedString(s, attributes: a))
  }
  mutating func emit(_ nodes: [_MDInline], _ attrs: AttributeContainer) {
    func with(_ flag: InlinePresentationIntent) -> AttributeContainer {
      var a = attrs; a.inlinePresentationIntent = (attrs.inlinePresentationIntent ?? []).union(flag); return a
    }
    for n in nodes {
      switch n {
      case .text(let s, let r): append(s, attrs, r)
      case .code(let s, let r): append(s, with(.code), r)
      case .softBreak(let r): append(" ", with(.softBreak), r)
      case .lineBreak(let r): append("\n", with(.lineBreak), r)
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
      case .attributes(let body, let inner):
        var a = attrs
        if let scope { a.merge(_MDRenderer.extendedAttributes(body, scope)) }
        emit(inner, a)
      }
    }
  }

  /// `key: value, ...` (JSON5 object members) decoded by the scope's MarkdownDecodableAttributedStringKeys;
  /// unknown keys and values that do not decode are dropped
  static func extendedAttributes(_ body: String, _ scope: AttributeScopeCodableConfiguration) -> AttributeContainer {
    var c = AttributeContainer()
    guard let json = _json5ToJSON("{" + body + "}").data(using: .utf8),
          let obj = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else { return c }
    let markdownKeys = scope._keys.values.compactMap { $0.type as? any MarkdownDecodableAttributedStringKey.Type }
    for (name, value) in obj {
      guard let k = markdownKeys.first(where: { $0.markdownName == name }),
            let data = try? JSONSerialization.data(withJSONObject: [value]),
            let v = try? _decodeMarkdownValue(k, data) else { continue }
      c._storage[k.name] = v
    }
    return c
  }
}

private struct _MDValueBox<K: MarkdownDecodableAttributedStringKey>: Decodable {
  let value: K.Value
  init(from decoder: Decoder) throws {
    var c = try decoder.unkeyedContainer()
    value = try K.decodeMarkdown(from: c.superDecoder())
  }
}
private func _decodeMarkdownValue<K: MarkdownDecodableAttributedStringKey>(_ k: K.Type, _ data: Data) throws -> AnyHashable {
  _registerAttributeKey(K.self)
  return AnyHashable(try JSONDecoder().decode(_MDValueBox<K>.self, from: data).value)
}
/// JSON5 (unquoted keys, single-quoted strings, trailing commas) to JSON
func _json5ToJSON(_ s: String) -> String {
  var out = "", i = s.startIndex
  var lastSignificant: Character = "{"
  while i < s.endIndex {
    let ch = s[i]
    if ch == "\"" || ch == "'" {
      var j = s.index(after: i), body = ""
      while j < s.endIndex, s[j] != ch {
        if s[j] == "\\", s.index(after: j) < s.endIndex { body.append(s[j]); j = s.index(after: j) }
        else if s[j] == "\"" { body.append("\\") }
        body.append(s[j]); j = s.index(after: j)
      }
      out += "\"" + body.replacingOccurrences(of: "\\'", with: "'") + "\""
      lastSignificant = "\""
      i = j < s.endIndex ? s.index(after: j) : j
      continue
    }
    if (ch.isLetter || ch == "_" || ch == "$") && (lastSignificant == "{" || lastSignificant == ",") {
      var j = i, word = ""
      while j < s.endIndex, s[j].isLetter || s[j].isNumber || s[j] == "_" || s[j] == "$" { word.append(s[j]); j = s.index(after: j) }
      var k = j
      while k < s.endIndex, s[k] == " " { k = s.index(after: k) }
      out += k < s.endIndex && s[k] == ":" ? "\"" + word + "\"" : word
      lastSignificant = "a"
      i = j
      continue
    }
    if ch == "}" || ch == "]" {   // trailing commas
      while let l = out.last, l == " " || l == "\n" { out.removeLast() }
      if out.last == "," { out.removeLast() }
    }
    out.append(ch)
    if !ch.isWhitespace { lastSignificant = ch }
    i = s.index(after: i)
  }
  return out
}

indirect enum _MDInline {
  case text(String, Range<Int>), code(String, Range<Int>), softBreak(Range<Int>), lineBreak(Range<Int>)
  case emph([_MDInline]), strong([_MDInline]), strike([_MDInline])
  case link(String, [_MDInline]), image(String, [_MDInline])
  case attributes(String, [_MDInline])           // ^[text](key: value)
}

struct _MDInlineParser {
  enum Item {
    case node(_MDInline)
    case delim(Character, Int, canOpen: Bool, canClose: Bool, at: Int)
    case bracket(image: Bool, extended: Bool, active: Bool, at: Int)
  }
  let c: [Character]
  let preserve: Bool
  let refs: [String: String]
  let extended: Bool
  var items: [Item] = []
  init(_ c: [Character], preserveWhitespace: Bool, refs: [String: String] = [:], extended: Bool = false) {
    self.c = c; preserve = preserveWhitespace; self.refs = refs; self.extended = extended
  }

  static func isPunct(_ ch: Character) -> Bool { ch.isPunctuation || ch.isSymbol }
  mutating func text(_ s: String, _ r: Range<Int>) {
    if case .node(.text(let t, let tr))? = items.last, tr.upperBound == r.lowerBound { items[items.count - 1] = .node(.text(t + s, tr.lowerBound..<r.upperBound)) }
    else { items.append(.node(.text(s, r))) }
  }

  mutating func parse() -> [_MDInline] {
    var i = 0
    while i < c.count {
      let ch = c[i]
      switch ch {
      case "\\":
        if i + 1 < c.count, c[i + 1] == "\n" { items.append(.node(.lineBreak(i..<(i + 2)))); i += 2; skipLeadingSpaces(&i); continue }
        if i + 1 < c.count, c[i + 1].isASCII, _MDInlineParser.isPunct(c[i + 1]) { text(String(c[i + 1]), i..<(i + 2)); i += 2; continue }
        text("\\", i..<(i + 1)); i += 1
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
        if found < 0 { text(String(repeating: "`", count: n), i..<(i + n)); i += n; continue }
        var code = String(c[(i + n)..<found]).replacingOccurrences(of: "\n", with: " ")
        if code.count >= 2, code.first == " ", code.last == " ", !code.allSatisfy({ $0 == " " }) { code = String(code.dropFirst().dropLast()) }
        items.append(.node(.code(code, i..<(found + n)))); i = found + n
      case "*", "_", "~":
        var n = 0
        while i + n < c.count, c[i + n] == ch { n += 1 }
        let before: Character = i > 0 ? c[i - 1] : " ", after: Character = i + n < c.count ? c[i + n] : " "
        let left = !after.isWhitespace && (!_MDInlineParser.isPunct(after) || before.isWhitespace || _MDInlineParser.isPunct(before))
        let right = !before.isWhitespace && (!_MDInlineParser.isPunct(before) || after.isWhitespace || _MDInlineParser.isPunct(after))
        var canOpen = left, canClose = right
        if ch == "_" { canOpen = left && (!right || _MDInlineParser.isPunct(before)); canClose = right && (!left || _MDInlineParser.isPunct(after)) }
        if ch == "~" && n > 2 { text(String(repeating: "~", count: n), i..<(i + n)); i += n; continue }
        items.append(.delim(ch, n, canOpen: canOpen, canClose: canClose, at: i)); i += n
      case "!" where i + 1 < c.count && c[i + 1] == "[":
        items.append(.bracket(image: true, extended: false, active: true, at: i)); i += 2
      case "^" where extended && i + 1 < c.count && c[i + 1] == "[":
        items.append(.bracket(image: false, extended: true, active: true, at: i)); i += 2
      case "[":
        items.append(.bracket(image: false, extended: false, active: true, at: i)); i += 1
      case "]":
        let close = i
        i += 1
        guard let b = items.lastIndex(where: { if case .bracket = $0 { return true }; return false }),
              case .bracket(let isImage, let isExtended, let active, let at) = items[b] else { text("]", close..<(close + 1)); continue }
        let opener = isImage || isExtended ? 2 : 1
        var target: (String, Int)? = nil
        if isExtended {
          target = attributeBody(i)
        } else if active {
          target = linkDestination(i)
          if target == nil {   // reference links: [text][label], [label][], [label]
            let raw = String(c[(at + opener)..<close])
            if let (label, next) = linkLabel(i) {
              let key = _MDBlockParser.normalizeLabel(label.isEmpty ? raw : label)
              if let dest = refs[key] { target = (dest, next) }
            } else if let dest = refs[_MDBlockParser.normalizeLabel(raw)] {
              target = (dest, i)
            }
          }
        }
        if let (dest, next) = target {
          var inner = Array(items[(b + 1)...])
          _MDInlineParser.processEmphasis(&inner, 0)
          let nodes = _MDInlineParser.nodes(inner)
          items.removeSubrange(b...)
          items.append(.node(isExtended ? .attributes(dest, nodes) : isImage ? .image(dest, nodes) : .link(dest, nodes)))
          if !isImage && !isExtended {   // no links inside links
            for k in items.indices { if case .bracket(false, false, _, let a) = items[k] { items[k] = .bracket(image: false, extended: false, active: false, at: a) } }
          }
          i = next
        } else {
          items[b] = .node(.text(isImage ? "![" : isExtended ? "^[" : "[", at..<(at + opener)))
          text("]", close..<(close + 1))
        }
      case "<":
        if let (url, label, next) = autolink(i) { items.append(.node(.link(url, [.text(label, (i + 1)..<(next - 1))]))); i = next } else { text("<", i..<(i + 1)); i += 1 }
      case "&":
        if let (s, next) = entity(i) { text(s, i..<next); i = next } else { text("&", i..<(i + 1)); i += 1 }
      case "\n":
        if preserve { text("\n", i..<(i + 1)); i += 1; continue }
        var trailing = 0
        if case .node(.text(let t, let r))? = items.last {
          trailing = t.reversed().prefix(while: { $0 == " " }).count
          items[items.count - 1] = .node(.text(String(t.dropLast(trailing)), r.lowerBound..<(r.upperBound - trailing)))
        }
        items.append(.node(trailing >= 2 ? .lineBreak(i..<(i + 1)) : .softBreak(i..<(i + 1))))
        i += 1
        skipLeadingSpaces(&i)
      default:
        var j = i
        let stops: Set<Character> = extended ? ["\\", "`", "*", "_", "~", "!", "[", "]", "<", "&", "\n", "^"] : ["\\", "`", "*", "_", "~", "!", "[", "]", "<", "&", "\n"]
        while j < c.count, !stops.contains(c[j]) { j += 1 }
        if j == i { j += 1 }
        text(String(c[i..<j]), i..<j); i = j
      }
    }
    _MDInlineParser.processEmphasis(&items, 0)
    var result = _MDInlineParser.nodes(items)
    if !preserve, case .text(let t, let r)? = result.last {   // trailing spaces at the end of a block are dropped
      let trimmed = String(t.reversed().drop(while: { $0 == " " }).reversed())
      result[result.count - 1] = .text(trimmed, r.lowerBound..<(r.upperBound - (t.count - trimmed.count)))
    }
    return result
  }
  func skipLeadingSpaces(_ i: inout Int) { if !preserve { while i < c.count, c[i] == " " { i += 1 } } }

  /// `[label]` right after a link text: the label (empty for `[]`) and the index after it
  func linkLabel(_ start: Int) -> (String, Int)? {
    guard start < c.count, c[start] == "[" else { return nil }
    var j = start + 1, label = ""
    while j < c.count, c[j] != "]" {
      if c[j] == "[" { return nil }
      if c[j] == "\\", j + 1 < c.count { label.append(c[j + 1]); j += 2; continue }
      label.append(c[j]); j += 1
    }
    guard j < c.count else { return nil }
    return (label, j + 1)
  }
  /// `(key: value, ...)` after `^[text]`: the body (without the parentheses) and the index after `)`
  func attributeBody(_ start: Int) -> (String, Int)? {
    guard start < c.count, c[start] == "(" else { return nil }
    var j = start + 1, depth = 0, quote: Character? = nil, body = ""
    while j < c.count {
      let ch = c[j]
      if let q = quote {
        if ch == "\\", j + 1 < c.count { body.append(ch); body.append(c[j + 1]); j += 2; continue }
        if ch == q { quote = nil }
      } else if ch == "\"" || ch == "'" { quote = ch }
      else if ch == "{" || ch == "[" || ch == "(" { depth += 1 }
      else if ch == "}" || ch == "]" { depth -= 1 }
      else if ch == ")" { if depth == 0 { return (body, j + 1) }; depth -= 1 }
      body.append(ch); j += 1
    }
    return nil
  }
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
      guard case .delim(let ch, let cnt, let cOpen, true, let cAt) = items[closer], cnt > 0 else { closer += 1; continue }
      var opener = closer - 1, found = false
      while opener >= bottom {
        if case .delim(ch, let ocnt, true, let oClose, _) = items[opener], ocnt > 0 {
          let ruleOf3 = ch != "~" && (cOpen || oClose) && (ocnt + cnt) % 3 == 0 && !(ocnt % 3 == 0 && cnt % 3 == 0)
          let tildeMismatch = ch == "~" && ocnt != cnt
          if !ruleOf3 && !tildeMismatch { found = true; break }
        }
        opener -= 1
      }
      if !found { closer += 1; continue }
      guard case .delim(_, let ocnt, let oOpen, let oClose, let oAt) = items[opener] else { closer += 1; continue }
      let use = ch == "~" ? cnt : (cnt >= 2 && ocnt >= 2 ? 2 : 1)
      let inner = nodes(Array(items[(opener + 1)..<closer]))
      let wrapped: _MDInline = ch == "~" ? .strike(inner) : use == 2 ? .strong(inner) : .emph(inner)
      items.replaceSubrange((opener + 1)..<closer, with: [.node(wrapped)])
      closer = opener + 2
      items[opener] = .delim(ch, ocnt - use, canOpen: oOpen, canClose: oClose, at: oAt)          // the opener gives up its last characters
      items[closer] = .delim(ch, cnt - use, canOpen: cOpen, canClose: true, at: cAt + use)       // the closer its first ones
      if ocnt - use == 0 { items.remove(at: opener); closer -= 1 }
      if cnt - use == 0 { items.remove(at: closer) }
    }
  }
  static func nodes(_ items: [Item]) -> [_MDInline] {
    var out: [_MDInline] = []
    func add(_ s: String, _ r: Range<Int>) {
      if case .text(let t, let tr)? = out.last, tr.upperBound == r.lowerBound { out[out.count - 1] = .text(t + s, tr.lowerBound..<r.upperBound) }
      else { out.append(.text(s, r)) }
    }
    for it in items {
      switch it {
      case .node(.text(let s, let r)): add(s, r)
      case .node(let n): out.append(n)
      case .delim(let ch, let n, _, _, let at): if n > 0 { add(String(repeating: ch, count: n), at..<(at + n)) }
      case .bracket(let image, let extended, _, let at): add(image ? "![" : extended ? "^[" : "[", at..<(at + (image || extended ? 2 : 1)))
      }
    }
    return out
  }
}
