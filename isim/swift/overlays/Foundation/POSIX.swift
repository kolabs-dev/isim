// isim Foundation: C library wrappers that earlier isim releases had here, before isim had a Swift Darwin overlay
// (swift/overlays/Darwin). Kept exported for apps built with those releases (ABI), hidden from new code as SPI so
// they do not clash with Darwin's: new apps call the Darwin overlay's.
import Darwin

/// The calling thread's errno (Darwin values; isim's libSystem translates the host's)
@_spi(isimABI) public var errno: Int32 {
    get { __error().pointee }
    set { __error().pointee = newValue }
}

// Variadic C functions cannot be called from Swift: Apple's Darwin overlay wraps them, so does isim.
@_spi(isimABI) public func open(_ path: UnsafePointer<CChar>, _ oflag: Int32) -> Int32 { _isim_open(path, oflag, 0) }
@_spi(isimABI) public func open(_ path: UnsafePointer<CChar>, _ oflag: Int32, _ mode: mode_t) -> Int32 { _isim_open(path, oflag, Int32(mode)) }
@_spi(isimABI) public func openat(_ fd: Int32, _ path: UnsafePointer<CChar>, _ oflag: Int32) -> Int32 { _isim_open(path, oflag, 0) }
@_spi(isimABI) public func fcntl(_ fd: Int32, _ cmd: Int32) -> Int32 { _isim_fcntl(fd, cmd, 0) }
@_spi(isimABI) public func fcntl(_ fd: Int32, _ cmd: Int32, _ value: Int32) -> Int32 { _isim_fcntl(fd, cmd, value) }
@_spi(isimABI) public func ioctl(_ fd: Int32, _ request: UInt, _ value: UnsafeMutableRawPointer) -> Int32 { _isim_ioctl(fd, request, value) }

// signal(3) dispositions (macros in C)
@_spi(isimABI) public typealias sig_t = __sighandler_t
@_spi(isimABI) public var SIG_DFL: sig_t? { nil }
@_spi(isimABI) public var SIG_IGN: sig_t { unsafeBitCast(UnsafeRawPointer(bitPattern: 1)!, to: sig_t.self) }
@_spi(isimABI) public var SIG_ERR: sig_t { unsafeBitCast(UnsafeRawPointer(bitPattern: -1)!, to: sig_t.self) }
