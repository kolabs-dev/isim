// isim UIKit overlay (self-authored): what Swift apps need beyond the imported ObjC API.
@_exported import UIKit

extension UIApplicationDelegate {
  /// Entry point for `@main` app delegates (same contract as Apple's UIKit overlay).
  public static func main() {
    UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(self))
  }
}
