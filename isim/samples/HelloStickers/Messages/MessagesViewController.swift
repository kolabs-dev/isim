// The Messages extension's view controller (the Messages framework's MSMessagesAppViewController: issue #406).
import UIKit

final class MessagesViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        print("stk messages extension loaded")
    }
}
