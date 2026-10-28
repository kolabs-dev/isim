# SwiftData

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 82.3% of Apple's iOS API (652 of 792, exact) · **Rows:** 13: 12 ✅ 1 ❌ · **iOS:** 17.0+
<!-- /generated:header -->

**Area:** [Data & persistence](../COVERAGE.md#data) · **Apple:** [SwiftData](https://developer.apple.com/documentation/swiftdata) · **Issues:** [`area:data`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Adata)

## How isim implements it

- **Approach:** isim's own Swift overlay, `isim/swift/overlays/SwiftData`, with a host compiler plugin for the macros (`isim/swift/macro-support/SwiftDataMacros.swift`).
  - `@Model` expands like Apple's: stored properties become accessors over the model's backing data (with observation), and `persistentBackingData`, `schemaMetadata` and `init(backingData:)` are generated.
  - Models are stored in an **SQLite store on disk** (`Store.swift`, the SQLite isim's Core Data uses) at `ModelConfiguration.url`: by default `default.store` in the app's Application Support. Each entity has a table; each row holds a model's primary key and its values as JSON (attributes as their Codable encoding, relationships as primary keys). `isStoredInMemoryOnly` keeps an in-memory database.
- **Adapted:**
  - fetches load the entity's rows and evaluate the predicate and sort in Swift (Apple translates them to SQL);
  - an upsert takes the relationships of the stored model when the new one leaves them empty.
- **Unlike Apple's macro**, a property an initializer leaves unset is not a compile error: it is found when read (its default value, or `nil`). The compiler gives macro-made init accessors no implicit `= nil`, so optionals would otherwise have to be set in every initializer.
- **Migration** (`Migration.swift`): the store records its schema version; a container opened with a migration plan runs the plan's stages from that version. Lightweight changes need no rewrite in isim's JSON rows: added properties take their defaults, removed ones are dropped, and `originalName` reads a renamed property (*adapted*).
- **Model actors** (`Actors.swift`): each runs its own context on a serial dispatch queue. The main context hears saves made on other contexts, so `@Query` views refresh after a background save (as on iOS 18).
- **History** (`History.swift`, iOS 18): each save writes one transaction to the store's `isim_history` table: author, time, bundle and process, and its inserts, updates (with the properties that changed) and deletes (with a tombstone of the `.preserveValueOnDeletion` attributes). `fetchHistory` / `deleteHistory` apply the descriptor's predicate, sort and limit in Swift (*adapted*).
- **Custom data stores** (`DataStore.swift`, iOS 18): a container made from an app's `DataStoreConfiguration` runs its contexts on the app's `DataStore`. Fetches ask for every model of the entity and apply the predicate and sort in memory, as when a store answers `.preferInMemoryFilter`. Saves send snapshots made with `Snapshot(from:relatedBackingDatas:)`; the identifiers the store assigns replace the temporary ones. `delete(model:where:)` uses `DataStoreBatching`, and history uses `HistoryProviding` (*adapted*).
- **Observers** (`Observers.swift`, iOS 27): `ResultsObserver` refetches when its context or store changes and reports the change through Observation; `HistoryObserver` counts the store's new transactions for the observed models (*adapted*).
- **Not yet:** CloudKit sync, inheritance, `ModelDocument`; history tokens never expire (`historyTokenExpired` is not thrown).
- **Objective-C / C interface:** none (SwiftData is Swift-only).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `@Model` (`PersistentModel`: `persistentBackingData`, `schemaMetadata`, `init(backingData:)`, `persistentModelID`, `modelContext`, `hasChanges`, `isDeleted`, `getValue` / `setValue` and their transformable forms, `createBackingData()`), `BackingData`, `RelationshipCollection`, `@Transient` | ✅ | ≤17 | adapted: real compiler macros expanding like Apple's; attributes are any Codable value (structs, enums, arrays, optionals, dates); a property's own changes are observed, so views that read it refresh; tested (HelloSwiftData, `test_swiftdata`; HelloSwiftDataTemplate) |
| SQLite store on disk (`ModelConfiguration` with its `url:` and `isStoredInMemoryOnly:` forms, `allowsSave`, `GroupContainer`, `CloudKitDatabase`; `ModelContainer`, `configurations`, `deleteAllData()`, `erase()`, `storeIdentifier(forConfigurationNamed:)`) | ✅ | ≤17 | adapted: one table per entity, JSON values; models survive a relaunch; containers on the same file share the store, so a context sees another's saves at its next fetch; `PersistentIdentifier` (entity, store, primary key, `isTemporary` before insert, `identifier(for:entityName:primaryKey:)`) is stable across launches; tested (relaunches) |
| `@Relationship` (inverses, `deleteRule`: `.cascade`, `.nullify`, `.deny`, `.noAction`), to-one and to-many relationships | ✅ | ≤17 | an inverse is the one named by `inverse:`, or inferred when one relationship goes back; setting either side updates the other; relating a model to an inserted one inserts it; `deny` makes the save fail (`SwiftDataError.modelValidationFailure`) while the relationship is not empty; `minimumModelCount` / `maximumModelCount` are kept, not checked; tested |
| `@Attribute(.unique)`, `#Unique`, `#Index`, `Schema.Attribute.Option` (`.unique`, `.externalStorage`, `.allowsCloudEncryption`, `.preserveValueOnDeletion`, `.ephemeral`, `.spotlight`, `.transformable(by:)`) | ✅ | 18.0 | adapted: inserting a model whose unique values match a stored one updates that model (an upsert); unique constraints and `#Index` become SQLite indexes on the JSON values; the other options are kept without effect; tested |
| `ModelContext` (`insert`, `delete`, `delete(model:where:includeSubclasses:)`, `save`, `rollback`, `autosaveEnabled`, `hasChanges`, `fetch`, `fetchCount`, `fetchIdentifiers`, `enumerate`, `transaction`, `model(for:)`, `registeredModel(for:)`, `insertedModelsArray` / `changedModelsArray` / `deletedModelsArray`, `willSave` / `didSave` and `NotificationKey`, `author`, `processPendingChanges()`), `FetchDescriptor` | ✅ | ≤17 | one instance per stored model in a context; rollback restores changed models' saved values; the main context autosaves after the current event; other contexts (`ModelContext(container)`) do not; a context is used on one actor or thread at a time (it is not Sendable), as on iOS; tested |
| `Schema` (`entities`, `entitiesByName`, `entity(for:)`, `entityName(for:)`, `Entity`, `Version`, `PropertyMetadata`, `SchemaProperty`, `Schema.Attribute`, `Schema.Relationship`), `SwiftDataError` | ✅ | ≤17 | a schema includes the types its models' relationships reach; tested |
| `@Query`, `.modelContainer(for:inMemory:isAutosaveEnabled:onSetup:)` on views and scenes, `.modelContext`, `\.modelContext` | ✅ | ≤17 | `@Query` views refresh after inserts, deletes, saves and property changes; tested (HelloSwiftDataTemplate, HelloSwiftData) |
| `VersionedSchema`, `SchemaMigrationPlan`, `MigrationStage` (`.lightweight`, `.custom` with `willMigrate` / `didMigrate`), `Schema(versionedSchema:)`, `ModelContainer(for:migrationPlan:configurations:)` and `migrationPlan` | ✅ | ≤17 | adapted: the store records its schema version; custom stages get a context over the old version's models (`willMigrate`), then the new one's (`didMigrate`), and are saved; a store newer than the plan's schemas fails with `SwiftDataError.backwardMigration`; tested (HelloSwiftData, `test_swiftdata_migration`: V1 to V2 across launches, a renamed property) |
| `ModelActor` and the `@ModelActor` macro (`modelExecutor`, `modelContainer`, `init(modelContainer:)`, `modelContext`, `subscript(_:as:)`), `ModelExecutor`, `SerialModelExecutor`, `DefaultSerialModelExecutor` | ✅ | ≤17 | adapted: the executor is a serial dispatch queue; the actor's saves reach the main context's queries; tested (HelloSwiftData: a trip added and one renamed off the main thread, the list follows) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `ModelDocument` (1 type; with their members under "Not yet in isim") |
| History: `HistoryDescriptor` (`predicate`, `sortBy`, `fetchLimit`), `ModelContext.fetchHistory(_:)` / `deleteHistory(_:)`, `HistoryTransaction`, `HistoryChange`, `HistoryInsert` / `HistoryUpdate` (`updatedAttributes`) / `HistoryDelete` (`tombstone`), `HistoryTombstone`, `HistoryToken`, `DefaultHistoryTransaction` (`bundleIdentifier`, `processIdentifier`), `DefaultHistoryInsert` / `Update` / `Delete`, `DefaultHistoryToken`, `NotificationKey.historyTokens` | ✅ | 18.0 | adapted: the default store records a transaction per save in its database; tokens compare in order, so `#Predicate { $0.token > token }` gives the changes since; tombstones keep `.preserveValueOnDeletion` attributes only; tested (test_swiftdata.py::test_swiftdata_history: two authors, an update's changed attribute, a delete's tombstone, predicates, sort, limit, `deleteHistory`, the token in `didSave`) |
| Custom data stores: `DataStore` (fetch, fetchCount, fetchIdentifiers, save, erase, initializeState / invalidateState, cachedSnapshots), `DataStoreConfiguration`, `DataStoreSnapshot`, `DataStoreSnapshotCodingKey`, `DataStoreSnapshotValue`, `DataStoreFetchRequest` / `Result`, `DataStoreSaveChangesRequest` / `Result` (remapped identifiers, history token), `DataStoreBatching`, `DataStoreBatchDeleteRequest`, `HistoryProviding`, `DataStoreError`, `EditingState`, `ModelContext.editingState`, `ModelContainer(for:migrationPlan:configurations:)` with custom configurations, `PersistentIdentifier.identifier(for:entityName:primaryKey:)` with any Codable key, `DefaultStore`, `DefaultSnapshot`, `ModelContext.debugDescription` | ✅ | 18.0 | adapted: predicates and sorts always run in memory (the store gets the entity's whole fetch); `DefaultStore` is the default SQLite store behind the protocol (its own fetch answers `.preferInMemoryFilter` / `.preferInMemorySort`); tested (test_swiftdata.py::test_swiftdata_history: Apple's JSON-file store sample with UUID identifiers, a relationship, an update and a delete read back by a new container) |
| Observers: `ResultsObserver` (all its initializers, `results`, `sections`, `fetchDescriptor`, `filterBy`, `sortBy`, `sectionBy`, `element(at:)`, `indexPath(for:)`), `FetchResultsCollection`, `SectionedResults`, `ResultsSection`, `HistoryObserver` (`eventCounter`, `observedModels`, `authors`), `Query.sections`, `Query.fetchError` | ✅ | 27.0 | adapted: results are refetched when the context or the store changes, and Observation reports it; sections follow the order of their first models; `HistoryObserver` counts new transactions that change the observed models (by the listed authors, when there are any); `Query.sections` is one section titled ""; tested (test_swiftdata.py::test_swiftdata_observers under iOS 27; test_swiftdata_history checks iOS 18 lacks them) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
140 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`func fetch<T>(FetchDescriptor<T>, batchSize: Int) throws -> FetchResultsCollection<T>`](https://developer.apple.com/documentation/swiftdata/modelcontext/fetch(_:batchsize:))
- [`func fetchIdentifiers<T>(FetchDescriptor<T>, batchSize: Int) throws -> FetchResultsCollection<PersistentIdentifier>`](https://developer.apple.com/documentation/swiftdata/modelcontext/fetchidentifiers(_:batchsize:))
- [`ModelDocument`](https://developer.apple.com/documentation/swiftdata/modeldocument)
- [`Root`](https://developer.apple.com/documentation/swiftdata/persistentmodel/root)
- [`Root`](https://developer.apple.com/documentation/swiftdata/persistentmodel/root)
- [`macro Query()`](https://developer.apple.com/documentation/swiftdata/query())
- [`macro Query<Element>(FetchDescriptor<Element>, animation: Animation)`](https://developer.apple.com/documentation/swiftdata/query(_:animation:))
- [`macro Query<Element>(FetchDescriptor<Element>, animation: Animation, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query(_:animation:sectionby:)-91gkm)
- [`macro Query<Element>(FetchDescriptor<Element>, animation: Animation, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query(_:animation:sectionby:)-9futr)
- [`macro Query<Element>(FetchDescriptor<Element>, transaction: Transaction?)`](https://developer.apple.com/documentation/swiftdata/query(_:transaction:))
- [`macro Query<Element>(FetchDescriptor<Element>, transaction: Transaction?, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query(_:transaction:sectionby:)-1poj9)
- [`macro Query<Element>(FetchDescriptor<Element>, transaction: Transaction?, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query(_:transaction:sectionby:)-2iol)
- [`macro Query(animation: Animation)`](https://developer.apple.com/documentation/swiftdata/query(animation:))
- [`macro Query<Element>(filter: Predicate<Element>?, sort: [SortDescriptor<Element>], animation: Animation)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:animation:))
- [`macro Query<Element>(filter: Predicate<Element>?, sort: [SortDescriptor<Element>], animation: Animation, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:animation:sectionby:)-1s3xp)
- [`macro Query<Element>(filter: Predicate<Element>?, sort: [SortDescriptor<Element>], animation: Animation, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:animation:sectionby:)-82mot)
- [`macro Query<Value, Element>(filter: Predicate<Element>?, sort: KeyPath<Element, Value>, order: SortOrder, animation: Animation)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:order:animation:)-80h6f)
- [`macro Query<Value, Element>(filter: Predicate<Element>?, sort: KeyPath<Element, Value?>, order: SortOrder, animation: Animation)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:order:animation:)-pb15)
- [`macro Query<Value, Element>(filter: Predicate<Element>?, sort: KeyPath<Element, Value>, order: SortOrder, animation: Animation, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:order:animation:sectionby:)-132tv)
- [`macro Query<Value, Element>(filter: Predicate<Element>?, sort: KeyPath<Element, Value?>, order: SortOrder, animation: Animation, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:order:animation:sectionby:)-66vd3)
- [`macro Query<Value, Element>(filter: Predicate<Element>?, sort: KeyPath<Element, Value>, order: SortOrder, animation: Animation, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:order:animation:sectionby:)-75r20)
- [`macro Query<Value, Element>(filter: Predicate<Element>?, sort: KeyPath<Element, Value?>, order: SortOrder, animation: Animation, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:order:animation:sectionby:)-7o0vo)
- [`macro Query<Value, Element>(filter: Predicate<Element>?, sort: KeyPath<Element, Value>, order: SortOrder, transaction: Transaction?)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:order:transaction:)-6kkiu)
- [`macro Query<Value, Element>(filter: Predicate<Element>?, sort: KeyPath<Element, Value?>, order: SortOrder, transaction: Transaction?)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:order:transaction:)-8tk8u)
- [`macro Query<Value, Element>(filter: Predicate<Element>?, sort: KeyPath<Element, Value>, order: SortOrder, transaction: Transaction?, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:order:transaction:sectionby:)-3cn7t)
- [`macro Query<Value, Element>(filter: Predicate<Element>?, sort: KeyPath<Element, Value?>, order: SortOrder, transaction: Transaction?, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:order:transaction:sectionby:)-6c6ho)
- [`macro Query<Value, Element>(filter: Predicate<Element>?, sort: KeyPath<Element, Value?>, order: SortOrder, transaction: Transaction?, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:order:transaction:sectionby:)-9mbr6)
- [`macro Query<Value, Element>(filter: Predicate<Element>?, sort: KeyPath<Element, Value>, order: SortOrder, transaction: Transaction?, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:order:transaction:sectionby:)-i779)
- [`macro Query<Element>(filter: Predicate<Element>?, sort: [SortDescriptor<Element>], transaction: Transaction?)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:transaction:))
- [`macro Query<Element>(filter: Predicate<Element>?, sort: [SortDescriptor<Element>], transaction: Transaction?, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:transaction:sectionby:)-4wwsy)
- [`macro Query<Element>(filter: Predicate<Element>?, sort: [SortDescriptor<Element>], transaction: Transaction?, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query(filter:sort:transaction:sectionby:)-6qrae)
- [`macro Query(transaction: Transaction)`](https://developer.apple.com/documentation/swiftdata/query(transaction:))
- [`init(FetchDescriptor<Element>, animation: Animation)`](https://developer.apple.com/documentation/swiftdata/query/init(_:animation:))
- [`init(FetchDescriptor<Element>, animation: Animation, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query/init(_:animation:sectionby:)-1yoyc)
- [`init(FetchDescriptor<Element>, animation: Animation, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query/init(_:animation:sectionby:)-8yip7)
- [`init(FetchDescriptor<Element>, transaction: Transaction?)`](https://developer.apple.com/documentation/swiftdata/query/init(_:transaction:))
- [`init(FetchDescriptor<Element>, transaction: Transaction?, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query/init(_:transaction:sectionby:)-3pg23)
- [`init(FetchDescriptor<Element>, transaction: Transaction?, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query/init(_:transaction:sectionby:)-8ecyq)
- [`init(filter: Predicate<Element>?, sort: [SortDescriptor<Element>], animation: Animation)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:animation:))
- [`init(filter: Predicate<Element>?, sort: [SortDescriptor<Element>], animation: Animation, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:animation:sectionby:)-1sjv1)
- [`init(filter: Predicate<Element>?, sort: [SortDescriptor<Element>], animation: Animation, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:animation:sectionby:)-35eif)
- [`init<Value>(filter: Predicate<Element>?, sort: KeyPath<Element, Value?>, order: SortOrder, animation: Animation)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:order:animation:)-1qfoj)
- [`init<Value>(filter: Predicate<Element>?, sort: KeyPath<Element, Value>, order: SortOrder, animation: Animation)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:order:animation:)-3qovd)
- [`init<Value>(filter: Predicate<Element>?, sort: KeyPath<Element, Value?>, order: SortOrder, animation: Animation, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:order:animation:sectionby:)-39v3n)
- [`init<Value>(filter: Predicate<Element>?, sort: KeyPath<Element, Value>, order: SortOrder, animation: Animation, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:order:animation:sectionby:)-3myq0)
- [`init<Value>(filter: Predicate<Element>?, sort: KeyPath<Element, Value>, order: SortOrder, animation: Animation, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:order:animation:sectionby:)-4peqq)
- [`init<Value>(filter: Predicate<Element>?, sort: KeyPath<Element, Value?>, order: SortOrder, animation: Animation, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:order:animation:sectionby:)-6td6n)
- [`init<Value>(filter: Predicate<Element>?, sort: KeyPath<Element, Value>, order: SortOrder, transaction: Transaction?)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:order:transaction:)-2bx9a)
- [`init<Value>(filter: Predicate<Element>?, sort: KeyPath<Element, Value?>, order: SortOrder, transaction: Transaction?)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:order:transaction:)-8q7vs)
- [`init<Value>(filter: Predicate<Element>?, sort: KeyPath<Element, Value?>, order: SortOrder, transaction: Transaction?, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:order:transaction:sectionby:)-2kk0t)
- [`init<Value>(filter: Predicate<Element>?, sort: KeyPath<Element, Value?>, order: SortOrder, transaction: Transaction?, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:order:transaction:sectionby:)-62fdm)
- [`init<Value>(filter: Predicate<Element>?, sort: KeyPath<Element, Value>, order: SortOrder, transaction: Transaction?, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:order:transaction:sectionby:)-68vqy)
- [`init<Value>(filter: Predicate<Element>?, sort: KeyPath<Element, Value>, order: SortOrder, transaction: Transaction?, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:order:transaction:sectionby:)-8finq)
- [`init(filter: Predicate<Element>?, sort: [SortDescriptor<Element>], transaction: Transaction?)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:transaction:))
- [`init(filter: Predicate<Element>?, sort: [SortDescriptor<Element>], transaction: Transaction?, sectionBy: KeyPath<Element, String?>)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:transaction:sectionby:)-353r3)
- [`init(filter: Predicate<Element>?, sort: [SortDescriptor<Element>], transaction: Transaction?, sectionBy: KeyPath<Element, String>)`](https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:transaction:sectionby:)-90bbe)
- [`static var codable: Schema.Attribute.Option`](https://developer.apple.com/documentation/swiftdata/schema/attribute/option/codable)
- [`static var codable: Schema.Attribute.Option`](https://developer.apple.com/documentation/swiftdata/schema/attribute/option/codable)
- [`Schema.CompositeAttribute`](https://developer.apple.com/documentation/swiftdata/schema/compositeattribute)
- [`Schema.CompositeAttribute`](https://developer.apple.com/documentation/swiftdata/schema/compositeattribute)
- [`static func == (Schema.CompositeAttribute, Schema.CompositeAttribute) -> Bool`](https://developer.apple.com/documentation/swiftdata/schema/compositeattribute/==(_:_:))
- [`static func == (Schema.CompositeAttribute, Schema.CompositeAttribute) -> Bool`](https://developer.apple.com/documentation/swiftdata/schema/compositeattribute/==(_:_:))
- [`var debugDescription: String`](https://developer.apple.com/documentation/swiftdata/schema/compositeattribute/debugdescription)
- [`var debugDescription: String`](https://developer.apple.com/documentation/swiftdata/schema/compositeattribute/debugdescription)
- [`func encode(to: any Encoder) throws`](https://developer.apple.com/documentation/swiftdata/schema/compositeattribute/encode(to:))
- [`func encode(to: any Encoder) throws`](https://developer.apple.com/documentation/swiftdata/schema/compositeattribute/encode(to:))
- [`init(from: any Decoder) throws`](https://developer.apple.com/documentation/swiftdata/schema/compositeattribute/init(from:))
- [`init(from: any Decoder) throws`](https://developer.apple.com/documentation/swiftdata/schema/compositeattribute/init(from:))
- [`init(name: String, originalName: String?, options: [Schema.Attribute.Option], valueType: any Any.Type, defaultValue: Any?, hashModifier: String?)`](https://developer.apple.com/documentation/swiftdata/schema/compositeattribute/init(name:originalname:options:valuetype:defaultvalue:hashmodifier:))
- [`init(name: String, originalName: String?, options: [Schema.Attribute.Option], valueType: any Any.Type, defaultValue: Any?, hashModifier: String?)`](https://developer.apple.com/documentation/swiftdata/schema/compositeattribute/init(name:originalname:options:valuetype:defaultvalue:hashmodifier:))
- [`var properties: [Schema.Attribute]`](https://developer.apple.com/documentation/swiftdata/schema/compositeattribute/properties)
- [`var properties: [Schema.Attribute]`](https://developer.apple.com/documentation/swiftdata/schema/compositeattribute/properties)
- [`var inheritedProperties: [any SchemaProperty]`](https://developer.apple.com/documentation/swiftdata/schema/entity/inheritedproperties)
- [`var inheritedProperties: [any SchemaProperty]`](https://developer.apple.com/documentation/swiftdata/schema/entity/inheritedproperties)
- [`var inheritedProperties: [any SchemaProperty]`](https://developer.apple.com/documentation/swiftdata/schema/entity/inheritedproperties)
- [`var inheritedProperties: [any SchemaProperty]`](https://developer.apple.com/documentation/swiftdata/schema/entity/inheritedproperties)
- [`var inheritedPropertiesByName: [String : any SchemaProperty]`](https://developer.apple.com/documentation/swiftdata/schema/entity/inheritedpropertiesbyname)
- [`var inheritedPropertiesByName: [String : any SchemaProperty]`](https://developer.apple.com/documentation/swiftdata/schema/entity/inheritedpropertiesbyname)
- [`var inheritedPropertiesByName: [String : any SchemaProperty]`](https://developer.apple.com/documentation/swiftdata/schema/entity/inheritedpropertiesbyname)
- [`var inheritedPropertiesByName: [String : any SchemaProperty]`](https://developer.apple.com/documentation/swiftdata/schema/entity/inheritedpropertiesbyname)
- [`init(String)`](https://developer.apple.com/documentation/swiftdata/schema/entity/init(_:))
- [`init(String)`](https://developer.apple.com/documentation/swiftdata/schema/entity/init(_:))
- [`init(String)`](https://developer.apple.com/documentation/swiftdata/schema/entity/init(_:))
- [`init(String)`](https://developer.apple.com/documentation/swiftdata/schema/entity/init(_:))
- [`init(String, properties: any SchemaProperty...)`](https://developer.apple.com/documentation/swiftdata/schema/entity/init(_:properties:))
- [`init(String, properties: any SchemaProperty...)`](https://developer.apple.com/documentation/swiftdata/schema/entity/init(_:properties:))
- [`init(String, properties: any SchemaProperty...)`](https://developer.apple.com/documentation/swiftdata/schema/entity/init(_:properties:))
- [`init(String, properties: any SchemaProperty...)`](https://developer.apple.com/documentation/swiftdata/schema/entity/init(_:properties:))
- [`init(String, subentities: Schema.Entity..., properties: any SchemaProperty...)`](https://developer.apple.com/documentation/swiftdata/schema/entity/init(_:subentities:properties:))
- [`init(String, subentities: Schema.Entity..., properties: any SchemaProperty...)`](https://developer.apple.com/documentation/swiftdata/schema/entity/init(_:subentities:properties:))
- [`init(String, subentities: Schema.Entity..., properties: any SchemaProperty...)`](https://developer.apple.com/documentation/swiftdata/schema/entity/init(_:subentities:properties:))
- [`init(String, subentities: Schema.Entity..., properties: any SchemaProperty...)`](https://developer.apple.com/documentation/swiftdata/schema/entity/init(_:subentities:properties:))
- [`var subentities: Set<Schema.Entity>`](https://developer.apple.com/documentation/swiftdata/schema/entity/subentities)
- [`var subentities: Set<Schema.Entity>`](https://developer.apple.com/documentation/swiftdata/schema/entity/subentities)
- [`var subentities: Set<Schema.Entity>`](https://developer.apple.com/documentation/swiftdata/schema/entity/subentities)
- [`var subentities: Set<Schema.Entity>`](https://developer.apple.com/documentation/swiftdata/schema/entity/subentities)
- [`var superentity: Schema.Entity?`](https://developer.apple.com/documentation/swiftdata/schema/entity/superentity)
- [`var superentity: Schema.Entity?`](https://developer.apple.com/documentation/swiftdata/schema/entity/superentity)
- [`var superentity: Schema.Entity?`](https://developer.apple.com/documentation/swiftdata/schema/entity/superentity)
- [`var superentity: Schema.Entity?`](https://developer.apple.com/documentation/swiftdata/schema/entity/superentity)
- [`var superentityName: String?`](https://developer.apple.com/documentation/swiftdata/schema/entity/superentityname)
- [`var superentityName: String?`](https://developer.apple.com/documentation/swiftdata/schema/entity/superentityname)
- [`var superentityName: String?`](https://developer.apple.com/documentation/swiftdata/schema/entity/superentityname)
- [`var superentityName: String?`](https://developer.apple.com/documentation/swiftdata/schema/entity/superentityname)
- [`Schema.Index`](https://developer.apple.com/documentation/swiftdata/schema/index)
- [`Schema.Index`](https://developer.apple.com/documentation/swiftdata/schema/index)
- [`Schema.Index.CodingKeys`](https://developer.apple.com/documentation/swiftdata/schema/index/codingkeys)
- [`Schema.Index.CodingKeys`](https://developer.apple.com/documentation/swiftdata/schema/index/codingkeys)
- [`case indices`](https://developer.apple.com/documentation/swiftdata/schema/index/codingkeys/indices)
- [`case indices`](https://developer.apple.com/documentation/swiftdata/schema/index/codingkeys/indices)
- [`let indices: [Schema.Index<T>.Types<T>]`](https://developer.apple.com/documentation/swiftdata/schema/index/indices)
- [`let indices: [Schema.Index<T>.Types<T>]`](https://developer.apple.com/documentation/swiftdata/schema/index/indices)
- [`init(Schema.Index<T>.Types<T>...)`](https://developer.apple.com/documentation/swiftdata/schema/index/init(_:)-4i37e)
- [`init(Schema.Index<T>.Types<T>...)`](https://developer.apple.com/documentation/swiftdata/schema/index/init(_:)-4i37e)
- [`init([PartialKeyPath<T>]...)`](https://developer.apple.com/documentation/swiftdata/schema/index/init(_:)-527in)
- [`init([PartialKeyPath<T>]...)`](https://developer.apple.com/documentation/swiftdata/schema/index/init(_:)-527in)
- [`Schema.Index.Types`](https://developer.apple.com/documentation/swiftdata/schema/index/types)
- [`Schema.Index.Types`](https://developer.apple.com/documentation/swiftdata/schema/index/types)
- [`case binary([PartialKeyPath<P>])`](https://developer.apple.com/documentation/swiftdata/schema/index/types/binary(_:))
- [`case binary([PartialKeyPath<P>])`](https://developer.apple.com/documentation/swiftdata/schema/index/types/binary(_:))
- [`case rtree([PartialKeyPath<P>])`](https://developer.apple.com/documentation/swiftdata/schema/index/types/rtree(_:))
- [`case rtree([PartialKeyPath<P>])`](https://developer.apple.com/documentation/swiftdata/schema/index/types/rtree(_:))
- [`static func load(from: URL) throws -> Schema`](https://developer.apple.com/documentation/swiftdata/schema/load(from:))
- [`static func load(from: URL) throws -> Schema`](https://developer.apple.com/documentation/swiftdata/schema/load(from:))
- [`func save(to: URL) throws`](https://developer.apple.com/documentation/swiftdata/schema/save(to:))
- [`func save(to: URL) throws`](https://developer.apple.com/documentation/swiftdata/schema/save(to:))
- [`Schema.Unique`](https://developer.apple.com/documentation/swiftdata/schema/unique)
- [`Schema.Unique`](https://developer.apple.com/documentation/swiftdata/schema/unique)
- [`Schema.Unique.CodingKeys`](https://developer.apple.com/documentation/swiftdata/schema/unique/codingkeys)
- [`Schema.Unique.CodingKeys`](https://developer.apple.com/documentation/swiftdata/schema/unique/codingkeys)
- [`case constraints`](https://developer.apple.com/documentation/swiftdata/schema/unique/codingkeys/constraints)
- [`case constraints`](https://developer.apple.com/documentation/swiftdata/schema/unique/codingkeys/constraints)
- [`let constraints: [[PartialKeyPath<T>]]`](https://developer.apple.com/documentation/swiftdata/schema/unique/constraints)
- [`let constraints: [[PartialKeyPath<T>]]`](https://developer.apple.com/documentation/swiftdata/schema/unique/constraints)
- [`init([PartialKeyPath<T>]...)`](https://developer.apple.com/documentation/swiftdata/schema/unique/init(_:))
- [`init([PartialKeyPath<T>]...)`](https://developer.apple.com/documentation/swiftdata/schema/unique/init(_:))
- [`static func < (Schema.Version, Schema.Version) -> Bool`](https://developer.apple.com/documentation/swiftdata/schema/version-swift.struct/_(_:_:))
- [`static func < (Schema.Version, Schema.Version) -> Bool`](https://developer.apple.com/documentation/swiftdata/schema/version-swift.struct/_(_:_:))
- [`var isRelationship: Bool`](https://developer.apple.com/documentation/swiftdata/schemaproperty/isrelationship-ksdo)
- [`var isRelationship: Bool`](https://developer.apple.com/documentation/swiftdata/schemaproperty/isrelationship-ksdo)

</details>
<!-- /generated:missing -->
