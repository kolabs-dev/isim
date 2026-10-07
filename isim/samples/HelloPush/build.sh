#!/usr/bin/env bash
# Build HelloPush.app (remote notifications) with its Notification Service extension (PlugIns/PushService.appex) and
# Notification Content extension (PlugIns/PushContent.appex), linked like Xcode with the _NSExtensionMain entry point.
# Payloads for `isim push` are in payloads/. Needs the swift:6.2 image; ImageMagick draws the app icon.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUserNotifications.dylib ] || { echo "HelloPush: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloPush.app; objd=$(realpath -m ../../out/swift/obj)
rm -rf "$out"; mkdir -p "$out/PlugIns/PushService.appex" "$out/PlugIns/PushContent.appex" "$objd"
"$isim" swiftc -module-name HelloPush -parse-as-library -wmo -c HelloPush.swift -o "$objd/HelloPush.o"
"$isim" cc "$objd/HelloPush.o" -o "$out/HelloPush"
cp Info.plist "$out/"
cp HelloPush.entitlements "$out/archived-expanded-entitlements.xcent"     # aps-environment, like Xcode simulator builds
"$isim" swiftc -module-name PushService -parse-as-library -wmo -application-extension -c Service/NotificationService.swift -o "$objd/PushService.o"
"$isim" cc "$objd/PushService.o" -o "$out/PlugIns/PushService.appex/PushService" -Wl,-e,_NSExtensionMain -framework UserNotifications
cp Service/Info.plist "$out/PlugIns/PushService.appex/"
"$isim" swiftc -module-name PushContent -parse-as-library -wmo -application-extension -c Content/NotificationViewController.swift -o "$objd/PushContent.o"
"$isim" cc "$objd/PushContent.o" -o "$out/PlugIns/PushContent.appex/PushContent" -Wl,-e,_NSExtensionMain -framework UserNotifications -framework UserNotificationsUI
cp Content/Info.plist "$out/PlugIns/PushContent.appex/"
magick -size 180x180 gradient:'#ff3b30'-'#c41d14' -fill white -font DejaVu-Sans-Bold -pointsize 96 -gravity center -annotate 0 'P' "$out/AppIcon60x60@3x.png" 2>/dev/null || true
echo "built $out"
