// Sample: a background URLSession on isim — a download that keeps going while the app is in the background; when it
// finishes there, iOS (and isim) wakes the app with application(_:handleEventsForBackgroundURLSession:completionHandler:),
// delivers the session's events and calls urlSessionDidFinishEvents(forBackgroundURLSession:).
import UIKit

final class Transfers: NSObject, URLSessionDownloadDelegate {
    static let shared = Transfers()
    static let identifier = "dev.isim.samples.transfers"
    var completion: (() -> Void)?
    lazy var session = URLSession(configuration: .background(withIdentifier: Transfers.identifier), delegate: self, delegateQueue: nil)

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let size = (try? Data(contentsOf: location))?.count ?? -1
        print("download finished: \(size) bytes, app \(DispatchQueue.main.sync { UIApplication.shared.applicationState == .background ? "in the background" : "active" })")
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("task complete, error \(error.map { "\($0)" } ?? "none")")
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("session finished events")
        DispatchQueue.main.async { self.completion?(); self.completion = nil }
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController(); vc.view.backgroundColor = .systemBackground
        let b = UIButton(type: .system)
        b.setTitle("Download", for: .normal); b.frame = CGRect(x: 40, y: 200, width: 200, height: 44)
        b.accessibilityIdentifier = "download"
        b.addAction(UIAction { _ in
            let url = URL(string: ProcessInfo.processInfo.environment["TRANSFER_URL"] ?? "http://127.0.0.1:8765/file")!
            Transfers.shared.session.downloadTask(with: url).resume()
            print("download started")
        }, for: .primaryActionTriggered)
        vc.view.addSubview(b)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        _ = Transfers.shared.session                     // recreated at launch: unfinished transfers start again
        return true
    }
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        print("handle events for \(identifier)")
        Transfers.shared.completion = completionHandler
    }
}
