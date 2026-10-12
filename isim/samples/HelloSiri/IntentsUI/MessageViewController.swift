// HelloSiri's Intents UI extension: Siri's message confirmation as a chat bubble.
import UIKit
import Intents
import IntentsUI

class MessageViewController: UIViewController, INUIHostedViewControlling {
    let bubble = UILabel(), to = UILabel()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.96, alpha: 1)
        to.font = .systemFont(ofSize: 13, weight: .semibold); to.textColor = .secondaryLabel
        bubble.font = .systemFont(ofSize: 17); bubble.textColor = .white; bubble.numberOfLines = 0; bubble.textAlignment = .center
        bubble.backgroundColor = UIColor(red: 0.42, green: 0.25, blue: 0.13, alpha: 1); bubble.layer.cornerRadius = 18; bubble.clipsToBounds = true
        view.addSubview(to); view.addSubview(bubble)
    }
    func configureView(for parameters: Set<INParameter>, of interaction: INInteraction, interactiveBehavior: INUIInteractiveBehavior,
                       context: INUIHostedViewContext, completion: @escaping (Bool, Set<INParameter>, CGSize) -> Void) {
        guard let m = interaction.intent as? INSendMessageIntent else { completion(false, [], .zero); return }
        to.text = "☕︎ To " + (m.recipients ?? []).map { $0.displayName }.joined(separator: ", ")
        bubble.text = m.content
        let w = view.bounds.width > 0 ? view.bounds.width : 358
        to.frame = CGRect(x: 14, y: 10, width: w - 28, height: 18)
        bubble.frame = CGRect(x: 14, y: 34, width: w - 28, height: 44)
        NSLog("HelloSiri: Intents UI configured for “%@”", m.content ?? "")
        completion(true, parameters, CGSize(width: w, height: 90))
    }
}
