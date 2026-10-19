// Sample: cell configuration overrides on isim (issue #242) — Swift subclasses of UICollectionViewListCell,
// UITableViewCell and UITableViewHeaderFooterView override updateConfiguration(using:) (UIKit calls it before layout
// when the state changes), a cell adds a custom state by overriding configurationState, and
// configurationUpdateHandler gets the same UICellConfigurationState.
import UIKit

/// a copy changed in place (configurations are structs on iOS; isim's list configuration is a class)
func with<T>(_ value: T, _ change: (inout T) -> Void) -> T { var v = value; change(&v); return v }

extension UIConfigurationStateCustomKey {
    static let isArchived = UIConfigurationStateCustomKey("dev.isim.isArchived")
}

final class ArchivedCell: UICollectionViewListCell {
    var archived = false { didSet { setNeedsUpdateConfiguration() } }
    var title = ""
    override var configurationState: UICellConfigurationState {
        var state = super.configurationState
        state[.isArchived] = archived
        return state
    }
    override func updateConfiguration(using state: UICellConfigurationState) {
        contentConfiguration = with(defaultContentConfiguration().updated(for: state)) {
            $0.text = title + ((state[.isArchived] as? Bool) == true ? " (archived)" : "")
        }
        print("cv override \(title) selected=\(state.isSelected) archived=\((state[.isArchived] as? Bool) ?? false)")
    }
}

final class TableCell: UITableViewCell {
    override func updateConfiguration(using state: UICellConfigurationState) {
        contentConfiguration = with(defaultContentConfiguration()) { $0.text = "Table row" + (state.isSelected ? " (selected)" : "") }
        print("table override selected=\(state.isSelected) editing=\(state.isEditing)")
    }
}

final class Header: UITableViewHeaderFooterView {
    override func updateConfiguration(using state: UIViewConfigurationState) {
        print("header override disabled=\(state.isDisabled)")
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UITableViewDataSource, UITableViewDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = .systemGroupedBackground
        let h = UIScreen.main.bounds.height
        let cv = UICollectionView(frame: CGRect(x: 0, y: 60, width: UIScreen.main.bounds.width, height: h / 2 - 60),
                                  collectionViewLayout: UICollectionViewCompositionalLayout.list(using: .init(appearance: .insetGrouped)))
        cv.register(ArchivedCell.self, forCellWithReuseIdentifier: "c")
        cv.dataSource = self; cv.delegate = self
        cv.accessibilityIdentifier = "cv"
        vc.view.addSubview(cv)
        let tv = UITableView(frame: CGRect(x: 0, y: h / 2, width: UIScreen.main.bounds.width, height: h / 2), style: .insetGrouped)
        tv.register(TableCell.self, forCellReuseIdentifier: "t")
        tv.register(Header.self, forHeaderFooterViewReuseIdentifier: "h")
        tv.dataSource = self; tv.delegate = self
        tv.accessibilityIdentifier = "tv"
        vc.view.addSubview(tv)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        return true
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 2 }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let c = collectionView.dequeueReusableCell(withReuseIdentifier: "c", for: indexPath) as! ArchivedCell
        c.title = ["Inbox", "Old mail"][indexPath.item]
        c.archived = indexPath.item == 1
        c.accessibilityIdentifier = "item\(indexPath.item)"
        if indexPath.item == 0 {
            c.configurationUpdateHandler = { cell, state in print("cv handler selected=\(state.isSelected)") }
        }
        return c
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "t", for: indexPath)
        c.accessibilityIdentifier = "row0"
        return c
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        tableView.dequeueReusableHeaderFooterView(withIdentifier: "h")
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 30 }
}
