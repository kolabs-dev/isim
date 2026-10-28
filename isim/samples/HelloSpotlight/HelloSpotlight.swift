// Sample: CoreSpotlight (issue #412). A notes app ("Notes Index") that indexes its notes with Apple's attributes and a
// custom one in a batch with a client state, searches them with CSSearchQuery (Spotlight's query language) and, on
// iOS 18, CSUserQuery (what the user types, with suggestions and engagement); its index delegate reindexes when
// Spotlight asks (`isim spotlight reindex APP`) and gets the summaries Spotlight makes. Its index extension
// (IndexExtension/) does the same while the app is not running, and its import extension (ImportExtension/) fills in
// the attributes of .spnote documents written to Documents. Every step is logged ("sp ...").
import UIKit
import CoreSpotlight

func log(_ s: String) { NSLog("sp %@", s) }

final class IndexDelegate: NSObject, CSSearchableIndexDelegate {
    func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        log("delegate reindex all")
        searchableIndex.indexSearchableItems(notes.map(searchableItem)) { _ in acknowledgementHandler() }
    }
    func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        log("delegate reindex \(identifiers.joined(separator: ","))")
        searchableIndex.indexSearchableItems(notes.filter { identifiers.contains($0.id) }.map(searchableItem)) { _ in acknowledgementHandler() }
    }
    func searchableIndexDidThrottle(_ searchableIndex: CSSearchableIndex) { log("delegate throttled") }
    func searchableIndexDidFinishThrottle(_ searchableIndex: CSSearchableIndex) { log("delegate finished throttling") }
    func searchableItemsDidUpdate(_ items: [CSSearchableItem]) {
        for i in items.sorted(by: { $0.uniqueIdentifier < $1.uniqueIdentifier }) {
            log("delegate updated \(i.uniqueIdentifier) summary: \(i.attributeSet.textContentSummary ?? "-")")
        }
    }
    func searchableItems(forIdentifiers identifiers: [String], searchableItemsHandler: @escaping ([CSSearchableItem]) -> Void) {
        log("delegate items \(identifiers.joined(separator: ","))")
        searchableItemsHandler(notes.filter { identifiers.contains($0.id) }.map(searchableItem))
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: NotesViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class NotesViewController: UIViewController {
    let index = CSSearchableIndex(name: "notes", protectionClass: .completeUntilFirstUserAuthentication)
    let delegate = IndexDelegate()
    let status = UILabel()
    var query: CSSearchQuery?
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notes Index"
        view.backgroundColor = .systemBackground
        index.indexDelegate = delegate
        var y: CGFloat = 110
        for (id, t) in [("index", "Index Notes"), ("query", "Search: coffee"), ("filters", "Search: rated, recent"), ("bad", "Bad Query"),
                        ("user", "User Query: “co”"), ("update", "Update Rating"), ("document", "Write Document"), ("remove", "Delete Everything")] {
            let b = UIButton(type: .system)
            b.setTitle(t, for: .normal)
            b.frame = CGRect(x: 20, y: y, width: 300, height: 36)
            b.contentHorizontalAlignment = .left
            b.accessibilityIdentifier = id
            b.addAction(UIAction { [weak self] _ in self?.tap(id) }, for: .primaryActionTriggered)
            view.addSubview(b)
            y += 44
        }
        status.frame = CGRect(x: 20, y: y + 10, width: view.bounds.width - 40, height: 120)
        status.numberOfLines = 0
        status.accessibilityIdentifier = "status"
        status.text = "Ready"
        view.addSubview(status)
        log("launched available=\(CSSearchableIndex.isIndexingAvailable())")
    }
    func show(_ s: String) { DispatchQueue.main.async { self.status.text = s }; log(s) }

    func search(_ q: String, fetch: [String], filters: [String] = []) {
        let ctx = CSSearchQueryContext()
        ctx.fetchAttributes = fetch
        ctx.filterQueries = filters
        let query = CSSearchQuery(queryString: q, queryContext: ctx)
        var found: [CSSearchableItem] = []
        query.foundItemsHandler = { found += $0 }
        query.completionHandler = { [weak self] error in
            if let e = error as NSError? { self?.show("query error \(e.domain) \(e.code)"); return }
            let names = found.sorted { $0.uniqueIdentifier < $1.uniqueIdentifier }.map { "\($0.uniqueIdentifier) (\($0.attributeSet.title ?? "-"), \($0.attributeSet.rating ?? 0))" }
            self?.show("found \(query.foundItemCount): \(names.joined(separator: ", "))")
        }
        self.query = query
        query.start()
    }

    func tap(_ id: String) {
        switch id {
        case "index":
            index.beginBatch()
            index.indexSearchableItems(notes.map(searchableItem))
            index.endBatch(withClientState: Data("v1".utf8)) { [weak self] error in
                self?.index.fetchLastClientState { state, _ in
                    self?.show("indexed \(notes.count) notes, client state \(state.map { String(decoding: $0, as: UTF8.self) } ?? "-") error \(error.map { "\($0)" } ?? "none")")
                }
            }
        case "query":
            search(#"title == "*coffee*"cd || contentDescription == "*coffee*"cd"#, fetch: ["title", "rating"])
        case "filters":
            search(#"rating >= 4 && contentCreationDate > $time.today(-7)"#, fetch: ["title", "rating"], filters: [#"domainIdentifier == "notes""#])
        case "bad":
            search(#"title == "unclosed"#, fetch: [])
        case "user":
            guard #available(iOS 18.0, *) else { show("user queries need iOS 18"); return }
            Task { await userQuery() }
        case "update":
            let a = CSSearchableItemAttributeSet(contentType: .text)
            a.rating = 2
            let item = CSSearchableItem(uniqueIdentifier: "note-trip", domainIdentifier: "notes", attributeSet: a)
            item.isUpdate = true
            index.indexSearchableItems([item]) { [weak self] _ in self?.search(#"title == "Trip*""#, fetch: ["title", "rating"]) }
        case "document":
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? "Packing list\nPassport, charger, a good book. #travel #lisbon\n".write(to: docs.appendingPathComponent("packing.spnote"), atomically: true, encoding: .utf8)
            show("wrote packing.spnote")
        case "remove":
            index.deleteAllSearchableItems { [weak self] _ in self?.show("deleted everything") }
        default: break
        }
    }

    @available(iOS 18.0, *)
    func userQuery() async {
        let ctx = CSUserQueryContext()
        ctx.fetchAttributes = ["title"]
        ctx.maxSuggestionCount = 3
        ctx.enableRankedResults = true
        let q = CSUserQuery(userQueryString: "co", userQueryContext: ctx)
        var items: [CSUserQuery.Item] = [], suggestions: [String] = []
        do {
            for try await r in q.responses {
                switch r {
                case .item(let i): items.append(i)
                case .suggestion(let s): suggestions.append(String(s.suggestion.localizedAttributedSuggestion.characters))
                @unknown default: break
                }
            }
        } catch { show("user query error \(error)"); return }
        if let first = items.first { q.userEngaged(first, visibleItems: items, interaction: .select) }
        show("user query: \(items.map(\.item.uniqueIdentifier).joined(separator: ", ")); suggestions: \(suggestions.joined(separator: ", "))")
    }
}
