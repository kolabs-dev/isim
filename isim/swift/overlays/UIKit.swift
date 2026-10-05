// isim UIKit overlay (self-authored): what Swift apps need beyond the imported ObjC API.
@_exported import UIKit

extension UIApplicationDelegate {
  /// Entry point for `@main` app delegates (same contract as Apple's UIKit overlay).
  public static func main() {
    UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(self))
  }
}

// MARK: - Geometry conveniences (UIKit Swift overlay API)
extension UIEdgeInsets: Equatable {
    public static var zero: UIEdgeInsets { UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
    public static func == (a: UIEdgeInsets, b: UIEdgeInsets) -> Bool { a.top == b.top && a.left == b.left && a.bottom == b.bottom && a.right == b.right }
}
extension NSDirectionalEdgeInsets: Equatable {
    public static var zero: NSDirectionalEdgeInsets { NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0) }
    public static func == (a: NSDirectionalEdgeInsets, b: NSDirectionalEdgeInsets) -> Bool { a.top == b.top && a.leading == b.leading && a.bottom == b.bottom && a.trailing == b.trailing }
}
extension CGRect {
    public func inset(by i: UIEdgeInsets) -> CGRect {
        CGRect(x: origin.x + i.left, y: origin.y + i.top, width: size.width - i.left - i.right, height: size.height - i.top - i.bottom)
    }
}
