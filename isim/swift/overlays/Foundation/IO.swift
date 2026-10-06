// isim Foundation: FileHandle and Scanner Swift refinements (Apple's Foundation overlay API shape).
// Apple takes `some DataProtocol` in write(contentsOf:); isim has no DataProtocol, so any UInt8 sequence.
extension FileHandle {
  public func write<T: Sequence>(contentsOf data: T) throws where T.Element == UInt8 {
    try _isimWrite(Data(data))
  }
  public func offset() throws -> UInt64 {
    var o: UInt64 = 0
    try _isimGetOffset(&o)
    return o
  }
  @discardableResult
  public func seekToEnd() throws -> UInt64 {
    var o: UInt64 = 0
    try _isimSeekToEnd(&o)
    return o
  }
}

extension Scanner {
  /// The scan position as a String.Index into `string`.
  public var currentIndex: String.Index {
    get { String.Index(utf16Offset: scanLocation, in: string) }
    set { scanLocation = newValue.utf16Offset(in: string) }
  }
  public func scanString(_ searchString: String) -> String? {
    var r: NSString?
    return scanString(searchString, into: &r) ? (r as String?) ?? searchString : nil
  }
  public func scanUpToString(_ substring: String) -> String? {
    var r: NSString?
    return scanUpTo(substring, into: &r) ? r as String? : nil
  }
  public func scanCharacters(from set: CharacterSet) -> String? {
    var r: NSString?
    return scanCharacters(from: set._bridgeToObjectiveC(), into: &r) ? r as String? : nil
  }
  public func scanUpToCharacters(from set: CharacterSet) -> String? {
    var r: NSString?
    return scanUpToCharacters(from: set._bridgeToObjectiveC(), into: &r) ? r as String? : nil
  }
  public func scanCharacter() -> Character? {
    skipIgnored()
    guard !isAtEnd else { return nil }
    let i = currentIndex
    let c = string[i]
    currentIndex = string.index(after: i)
    return c
  }
  public enum NumberRepresentation: Sendable { case decimal, hexadecimal }
  public func scanInt(representation: NumberRepresentation = .decimal) -> Int? {
    if representation == .hexadecimal { return scanUInt64(representation: .hexadecimal).map { Int(truncatingIfNeeded: $0) } }
    var v = 0
    return scanInt(&v) ? v : nil
  }
  public func scanInt32(representation: NumberRepresentation = .decimal) -> Int32? {
    scanInt(representation: representation).map { Int32(clamping: $0) }
  }
  public func scanInt64(representation: NumberRepresentation = .decimal) -> Int64? {
    if representation == .hexadecimal { return scanUInt64(representation: .hexadecimal).map { Int64(truncatingIfNeeded: $0) } }
    var v: Int64 = 0
    return scanInt64(&v) ? v : nil
  }
  public func scanUInt64(representation: NumberRepresentation = .decimal) -> UInt64? {
    var v: UInt64 = 0
    return (representation == .hexadecimal ? scanHexInt64(&v) : scanUnsignedLongLong(&v)) ? v : nil
  }
  public func scanDouble(representation: NumberRepresentation = .decimal) -> Double? {
    var v = 0.0
    return (representation == .hexadecimal ? scanHexDouble(&v) : scanDouble(&v)) ? v : nil
  }
  public func scanFloat(representation: NumberRepresentation = .decimal) -> Float? {
    var v: Float = 0
    return (representation == .hexadecimal ? scanHexFloat(&v) : scanFloat(&v)) ? v : nil
  }
  public func scanDecimal() -> Decimal? {
    _isim_scanNumberString(true).flatMap { Decimal(string: $0) }
  }
  private func skipIgnored() {
    guard let skip = charactersToBeSkipped else { return }
    var r: NSString?
    _ = scanCharacters(from: skip, into: &r)
  }
}
