import Darwin
import Foundation

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
