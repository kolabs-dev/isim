"""HelloAttest: isim's simulated Secure Enclave and local DeviceCheck / App Attest (issue #27).

- A CryptoKit Secure Enclave key with `.biometryCurrentSet` access control: each signature asks for Face ID (the
  permission alert, then the simulated scan alert); a non-matching face fails the signature; an LAContext that already
  authenticated signs twice without asking again.
- DeviceCheck: the app's token validates with `isim devicecheck validate`; `query` / `update` keep the two bits.
- App Attest: the app (playing the server) verifies the attestation object (fmt, x5c, nonce extension, key id, app id,
  AAGUID appattestdevelop) and assertions (signature, increasing counter); a second attestation of the key fails;
  the x5c chain verifies with openssl against `isim appattest root`.
"""
import base64
import json
import os
import re
import subprocess

import pytest

from isimtest import ISIM

APP = "HelloAttest"


def isim(data, *args):
    r = subprocess.run([str(ISIM), *args], env=dict(os.environ, ISIM_DATA=str(data)), capture_output=True, text=True, timeout=60)
    return r.stdout + r.stderr


def der_items(data, i=0):
    """(tag, start of contents, length) at i (DER)"""
    tag, n = data[i], data[i + 1]
    i += 2
    if n & 0x80:
        k = n & 0x7f
        n = int.from_bytes(data[i:i + k], "big")
        i += k
    return tag, i, n


def cbor(data, i=0):
    """a minimal CBOR reader for the attestation object -> (value, next index)"""
    head = data[i]
    major, info = head >> 5, head & 0x1f
    i += 1
    if info >= 24:
        k = {24: 1, 25: 2, 26: 4, 27: 8}[info]
        info = int.from_bytes(data[i:i + k], "big")
        i += k
    if major == 0:
        return info, i
    if major == 1:
        return -1 - info, i
    if major in (2, 3):
        v = data[i:i + info]
        return (v if major == 2 else v.decode()), i + info
    if major == 4:
        out = []
        for _ in range(info):
            v, i = cbor(data, i)
            out.append(v)
        return out, i
    if major == 5:
        out = {}
        for _ in range(info):
            k, i = cbor(data, i)
            v, i = cbor(data, i)
            out[k] = v
        return out, i
    raise ValueError(major)


@pytest.mark.os_matrix                                              # the Face ID alerts are system UI
def test_enclave_devicecheck_appattest(launch, device_data, tmp_path):
    app = launch(APP)
    app.wait_log(r"launched; secure enclave available: true")

    # a Secure Enclave key that needs Face ID
    app.wait_tap_id("enclave-create")
    app.wait_log(r"enclave key created: available=true blob=\d+ public=64")
    app.tap_id("enclave-sign")
    app.wait_view(r"text=Do you want to allow “Attest” to use Face ID\?")
    app.tap_text("OK")
    app.wait_view(r"text=Matching Face")
    app.wait_still()
    app.screenshot("enclave-faceid")
    app.tap_text("Matching Face")
    app.wait_log(r"enclave signature verified: true")
    app.wait_view(r"text=Matching Face", gone=True)
    app.wait_still()
    app.tap_id("enclave-sign")                                      # a face that does not match: no signature
    app.wait_view(r"text=Non-matching Face")
    app.tap_text("Non-matching Face")
    app.wait_view(r"text=Face Not Recognized")
    app.tap_text("Cancel")
    app.wait_log(r"enclave sign failed: CryptoKit\.CryptoKitError|enclave sign failed: \S+ -?\d+")
    app.wait_view(r"text=Face Not Recognized", gone=True)
    app.wait_still()
    app.tap_id("enclave-context")                                   # one Face ID, two signatures
    app.wait_view(r"text=Matching Face")
    app.tap_text("Matching Face")
    app.wait_log(r"context 2 signature verified: true")

    # DeviceCheck
    app.tap_id("devicecheck")
    token = app.wait_log(r"device token: (\S+)").group(1)
    (tmp_path / "token").write_text(token)
    valid = json.loads(isim(device_data, "devicecheck", "validate", f"@{tmp_path / 'token'}"))
    assert valid["valid"] and valid["bundle"] == "dev.isim.samples.HelloAttest" and len(valid["device"]) == 32, valid
    assert "Failed to find bit state" in isim(device_data, "devicecheck", "query", token)
    assert '"bit0": true, "bit1": false' in isim(device_data, "devicecheck", "update", token, "true", "false")
    assert '"bit0": true' in isim(device_data, "devicecheck", "query", token)
    assert "invalid token" in isim(device_data, "devicecheck", "query", token[:-4] + "AAA=")

    # App Attest
    app.tap_id("attest")
    line = app.wait_log(r"attestation: .*").group(0)
    assert line == ("attestation: fmt=apple-appattest x5c=2 nonce=true keyId=true credentialId=true appId=true "
                    "aaguid=appattestdevelop counter=0 receipt=true"), line
    obj = base64.b64decode(app.wait_log(r"attestation object: (\S+)").group(1))
    app.wait_log(r"attest again: 3")                                # DCError.invalidKey: a key is attested once
    app.tap_id("assert")
    app.wait_log(r"assertion: verified=true appId=true counter=1 increased=true")
    app.tap_id("assert")
    app.wait_log(r"assertion: verified=true appId=true counter=2 increased=true")
    app.wait_still()
    app.screenshot("appattest")
    assert app.quit() == 0
    assert "Face ID matched" in app.log and app.log.count("Face ID matched") == 2, "one Face ID per signature, one for the context"

    # the attestation's certificate chain ends at this device data's App Attest root (openssl, independent of isim)
    att, _ = cbor(obj)
    leaf, ca = att["attStmt"]["x5c"]
    (tmp_path / "leaf.der").write_bytes(leaf)
    (tmp_path / "ca.der").write_bytes(ca)
    root = isim(device_data, "appattest", "root")
    assert root.startswith("-----BEGIN CERTIFICATE-----"), root
    (tmp_path / "root.pem").write_text(root)

    def pem(der_file):
        return subprocess.run(["openssl", "x509", "-inform", "DER", "-in", str(der_file)], capture_output=True, text=True, check=True).stdout
    (tmp_path / "chain.pem").write_text(pem(tmp_path / "ca.der"))
    (tmp_path / "leaf.pem").write_text(pem(tmp_path / "leaf.der"))
    v = subprocess.run(["openssl", "verify", "-CAfile", str(tmp_path / "root.pem"), "-untrusted", str(tmp_path / "chain.pem"),
                        str(tmp_path / "leaf.pem")], capture_output=True, text=True)
    assert v.returncode == 0 and ": OK" in v.stdout, v.stdout + v.stderr
    text = subprocess.run(["openssl", "x509", "-in", str(tmp_path / "leaf.pem"), "-noout", "-text"], capture_output=True, text=True).stdout
    assert "1.2.840.113635.100.8.2" in text and "prime256v1" in text, text
