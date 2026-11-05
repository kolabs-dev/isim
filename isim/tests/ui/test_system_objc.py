"""The C and Objective-C system APIs that binary SDKs link (HelloSystemObjC, #200): JavaScriptCore (JSContext, blocks,
JSExport, the C API), CMTime, AVFoundation's Objective-C classes, Security, SystemConfiguration reachability, CFNetwork's CFHost, CoreFoundation's
streams and sockets (CFReadStream / CFWriteStream, CFSocket), Network's
path monitor and C API (a Bonjour-advertised echo listener, browser, connection, TLS), CoreTelephony, MobileCoreServices, CoreFoundation strings, AdSupport, StoreKit, zlib, libcompression and
libc++ iostreams, locales and regex."""
import glob

import pytest


def has_host_jsc():
    return any(glob.glob(f"/usr/lib/*/libjavascriptcoregtk-{v}.so.*") for v in ("6.0", "4.1"))


def test_system_objc(launch):
    app = launch("HelloSystemObjC")
    app.wait_log(r"^HelloSystemObjC: done")
    lines = [r"cmtime sum=1\.75 cmp=1 valid=1", "avaudiosession category=AVAudioSessionCategoryAmbient error=none",
             r"avplayer time=0\.0 class=AVPlayer", "avmetadata TALB id3/TALB itsk/%A9nam uiso/titl itsk com.apple.itunes",
             "security random=0 nonzero=1 key=1 verified=1",
             "reachability flags=1 callback=1", "cfhost localhost ok=1 before=0 resolved=1 loopback=1 typeid=1", "cfhost unknown ok=0 netdb=1",
             "cfhost 127.0.0.1 names=1 addresses=1", "cfhost async type=0 resolved=1 loopback=1 error=0 main=1", 
             "cfstream data buffer=he read=llo status=5 typeid=1 bridged=1", "cfstream memory written=abc typeid=1",
             "cfstream file appended=onetwo offset=6", "cfstream bound read=xyz queue=1",
             "cfsocket listening bound=1 port=1 typeid=1 valid=1", "cfsocket accepted address=1 main=1",
             r"cfstream tcp open=1 remote=127\.0\.0\.1:1 handle=1", "cfstream tcp echo=PING", "cfstream signature echo=PONG",
             "cfsocket udp sent=1", "cfsocket udp data=datagram address=1 type=1", "cfstream refused error=posix posix=1 copied=1",
             "telephony carriers=0", "telephony restricted=0 subscribers=0 error domain=0", "telephony add plan result=1 fail=1",
             "uttype png=public.png image=1", "cfstring length=15 text=core foundation", "idfa zero=1",
             "skadnetwork class=SKAdNetwork", r"zlib 1\.\d+(\.\d+)* crc=[0-9a-f]{8} roundtrip=1 compression=1",
             "compression lzfse=1 lz4=1 lzma=1 brotli=1 nsdata=1",
             "c\\+\\+ pi=3\\.142 hex=ff read=12,34\\.500,word regex=42 upper=Q", "c\\+\\+ cerr ok", r"path status=\d ipv4=\d",
             "nw endpoint host=example.com port=443 type=2 address=127.0.0.1 type=1", "nw listener ready port=1",
             "nw context second after first", "nw browse found isim echo _isimecho._tcp batch=1 browsing=_isimecho._tcp", "nw connected type=1 remote port=1", "nw sent error=0",
             "nw echo hello over nw final=1", "nw tls failed domain=3",
             "nw txt flag:2 name:4 keys=2 bytes=15 equal=1 name=4", "nw metadata ip=1 ecn=3 class=5 ws=1 opcode=9 close=1001 def=1",
             "nw quic options=1 timeout=9000 datagram=1 attribution=2",
             "nw group added=1 unicast=0 members=2 proxy=example.com framer=value message=7 is=1"]
    if has_host_jsc():
        lines += ["js 6\\*7=42 str=a\\+b", "js block twice\\(21\\)=42 native=hi:2", "js object name=isim list=1,2,3 ok=1",
                  "js export count=15", "js call=42", "js exception=TypeError", "js C api max=9"]
    for line in lines:
        app.wait_log(r"^HelloSystemObjC: " + line)
    assert app.quit() == 0
