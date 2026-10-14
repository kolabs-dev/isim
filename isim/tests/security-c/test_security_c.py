"""Certificates, trust and identities from C and Objective-C (SecurityCTest.app, issue #229) on tests/security's test
PKI: SecCertificate (data, summary, common name, serial, key), SecPolicy (SSL, basic), SecTrust (anchors, verify date,
host name mismatch, untrusted root, expired certificate, exceptions, the deprecated SecTrustEvaluate, chain, key),
SecPKCS12Import and SecIdentity, and CFGetTypeID against each ...GetTypeID()."""
from isimtest import need_apps, selftest


def test_security_c(device_data):
    need_apps("SecurityCTest")
    selftest("SecurityCTest", data=device_data)
