// Built with the isim 0.2.0 release toolchain (see build-probe.sh); run by tests/abi/run.sh on the current
// runtime to prove that apps built with an older isim keep working.
import SwiftUI
import UIKit

func cgProbe() {
    let img = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 10)).image { c in
        UIColor.red.setFill(); c.fill(CGRect(x: 0, y: 0, width: 20, height: 10))
    }.cgImage!
    let crop = img.cropping(to: CGRect(x: 0, y: 0, width: 4, height: 3))
    var drew = false
    let out = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { c in
        c.cgContext.draw(img, in: CGRect(x: 0, y: 0, width: 8, height: 8)); drew = true
    }
    let red = out.cgImage.map { _ in drew } ?? false
    print("abi cg: width=\(img.width) height=\(img.height) crop=\(crop?.width ?? -1)x\(crop?.height ?? -1) drawn=\(red)")
}

struct ProbeView: View {
    var body: some View {
        VStack(spacing: 40) {
            Color.blue.frame(width: 200, height: 120)
                .gesture(DragGesture().onChanged { _ in }.onEnded { v in print("abi drag ended dx=\(Int(v.translation.width))") })
            Color.green.frame(width: 200, height: 120)
                .gesture(TapGesture().onEnded { print("abi tap ended") })
            Color.orange.frame(width: 200, height: 120)
                .gesture(LongPressGesture(minimumDuration: 0.3).onEnded { ok in print("abi long press ended \(ok)") })
        }
        .onAppear { cgProbe() }
    }
}

@main struct ABIProbeApp: App {
    var body: some Scene { WindowGroup { ProbeView() } }
}
