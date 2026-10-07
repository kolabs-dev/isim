// isim: os_unfair_lock for the Distributed module's LocalTestingDistributedActorSystem. Apple's `Darwin` module
// re-exports <os/lock.h>; isim's keeps it in the `os` module, so the upstream source sees these declarations
// instead (same C functions in isim's libSystem, same 32-bit layout).
import Swift

struct os_unfair_lock {
  var _os_unfair_lock_opaque: UInt32 = 0
  init() {}
}

@_extern(c, "os_unfair_lock_lock")
func _isim_os_unfair_lock_lock(_ lock: UnsafeMutableRawPointer)
@_extern(c, "os_unfair_lock_unlock")
func _isim_os_unfair_lock_unlock(_ lock: UnsafeMutableRawPointer)

@inline(__always) func os_unfair_lock_lock(_ lock: UnsafeMutablePointer<os_unfair_lock>) { unsafe _isim_os_unfair_lock_lock(UnsafeMutableRawPointer(lock)) }
@inline(__always) func os_unfair_lock_unlock(_ lock: UnsafeMutablePointer<os_unfair_lock>) { unsafe _isim_os_unfair_lock_unlock(UnsafeMutableRawPointer(lock)) }
