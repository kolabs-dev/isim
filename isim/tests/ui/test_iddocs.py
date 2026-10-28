"""IdentityDocumentServices (iOS 26, issue #403, HelloIDDocs): an identity document provider registers the mDL its
entitlement allows, is refused another document type, an expired registration is not listed, removing an unknown one
is invalidRequest; a DeviceRequest validates to its document, elements (intent to retain) and reader certificate chain,
and an http origin or a request that is not a DeviceRequest is invalidRequest. Before iOS 26 the API is unavailable."""
import os
import subprocess

import pytest

from isimtest import ISIM


@pytest.mark.os_matrix
def test_identity_documents(launch, device_data, ios):
    version = ios[0] or "26.0"
    app = launch("HelloIDDocs", data=device_data, os_version=version)
    if int(version.split(".")[0]) < 26:
        app.wait_log(r"^id needs iOS 26$")
        assert app.quit() == 0
        return
    app.wait_log(r"^id status authorized$")
    app.wait_log(r"^id added license-1$")
    app.wait_log(r"^id added old$")
    app.wait_log(r"^id photo id refused invalidRequest$")
    app.wait_log(r'^id registrations \["license-1:org\.iso\.18013\.5\.1\.mDL"\]$')
    app.wait_log(r"^id remove missing invalidRequest$")
    app.wait_log(r'^id request org\.iso\.18013\.5\.1\.mDL mandatory=true \["org\.iso\.18013\.5\.1\.birth_date=false", '
                 r'"org\.iso\.18013\.5\.1\.family_name=false", "org\.iso\.18013\.5\.1\.portrait=true"\]$')
    app.wait_log(r"^id reader chain \[1\]$")
    app.wait_log(r"^id http origin invalidRequest$")
    app.wait_log(r"^id garbage true$")
    assert app.quit() == 0
    r = subprocess.run([str(ISIM), "iddocs", "list"], env=dict(os.environ, ISIM_DATA=str(device_data)),
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60)
    assert "dev.isim.samples.HelloIDDocs: org.iso.18013.5.1.mDL license-1 until " in r.stdout, r.stdout
