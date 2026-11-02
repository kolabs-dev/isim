"""HelloNetworkExtension (issue #424): NEHotspotConfigurationManager (iOS's join alert, the configured SSIDs, passphrase
checks), NEVPNManager (iOS's "Would Like to Add VPN Configurations" alert, an IKEv2 configuration saved and loaded after a
relaunch, the simulated connection's states), NETunnelProviderManager (a session started without its provider),
NEAppPushManager (active on the simulated Wi-Fi) and, on iOS 26, NEURLFilterManager (no control provider in the app)."""
import plistlib
import re

import pytest

pytestmark = pytest.mark.os_matrix                 # the iOS 26 URL filter; the alerts are system UI
STORE = "Library/NetworkExtension/dev.isim.samples.HelloNetworkExtension.plist"


def test_network_extension(launch, device_data, ios):
    version = float(ios[0] or 18)
    app = launch("HelloNetworkExtension")
    app.wait_log(r"^ne: configured SSIDs \[\]$")
    app.wait_still()

    app.tap_id("join")                                                     # hotspot: iOS's alert, then remembered
    app.wait_view(r"text=“Network Tools” Wants to Join Wi-Fi Network “Café Wi-Fi”")
    app.wait_still()
    app.screenshot("join-wifi")
    app.tap_text("Join")
    app.wait_log(r"^ne: join error none$")
    app.wait_log(r'^ne: configured SSIDs \["Café Wi-Fi"\]$')
    app.wait_still()
    app.tap_id("join-bad")
    app.wait_log(r"^ne: short password error 2 invalidWPA=true$")

    app.tap_id("vpn-add")                                                  # personal VPN: iOS's alert once per app
    app.wait_view(r"text=“Network Tools” Would Like to Add VPN Configurations")
    app.wait_still()
    app.screenshot("add-vpn")
    app.tap_text("Allow")
    app.wait_log(r"^ne: vpn save error none$")
    app.wait_still()
    app.tap_id("vpn-connect")
    app.wait_log(r"^ne: vpn status connecting$")
    app.wait_log(r"^ne: vpn status connected$")
    app.wait_view(r"id=status text=VPN connected")
    app.tap_id("vpn-disconnect")
    app.wait_log(r"^ne: vpn status disconnecting$")
    app.wait_log(r"^ne: vpn status disconnected$")

    app.tap_id("tunnel")                                                   # packet tunnel: no provider is launched
    app.wait_log(r"^ne: tunnel save error none$")
    app.wait_log(r"^ne: vpn status connected \(tunnel\)$")
    assert "the provider dev.isim.samples.HelloNetworkExtension.Tunnel is not launched" in app.log

    app.tap_id("push")                                                     # app push: matches the simulated Wi-Fi "isim"
    app.wait_log(r"^ne: push save error none$")
    app.wait_log(r"^ne: push active true$")
    app.wait_log(r"^ne: push managers 1 active true$")

    app.tap_id("filter")
    if version >= 26:
        app.wait_view(r"text=“Network Tools” Would Like to Filter Network Content")
        app.tap_text("Allow")
        app.wait_log(r"^ne: url filter saved status stopped error extensionNotFound$")
    else:
        app.wait_log(r"^ne: url filter needs iOS 26$")

    stored = plistlib.loads((device_data / STORE).read_bytes())
    assert [h["ssid"] for h in stored["hotspots"]] == ["Café Wi-Fi"], "the joined network is stored for the app"
    vpn = stored["vpn"][0]
    assert vpn["name"] == "Example VPN" and vpn["protocol"]["kind"] == "ikev2" and vpn["protocol"]["serverAddress"] == "vpn.example.com"
    assert vpn["protocol"]["ikeSA"]["enc"] == 6 and vpn["rules"][0]["action"] == 1, "IKEv2 parameters and the on-demand rule saved"
    assert stored["tunnel"][0]["protocol"]["providerBundleIdentifier"] == "dev.isim.samples.HelloNetworkExtension.Tunnel"
    assert app.quit() == 0

    app = launch("HelloNetworkExtension")                                  # relaunch: loaded back, no alert again
    app.wait_log(r"^ne: vpn loaded Example VPN enabled=true server=vpn\.example\.com$")
    app.wait_log(r'^ne: configured SSIDs \["Café Wi-Fi"\]$')
    app.wait_still()
    app.tap_id("forget")
    app.wait_log(r"^ne: configured SSIDs \[\]$")
    app.tap_id("vpn-remove")
    app.wait_log(r"^ne: vpn removed error none$")
    assert "vpn" not in plistlib.loads((device_data / STORE).read_bytes())
    assert not re.search(r"Would Like to Add VPN", app.view_dump())
