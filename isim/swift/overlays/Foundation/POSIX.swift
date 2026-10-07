// isim Foundation: C library pieces that Apple's Swift Darwin overlay provides and that isim has no Swift
// Darwin overlay for (self-authored). `errno` is a macro in C (`*__error()`), which Swift cannot import.
import Darwin

/// The calling thread's errno (Darwin values; isim's libSystem translates the host's)
public var errno: Int32 {
    get { __error().pointee }
    set { __error().pointee = newValue }
}

// Variadic C functions cannot be called from Swift: Apple's Darwin overlay wraps them, so does isim.
public func open(_ path: UnsafePointer<CChar>, _ oflag: Int32) -> Int32 { _isim_open(path, oflag, 0) }
public func open(_ path: UnsafePointer<CChar>, _ oflag: Int32, _ mode: mode_t) -> Int32 { _isim_open(path, oflag, Int32(mode)) }
public func openat(_ fd: Int32, _ path: UnsafePointer<CChar>, _ oflag: Int32) -> Int32 { _isim_open(path, oflag, 0) }
public func fcntl(_ fd: Int32, _ cmd: Int32) -> Int32 { _isim_fcntl(fd, cmd, 0) }
public func fcntl(_ fd: Int32, _ cmd: Int32, _ value: Int32) -> Int32 { _isim_fcntl(fd, cmd, value) }
public func ioctl(_ fd: Int32, _ request: UInt, _ value: UnsafeMutableRawPointer) -> Int32 { _isim_ioctl(fd, request, value) }

// signal(3) dispositions (macros in C)
public typealias sig_t = __sighandler_t
public var SIG_DFL: sig_t? { nil }
public var SIG_IGN: sig_t { unsafeBitCast(UnsafeRawPointer(bitPattern: 1)!, to: sig_t.self) }
public var SIG_ERR: sig_t { unsafeBitCast(UnsafeRawPointer(bitPattern: -1)!, to: sig_t.self) }
