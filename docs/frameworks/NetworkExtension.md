# NetworkExtension

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Web, network & communication](../COVERAGE.md#web) · **Apple:** [NetworkExtension](https://developer.apple.com/documentation/networkextension) · **Issues:** [`area:web`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aweb)

## How isim implements it

- **Approach:** isim's own managers (`isim/swift/overlays/NetworkExtension`). An app's configurations are stored in the
  device data (`Library/NetworkExtension/<bundle id>.plist`), so they load back after a relaunch, and iOS's permission
  alerts are shown: joining a Wi-Fi network (`ISIM_HOTSPOT_PERMISSION`), adding VPN configurations and filtering network
  content (`ISIM_VPN_PERMISSION`, remembered per app). The device's Wi-Fi network is simulated (`ISIM_WIFI_SSID`, default
  `isim`).
- **Not run:** tunnels, filters and providers. A packet tunnel needs a host TUN device and privileges, so a VPN or
  tunnel connection goes through its states (connecting, connected, disconnecting, disconnected, with
  `NEVPNStatusDidChange`) without routing traffic, and provider extensions (packet tunnel, app push, URL filter control)
  are not launched.
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/NetworkExtension` over the Swift classes;
  `NEURLFilterManager` is Swift only, like Apple's.
- **Versus Apple's Simulator:** the Simulator cannot save VPN configurations or join networks; isim saves and loads them
  and simulates the connection, so an app's VPN and hotspot screens can be developed and tested.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `NEHotspotConfigurationManager` (`shared`, `apply(_:completionHandler:)`, `getConfiguredSSIDs`, `removeConfiguration(forSSID:)`, `removeConfiguration(forHS20DomainName:)`), `NEHotspotConfiguration` (SSID, SSID prefix, WPA / WEP passphrase, EAP, Hotspot 2.0; `joinOnce`, `lifeTimeInDays`, `hidden`), `NEHotspotEAPSettings`, `NEHotspotHS20Settings`, `NEHotspotConfigurationError` | ✅ | ≤17 | adapted: `apply` checks the configuration as iOS does (SSID length, WPA 8–63 characters or 64 hex digits, WEP 5/13 characters or 10/26 hex digits, EAP credentials, Hotspot 2.0 domain), needs the `com.apple.developer.networking.HotspotConfiguration` entitlement (else `.systemConfiguration`), shows iOS's “Wants to Join Wi-Fi Network” alert (Cancel: `.userDenied`) and records the network for the app; nothing joins a real network. Not yet: `joinAccessoryHotspot` (AccessorySetupKit). Tested (HelloNetworkExtension, tests/ui/test_network_extension.py) |
| `NEVPNManager` (`shared()`, load / save / remove from preferences, `isEnabled`, `localizedDescription`, `protocolConfiguration`, `isOnDemandEnabled`, `onDemandRules`, `connection`), `NEVPNProtocol`, `NEVPNProtocolIPSec`, `NEVPNProtocolIKEv2` (security associations, dead peer detection, certificates, TLS versions, post-quantum key exchange, `NEVPNIKEv2PPKConfiguration`), `NEProxySettings`, `NEProxyServer`, the on-demand rules (`NEOnDemandRuleConnect` / `Disconnect` / `Ignore` / `EvaluateConnection`, `NEEvaluateConnectionRule`), `NEVPNError`, `NEVPNConnectionError` | ✅ | ≤17 | adapted: the first save shows iOS's “Would Like to Add VPN Configurations” alert (Don’t Allow: `.configurationReadWriteFailed`); a configuration without a protocol or server is `.configurationInvalid`. Every property is stored and loaded back. On-demand rules are kept but not evaluated. Raw values of the IKEv2 enums and `NEVPNConnectionError` follow Apple's headers. Tested (HelloNetworkExtension) |
| `NEVPNConnection` (`startVPNTunnel()`, `startVPNTunnel(options:)`, `stopVPNTunnel()`, `status`, `connectedDate`, `manager`, `fetchLastDisconnectError`), `NEVPNStatus`, `NEVPNStatusDidChange`, `NEVPNConfigurationChange`, `NEVPNConnectionStartOptionUsername` / `Password` | ✅ | ≤17 | adapted: simulated: connecting, then connected after 0.3 s; stopping goes disconnecting → disconnected; each change posts `NEVPNStatusDidChange`. No traffic is routed (a tunnel needs a host TUN device and privileges). Starting an unsaved configuration throws `.configurationInvalid`, a disabled one `.configurationDisabled`. The notification name strings are proposed. Tested (HelloNetworkExtension) |
| `NETunnelProviderManager` (`loadAllFromPreferences`, `forPerAppVPN()`, `routingMethod`, `appRules`, `copyAppRules()`, the Safari / Mail / Calendar / Contacts / associated / excluded domains), `NETunnelProviderProtocol` (`providerBundleIdentifier`, `providerConfiguration`), `NETunnelProviderSession` (`startTunnel(options:)`, `stopTunnel()`, `sendProviderMessage`), `NEAppRule`, `NETunnelProviderRoutingMethod` | ✅ | ≤17 | adapted: any number of configurations per app, stored and loaded; the session goes through `NEVPNConnection`'s simulated states without launching the provider extension, and provider messages get no response (`nil`). Tested (HelloNetworkExtension) |
| `NEAppPushManager` (load all / load / save / remove, `matchSSIDs`, `matchPrivateLTENetworks`, `matchEthernet`, `matchMissionCriticalService` (27.0), `providerBundleIdentifier`, `providerConfiguration`, `delegate`, `isEnabled`, `isActive`), `NEAppPushDelegate`, `NEPrivateLTENetwork`, `NEAppPushManagerError`, `NEAppPushErrorDomain` | ✅ | 14.0 | adapted: `isActive` (KVO-observable) is true while an enabled, saved configuration matches the simulated Wi-Fi network (`ISIM_WIFI_SSID`); the provider extension is not launched, so no incoming call reaches the delegate. Tested (HelloNetworkExtension) |
| `NEURLFilterManager` (`shared`, load / save / remove, `setConfiguration(pirServerURL:…)`, `isEnabled`, `status`, `lastDisconnectError`, `handleStatusChange()`, `handleConfigChange()`, `refreshPIRParameters`, `resetPIRCache`, the iOS 27 URL parsing and report settings) | ✅ | 26.0 | adapted: saved after iOS's “Would Like to Filter Network Content” alert; isim does not filter URLs: an enabled filter whose control provider extension is not in the app stops with `.extensionNotFound`, one whose extension is there reports `.running` without filtering. Swift only, like Apple's. Tested (HelloNetworkExtension, iOS 26 and 27) |
| Providers and other managers: `NEPacketTunnelProvider`, `NEAppProxyProvider`, `NEFilterDataProvider` / `NEFilterControlProvider` / `NEFilterManager`, `NEDNSProxyManager`, `NEDNSSettingsManager`, `NEHotspotHelper`, `NEHotspotNetwork`, `NERelayManager`, `NEAppPushProvider`, `NEURLFilter`, `NEURLFilterControlProvider` | ❌ | ≤17 | not implemented: they run inside provider extensions that isim does not launch, or need the host's network stack |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
