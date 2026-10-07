// isim: the platform lock under Synchronization's Mutex. Same shape as the upstream Darwin implementation
// (os_unfair_lock), but declares the os_unfair_lock C functions itself: isim's `Darwin` module does not
// re-export <os/lock.h> (it lives in the `os` module). isim's libSystem implements them on a Linux futex.

@usableFromInline
@_extern(c, "os_unfair_lock_lock")
internal func _isim_os_unfair_lock_lock(_ lock: UnsafeMutablePointer<UInt32>)

@usableFromInline
@_extern(c, "os_unfair_lock_trylock")
internal func _isim_os_unfair_lock_trylock(_ lock: UnsafeMutablePointer<UInt32>) -> Bool

@usableFromInline
@_extern(c, "os_unfair_lock_unlock")
internal func _isim_os_unfair_lock_unlock(_ lock: UnsafeMutablePointer<UInt32>)

@available(SwiftStdlib 6.0, *)
@frozen
@_staticExclusiveOnly
public struct _MutexHandle: ~Copyable {
  @usableFromInline
  let value: _Cell<UInt32>

  @available(SwiftStdlib 6.0, *)
  @_alwaysEmitIntoClient
  @_transparent
  public init() {
    value = _Cell(0)
  }

  @available(SwiftStdlib 6.0, *)
  @_alwaysEmitIntoClient
  @_transparent
  internal borrowing func _lock() {
    unsafe _isim_os_unfair_lock_lock(value._address)
  }

  @available(SwiftStdlib 6.0, *)
  @_alwaysEmitIntoClient
  @_transparent
  internal borrowing func _tryLock() -> Bool {
    unsafe _isim_os_unfair_lock_trylock(value._address)
  }

  @available(SwiftStdlib 6.0, *)
  @_alwaysEmitIntoClient
  @_transparent
  internal borrowing func _unlock() {
    unsafe _isim_os_unfair_lock_unlock(value._address)
  }
}
