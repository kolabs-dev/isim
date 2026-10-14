import Darwin
import Foundation
import os

/// <sys/stat.h> permission bits (typed `mode_t`, so `open(_:_:_ mode:)` resolves) and flock(2) from <sys/file.h>.
func posixTests() {
    let path = NSTemporaryDirectory() + "posix-flock-\(getpid())"
    unlink(path)
    defer { unlink(path) }
    let fd = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    check(fd >= 0, "open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)")
    guard fd >= 0 else { return }
    defer { close(fd) }
    var st = stat()
    check(fstat(fd, &st) == 0 && st.st_mode & S_IFMT == S_IFREG && st.st_mode & S_IRWXU == S_IRUSR | S_IWUSR
          && st.st_mode & (S_IRWXG | S_IRWXO) == 0, "file mode is rw------- (\(String(st.st_mode, radix: 8)))")
    check(S_IRWXU == 0o700 && S_ISUID == 0o4000 && S_ISGID == 0o2000 && S_ISVTX == 0o1000 && S_IXOTH == 1,
          "permission bits have Darwin values")

    check(flock(fd, LOCK_EX) == 0, "flock(fd, LOCK_EX)")
    // flock locks belong to the open file description: a second open() of the file conflicts, even in this process
    let other = open(path, O_RDWR)
    defer { close(other) }
    check(flock(other, LOCK_EX | LOCK_NB) == -1, "LOCK_EX | LOCK_NB on a second descriptor fails while locked")
    check(flock(other, LOCK_SH | LOCK_NB) == -1, "LOCK_SH | LOCK_NB fails while exclusively locked")
    check(flock(fd, LOCK_UN) == 0, "flock(fd, LOCK_UN)")
    check(flock(other, LOCK_SH | LOCK_NB) == 0 && flock(fd, LOCK_SH | LOCK_NB) == 0, "two shared locks after unlock")
    check(flock(other, LOCK_UN) == 0 && flock(fd, LOCK_UN) == 0, "both shared locks released")
}

/// The Darwin overlay's wrappers for variadic C functions: fcntl (no argument, an integer, a pointer), ioctl (a
/// pointer, an integer, none), openat, errno.
func fcntlIoctlTests() {
    var fds: [Int32] = [0, 0]
    check(socketpair(AF_UNIX, SOCK_STREAM, 0, &fds) == 0, "socketpair")
    defer { close(fds[0]); close(fds[1]) }
    let flags = fcntl(fds[0], F_GETFL)
    check(flags >= 0 && flags & O_NONBLOCK == 0, "fcntl(fd, F_GETFL): blocking")
    check(fcntl(fds[0], F_SETFL, flags | O_NONBLOCK) == 0 && fcntl(fds[0], F_GETFL) & O_NONBLOCK != 0, "fcntl(fd, F_SETFL, O_NONBLOCK)")
    var byte: UInt8 = 0
    errno = 0
    check(read(fds[0], &byte, 1) == -1 && errno == EAGAIN, "a non-blocking read with nothing to read: EAGAIN (errno \(errno))")
    check(fcntl(fds[0], F_SETFD, FD_CLOEXEC) == 0 && fcntl(fds[0], F_GETFD) & FD_CLOEXEC != 0, "fcntl F_SETFD / F_GETFD FD_CLOEXEC")

    _ = "hello".withCString { write(fds[1], $0, 5) }
    var pending: Int32 = 0
    check(ioctl(fds[0], UInt(FIONREAD), &pending) == 0 && pending == 5, "ioctl(fd, FIONREAD, &n): \(pending) bytes waiting")
    var off: Int32 = 0
    check(ioctl(fds[1], UInt(FIONBIO), &off) == 0 && fcntl(fds[1], F_GETFL) & O_NONBLOCK == 0, "ioctl(fd, FIONBIO, &0): blocking")
    var on: Int32 = 1
    check(ioctl(fds[1], UInt(FIONBIO), &on) == 0 && fcntl(fds[1], F_GETFL) & O_NONBLOCK != 0, "ioctl(fd, FIONBIO, &1): non-blocking")
    check(ioctl(fds[1], UInt(FIOCLEX)) == 0 && fcntl(fds[1], F_GETFD) & FD_CLOEXEC != 0, "ioctl(fd, FIOCLEX) with no argument")
    check(ioctl(fds[1], 0x1234_5678) == -1 && errno == ENOTTY, "an unknown ioctl fails with ENOTTY")

    // a pointer argument: record locks and F_GETPATH
    let dir = NSTemporaryDirectory()
    let name = "posix-fcntl-\(getpid())"
    let dfd = open(dir, O_RDONLY | O_DIRECTORY)
    check(dfd >= 0, "open(dir, O_DIRECTORY)")
    let fd = openat(dfd, name, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    check(fd >= 0, "openat(dirfd, name, O_CREAT | O_RDWR, mode)")
    defer { close(fd); close(dfd); unlink(dir + "/" + name) }
    var lock = flock(l_start: 0, l_len: 10, l_pid: 0, l_type: Int16(F_WRLCK), l_whence: Int16(SEEK_SET))
    check(fcntl(fd, F_SETLK, &lock) == 0, "fcntl(fd, F_SETLK, &flock)")
    var probe = flock(l_start: 0, l_len: 10, l_pid: 0, l_type: Int16(F_WRLCK), l_whence: Int16(SEEK_SET))
    check(fcntl(fd, F_GETLK, &probe) == 0 && probe.l_type == Int16(F_UNLCK), "F_GETLK: the owner's own lock does not conflict")
    var path = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    check(fcntl(fd, F_GETPATH, &path) == 0 && String(cString: path).hasSuffix("/" + name), "fcntl(fd, F_GETPATH, buf): \(String(cString: path))")
    let cwdFile = openat(AT_FDCWD, dir + "/" + name, O_RDONLY)
    check(cwdFile >= 0, "openat(AT_FDCWD, absolute path)")
    close(cwdFile)
}

/// The C library headers from Swift (issue #220): uname into utsname, sysctlbyname, the user database, available memory
func darwinHeaderTests() {
    var u = utsname()
    check(uname(&u) == 0, "uname(&utsname())")
    let machine = withUnsafeBytes(of: &u.machine) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
    let sysname = withUnsafeBytes(of: &u.sysname) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
    check(machine == "x86_64" && sysname == "Darwin", "utsname: \(sysname) \(machine)")
    var size = 0
    check(sysctlbyname("hw.machine", nil, &size, nil, 0) == 0 && size > 1, "sysctlbyname size query: \(size)")
    var buf = [CChar](repeating: 0, count: size)
    check(sysctlbyname("hw.machine", &buf, &size, nil, 0) == 0 && String(cString: buf) == "x86_64", "sysctlbyname(\"hw.machine\")")
    var ncpu: Int32 = 0, len = MemoryLayout<Int32>.size
    check(sysctlbyname("hw.ncpu", &ncpu, &len, nil, 0) == 0 && ncpu > 0, "sysctlbyname(\"hw.ncpu\"): \(ncpu)")
    check(getpwuid(getuid()).map { String(cString: $0.pointee.pw_name) } == "mobile", "getpwuid(getuid()).pw_name")
    check(os_proc_available_memory() > 0, "os_proc_available_memory()")
}
