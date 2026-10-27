#!/usr/bin/env python3
"""Writes the PDFs CGPDFTest reads (tests/cgpdf/fixtures/, committed; re-run only to change them). The writer and the
standard security handler here follow the PDF specification (ISO 32000-2, 7.6) independently of isim's parser, and
poppler's pdfinfo checks every file (it must open each, the encrypted ones with their passwords).

Needs the `cryptography` package for AES. Usage: python3 make_fixtures.py [OUTDIR]"""
import hashlib
import os
import re
import struct
import subprocess
import sys
import zlib

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")
PAD = bytes.fromhex("28BF4E5E4E758A4164004E56FFFA01082E2E00B6D0683E802F0CA9FE6453697A")
ID0 = bytes.fromhex("6973696d2063677064662074657374")[:16].ljust(16, b"!")
P = -3900          # printing allowed (bit 3), copying not (bit 5)


class N(str):
    """a name"""


class R:
    def __init__(self, num):
        self.num = num


class Stream:
    def __init__(self, d, data, compress=True):
        self.d, self.data = dict(d), zlib.compress(data) if compress else data
        if compress:
            self.d["Filter"] = N("FlateDecode")


def rc4(key, data):
    s, j, out = list(range(256)), 0, bytearray()
    for i in range(256):
        j = (j + s[i] + key[i % len(key)]) & 255
        s[i], s[j] = s[j], s[i]
    i = j = 0
    for b in data:
        i = (i + 1) & 255
        j = (j + s[i]) & 255
        s[i], s[j] = s[j], s[i]
        out.append(b ^ s[(s[i] + s[j]) & 255])
    return bytes(out)


def aes_cbc(key, iv, data, decrypt=False):
    c = Cipher(algorithms.AES(key), modes.CBC(iv))
    x = c.decryptor() if decrypt else c.encryptor()
    return x.update(data) + x.finalize()


def aes_pad(key, data):
    """AESV2/AESV3: a random IV, then CBC with PKCS#7 padding"""
    iv = os.urandom(16)
    n = 16 - len(data) % 16
    return iv + aes_cbc(key, iv, data + bytes([n]) * n)


class Security:
    """the standard security handler: R3 (RC4 128-bit), R4 (AESV2) or R6 (AESV3)"""

    def __init__(self, rev, user, owner):
        self.rev = rev
        u, o = user.encode(), owner.encode()
        if rev == 6:
            self.key = os.urandom(32)
            uvs, uks, ovs, oks = (os.urandom(8) for _ in range(4))
            self.U = self.hash6(u, uvs, b"") + uvs + uks
            self.UE = aes_cbc(self.hash6(u, uks, b""), bytes(16), self.key)
            self.O = self.hash6(o, ovs, self.U) + ovs + oks
            self.OE = aes_cbc(self.hash6(o, oks, self.U), bytes(16), self.key)
            perms = struct.pack("<iI", P, 0xFFFFFFFF) + b"Tadb" + os.urandom(4)
            c = Cipher(algorithms.AES(self.key), modes.ECB()).encryptor()
            self.Perms = c.update(perms) + c.finalize()
            return
        pu, po = (u + PAD)[:32], (o + PAD)[:32]
        h = hashlib.md5(po).digest()
        for _ in range(50):
            h = hashlib.md5(h).digest()
        o_ = rc4(h, pu)
        for i in range(1, 20):
            o_ = rc4(bytes(b ^ i for b in h), o_)
        self.O = o_
        k = hashlib.md5(pu + self.O + struct.pack("<i", P) + ID0).digest()
        for _ in range(50):
            k = hashlib.md5(k).digest()
        self.key = k
        x = rc4(k, hashlib.md5(PAD + ID0).digest())
        for i in range(1, 20):
            x = rc4(bytes(b ^ i for b in k), x)
        self.U = x + bytes(16)

    @staticmethod
    def hash6(pw, salt, udata):
        k = hashlib.sha256(pw + salt + udata).digest()
        i = 0
        while True:
            e = aes_cbc(k[:16], k[16:32], (pw + k + udata) * 64)
            k = (hashlib.sha256, hashlib.sha384, hashlib.sha512)[sum(e[:16]) % 3](e).digest()
            i += 1
            if i >= 64 and e[-1] <= i - 32:
                return k[:32]

    def encrypt(self, num, gen, data):
        if self.rev == 6:
            return aes_pad(self.key, data)
        salt = b"sAlT" if self.rev == 4 else b""
        k = hashlib.md5(self.key + struct.pack("<I", num)[:3] + struct.pack("<H", gen) + salt).digest()[:16]
        return aes_pad(k, data) if self.rev == 4 else rc4(k, data)

    def dict(self):
        d = {"Filter": N("Standard"), "P": P, "O": self.O, "U": self.U}
        if self.rev == 3:
            d.update(V=2, R=3, Length=128)
        else:
            cf = N("AESV2") if self.rev == 4 else N("AESV3")
            d.update(V=4 if self.rev == 4 else 5, R=self.rev, Length=128 if self.rev == 4 else 256,
                     CF={"StdCF": {"CFM": cf, "AuthEvent": N("DocOpen"), "Length": 16 if self.rev == 4 else 32}},
                     StmF=N("StdCF"), StrF=N("StdCF"))
            if self.rev == 6:
                d.update(OE=self.OE, UE=self.UE, Perms=self.Perms)
        return d


def ser(v, enc=None):
    """a value in PDF syntax; enc(bytes) encrypts strings"""
    if isinstance(v, bool):
        return b"true" if v else b"false"
    if v is None:
        return b"null"
    if isinstance(v, N):
        return b"/" + v.encode()
    if isinstance(v, int):
        return str(v).encode()
    if isinstance(v, float):
        return ("%.4f" % v).rstrip("0").encode()
    if isinstance(v, str):
        v = v.encode("latin-1")
    if isinstance(v, bytes):
        return b"<" + (enc(v) if enc else v).hex().encode() + b">"
    if isinstance(v, R):
        return b"%d 0 R" % v.num
    if isinstance(v, list):
        return b"[" + b" ".join(ser(x, enc) for x in v) + b"]"
    if isinstance(v, dict):
        return b"<<" + b"".join(b"/" + k.encode() + b" " + ser(x, enc) for k, x in v.items()) + b">>"
    raise TypeError(v)


def body(num, v, sec=None, gen=0):
    enc = (lambda b: sec.encrypt(num, gen, b)) if sec else None
    if isinstance(v, Stream):
        data = sec.encrypt(num, gen, v.data) if sec else v.data
        d = dict(v.d, Length=len(data))
        return ser(d, enc) + b"\nstream\n" + data + b"\nendstream"
    return ser(v, enc)


def document(title=b"\xfe\xff" + "Plain été".encode("utf-16-be")):
    """the objects of the common document: 2 pages (the second rotated 90 with a crop box), an outline, a named
    destination, document info. Object numbers are the list positions + 1."""
    page1 = b"BT /F1 24 Tf 72 700 Td (Hello CGPDF) Tj ET\n0 0 1 rg 10 20 50 60 re f\nq /Im1 Do Q\n"
    page2 = b"1 0 0 RG 2 w 100 100 m 200 200 l S\n[1 2] 0 d (multi word) Tj\n"
    return [
        {"Type": N("Catalog"), "Pages": R(2), "Outlines": R(8), "Names": R(11), "PageMode": N("UseOutlines")},   # 1
        {"Type": N("Pages"), "Kids": [R(3), R(4)], "Count": 2, "MediaBox": [0, 0, 612, 792],
         "Resources": {"Font": {"F1": R(7)}, "XObject": {"Im1": R(13)}}},                                          # 2
        {"Type": N("Page"), "Parent": R(2), "Contents": R(5)},                                                     # 3
        {"Type": N("Page"), "Parent": R(2), "Contents": [R(6), R(14)], "Rotate": 90, "MediaBox": [0, 0, 300, 400],
         "CropBox": [10, 20, 290, 380], "Resources": {"Font": {"F1": R(7)}}},                                      # 4
        Stream({}, page1),                                                                                         # 5
        Stream({}, page2),                                                                                         # 6
        {"Type": N("Font"), "Subtype": N("Type1"), "BaseFont": N("Helvetica")},                                    # 7
        {"Type": N("Outlines"), "First": R(9), "Last": R(10), "Count": 2},                                         # 8
        {"Title": b"\xfe\xff" + "Chapter 1".encode("utf-16-be"), "Parent": R(8), "Next": R(10),
         "Dest": [R(3), N("XYZ"), 72, 700, 0]},                                                                    # 9
        {"Title": b"Chapter 2", "Parent": R(8), "Prev": R(9), "Dest": b"chap2"},                                   # 10
        {"Dests": R(12)},                                                                                          # 11
        {"Names": [b"chap2", [R(4), N("Fit")]]},                                                                   # 12
        Stream({"Type": N("XObject"), "Subtype": N("Image"), "Width": 2, "Height": 2, "ColorSpace": N("DeviceRGB"),
                "BitsPerComponent": 8}, bytes([255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255])),                  # 13
        Stream({}, b"BI /W 1 /H 1 /CS /G /BPC 8 ID \x80 EI\n", compress=False),                                    # 14
        {"Title": title, "Author": b"isim \x80 tests", "CreationDate": b"D:20240229123456+02'00'",
         "Keywords": b"pdf, cgpdf"},                                                                               # 15
    ]


INFO = 15


def classic(objs, *, sec=None, version=b"1.4", info=INFO, broken_xref=False):
    out = bytearray(b"%PDF-" + version + b"\n%\xe2\xe3\xcf\xd3\n")
    offs = []
    allobjs = list(objs) + ([sec.dict()] if sec else [])
    for i, v in enumerate(allobjs, 1):
        offs.append(len(out))
        out += b"%d 0 obj\n" % i + body(i, v, sec if i <= len(objs) else None) + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(allobjs) + 1)
    for o in offs:
        out += b"%010d 00000 n \n" % o
    trailer = {"Size": len(allobjs) + 1, "Root": R(1), "Info": R(info), "ID": [ID0, ID0]}
    if sec:
        trailer["Encrypt"] = R(len(allobjs))
    out += b"trailer\n" + ser(trailer) + b"\nstartxref\n%d\n%%%%EOF\n" % (xref + 7 if broken_xref else xref)
    return bytes(out), offs, xref


def incremental():
    """the plain document, then an update that replaces the info dictionary (a /Prev chain)"""
    base, offs, xref = classic(document())
    out = bytearray(base)
    off = len(out)
    out += b"%d 0 obj\n" % INFO + ser({"Title": b"Updated title", "Author": b"second revision"}) + b"\nendobj\n"
    x2 = len(out)
    out += b"xref\n0 1\n0000000000 65535 f \n%d 1\n%010d 00000 n \n" % (INFO, off)
    out += b"trailer\n" + ser({"Size": len(offs) + 1, "Root": R(1), "Info": R(INFO), "Prev": xref, "ID": [ID0, ID0]})
    out += b"\nstartxref\n%d\n%%%%EOF\n" % x2
    return bytes(out)


def objstm():
    """PDF 1.5: every non-stream object in an object stream, a cross-reference stream with a PNG predictor"""
    objs = document()
    n = len(objs)
    packed = [i for i, v in enumerate(objs, 1) if not isinstance(v, Stream)]
    stm_num, xref_num = n + 1, n + 2
    head, data = b"", b""
    for i in packed:
        head += b"%d %d " % (i, len(data))
        data += ser(objs[i - 1]) + b"\n"
    out = bytearray(b"%PDF-1.5\n%\xe2\xe3\xcf\xd3\n")
    entries = {0: (0, 0, 65535)}
    for i, v in enumerate(objs, 1):
        if isinstance(v, Stream):
            entries[i] = (1, len(out), 0)
            out += b"%d 0 obj\n" % i + body(i, v, None) + b"\nendobj\n"
    for k, i in enumerate(packed):
        entries[i] = (2, stm_num, k)
    entries[stm_num] = (1, len(out), 0)
    out += b"%d 0 obj\n" % stm_num + body(stm_num, Stream({"Type": N("ObjStm"), "N": len(packed), "First": len(head)},
                                                          head + data)) + b"\nendobj\n"
    entries[xref_num] = (1, len(out), 0)
    rows = [struct.pack(">BIH", *entries[i]) for i in range(xref_num + 1)]
    raw, prev = b"", bytes(7)                           # PNG Up predictor (12), 7 columns
    for r in rows:
        raw += b"\x02" + bytes((a - b) & 255 for a, b in zip(r, prev))
        prev = r
    xs = Stream({"Type": N("XRef"), "Size": xref_num + 1, "W": [1, 4, 2], "Root": R(1), "Info": R(INFO),
                 "ID": [ID0, ID0], "DecodeParms": {"Predictor": 12, "Columns": 7}}, raw)
    x = len(out)
    out += b"%d 0 obj\n" % xref_num + body(xref_num, xs, None) + b"\nendobj\nstartxref\n%d\n%%%%EOF\n" % x
    return bytes(out)


def text_document():
    """two pages of text (the second rotated 90 with a crop box) with page labels: i, then A-5"""
    t1 = b"BT /F1 20 Tf 72 700 Td (First line) Tj 0 -30 Td (Second) Tj ET\n"
    t2 = b"BT /F1 20 Tf 50 300 Td (Turned) Tj ET\n"
    return [
        {"Type": N("Catalog"), "Pages": R(2), "PageLabels": {"Nums": [0, {"S": N("r")}, 1, {"S": N("D"), "P": b"A-", "St": 5}]}},
        {"Type": N("Pages"), "Kids": [R(3), R(4)], "Count": 2, "MediaBox": [0, 0, 612, 792], "Resources": {"Font": {"F1": R(7)}}},
        {"Type": N("Page"), "Parent": R(2), "Contents": R(5)},
        {"Type": N("Page"), "Parent": R(2), "Contents": R(6), "Rotate": 90, "MediaBox": [0, 0, 300, 400],
         "CropBox": [10, 20, 290, 380]},
        Stream({}, t1),
        Stream({}, t2),
        {"Type": N("Font"), "Subtype": N("Type1"), "BaseFont": N("Helvetica")},
        {"Title": b"Text"},
    ]


def annots_document():
    """two pages of text; the first has an annotation of each kind PDFKit reads (issue #358): a highlight, a note with
    its popup, links (a URL and a page), ink, a square, a line with an arrow, free text, a text field (a kid of its
    field) and a check box; the outline's items have a URL and a named action"""
    t1 = b"BT /F1 20 Tf 72 700 Td (The quick brown fox) Tj 0 -30 Td (jumps over the lazy dog) Tj 0 -30 Td (The end) Tj ET\n"
    t2 = b"BT /F1 20 Tf 72 700 Td (Second page fox) Tj ET\n"
    return [
        {"Type": N("Catalog"), "Pages": R(2), "Outlines": R(22), "AcroForm": {"Fields": [R(19), R(18)]}},          # 1
        {"Type": N("Pages"), "Kids": [R(3), R(4)], "Count": 2, "MediaBox": [0, 0, 612, 792], "Resources": {"Font": {"F1": R(7)}}},
        {"Type": N("Page"), "Parent": R(2), "Contents": R(5), "Annots": [R(n) for n in range(8, 19)]},          # 3
        {"Type": N("Page"), "Parent": R(2), "Contents": R(6)},                                                     # 4
        Stream({}, t1),                                                                                            # 5
        Stream({}, t2),                                                                                            # 6
        {"Type": N("Font"), "Subtype": N("Type1"), "BaseFont": N("Helvetica")},                                    # 7
        {"Type": N("Annot"), "Subtype": N("Highlight"), "Rect": [70, 695, 280, 722], "C": [1, 1, 0], "Contents": b"Important",
         "T": b"Kev", "QuadPoints": [72, 720, 270, 720, 72, 696, 270, 696], "F": 4},                                 # 8
        {"Type": N("Annot"), "Subtype": N("Text"), "Rect": [400, 700, 420, 720], "Contents": b"A note", "Name": N("Comment"),
         "Popup": R(10), "C": [1, 0.8, 0]},                                                                        # 9
        {"Type": N("Annot"), "Subtype": N("Popup"), "Rect": [420, 600, 560, 700], "Parent": R(9), "Open": True},   # 10
        {"Type": N("Annot"), "Subtype": N("Link"), "Rect": [72, 640, 150, 660], "Border": [0, 0, 0],
         "A": {"S": N("URI"), "URI": b"https://example.com/fox"}},                                                  # 11
        {"Type": N("Annot"), "Subtype": N("Link"), "Rect": [160, 640, 250, 660], "Border": [0, 0, 0],
         "Dest": [R(4), N("XYZ"), 72, 720, 0]},                                                                    # 12
        {"Type": N("Annot"), "Subtype": N("Ink"), "Rect": [100, 100, 200, 200], "C": [0, 0, 1], "BS": {"W": 3},
         "InkList": [[110, 110, 150, 190, 190, 110]]},                                                             # 13
        {"Type": N("Annot"), "Subtype": N("Square"), "Rect": [300, 100, 400, 200], "C": [1, 0, 0], "IC": [0, 1, 0],
         "BS": {"W": 2, "S": N("D"), "D": [3, 2]}},                                                                # 14
        {"Type": N("Annot"), "Subtype": N("Line"), "Rect": [50, 300, 250, 340], "L": [60, 320, 240, 320],
         "LE": [N("None"), N("ClosedArrow")], "C": [0, 0, 0]},                                                     # 15
        {"Type": N("Annot"), "Subtype": N("FreeText"), "Rect": [300, 300, 500, 340], "Contents": b"Free text",
         "DA": b"/Helv 14 Tf 0 0 1 rg", "Q": 1},                                                                   # 16
        {"Type": N("Annot"), "Subtype": N("Widget"), "Rect": [72, 400, 272, 424], "Parent": R(19),
         "DA": b"/Helv 12 Tf 0 g", "MK": {"BG": [0.9, 0.9, 0.9], "BC": [0, 0, 0]}},                                # 17
        {"Type": N("Annot"), "Subtype": N("Widget"), "Rect": [300, 400, 320, 420], "FT": N("Btn"), "T": b"agree",
         "V": N("Yes"), "AS": N("Yes"), "AP": {"N": {"Yes": R(20), "Off": R(21)}}, "MK": {"BC": [0, 0, 0]}},        # 18
        {"FT": N("Tx"), "T": b"name", "V": b"Ann", "Kids": [R(17)], "Ff": 0},                                      # 19
        Stream({"Type": N("XObject"), "Subtype": N("Form"), "BBox": [0, 0, 20, 20]}, b"0 0 m 20 20 l S\n"),       # 20
        Stream({"Type": N("XObject"), "Subtype": N("Form"), "BBox": [0, 0, 20, 20]}, b""),                         # 21
        {"Type": N("Outlines"), "First": R(23), "Last": R(24), "Count": 2},                                        # 22
        {"Title": b"Web", "Parent": R(22), "Next": R(24), "A": {"S": N("URI"), "URI": b"https://example.com/out"}}, # 23
        {"Title": b"Next", "Parent": R(22), "Prev": R(23), "A": {"S": N("Named"), "N": N("NextPage")}},            # 24
        {"Title": b"Annots"},                                                                                      # 25
    ]


def check(path, password=None, flag="-upw"):
    cmd = ["pdfinfo"] + ([flag, password] if password is not None else []) + [path]
    r = subprocess.run(cmd, capture_output=True, text=True)
    assert r.returncode == 0 and re.search(r"Pages: +2\n", r.stdout), f"{path}: {r.stderr}{r.stdout}"
    return r.stdout


def main():
    os.makedirs(OUT, exist_ok=True)
    files = {
        "plain.pdf": classic(document())[0],
        "incremental.pdf": incremental(),
        "objstm.pdf": objstm(),
        "damaged.pdf": classic(document(), broken_xref=True)[0],
        "text.pdf": classic(text_document(), info=8)[0],
        "annots.pdf": classic(annots_document(), info=25)[0],
        "rc4.pdf": classic(document(), sec=Security(3, "user", "owner"))[0],
        "aes128.pdf": classic(document(), sec=Security(4, "", "owner"), version=b"1.6")[0],
        "aes256.pdf": classic(document(), sec=Security(6, "user", "owner"), version=b"1.7")[0],
    }
    for name, data in files.items():
        path = os.path.join(OUT, name)
        with open(path, "wb") as f:
            f.write(data)
        info = check(path, "user" if name in ("rc4.pdf", "aes256.pdf") else None)
        if name in ("rc4.pdf", "aes256.pdf"):
            check(path, "owner", "-opw")
            assert subprocess.run(["pdfinfo", path], capture_output=True).returncode != 0, f"{name} opened without a password"
        print(name, len(data), "bytes;", " ".join(l.split(":", 1)[1].strip() for l in info.splitlines() if l.startswith("Title")))


if __name__ == "__main__":
    main()
