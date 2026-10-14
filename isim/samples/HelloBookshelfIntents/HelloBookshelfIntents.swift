// Sample: App Intents beyond parameters (issue #230): a book entity with @Property values and an EntityPropertyQuery
// (Shortcuts' "Find Books where …"), parameter summaries (Summary, When), a DynamicOptionsProvider with an
// IntentItemCollection, @Dependency from AppDependencyManager, AppIntentError, and IntentPerson / IntentFile /
// IntentCurrencyAmount parameters and results. The system runs them (Siri, Shortcuts; the test drives requests).
import SwiftUI
import AppIntents

// MARK: the app's own model, shared with the intents through AppDependencyManager

final class Library: @unchecked Sendable {
    let books: [BookEntity] = [
        BookEntity(id: "1", title: "Swift Basics", author: "Ana Lima", pages: 180),
        BookEntity(id: "2", title: "Advanced Swift", author: "Bo Chen", pages: 520),
        BookEntity(id: "3", title: "Gardening", author: "Cy Diaz", pages: 240),
    ]
    var shelves: [String: [String]] = [:]
    var loans: [String] = []
    func shelve(_ book: BookEntity, on shelf: String) { shelves[shelf, default: []].append(book.title) }
}

// MARK: entities

struct BookEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Book" }
    static var defaultQuery: BookQuery { BookQuery() }
    let id: String
    @Property(title: "Title") var title: String
    @Property(title: "Author") var author: String
    @Property(title: "Pages") var pages: Int
    init(id: String, title: String, author: String, pages: Int) {
        self.id = id; self.title = title; self.author = author; self.pages = pages
    }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)", subtitle: "\(author)") }
    @available(iOS 26.0, *)
    @ComputedProperty(title: "Summary") var summary: String { "\(title) by \(author)" }
}

/// "Find Books where Title contains … and Pages is less than …, sorted by Pages"
struct BookQuery: EntityPropertyQuery {
    typealias ComparatorMappingType = (BookEntity) -> Bool
    @Dependency var library: Library
    static var properties = QueryProperties {
        Property(\BookEntity.$title) {
            EqualToComparator { v in { $0.title == v } }
            ContainsComparator { v in { $0.title.localizedCaseInsensitiveContains(v) } }
            HasPrefixComparator { v in { $0.title.hasPrefix(v) } }
        }
        Property(\BookEntity.$pages) {
            LessThanComparator { v in { $0.pages < v } }
            GreaterThanComparator { v in { $0.pages > v } }
        }
    }
    static var sortingOptions = SortingOptions {
        SortableBy(\BookEntity.$title)
        SortableBy(\BookEntity.$pages)
    }
    func entities(for identifiers: [String]) async throws -> [BookEntity] { library.books.filter { identifiers.contains($0.id) } }
    func suggestedEntities() async throws -> [BookEntity] { library.books }
    func entities(matching comparators: [(BookEntity) -> Bool], mode: ComparatorMode, sortedBy: [EntityQuerySort<BookEntity>],
                  limit: Int?) async throws -> [BookEntity] {
        var found = library.books.filter { b in mode == .and ? comparators.allSatisfy { $0(b) } : comparators.contains { $0(b) } }
        for s in sortedBy.reversed() {
            if s.by == \BookEntity.$pages { found.sort { s.order == .ascending ? $0.pages < $1.pages : $0.pages > $1.pages } }
            else { found.sort { s.order == .ascending ? $0.title < $1.title : $0.title > $1.title } }
        }
        return Array(found.prefix(limit ?? found.count))
    }
}

// MARK: dynamic options

struct ShelfOptions: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<String> {
        IntentItemCollection(promptLabel: "Pick a shelf") {
            IntentItemSection<String>("Mine") {
                IntentItem("Favorites", title: "Favorites", subtitle: "the best ones")
                IntentItem("To Read")
            }
            IntentItemSection("Shared", items: ["Book Club"])
        }
    }
}

// MARK: intents

struct OpenBookIntent: AppIntent {
    static var title: LocalizedStringResource { "Open Book" }
    @Parameter(title: "Book") var book: BookEntity
    static var parameterSummary: some ParameterSummary { Summary("Open \(\.$book)") }
    func perform() async throws -> some IntentResult & ProvidesDialog { .result(dialog: "Opening \(book.title).") }
}

struct ShelveBookIntent: AppIntent {
    static var title: LocalizedStringResource { "Shelve Book" }
    @Parameter(title: "Book") var book: BookEntity
    @Parameter(title: "Shelf", optionsProvider: ShelfOptions()) var shelf: String
    @Parameter(title: "Note", default: "") var note: String
    @Dependency var library: Library
    static var parameterSummary: some ParameterSummary {
        When(\.$shelf, .equalTo, "Favorites") {
            Summary("Favorite \(\.$book)")
        } otherwise: {
            Summary("Put \(\.$book) on \(\.$shelf)") { \.$note }
        }
    }
    func perform() async throws -> some IntentResult & ProvidesDialog {
        library.shelve(book, on: shelf)
        return .result(dialog: "\(book.title) is on \(shelf) (\(library.shelves[shelf]?.count ?? 0) there).")
    }
}

struct LendBookIntent: AppIntent {
    static var title: LocalizedStringResource { "Lend Book" }
    @Parameter(title: "Book") var book: BookEntity
    @Parameter(title: "Friend") var friend: IntentPerson
    @Parameter(title: "Deposit") var deposit: IntentCurrencyAmount
    @Dependency var library: Library
    static var parameterSummary: some ParameterSummary { Summary("Lend \(\.$book) to \(\.$friend)") { \.$deposit } }
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<IntentFile> {
        library.loans.append(book.title)
        var handle = "-"
        if case .emailAddress(let e)? = friend.handle?.value { handle = e }
        let slip = "\(book.title) lent to \(friend) (\(handle)) for \(deposit)"
        return .result(value: IntentFile(data: Data(slip.utf8), filename: "loan-slip.txt", type: .plainText),
                       dialog: "\(slip).")
    }
}

struct MissingBookIntent: AppIntent {
    static var title: LocalizedStringResource { "Find Missing Book" }
    @Dependency var library: Library
    func perform() async throws -> some IntentResult {
        guard library.books.contains(where: { $0.title == "The Lost Book" }) else { throw AppIntentError.Unrecoverable.entityNotFound }
        return .result()
    }
}

/// the library is not ready the first time: AppIntentError.restartPerform runs perform() again
struct SyncLibraryIntent: AppIntent {
    static var title: LocalizedStringResource { "Sync Library" }
    nonisolated(unsafe) static var attempts = 0
    func perform() async throws -> some IntentResult & ProvidesDialog {
        Self.attempts += 1
        if Self.attempts == 1 { throw AppIntentError.restartPerform }
        return .result(dialog: "Synced after \(Self.attempts) attempts.")
    }
}

// MARK: the app

@main
struct HelloBookshelfIntentsApp: App {
    @Dependency var library: Library
    init() {
        AppDependencyManager.shared.add(dependency: Library())
        print("bi dependency \(library.books.count) books"); fflush(stdout)
    }
    var body: some Scene {
        WindowGroup {
            List(library.books) { b in
                VStack(alignment: .leading) { Text(b.title).font(.headline); Text("\(b.author) · \(b.pages) pages").font(.caption) }
            }
        }
    }
}
