import UIKit

struct Note { var title: String; var body: String }

/// Prototype cell from Main.storyboard (custom class, outlets to its labels).
final class NoteCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var starView: UIImageView!
    static var awoken = 0
    override func awakeFromNib() {
        super.awakeFromNib()
        NoteCell.awoken += 1
    }
}

/// Cell from BadgeCell.xib, registered with UINib.
final class BadgeCell: UITableViewCell {
    @IBOutlet weak var badgeLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        badgeLabel.layer.cornerRadius = 6
    }
}

final class NotesViewController: UITableViewController {
    var notes = [Note(title: "Groceries", body: "Milk, eggs, bread"), Note(title: "Ideas", body: "Storyboards on Linux")]
    var awoke = false

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        print("notes: init(coder:) title=\(title ?? "nil")")
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        awoke = true
        print("notes: awakeFromNib navigationItem=\(navigationItem.title ?? "nil") tab=\(navigationController?.tabBarItem.title ?? "-")")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "BadgeCell", bundle: nil), forCellReuseIdentifier: "BadgeCell")
        let loaded = Bundle.main.loadNibNamed("BadgeCell", owner: nil, options: nil) ?? []
        print("notes: viewDidLoad tableView=\(type(of: tableView!)) dataSource=\(tableView.dataSource === self) "
              + "storyboard=\(storyboard != nil) nib objects=\(loaded.count) first=\(loaded.first.map { String(describing: type(of: $0)) } ?? "nil")")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? notes.count : 1
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Notes", "Pinned", "About"][section]
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath) as! NoteCell
            cell.titleLabel.text = notes[indexPath.row].title
            cell.detailLabel.text = notes[indexPath.row].body
            cell.accessibilityIdentifier = "note-\(indexPath.row)"
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "BadgeCell", for: indexPath) as! BadgeCell
            cell.badgeLabel.text = "Pinned from a xib"
            cell.accessibilityIdentifier = "badge-cell"
            return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "BasicCell", for: indexPath)
            cell.textLabel?.text = "Storyboard prototype"
            cell.detailTextLabel?.text = "Subtitle style"
            cell.accessibilityIdentifier = "basic-cell"
            return cell
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("notes: prepare \(segue.identifier ?? "nil") -> \(type(of: segue.destination)) sender=\(sender.map { String(describing: type(of: $0)) } ?? "nil")")
        if segue.identifier == "showNote", let detail = segue.destination as? NoteDetailViewController,
           let row = tableView.indexPathForSelectedRow?.row {
            detail.note = notes[row]
        }
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        print("notes: shouldPerformSegue \(identifier)")
        return true
    }

    @IBAction func resetNotes(_ sender: Any) {
        notes = [Note(title: "Groceries", body: "Milk, eggs, bread")]
        tableView.reloadData()
        print("notes: reset -> \(notes.count)")
    }

    /// Unwind target for Compose's Cancel/Save and Detail's Done.
    @IBAction func unwindToNotes(_ segue: UIStoryboardSegue) {
        print("notes: unwind \(segue.identifier ?? "nil") from \(type(of: segue.source))")
        if segue.identifier == "saveUnwind", let compose = segue.source as? ComposeViewController {
            let title = compose.titleField.text ?? ""
            notes.append(Note(title: title.isEmpty ? "Untitled" : title, body: "Added with an unwind segue"))
            tableView.reloadData()
            print("notes: saved \"\(title)\" -> \(notes.count) notes")
        }
    }
}

final class ComposeViewController: UIViewController {
    @IBOutlet weak var titleField: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        print("compose: viewDidLoad field=\(titleField != nil) placeholder=\(titleField?.placeholder ?? "nil")")
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("compose: prepare \(segue.identifier ?? "nil") -> \(type(of: segue.destination))")
    }
}
