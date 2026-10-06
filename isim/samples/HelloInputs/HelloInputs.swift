// Sample: UIKit input controls on isim — UITextView (scrolling and self-sizing, delegate), UIPickerView,
// UIDatePicker (wheels, compact, inline, count-down timer), UIColorWell, UISearchBar / UISearchController,
// UIRefreshControl and UIAppearance proxies.
import UIKit

let start = Date(timeIntervalSince1970: 1773481260)      // 2026-03-14 09:41 UTC

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // appearance proxies: every navigation bar gets an orange tint; switches inside the pickers page are purple
        UINavigationBar.appearance().tintColor = .systemOrange
        UISwitch.appearance(whenContainedInInstancesOf: [PickersViewController.self]).onTintColor = .systemPurple
        let text = UINavigationController(rootViewController: TextViewController())
        text.tabBarItem = UITabBarItem(title: "Text", image: UIImage(systemName: "doc.text"), tag: 0)
        let pickers = UINavigationController(rootViewController: PickersViewController())
        pickers.tabBarItem = UITabBarItem(title: "Pickers", image: UIImage(systemName: "calendar"), tag: 1)
        let list = UINavigationController(rootViewController: ListViewController())
        list.tabBarItem = UITabBarItem(title: "List", image: UIImage(systemName: "list.bullet"), tag: 2)
        let tabs = UITabBarController()
        tabs.viewControllers = [text, pickers, list]
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = tabs
        window?.makeKeyAndVisible()
        return true
    }
}

// MARK: - Text
final class TextViewController: UIViewController, UITextViewDelegate {
    let notes = UITextView()
    let bio = UITextView()
    let counter = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Text"
        view.backgroundColor = .systemGroupedBackground
        bio.font = .systemFont(ofSize: 17)
        bio.isScrollEnabled = false
        bio.text = "Self-sizing bio"
        bio.layer.cornerRadius = 10
        bio.accessibilityIdentifier = "bio"
        bio.delegate = self
        counter.font = .systemFont(ofSize: 13)
        counter.textColor = .secondaryLabel
        counter.text = "\(bio.text.count) characters"
        counter.accessibilityIdentifier = "counter"
        notes.font = .systemFont(ofSize: 17)
        notes.text = (1...30).map { "Line \($0) of the notes" }.joined(separator: "\n")
        notes.layer.cornerRadius = 10
        notes.accessibilityIdentifier = "notes"
        notes.delegate = self
        let stack = UIStackView(arrangedSubviews: [bio, counter, notes])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            notes.heightAnchor.constraint(equalToConstant: 220),
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(done))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "text-done"
    }
    @objc func done() { view.endEditing(true) }

    func textViewDidBeginEditing(_ textView: UITextView) { print("begin \(textView.accessibilityIdentifier ?? "?")") }
    func textViewDidEndEditing(_ textView: UITextView) { print("end \(textView.accessibilityIdentifier ?? "?")") }
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "#" { print("blocked #"); return false }
        return true
    }
    func textViewDidChange(_ textView: UITextView) {
        counter.text = "\(bio.text.count) characters"
        print("changed \(textView.accessibilityIdentifier ?? "?"): \(textView.text.count) chars, caret \(textView.selectedRange.location)")
        if textView === notes, let line = textView.text.split(separator: "\n").first(where: { $0.contains("X") }) { print("notes line: \(line)") }
    }
}

// MARK: - Pickers
final class PickersViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    let fruits = ["Apple", "Banana", "Cherry", "Grape", "Lemon", "Mango", "Orange", "Peach", "Pear", "Plum"]
    let picker = UIPickerView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Pickers"
        view.backgroundColor = .systemBackground
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.accessibilityIdentifier = "pickers-scroll"
        view.addSubview(scroll)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor), scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
        ])
        picker.dataSource = self
        picker.delegate = self
        picker.accessibilityIdentifier = "fruit-picker"
        picker.selectRow(2, inComponent: 0, animated: false)
        stack.addArrangedSubview(caption("Fruit"))
        stack.addArrangedSubview(picker)

        let compact = datePicker("compact", mode: .dateAndTime, style: .compact)
        let row = UIStackView(arrangedSubviews: [caption("Starts"), compact])
        row.axis = .horizontal
        row.alignment = .center
        stack.addArrangedSubview(row)
        stack.addArrangedSubview(caption("Birthday"))
        stack.addArrangedSubview(datePicker("wheels", mode: .date, style: .wheels))
        stack.addArrangedSubview(caption("Calendar"))
        stack.addArrangedSubview(datePicker("inline", mode: .date, style: .inline))
        stack.addArrangedSubview(caption("Alarm"))
        stack.addArrangedSubview(datePicker("time", mode: .time, style: .wheels))
        let well = UIColorWell()
        well.title = "Accent"
        well.selectedColor = .systemTeal
        well.accessibilityIdentifier = "well"
        well.addAction(UIAction { [weak well] _ in print("well color \(well?.selectedColor.map { hexString($0) } ?? "nil")") }, for: .valueChanged)
        let toggle = UISwitch()
        toggle.isOn = true
        toggle.accessibilityIdentifier = "purple-switch"
        toggle.tag = 7
        let wellRow = UIStackView(arrangedSubviews: [caption("Accent"), UIView(), toggle, well])
        wellRow.axis = .horizontal
        wellRow.alignment = .center
        wellRow.spacing = 12
        stack.insertArrangedSubview(wellRow, at: 0)
        let timer = datePicker("countdown", mode: .countDownTimer, style: .wheels)
        timer.countDownDuration = 25 * 60
        stack.addArrangedSubview(caption("Timer"))
        stack.addArrangedSubview(timer)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let toggle = view.viewWithTag(7) as? UISwitch
        print("appearance: nav tint \(hexString(navigationController!.navigationBar.tintColor)), switch \(toggle?.onTintColor.map { hexString($0) } ?? "nil")")
    }
    func caption(_ s: String) -> UILabel {
        let l = UILabel()
        l.text = s
        l.font = .preferredFont(forTextStyle: .headline)
        return l
    }
    func datePicker(_ id: String, mode: UIDatePicker.Mode, style: UIDatePickerStyle) -> UIDatePicker {
        let p = UIDatePicker()
        p.datePickerMode = mode
        p.preferredDatePickerStyle = style
        p.date = start
        p.accessibilityIdentifier = id
        p.addAction(UIAction { [weak p] _ in
            guard let p else { return }
            if mode == .countDownTimer { print("date \(id) countdown \(Int(p.countDownDuration))") }
            else { print("date \(id) \(Int(p.date.timeIntervalSince1970))") }
        }, for: .valueChanged)
        return p
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { component == 0 ? fruits.count : 20 }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { component == 0 ? fruits[row] : "\(row + 1)" }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        print("picked \(fruits[pickerView.selectedRow(inComponent: 0)]) x\(pickerView.selectedRow(inComponent: 1) + 1)")
    }
}

func hexString(_ c: UIColor) -> String {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    c.getRed(&r, green: &g, blue: &b, alpha: &a)
    return String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
}

// MARK: - List (search controller, pull to refresh)
final class ListViewController: UITableViewController, UISearchResultsUpdating, UISearchBarDelegate {
    let all = ["Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado", "Connecticut", "Delaware", "Florida", "Georgia",
               "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky", "Louisiana", "Maine", "Maryland"]
    var shown: [String] = []
    var refreshes = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "States"
        navigationController?.navigationBar.prefersLargeTitles = true
        shown = all
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        let search = UISearchController(searchResultsController: nil)
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Search States"
        search.searchBar.delegate = self
        navigationItem.searchController = search
        let refresh = UIRefreshControl()
        refresh.addAction(UIAction { [weak self] _ in self?.reload() }, for: .valueChanged)
        refreshControl = refresh
    }
    func reload() {
        refreshes += 1
        print("refreshing \(refreshes)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.refreshControl?.endRefreshing()
            print("refreshed \(self.refreshes), refreshing \(self.refreshControl?.isRefreshing == true)")
        }
    }
    func updateSearchResults(for searchController: UISearchController) {
        let q = searchController.searchBar.text ?? ""
        shown = q.isEmpty ? all : all.filter { $0.lowercased().hasPrefix(q.lowercased()) }
        tableView.reloadData()
        print("search '\(q)' active \(searchController.isActive): \(shown.count) results")
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) { print("search cancelled") }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { shown.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var c = cell.defaultContentConfiguration()
        c.text = shown[indexPath.row]
        cell.contentConfiguration = c
        cell.accessibilityIdentifier = "state-\(shown[indexPath.row])"
        return cell
    }
}
