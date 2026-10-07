#!/usr/bin/env bash
# Build isim's Swift overlays (ObjectiveC, Foundation, UIKit) into the SDK: /usr/lib/swift/<Module>.swiftmodule
# and /usr/lib/swift/libswift<Module>.dylib (autolinked by the compiler via -module-link-name).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
SDK=$(realpath ../out/sdk); OBJ=../out/swift/obj/overlays; mkdir -p "$OBJ"
EVOLUTION="CoreLocation UniformTypeIdentifiers CoreTransferable Photos PhotosUI EventKit EventKitUI Contacts ContactsUI HealthKit CoreMotion CoreBluetooth CoreNFC AVFoundation simd SpriteKit GameplayKit GameController Combine SwiftUI Charts StoreKit GameKit AppTrackingTransparency GoogleMobileAds UserMessagingPlatform Network CryptoKit Security os OSLog LocalAuthentication DeviceCheck UserNotifications AVKit AudioToolbox CoreData CoreMedia MediaPlayer AdSupport MetricKit CloudKit AuthenticationServices QuartzCore CoreHaptics CoreVideo CoreML Vision NaturalLanguage Speech VisionKit"   # app-facing re-implementations: stable ABI across isim updates
EVOLUTION="$EVOLUTION WebKit SafariServices AuthenticationServices MessageUI MapKit MultipeerConnectivity"   # web & communication overlays
EVOLUTION="$EVOLUTION BackgroundTasks CoreSpotlight AppIntents ActivityKit WidgetKit"   # system integration overlays
PRIVACY="CoreLocation HealthKit Contacts EventKit Photos PhotosUI AVFoundation Speech"   # modules that also compile overlays/_Privacy (permission alerts, device data)
ONLY=" $* "   # build-overlays.sh [Module...]: only these (default: all)
build() { # Module  [ld deps...]   (sources: overlays/<Module>.swift or overlays/<Module>/*.swift)
  local m=$1; shift
  [ "$ONLY" = "  " ] || [[ "$ONLY" == *" $m "* ]] || return 0
  local srcs=("overlays/$m.swift"); [ -d "overlays/$m" ] && srcs=(overlays/"$m"/*.swift)
  for x in overlays/"$m"+*.swift; do if [ -e "$x" ]; then srcs+=("$x"); fi; done      # overlays/<Module>+Part.swift
  case " $PRIVACY " in *" $m "*) srcs+=(overlays/_Privacy/*.swift) ;; esac
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
build Foundation -lswiftObjectiveC -lswiftDispatch -lswiftCombine -lswift_Concurrency -framework Foundation -lisim_host
build UniformTypeIdentifiers -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation
build CoreTransferable -lswiftObjectiveC -lswiftFoundation -lswiftUniformTypeIdentifiers -lswift_Concurrency -framework Foundation
build UIKit -lswiftObjectiveC -lswiftFoundation -lswiftUniformTypeIdentifiers -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit   # (+ drag and drop: NSItemProvider)
build SwiftUI -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftUniformTypeIdentifiers -lswiftCoreTransferable -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host
build Charts -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit
build GameKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswift_Concurrency -framework Foundation -framework UIKit
build AppTrackingTransparency -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswift_Concurrency -framework Foundation -framework UIKit
build GoogleMobileAds -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswift_Concurrency -framework Foundation -framework UIKit
build UserMessagingPlatform -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswift_Concurrency -framework Foundation -framework UIKit
build AudioToolbox -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -framework Foundation -lisim_host
build CoreVideo -lswiftObjectiveC -lswiftFoundation -lswiftCoreGraphics -framework Foundation -framework CoreGraphics
build CoreMedia -lswiftObjectiveC -lswiftFoundation -lswiftCoreVideo -lswiftAudioToolbox -lswiftCoreGraphics -framework Foundation -framework CoreGraphics
build AVFoundation -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreMedia -lswiftCoreVideo -lswiftAudioToolbox -lswiftUIKit -lswiftCoreGraphics -framework Foundation -framework UIKit -framework CoreGraphics -lisim_host
build simd
build SpriteKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftUIKit -lswiftCoreGraphics -lswiftCombine -lswiftSwiftUI -lswift_Concurrency -lswiftsimd -lswiftAVFoundation -framework Foundation -framework UIKit -framework CoreGraphics -lisim_host
build GameplayKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftUIKit -lswiftCoreGraphics -lswiftsimd -lswiftSpriteKit -lswift_Concurrency -framework Foundation -framework UIKit
build GameController -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftUIKit -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host
build CryptoKit -lswiftObjectiveC -lswiftFoundation -framework Foundation -lisim_host
build Security -lswiftObjectiveC -lswiftFoundation -framework Foundation
build os -lswiftObjectiveC -lswiftFoundation -framework Foundation
build OSLog -lswiftos -lswiftObjectiveC -lswiftFoundation -framework Foundation
build LocalAuthentication -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host
build DeviceCheck -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation
build BackgroundTasks -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
build UserNotifications -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -framework Foundation -framework UIKit -framework UserNotifications
build CoreML -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreVideo -lswiftCoreGraphics -framework Foundation -framework CoreGraphics
build Vision -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreVideo -lswiftCoreMedia -lswiftAudioToolbox -lswiftCoreML -lswiftUIKit -lswiftCoreGraphics -framework Foundation -framework UIKit -framework CoreGraphics -framework CoreImage -framework ImageIO -lisim_host
build NaturalLanguage -lswiftObjectiveC -lswiftFoundation -lswift_Concurrency -framework Foundation
build Speech -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreMedia -lswiftCoreVideo -lswiftAudioToolbox -lswiftAVFoundation -lswiftUIKit -lswiftCoreGraphics -framework Foundation -framework UIKit -framework CoreGraphics -lisim_host
build VisionKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftUIKit -lswiftCoreGraphics -lswiftVision -lswiftCoreML -lswiftCoreVideo -lswiftCoreMedia -lswiftAudioToolbox -framework Foundation -framework UIKit -framework CoreGraphics
build AVKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreMedia -lswiftAVFoundation -lswiftUIKit -lswiftSwiftUI -lswiftCoreGraphics -lswiftCombine -framework Foundation -framework UIKit -framework CoreGraphics -lisim_host
build MediaPlayer -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftCoreMedia -lswiftUIKit -lswiftCoreGraphics -framework Foundation -framework UIKit -framework CoreGraphics -lisim_host
build CoreData -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreData
build StoreKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswift_Concurrency -framework Foundation -framework UIKit
build CoreLocation -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
build QuartzCore -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -framework Foundation -framework UIKit
build CoreHaptics -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -framework Foundation
build CoreMotion -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation
build CoreBluetooth -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -framework Foundation
build CoreNFC -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -framework Foundation
build HealthKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
build Contacts -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
build ContactsUI -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftContacts -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
build EventKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreGraphics
build EventKitUI -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftEventKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
build Photos -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreGraphics
build PhotosUI -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftPhotos -lswiftUniformTypeIdentifiers -lswiftCoreTransferable -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreGraphics
build Network -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation -lisim_host
build WebKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host
build SafariServices -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftWebKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit
build AdSupport -lswiftObjectiveC -lswiftFoundation -framework Foundation
build MetricKit -lswiftos -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -framework Foundation
build CloudKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreLocation -lswift_Concurrency -framework Foundation -framework UIKit
build AuthenticationServices -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftWebKit -lswiftSafariServices -lswiftSwiftUI -lswiftCryptoKit -lswiftSecurity -lswiftDispatch -lswiftCoreGraphics -lswiftCombine -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreGraphics
build MessageUI -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit
build MapKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftCoreLocation -lswiftContacts -lswiftSwiftUI -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit
build MultipeerConnectivity -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftNetwork -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit
build XCTest -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit -framework XCTest
build AppIntents -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit
build ActivityKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation -lisim_host
build WidgetKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftAppIntents -lswiftActivityKit -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host
build CoreSpotlight -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftUniformTypeIdentifiers -framework Foundation

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
