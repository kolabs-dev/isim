// HelloListExtras: UIKit members deprecated in iOS 18–27 that apps still call (issue #335), logged "lx deprecated ...":
// the sidebar list styles and header / footer backgrounds, the Bluetooth / Newsstand launch keys and the URL annotation
// key, the New Window menu group, a toolbar appearance's done-button appearance, UIScreen's capture state and display
// link, and a table header's detail label.
import UIKit

final class Ticker: NSObject {
    @objc func tick(_ link: CADisplayLink) {}
}

@MainActor func logDeprecatedMembers() {
    let header = UIListContentConfiguration.sidebarHeader()
    let sub = UIListContentConfiguration.sidebarSubtitleCell()
    let bold = header.textProperties.font.fontDescriptor.symbolicTraits.contains(.traitBold)
    log("deprecated sidebar header \(Int(header.textProperties.font.pointSize)) bold \(bold) subtitle \(Int(sub.secondaryTextProperties.font.pointSize))")
    let alpha = { (b: UIBackgroundConfiguration) in Int((b.backgroundColor?.cgColor.alpha ?? -1) * 100) }
    log("deprecated backgrounds plain \(alpha(.listPlainHeaderFooter())) grouped \(alpha(.listGroupedHeaderFooter())) sidebar \(alpha(.listSidebarHeader()))")
    let keys: [UIApplication.LaunchOptionsKey] = [.bluetoothCentrals, .bluetoothPeripherals, .newsstandDownloads]
    log("deprecated keys \(keys.map(\.rawValue).joined(separator: ",")) \(UIApplication.OpenURLOptionsKey.annotation.rawValue)")
    log("deprecated menu \(UIMenu.Identifier.newScene.rawValue)")
    let toolbar = UIToolbarAppearance()
    toolbar.doneButtonAppearance.normal.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 21)]
    let copy = UIToolbarAppearance(barAppearance: toolbar)
    let size = (copy.doneButtonAppearance.normal.titleTextAttributes[.font] as? UIFont)?.pointSize ?? 0
    log("deprecated toolbar done font \(Int(size)) plain \(copy.buttonAppearance.normal.titleTextAttributes.isEmpty)")
    let ticker = Ticker()
    let link = UIScreen.main.displayLink(withTarget: ticker, selector: #selector(Ticker.tick(_:)))
    link?.invalidate()
    log("deprecated screen captured \(UIScreen.main.isCaptured) link \(link != nil)")
    let hf = UITableViewHeaderFooterView(reuseIdentifier: nil)
    hf.textLabel?.text = "Title"
    hf.detailTextLabel?.text = "Detail"
    hf.frame = CGRect(x: 0, y: 0, width: 320, height: 60)
    hf.layoutIfNeeded()
    let below = (hf.detailTextLabel?.frame.minY ?? 0) >= (hf.textLabel?.frame.maxY ?? 1)
    log("deprecated header detail \(hf.detailTextLabel?.text ?? "-") below \(below)")
}
