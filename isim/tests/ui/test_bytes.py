"""Foundation's byte and error types (HelloBytes, issue #217): DataProtocol and MutableDataProtocol over Data, byte
arrays, slices and the unsafe buffers (regions, searching, copying, resetting), ContiguousBytes, POSIXError and
MachError (thrown, caught by code, bridged to and from NSError), POSIXErrorCode from errno, NSErrorPointer, and the
numeric initialisers from NSNumber."""
import re


def report(app):
    app.wait_log(r"^hb reported$")
    return {m[0]: m[1] for m in re.findall(r"^hb (\S+) (.*)$", app.log, re.M)}


def test_bytes(launch):
    app = launch("HelloBytes")
    r = report(app)
    assert r["data"] == "count=6 regions=1 hex=616263616263", r["data"]
    assert r["array"] == r["data"] and r["contiguous-array"] == r["data"] and r["raw-buffer"] == r["data"], r
    assert r["buffer"] == r["data"], r["buffer"]
    assert r["slice"] == "count=4 regions=1 hex=63616263", f"ArraySlice: {r['slice']}"
    assert r["raw-slice"] == "count=3 regions=1 hex=626361", f"Slice<UnsafeRawBufferPointer>: {r['raw-slice']}"
    assert r["one"] == "count=1 regions=1 hex=7f" and r["empty"] == "count=0 regions=0 hex=", (r["one"], r["empty"])
    assert r["first-range"] == "0..<2" and r["last-range"] == "3..<5" and r["missing-range"] == "nil", r
    assert r["copy"] == "copied=3 hex=636162", f"copyBytes(to:from:) stops at the buffer's size: {r['copy']}"
    assert r["reset"] == "array=610000616263 data=610000616263", r["reset"]
    assert r["contiguous-bytes"] == "data=588 array=588 slice=294 one=9", r["contiguous-bytes"]
    assert r["file"] == "abc", f"FileHandle.write(contentsOf:) with an ArraySlice: {r['file']}"
    assert r["posix-catch"] == "ENOENT domain=NSPOSIXErrorDomain", r["posix-catch"]
    assert r["posix-bridge"] == "EACCES=true code=13", f"NSError -> POSIXError: {r['posix-bridge']}"
    assert r["posix-nserror"] == "NSPOSIXErrorDomain 32", f"POSIXError -> NSError: {r['posix-nserror']}"
    assert r["errno"] == "fd=-1 ENOENT=true wouldblock=true", r["errno"]
    assert r["mach"] == "code=1 domain=NSMachErrorDomain" and r["mach-bridge"] == "true", (r["mach"], r["mach-bridge"])
    assert r["error-pointer"] == "ok=false domain=NSPOSIXErrorDomain code=2", r["error-pointer"]
    assert r["truncating"] == "Int=3 UInt8=44 Bool=true", r["truncating"]
    assert r["exactly"] == ("Int(3.0)=3 Int(3.5)=nil UInt8(300)=nil UInt8(-1)=nil Int64(UInt64.max)=nil "
                            "Double(Int64.max)=nil Float(0.5)=0.5 Float(0.1)=nil Bool(1)=true Bool(2)=nil"), r["exactly"]
    app.wait_view(lambda v: "posix-bridge" in v)
    assert app.quit() == 0
