// Sample: text blocks and tables in attributed strings on isim (UIKit) — NSTextTable / NSTextTableBlock cells with
// borders, padding, backgrounds, a header row, a cell spanning two columns, a percentage column width, vertical
// alignment, and an NSTextBlock quote with a leading border; shown by a UILabel and drawn by NSAttributedString.draw(in:)
// in a custom view, with boundingRect.
import UIKit

func log(_ s: String) { print("htt \(s)") }

/// a paragraph in the given blocks (outermost first)
func paragraph(_ text: String, _ blocks: [NSTextBlock], bold: Bool = false, align: NSTextAlignment = .natural) -> NSAttributedString {
    let ps = NSMutableParagraphStyle()
    ps.textBlocks = blocks
    ps.alignment = align
    return NSAttributedString(string: text + "\n", attributes: [.paragraphStyle: ps, .font: UIFont.systemFont(ofSize: 15, weight: bold ? .semibold : .regular)])
}

func scoreTable() -> NSAttributedString {
    let table = NSTextTable()
    table.numberOfColumns = 3
    table.collapsesBorders = true
    table.setWidth(1, type: .absolute, for: .border)
    table.setBorderColor(.separator)
    func cell(_ row: Int, _ col: Int, span: Int = 1) -> NSTextTableBlock {
        let b = NSTextTableBlock(table: table, startingRow: row, rowSpan: 1, startingColumn: col, columnSpan: span)
        b.setWidth(1, type: .absolute, for: .border)
        b.setBorderColor(.separator)
        b.setWidth(6, type: .absolute, for: .padding)
        if row == 0 { b.backgroundColor = .systemGray5 }
        b.verticalAlignment = .middle
        return b
    }
    let s = NSMutableAttributedString()
    let first = cell(0, 0)
    first.setContentWidth(40, type: .percentage)          // the first column takes 40% of the table
    s.append(paragraph("Team", [first], bold: true))
    s.append(paragraph("Won", [cell(0, 1)], bold: true, align: .center))
    s.append(paragraph("Lost", [cell(0, 2)], bold: true, align: .center))
    for (r, (team, won, lost)) in [("Lisbon", "12", "3"), ("Porto", "10", "5"), ("Braga", "7", "8")].enumerated() {
        s.append(paragraph(team, [cell(r + 1, 0)]))
        s.append(paragraph(won, [cell(r + 1, 1)], align: .center))
        s.append(paragraph(lost, [cell(r + 1, 2)], align: .center))
    }
    let foot = cell(4, 0, span: 3)
    foot.backgroundColor = .systemYellow.withAlphaComponent(0.3)
    s.append(paragraph("Updated after round 15", [foot], align: .center))
    return s
}

func quote() -> NSAttributedString {
    let q = NSTextBlock()
    q.setWidth(10, type: .absolute, for: .padding)
    if #available(iOS 27, *) {                            // per-edge widths and colours are iOS 27
        q.setWidth(4, type: .absolute, for: .border, rectEdge: .minXEdge)
        q.setBorderColor(.systemBlue, rectEdge: .minXEdge)
        q.setWidth(8, type: .absolute, for: .margin, rectEdge: .minYEdge)
    } else {
        q.setWidth(1, type: .absolute, for: .border)
        q.setBorderColor(.systemBlue)
    }
    q.backgroundColor = .systemBlue.withAlphaComponent(0.1)
    return paragraph("Tables come from NSTextTable, NSTextTableBlock and NSParagraphStyle.textBlocks.", [q])
}

final class DrawnView: UIView {
    var text = NSAttributedString()
    override func draw(_ rect: CGRect) { text.draw(in: bounds) }
}

final class ViewController: UIViewController {
    override func viewDidLoad() {
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Standings"; title.font = .boldSystemFont(ofSize: 28)
        let label = UILabel()
        label.numberOfLines = 0
        let text = NSMutableAttributedString(attributedString: scoreTable())
        text.append(quote())
        label.attributedText = text
        label.accessibilityIdentifier = "table-label"
        let drawn = DrawnView()
        drawn.backgroundColor = .clear
        drawn.text = scoreTable()
        drawn.accessibilityIdentifier = "drawn-table"
        let stack = UIStackView(arrangedSubviews: [title, label, drawn])
        stack.axis = .vertical; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let bound = drawn.text.boundingRect(with: CGSize(width: 300, height: 1000), options: .usesLineFragmentOrigin, context: nil)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            drawn.heightAnchor.constraint(equalToConstant: ceil(bound.height)),
        ])
        let ps = text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        let cell = ps?.textBlocks.first as? NSTextTableBlock
        log("cell row \(cell?.startingRow ?? -1) column \(cell?.startingColumn ?? -1) columns \(cell?.table.numberOfColumns ?? 0) width \(Int(cell?.contentWidth ?? 0))% percentage \(cell?.contentWidthValueType == .percentage)")
        log("bounding \(Int(bound.width))x\(Int(bound.height))")
        let copy = ps?.copy() as? NSParagraphStyle
        log("copy keeps blocks \(copy?.textBlocks.first === cell)")
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
