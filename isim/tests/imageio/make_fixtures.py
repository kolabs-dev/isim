#!/usr/bin/env python3
"""Writes the images ImageIOTest reads (tests/imageio/fixtures/, committed; re-run only to change them). Pillow writes
the EXIF, TIFF and GPS tags, independently of isim's ImageIO; the IPTC (Photoshop APP13) and XMP packets are built here
from their specifications. Usage: out/pyenv/bin/python make_fixtures.py [OUTDIR]"""
import io
import os
import struct
import sys

from PIL import Image, PngImagePlugin, TiffImagePlugin

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")
R = TiffImagePlugin.IFDRational

XMP = """<?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/">
 <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:xmp="http://ns.adobe.com/xap/1.0/"
    xmlns:photoshop="http://ns.adobe.com/photoshop/1.0/" xmlns:Iptc4xmpCore="http://iptc.org/std/Iptc4xmpCore/1.0/xmlns/"
    xmp:Rating="4" xmp:CreatorTool="isim fixtures" photoshop:City="Lisbon">
   <dc:title><rdf:Alt><rdf:li xml:lang="x-default">A test image</rdf:li><rdf:li xml:lang="pt">Uma imagem</rdf:li></rdf:Alt></dc:title>
   <dc:subject><rdf:Bag><rdf:li>red</rdf:li><rdf:li>green</rdf:li></rdf:Bag></dc:subject>
   <dc:creator><rdf:Seq><rdf:li>Ana</rdf:li><rdf:li>Rui</rdf:li></rdf:Seq></dc:creator>
   <Iptc4xmpCore:CreatorContactInfo rdf:parseType="Resource">
    <Iptc4xmpCore:CiEmailWork>ana@example.com</Iptc4xmpCore:CiEmailWork>
    <Iptc4xmpCore:CiAdrCity>Lisbon</Iptc4xmpCore:CiAdrCity>
   </Iptc4xmpCore:CreatorContactInfo>
  </rdf:Description>
 </rdf:RDF>
</x:xmpmeta>
<?xpacket end="w"?>"""


def exif():
    e = Image.Exif()
    e[0x010F] = "isim"                        # Make
    e[0x0110] = "Test Camera"                 # Model
    e[0x0112] = 1                             # Orientation
    e[0x011A] = R(300, 1)                     # XResolution
    e[0x011B] = R(300, 1)
    e[0x0128] = 2                             # ResolutionUnit: inches
    e[0x0131] = "make_fixtures.py"            # Software
    e[0x0132] = "2024:05:06 07:08:09"         # DateTime
    e[0x013B] = "Ana"                         # Artist
    e[0x8298] = "(c) isim"                    # Copyright
    x = e.get_ifd(0x8769)
    x[0x829A] = R(1, 125)                     # ExposureTime
    x[0x829D] = R(28, 10)                     # FNumber
    x[0x8822] = 2                             # ExposureProgram
    x[0x8827] = 100                           # ISOSpeedRatings
    x[0x9000] = b"0232"                       # ExifVersion
    x[0x9003] = "2024:05:06 07:08:09"         # DateTimeOriginal
    x[0x9010] = "+01:00"                      # OffsetTime
    x[0x9204] = R(-1, 3)                      # ExposureBiasValue (signed)
    x[0x9209] = 16                            # Flash
    x[0x920A] = R(42, 10)                     # FocalLength
    x[0xA002] = 16                            # PixelXDimension
    x[0xA003] = 8
    x[0xA405] = 26                            # FocalLenIn35mmFilm
    x[0xA434] = "Wide Lens"                   # LensModel
    g = e.get_ifd(0x8825)
    g[0] = b"\x02\x02\x00\x00"                # GPSVersionID
    g[1] = "N"
    g[2] = (R(37, 1), R(46, 1), R(2424, 100))  # 37° 46' 24.24" = 37.7734
    g[3] = "W"
    g[4] = (R(122, 1), R(25, 1), R(1074, 100))  # 122.4196...
    g[5] = b"\x00"                            # AltitudeRef: above sea level
    g[6] = R(105, 2)                          # Altitude 52.5
    g[7] = (R(12, 1), R(34, 1), R(56, 1))     # TimeStamp
    g[29] = "2024:05:06"                      # DateStamp
    return e


def iptc():
    """IPTC-IIM record 2 datasets in a Photoshop "8BIM" image resource 0x0404 (APP13)"""
    def ds(n, value):
        b = value.encode("utf-8")
        return bytes([0x1C, 2, n]) + struct.pack(">H", len(b)) + b
    data = (bytes([0x1C, 1, 90, 0, 3]) + b"\x1b%G" +            # 1:90 coded character set: UTF-8
            ds(5, "Fixture") + ds(25, "red") + ds(25, "green") + ds(80, "Ana") + ds(90, "Lisbon") +
            ds(101, "Portugal") + ds(116, "(c) isim") + ds(120, "A small test image") + ds(55, "20240506"))
    res = b"8BIM" + struct.pack(">H", 0x0404) + b"\0\0" + struct.pack(">I", len(data)) + data + b"\0" * (len(data) % 2)
    return b"Photoshop 3.0\0" + res


def segment(marker, payload):
    return bytes([0xFF, marker]) + struct.pack(">H", len(payload) + 2) + payload


def jpeg(path):
    im = Image.new("RGB", (16, 8), (200, 30, 30))
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=90, exif=exif())
    b = buf.getvalue()
    xmp = segment(0xE1, b"http://ns.adobe.com/xap/1.0/\0" + XMP.encode("utf-8"))
    app13 = segment(0xED, iptc())
    # after SOI and the APP0 / APP1 segments Pillow wrote
    p = 2
    while b[p] == 0xFF and 0xE0 <= b[p + 1] <= 0xEF:
        p += 2 + struct.unpack(">H", b[p + 2:p + 4])[0]
    open(path, "wb").write(b[:p] + xmp + app13 + b[p:])


def png(path):
    im = Image.new("RGBA", (16, 8), (30, 200, 30, 255))
    info = PngImagePlugin.PngInfo()
    info.add_itxt("XML:com.adobe.xmp", XMP)
    im.save(path, "PNG", exif=exif(), pnginfo=info)


def main():
    os.makedirs(OUT, exist_ok=True)
    jpeg(os.path.join(OUT, "meta.jpg"))
    png(os.path.join(OUT, "meta.png"))
    # check what Pillow reads back
    for name in ("meta.jpg", "meta.png"):
        im = Image.open(os.path.join(OUT, name))
        e = im.getexif()
        assert e[0x010F] == "isim" and e.get_ifd(0x8825)[1] == "N", name
        print(name, os.path.getsize(os.path.join(OUT, name)), "bytes;", "exif tags", len(e), "gps", len(e.get_ifd(0x8825)))


if __name__ == "__main__":
    main()
