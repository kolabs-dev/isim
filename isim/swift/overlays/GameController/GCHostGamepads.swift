// isim GameController: physical game controllers on the host. libisim_host reads them through SDL3's gamepad
// API (Xbox, PlayStation, Switch Pro and generic pads share SDL's standard layout); each host pad becomes a
// GCController with a GCExtendedGamepad, connected / disconnected with the usual notifications.
// ISIM_GAMEPADS=0 turns host pads off. Polled at 60 Hz on the main run loop while GameController is in use.
import Foundation
import isim_host

public let GCProductCategoryDualSense = "DualSense"
public let GCProductCategoryDualShock4 = "DualShock 4"
public let GCProductCategoryMFi = "MFi"
public let GCProductCategoryXboxOne = "Xbox One"
public let GCProductCategorySwitchPro = "Switch Pro Controller"
public let GCProductCategorySwitchJoyConPair = "Nintendo Switch Joy-Con (L/R)"
public let GCProductCategoryHID = "HID"

@MainActor enum _GCHostPads {
    nonisolated(unsafe) static var timer: Timer?
    nonisolated(unsafe) static var pads: [Int32: GCController] = [:]
    nonisolated(unsafe) static var disabled = false

    static func start() {
        guard timer == nil, !disabled else { return }
        poll()
        guard !disabled else { return }
        timer = Timer._isimScheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { _ in MainActor.assumeIsolated { poll() } }
    }

    static func text<T>(_ tuple: T) -> String {
        withUnsafeBytes(of: tuple) { raw in String(cString: raw.bindMemory(to: CChar.self).baseAddress!) }
    }

    static func category(_ sdlType: String) -> String {
        switch sdlType {
        case "xboxone", "xbox360": return GCProductCategoryXboxOne
        case "ps4": return GCProductCategoryDualShock4
        case "ps5": return GCProductCategoryDualSense
        case "ps3": return "DualShock 3"
        case "switchpro": return GCProductCategorySwitchPro
        case "joyconpair": return GCProductCategorySwitchJoyConPair
        default: return GCProductCategoryMFi
        }
    }

    static func poll() {
        var buf = [isim_gamepad](repeating: isim_gamepad(), count: 8)
        let n = buf.withUnsafeMutableBufferPointer { isim_gamepad_poll($0.baseAddress, 8) }
        if n < 0 { disabled = true; timer?.invalidate(); timer = nil; return }
        var seen = Set<Int32>()
        for i in 0..<Int(n) {
            let p = buf[i]
            seen.insert(p.id)
            let c: GCController
            if let known = pads[p.id] { c = known }
            else {
                c = GCController(extended: true)
                c.vendorName = text(p.name)
                c.productCategory = category(text(p.type))
                c._hostPadID = p.id
                pads[p.id] = c
                update(c, p)
                GCController.connect(c)
                continue
            }
            update(c, p)
        }
        for (id, c) in pads where !seen.contains(id) {
            pads[id] = nil
            GCController.disconnect(c)
        }
    }

    static func update(_ c: GCController, _ p: isim_gamepad) {
        guard let g = c.extendedGamepad else { return }
        func bit(_ i: Int) -> Float { p.buttons & (1 << UInt32(i)) != 0 ? 1 : 0 }
        let ax = [p.axes.0, p.axes.1, p.axes.2, p.axes.3, p.axes.4, p.axes.5]
        g.buttonA.setValue(bit(0)); g.buttonB.setValue(bit(1)); g.buttonX.setValue(bit(2)); g.buttonY.setValue(bit(3))
        g.buttonOptions?.setValue(bit(4)); g.buttonHome?.setValue(bit(5)); g.buttonMenu.setValue(bit(6))
        g.leftThumbstickButton?.setValue(bit(7)); g.rightThumbstickButton?.setValue(bit(8))
        g.leftShoulder.setValue(bit(9)); g.rightShoulder.setValue(bit(10))
        let dx = bit(14) - bit(13), dy = bit(11) - bit(12)
        if dx != g.dpad.xAxis.value || dy != g.dpad.yAxis.value { g.dpad.setValueForXAxis(dx, yAxis: dy) }
        // SDL's y axes point down; GameController's point up
        if ax[0] != g.leftThumbstick.xAxis.value || -ax[1] != g.leftThumbstick.yAxis.value { g.leftThumbstick.setValueForXAxis(ax[0], yAxis: -ax[1]) }
        if ax[2] != g.rightThumbstick.xAxis.value || -ax[3] != g.rightThumbstick.yAxis.value { g.rightThumbstick.setValueForXAxis(ax[2], yAxis: -ax[3]) }
        g.leftTrigger.setValue(ax[4]); g.rightTrigger.setValue(ax[5])
        // the micro gamepad profile mirrors the extended one
        if let m = c.microGamepad {
            m.buttonA.setValue(bit(0)); m.buttonX.setValue(bit(2)); m.buttonMenu.setValue(bit(6))
            if dx != m.dpad.xAxis.value || dy != m.dpad.yAxis.value { m.dpad.setValueForXAxis(dx, yAxis: dy) }
        }
    }
}
