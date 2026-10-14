#!/usr/bin/env python3
"""Regenerates the certificates SecurityTest uses for Apple's TLS trust rules and OCSP revocation (run by hand, needs
Python's cryptography package; the outputs are committed). Issued by the test CA of make_fixtures.py (ca.key); test-only.
  server.der        test.isim.dev, *.test.isim.dev (the leaf key), serverAuth, 2026-01-01 + 825 days: passes the SSL rules
                    (leaf.der, valid 10 years, is over Apple's 825-day limit)
  noeku.der         no serverAuth extended key usage      nosan.der   no subjectAltName (the host only in the CN)
  rsa1024.der       a 1024-bit RSA key
  ocsp-good.der / ocsp-revoked.der   name the OCSP responder http://127.0.0.1:47821 (the test serves the answers there)
  ocsp-good.resp / ocsp-revoked.resp the CA's OCSP answers for them (good / revoked), valid until 2046
"""
import datetime
import os

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509 import ocsp
from cryptography.x509.oid import AuthorityInformationAccessOID, ExtendedKeyUsageOID, NameOID

os.chdir(os.path.dirname(os.path.abspath(__file__)))
with open("ca.key", "rb") as f:
    ca_key = serialization.load_pem_private_key(f.read(), None)
with open("ca.pem", "rb") as f:
    ca = x509.load_pem_x509_certificate(f.read())
with open("leaf.key", "rb") as f:
    leaf_key = serialization.load_pem_private_key(f.read(), None)
START = datetime.datetime(2026, 1, 1, tzinfo=datetime.timezone.utc)


def issue(name, serial, key, san=True, eku=True, ocsp_url=None, names=("test.isim.dev",)):
    b = (x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, names[0])]))
         .issuer_name(ca.subject).public_key(key.public_key()).serial_number(serial)
         .not_valid_before(START).not_valid_after(START + datetime.timedelta(days=825))
         .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=False))
    if san:
        b = b.add_extension(x509.SubjectAlternativeName([x509.DNSName(n) for n in names]), critical=False)
    if eku:
        b = b.add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False)
    if ocsp_url:
        b = b.add_extension(x509.AuthorityInformationAccess([x509.AccessDescription(AuthorityInformationAccessOID.OCSP,
                                                                                   x509.UniformResourceIdentifier(ocsp_url))]), critical=False)
    cert = b.sign(ca_key, hashes.SHA256())
    with open(f"{name}.der", "wb") as f:
        f.write(cert.public_bytes(serialization.Encoding.DER))
    return cert


issue("server", 0x2000, leaf_key, names=("test.isim.dev", "*.test.isim.dev"))
issue("noeku", 0x2002, leaf_key, eku=False)
issue("nosan", 0x2003, leaf_key, san=False)
issue("rsa1024", 0x2004, rsa.generate_private_key(public_exponent=65537, key_size=1024))
for name, serial, revoked in (("ocsp-good", 0x3001, False), ("ocsp-revoked", 0x3002, True)):
    cert = issue(name, serial, leaf_key, ocsp_url="http://127.0.0.1:47821")
    b = ocsp.OCSPResponseBuilder().add_response(
        cert=cert, issuer=ca, algorithm=hashes.SHA1(),
        cert_status=ocsp.OCSPCertStatus.REVOKED if revoked else ocsp.OCSPCertStatus.GOOD,
        this_update=START, next_update=datetime.datetime(2046, 1, 1, tzinfo=datetime.timezone.utc),
        revocation_time=datetime.datetime(2026, 3, 1, tzinfo=datetime.timezone.utc) if revoked else None,
        revocation_reason=x509.ReasonFlags.key_compromise if revoked else None,
    ).responder_id(ocsp.OCSPResponderEncoding.HASH, ca)
    with open(f"{name}.resp", "wb") as f:
        f.write(b.sign(ca_key, hashes.SHA256()).public_bytes(serialization.Encoding.DER))
print("trust fixtures written")
