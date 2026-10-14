// isim Darwin: the Swift overlay of the C library, as Apple's Darwin overlay (self-authored). Swift cannot import C
// macros like `errno` or call variadic C functions (open, fcntl, ioctl), so these wrappers make them callable; they
// call isim's libSystem, which translates Darwin values (O_NONBLOCK, F_GETLK, FIONBIO, ...) to the host's.
@_exported import Darwin

/// The calling thread's errno (Darwin values; isim's libSystem translates the host's)
public var errno: Int32 {
    get { __error().pointee }
    set { __error().pointee = newValue }
}

// the standard streams (macros for __stdinp / __stdoutp / __stderrp in C), as in Swift's Darwin overlay
public var stdin: UnsafeMutablePointer<FILE> {
    get { __stdinp }
    set { __stdinp = newValue }
}
public var stdout: UnsafeMutablePointer<FILE> {
    get { __stdoutp }
    set { __stdoutp = newValue }
}
public var stderr: UnsafeMutablePointer<FILE> {
    get { __stderrp }
    set { __stderrp = newValue }
}

// open(2), openat(2)
public func open(_ path: UnsafePointer<CChar>, _ oflag: Int32) -> Int32 { _isim_open(path, oflag, 0) }
public func open(_ path: UnsafePointer<CChar>, _ oflag: Int32, _ mode: mode_t) -> Int32 { _isim_open(path, oflag, Int32(mode)) }
public func openat(_ fd: Int32, _ path: UnsafePointer<CChar>, _ oflag: Int32) -> Int32 { _isim_openat(fd, path, oflag, 0) }
public func openat(_ fd: Int32, _ path: UnsafePointer<CChar>, _ oflag: Int32, _ mode: mode_t) -> Int32 { _isim_openat(fd, path, oflag, Int32(mode)) }

// fcntl(2): no argument (F_GETFL, F_GETFD), an integer (F_SETFL, F_SETFD, F_DUPFD) or a pointer (F_GETLK, F_SETLK,
// F_SETLKW with a struct flock; F_GETPATH with a MAXPATHLEN buffer)
public func fcntl(_ fd: Int32, _ cmd: Int32) -> Int32 { _isim_fcntl(fd, cmd, 0) }
public func fcntl(_ fd: Int32, _ cmd: Int32, _ value: Int32) -> Int32 { _isim_fcntl(fd, cmd, value) }
public func fcntl(_ fd: Int32, _ cmd: Int32, _ ptr: UnsafeMutableRawPointer) -> Int32 { _isim_fcntl_ptr(fd, cmd, ptr) }

// ioctl(2): no argument (FIOCLEX, FIONCLEX), an integer, or a pointer (FIONBIO, FIONREAD)
public func ioctl(_ fd: Int32, _ request: UInt) -> Int32 { _isim_ioctl(fd, request, nil) }
public func ioctl(_ fd: Int32, _ request: UInt, _ value: Int32) -> Int32 { _isim_ioctl_int(fd, request, value) }
public func ioctl(_ fd: Int32, _ request: UInt, _ ptr: UnsafeMutableRawPointer) -> Int32 { _isim_ioctl(fd, request, ptr) }

// signal(3) dispositions (macros in C)
public typealias sig_t = __sighandler_t
public var SIG_DFL: sig_t? { nil }
public var SIG_IGN: sig_t { unsafeBitCast(UnsafeRawPointer(bitPattern: 1)!, to: sig_t.self) }
public var SIG_ERR: sig_t { unsafeBitCast(UnsafeRawPointer(bitPattern: -1)!, to: sig_t.self) }
