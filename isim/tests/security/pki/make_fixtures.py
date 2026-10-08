#!/usr/bin/env python3
"""Regenerates the test PKI used by SecurityTest (run by hand; the outputs are committed so tests run offline and
need no openssl binary). Test-only keys: never use them for anything else.
  ca.*          isim Test Root CA (EC P-256), 2026-2046
  leaf.*        test.isim.dev (RSA 2048) issued by the CA, 2026-2036, SAN DNS + email, serverAuth
  expired.*     the same key, valid only in January 2026
  selfsigned.*  self-signed, not trusted
  identity.p12  leaf key + leaf + CA, password "isim"
"""
import os
import subprocess

os.chdir(os.path.dirname(os.path.abspath(__file__)))


def ssl(*args):
    subprocess.run(["openssl", *args], check=True, stderr=subprocess.DEVNULL if args[0] == "genrsa" else None)


ssl("ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", "ca.key")
ssl("req", "-x509", "-new", "-key", "ca.key", "-subj", "/CN=isim Test Root CA/O=isim tests", "-not_before", "20260101000000Z",
    "-not_after", "20460101000000Z", "-addext", "basicConstraints=critical,CA:TRUE", "-addext", "keyUsage=critical,keyCertSign,cRLSign",
    "-out", "ca.pem")
ssl("genrsa", "-out", "leaf.key", "2048")
ssl("req", "-new", "-key", "leaf.key", "-subj", "/CN=test.isim.dev/O=isim tests/emailAddress=admin@isim.dev", "-out", "leaf.csr")
with open("leaf.ext", "w") as f:
    f.write("subjectAltName=DNS:test.isim.dev,DNS:*.test.isim.dev,email:admin@isim.dev\nbasicConstraints=CA:FALSE\n"
            "extendedKeyUsage=serverAuth,clientAuth\nkeyUsage=critical,digitalSignature,keyEncipherment\n")
ssl("x509", "-req", "-in", "leaf.csr", "-CA", "ca.pem", "-CAkey", "ca.key", "-set_serial", "0x1234", "-not_before", "20260101000000Z",
    "-not_after", "20360101000000Z", "-extfile", "leaf.ext", "-out", "leaf.pem")
ssl("x509", "-req", "-in", "leaf.csr", "-CA", "ca.pem", "-CAkey", "ca.key", "-set_serial", "0x99", "-not_before", "20260101000000Z",
    "-not_after", "20260201000000Z", "-extfile", "leaf.ext", "-out", "expired.pem")
ssl("req", "-x509", "-new", "-key", "leaf.key", "-subj", "/CN=self-signed.isim.dev", "-not_before", "20260101000000Z",
    "-not_after", "20360101000000Z", "-out", "selfsigned.pem")
for c in ("ca", "leaf", "expired", "selfsigned"):
    ssl("x509", "-in", f"{c}.pem", "-outform", "DER", "-out", f"{c}.der")
ssl("pkcs12", "-export", "-inkey", "leaf.key", "-in", "leaf.pem", "-certfile", "ca.pem", "-name", "isim test identity",
    "-passout", "pass:isim", "-out", "identity.p12")
os.remove("leaf.csr")
os.remove("leaf.ext")
print("fixtures written")
