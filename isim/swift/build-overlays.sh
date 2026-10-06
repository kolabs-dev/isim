#!/usr/bin/env bash
# Build isim's Swift overlays (ObjectiveC, Foundation, UIKit) into the SDK: /usr/lib/swift/<Module>.swiftmodule
# and /usr/lib/swift/libswift<Module>.dylib (autolinked by the compiler via -module-link-name).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
SDK=$(realpath ../out/sdk); OBJ=../out/swift/obj/overlays; mkdir -p "$OBJ"
EVOLUTION="AVFoundation simd SpriteKit GameplayKit GameController Combine SwiftUI StoreKit GameKit AppTrackingTransparency GoogleMobileAds UserMessagingPlatform"   # app-facing re-implementations: stable ABI across isim updates
ONLY=" $* "   # build-overlays.sh [Module...]: only these (default: all)
build() { # Module  [ld deps...]   (sources: overlays/<Module>.swift or overlays/<Module>/*.swift)
  local m=$1; shift
  [ "$ONLY" = "  " ] || [[ "$ONLY" == *" $m "* ]] || return 0
  local srcs=("overlays/$m.swift"); [ -d "overlays/$m" ] && srcs=(overlays/"$m"/*.swift)
  mkdir -p "$SDK/usr/lib/swift/$m.swiftmodule"
  ../out/bin/isim swiftc -parse-as-library -module-name "$m" -module-link-name "swift$m" \
    -Xfrontend -disable-objc-attr-requires-foundation-module $( case " $EVOLUTION " in *" $m "*) echo -enable-library-evolution ;; esac ) \
    -emit-module -emit-module-path "$SDK/usr/lib/swift/$m.swiftmodule/x86_64-apple-ios-simulator.swiftmodule" \
    -wmo -c "${srcs[@]}" -o "$OBJ/$m.o"
  ld64.lld -arch x86_64 -platform_version ios-simulator 15.0 0 -dylib -install_name "/usr/lib/swift/libswift$m.dylib" \
    -o "$SDK/usr/lib/swift/libswift$m.dylib" "$OBJ/$m.o" -L "$SDK/usr/lib" -L "$SDK/usr/lib/swift" \
    -F "$SDK/System/Library/Frameworks" -lSystem -lobjc -lswiftCore "$@"
  echo "built libswift$m.dylib"
}
build CoreGraphics -framework CoreGraphics
build ObjectiveC -framework Foundation   # NSObject lives in isim Foundation, not libobjc
build Combine
build Dispatch -framework Foundation
build Foundation -lswiftObjectiveC -lswiftDispatch -lswiftCombine -framework Foundation
build UIKit -lswiftObjectiveC -lswiftFoundation -framework Foundation -framework UIKit
build SwiftUI -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit
build GameKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswift_Concurrency -framework Foundation -framework UIKit
build AppTrackingTransparency -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswift_Concurrency -framework Foundation -framework UIKit
build GoogleMobileAds -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswift_Concurrency -framework Foundation -framework UIKit
build UserMessagingPlatform -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswift_Concurrency -framework Foundation -framework UIKit
build AVFoundation -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation -lisim_host
build simd
build SpriteKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftUIKit -lswiftCoreGraphics -lswiftCombine -lswiftSwiftUI -lswift_Concurrency -lswiftsimd -lswiftAVFoundation -framework Foundation -framework UIKit -framework CoreGraphics -lisim_host
build StoreKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswift_Concurrency -framework Foundation -framework UIKit

# stand-ins for remote Swift packages that isim cannot fetch or run (isim build reads this)
mkdir -p "$SDK/usr/share/isim"
cat > "$SDK/usr/share/isim/package-standins.json" <<'JSON'
{
  "https://github.com/googleads/swift-package-manager-google-mobile-ads.git": {
    "kind": "stub", "note": "Google Mobile Ads is not run on isim; ad loads fail, no ads are shown",
    "products": { "GoogleMobileAds": ["GoogleMobileAds"] }
  },
  "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git": {
    "kind": "stub", "note": "no consent form on isim; canRequestAds is false",
    "products": { "GoogleUserMessagingPlatform": ["UserMessagingPlatform"] }
  }
}
JSON
