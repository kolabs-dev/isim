import UIKit

final class NoteDetailViewController: UIViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bodyLabel: UILabel!
    var note: Note?
    weak var info: InfoViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = note?.title
        bodyLabel.text = note?.body
        print("detail: viewDidLoad \(note?.title ?? "nil") children=\(children.map { String(describing: type(of: $0)) })")
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("detail: prepare \(segue.identifier ?? "nil") -> \(type(of: segue.destination))")
        if let info = segue.destination as? InfoViewController {       // embed segue
            info.text = "Embedded: \(note?.title ?? "?")"
            self.info = info
        }
        if let more = segue.destination as? MoreViewController { more.message = "More about \(note?.title ?? "?")" }
    }

    @IBAction func showMore(_ sender: UIButton) {
        performSegue(withIdentifier: "showMore", sender: sender)
    }
}

final class InfoViewController: UIViewController {
    @IBOutlet weak var infoLabel: UILabel!
    var text = ""
    override func viewDidLoad() {
        super.viewDidLoad()
        infoLabel.text = text
        print("info: viewDidLoad parent=\(parent.map { String(describing: type(of: $0)) } ?? "nil") text=\(text)")
    }
}

final class MoreViewController: UIViewController {
    @IBOutlet weak var messageLabel: UILabel!
    var message = "More"
    override func viewDidLoad() {
        super.viewDidLoad()
        messageLabel.text = message
        print("more: viewDidLoad id-instantiable=\(storyboard?.instantiateViewController(withIdentifier: "MoreVC") is MoreViewController)")
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("more: label font \(Int(messageLabel.font.pointSize)), badge \(view.subviews.contains { $0.accessibilityIdentifier == "more-compact-badge" } ? "installed" : "not installed")")
    }
    /// @IBSegueAction: the "Make" segue's destination is created here, with an initializer of our own
    @IBSegueAction func makeMade(_ coder: NSCoder, sender: Any?, segueIdentifier: String?) -> MadeViewController? {
        print("more: segue action \(segueIdentifier ?? "nil") from \(sender.map { String(describing: type(of: $0)) } ?? "nil")")
        return MadeViewController(coder: coder, note: message)
    }
}

final class MadeViewController: UIViewController {
    @IBOutlet weak var madeLabel: UILabel!
    let note: String
    init?(coder: NSCoder, note: String) { self.note = note; super.init(coder: coder) }
    required init?(coder: NSCoder) { note = "(storyboard default)"; super.init(coder: coder) }
    override func viewDidLoad() {
        super.viewDidLoad()
        madeLabel.text = "Made for \(note)"
        print("made: \(note)")
    }
}
