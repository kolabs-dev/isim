# Core Data on isim

isim ships its own Core Data: an Objective-C `CoreData` framework (`isim/frameworks/CoreData`, headers in
`isim/sdk-src/Frameworks/CoreData`) plus a Swift overlay (`isim/swift/overlays/CoreData`) with typed fetches,
async `perform`, `ObservableObject` managed objects and SwiftUI's `@FetchRequest` / `@SectionedFetchRequest`.
Stores use the host's SQLite through isim's `/usr/lib/libsqlite3.dylib`. Coverage details: `COVERAGE.md`
("Data & persistence"). Tests: `isim/tests/coredata` (self-test) and `isim/tests/ui/coredata.sh` (the
`HelloCoreData` sample, built from an Xcode project).

## Compiled models (`.momd`) — isim's own format

`isim build` compiles every `.xcdatamodeld` / `.xcdatamodel` of a target with `isim/tools/momc.py`
(it also runs stand-alone: `momc.py Model.xcdatamodeld OUTDIR [--swift-codegen DIR]`).
The output is **not** Apple's binary `.mom`; Apple's Core Data cannot read it and isim cannot read Apple's.

```
<Name>.momd/
  VersionInfo.plist     NSManagedObjectModel_CurrentVersionName = the .xccurrentversion choice; isimFormat
  <Version>.mom         one per .xcdatamodel version: XML property list, see below
```

Each `.mom` is a dictionary:

| key | value |
|---|---|
| `isimFormat` | `"isim-managed-object-model"` (required; anything else is rejected) |
| `formatVersion` | `1` |
| `entities` | array of entity dictionaries |
| `fetchRequests` | `[{name, entity, predicate}]` — fetch request templates |
| `configurations` | `{name: [entity names]}` |
| `versionIdentifiers` | `[userDefinedModelVersionIdentifier]` |

Entity: `name`, `className` (representedClassName), `codeGenerationType` (`class` / `category` / `none`),
`parent`, `abstract`, `renamingIdentifier`, `uniquenessConstraints`, `userInfo`, and

- `attributes`: `{name, type ("Integer 16" … "Transformable", Xcode's names), optional, scalar, transient, indexed,
  defaultValue, valueTransformerName, customClassName, minValue, maxValue, regularExpression, renamingIdentifier}`;
  date defaults are seconds since 2001-01-01.
- `relationships`: `{name, destination, inverse, optional, toMany, ordered, minCount, maxCount, deleteRule ("Nullify",
  "Cascade", "Deny", "No Action"), transient, renamingIdentifier}`
- `fetchedProperties`: `{name, entity, predicate}` (`$FETCH_SOURCE` is substituted)

### Code generation

For the current version, entities with `codeGenerationType="class"` get `<Class>+CoreDataClass.swift`
(`@objc(<Class>) public class <Class>: <Parent or NSManagedObject>`) and `<Class>+CoreDataProperties.swift`
(`fetchRequest()`, `@NSManaged` properties, to-many / ordered accessors) — the same declarations Xcode generates.
`category` entities get only the properties file. Scalar attributes follow `usesScalarValueType`; Decimal attributes
are `NSNumber?` because isim's Foundation has no `NSDecimalNumber`.

## SQLite store layout (isim's own)

| table | contents |
|---|---|
| `Z_METADATA(Z_KEY, Z_VALUE)` | `NSStoreUUID`, `NSStoreType`, `isimFormat`, `isimSchema` (the model layout the file was written with; binary plists) |
| `Z_ENTITIES(Z_ENT, Z_NAME, Z_SUPER, Z_MAX)` | entity numbers; `Z_MAX` of a root entity = last primary key handed out |
| `Z<ROOT>(Z_PK, Z_ENT, Z_OPT, Z<ATTR>…, Z<TOONE>, Z_ENT_<TOONE>)` | one table per inheritance tree; `Z_OPT` is the row version used for optimistic locking |
| `Z_<ROOT>_<REL>(Z_SRC, Z_SRCENT, Z_DST, Z_DSTENT, Z_ORDER)` | ordered, inverse-less and many-to-many relationships |

Values: integers/booleans INTEGER, Double/Float/Decimal/Date REAL (dates in seconds since 2001-01-01), String/URI
TEXT, Binary BLOB, UUID 16-byte BLOB, Transformable the BLOB its value transformer produces.

Object IDs print as `x-coredata://<store UUID>/<Entity>/p<pk>` (temporary: `x-coredata:///<Entity>/t<UUID>`).

### Migration

When the stored `isimSchema` differs from the model and the store options allow automatic migration (the
`NSPersistentStoreDescription` defaults), isim migrates in place: it adds tables, columns (with the attribute's
default) and join tables, and follows `renamingIdentifier`s for entities and attributes. Removed properties stay in
the file unused; changed attribute types keep their stored values; changing an entity's parent fails. Without the
options, opening fails with `NSPersistentStoreIncompatibleVersionHashError` (134100). Mapping models and
`NSMigrationManager` are not available.

## Not available

SwiftData (needs Apple's Swift macros), `NSPersistentCloudKitContainer`, persistent history, `NSBatchInsertRequest`,
undo registration, enforced uniqueness constraints, binary/XML store types.
