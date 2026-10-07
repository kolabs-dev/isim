// Sample: drag and drop on isim — a UIDragInteraction source, a UIDropInteraction target that loads the dropped
// string, a UITableView reordered by dragging (dragDelegate/dropDelegate + the data source's move) that also accepts
// dropped text (performDrop inserts a row), and SwiftUI's .draggable / .dropDestination. Long press (0.5 s) lifts.
import UIKit
import SwiftUI

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = DragDropViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

struct SwiftUIDrops: View {
    @State var dropped: [String] = []
    @State var targeted = false
    var body: some View {
        VStack(spacing: 16) {
            Text("SwiftUI tag").padding(10).background(Color.orange.opacity(0.3)).draggable("SwiftUI tag").accessibilityIdentifier("swiftui-source")
            RoundedRectangle(cornerRadius: 12).fill(targeted ? Color.green.opacity(0.4) : Color.gray.opacity(0.2))
                .frame(height: 100)
                .overlay(Text(dropped.isEmpty ? "Drop here" : dropped.joined(separator: ", ")))
                .dropDestination(for: String.self, action: { items, _ in dropped += items; print("swiftui dropped \(items)"); return true },
                                 isTargeted: { targeted = $0 })
                .accessibilityIdentifier("swiftui-target")
        }
    }
}

final class DragDropViewController: UIViewController, UIDragInteractionDelegate, UIDropInteractionDelegate,
                                    UITableViewDataSource, UITableViewDragDelegate, UITableViewDropDelegate {
    let source = UILabel(), zone = UILabel(), table = UITableView(frame: .zero, style: .plain)
    var rows = ["A", "B", "C", "D"]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        source.text = "Swift"
        source.textAlignment = .center
        source.backgroundColor = .systemBlue.withAlphaComponent(0.2)
        source.isUserInteractionEnabled = true
        source.frame = CGRect(x: 20, y: 80, width: 150, height: 50)
        source.accessibilityIdentifier = "source"
        source.addInteraction(UIDragInteraction(delegate: self))
        zone.text = "Drop zone"
        zone.textAlignment = .center
        zone.backgroundColor = .systemGray5
        zone.isUserInteractionEnabled = true
        zone.frame = CGRect(x: 210, y: 80, width: 172, height: 100)
        zone.accessibilityIdentifier = "zone"
        zone.addInteraction(UIDropInteraction(delegate: self))
        table.frame = CGRect(x: 20, y: 200, width: view.bounds.width - 40, height: 220)
        table.dataSource = self
        table.dragDelegate = self
        table.dropDelegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        table.accessibilityIdentifier = "table"
        [source, zone, table].forEach(view.addSubview)
        let host = UIHostingController(rootView: SwiftUIDrops())
        addChild(host)
        host.view.frame = CGRect(x: 20, y: 440, width: view.bounds.width - 40, height: 200)
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    // MARK: drag source
    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        print("drag begins from source")
        let item = UIDragItem(itemProvider: NSItemProvider(object: "Swift" as NSString))
        item.localObject = "local"
        return [item]
    }
    func dragInteraction(_ interaction: UIDragInteraction, session: UIDragSession, didEndWith operation: UIDropOperation) {
        print("drag ended with \(operation == .copy ? "copy" : operation == .move ? "move" : "cancel")")
    }

    // MARK: drop target
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool { session.canLoadObjects(ofClass: String.self) }
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) { zone.backgroundColor = .systemGreen.withAlphaComponent(0.3); print("zone entered") }
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) { zone.backgroundColor = .systemGray5 }
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal { UIDropProposal(operation: .copy) }
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        let p = session.location(in: zone)
        session.loadObjects(ofClass: String.self) { [weak self] strings in
            self?.zone.text = strings.joined()
            print(String(format: "dropped: %@ at %.0f,%.0f", strings.joined(separator: ","), p.x, p.y))
        }
    }

    // MARK: table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        c.textLabel?.text = rows[indexPath.row]
        c.accessibilityIdentifier = "row-\(rows[indexPath.row])"
        return c
    }
    func tableView(_ tableView: UITableView, moveRowAt s: IndexPath, to d: IndexPath) {
        let r = rows.remove(at: s.row); rows.insert(r, at: d.row)
        print("order: \(rows.joined(separator: " "))")
    }
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        print("row drag begins: \(rows[indexPath.row])")
        let item = UIDragItem(itemProvider: NSItemProvider(object: rows[indexPath.row] as NSString))
        item.localObject = rows[indexPath.row]
        return [item]
    }
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        UITableViewDropProposal(operation: session.localDragSession != nil && tableView.hasActiveDrag ? .move : .copy, intent: .insertAtDestinationIndexPath)
    }
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        let dest = coordinator.destinationIndexPath ?? IndexPath(row: rows.count, section: 0)
        coordinator.session.loadObjects(ofClass: String.self) { [weak self] strings in
            guard let self else { return }
            self.rows.insert(contentsOf: strings, at: min(dest.row, self.rows.count))
            tableView.reloadData()
            print("inserted \(strings.joined()) at \(dest.row): \(self.rows.joined(separator: " "))")
        }
    }
}
