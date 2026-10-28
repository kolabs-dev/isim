"""SwiftData persistence (HelloSwiftData): the first launch seeds the on-disk store (relationships set from either side
keep their inverses; @Attribute(.unique) and #Unique inserts update the stored model); after a relaunch the models come
back from the store with their attributes and relationships, a second context's save reaches the main context, a
`deny` delete fails the save and rolls back, a `cascade` delete takes the trip's stops and nullifies the traveler's
side. The @Query list refreshes when a model's property changes, and the change is saved (autosave) for the next
launch."""


def test_swiftdata(launch, device_data):
    app = launch("HelloSwiftData", data=device_data)
    app.wait_log(r'sd2 schema: \["Stop", "Traveler", "Trip"\] unique=\[\["name"\]\] indices=\[\["start"\], \["name", "start"\]\] '
                 r'store=default\.store memory=false')
    app.wait_log(r"sd2 inverses: alfama\.trip=Lisbon lisbon\.stops=2 ana\.trips=\[\"Lisbon\"\] tokyo\.traveler=Bo bo inserted=true")
    app.wait_log(r"sd2 upsert: trips=2 travelers=2")
    seeded = (r"Lisbon\[leisure 1200EUR tags= note=- stops=Alfama>Belem by=Ana Silva\] "
              r"Tokyo\[work 3000JPY tags=conference\+spring note=keynote stops=Shibuya by=Bo\]")
    app.wait_log(r"sd2 seeded: " + seeded)
    app.wait_log(r"sd2 store file: true")
    app.wait_view(r"text=Lisbon: 2 stops")
    assert app.quit() == 0

    # relaunch: the store kept everything
    app = launch("HelloSwiftData", data=device_data)
    app.wait_log(r"sd2 relaunch: " + seeded)
    app.wait_log(r"sd2 identity: same=true id=Trip temporary=false transient=0")
    app.wait_log(r"sd2 other context: inserted=1 main sees=true")
    app.wait_log(r"sd2 deny: SwiftDataError\(modelValidationFailure\) still=true")
    app.wait_log(r"sd2 rollback: ana=Ana Silva trips=\[\"Lisbon\"\] changes=false")
    app.wait_log(r"sd2 cascade: stops=2 bo\.trips=\[\] trips=Lisbon\[.*\] Oslo\[leisure 500NOK tags= note=- stops= by=-\]")
    # a model actor adds and renames trips off the main thread; the list follows (#300)
    app.wait_log(r"sd2 actor: background stored")
    app.wait_log(r"sd2 actor rename: true")
    app.wait_view(r"text=Rome: 0 stops")
    app.wait_view(r"text=Bergen: 0 stops")

    # a property change refreshes the list, and autosave keeps it
    app.wait_tap_id("rename")
    app.wait_log(r"sd2 renamed: \[\"Porto\", \"Bergen\", \"Rome\"\]")
    app.wait_view(r"text=Porto: 2 stops")
    app.wait_still()
    assert app.quit() == 0
    app = launch("HelloSwiftData", data=device_data)
    app.wait_log(r"sd2 relaunch: Porto\[leisure 1200EUR .*stops=Alfama>Belem by=Ana Silva\] Bergen\[.*\] Rome\[work 100EUR")
    assert app.quit() == 0


def test_swiftdata_migration(launch, device_data):
    """A versioned schema migrated by a plan (#300): version 1's notes, then version 2 opens the store and its custom
    stage runs (willMigrate on the old models, didMigrate on the new ones; a renamed property is read by its
    originalName); opening it with version 1 again fails with backwardMigration."""
    app = launch("HelloSwiftData", data=device_data, env={"HELLOSWIFTDATA_NOTES": "v1"})
    app.wait_log(r'sd2 notes v1: \["groceries=milk eggs bread", "idea=a simulator for linux"\]')
    assert app.quit() == 0
    app = launch("HelloSwiftData", data=device_data, env={"HELLOSWIFTDATA_NOTES": "v2"})
    app.wait_log(r"sd2 notes: will migrate 2 notes")
    app.wait_log(r'sd2 notes v2: \["GROCERIES words=3 text=milk eggs bread", "IDEA words=4 text=a simulator for linux"\]')
    assert app.quit() == 0
    app = launch("HelloSwiftData", data=device_data, env={"HELLOSWIFTDATA_NOTES": "v1again"})
    app.wait_log(r"sd2 notes v1again: SwiftDataError\(backwardMigration\)")
    assert app.quit() == 0


def test_swiftdata_history(launch, device_data, ios):
    """History, custom data stores and observers (#399). Under iOS 18: each save is a history transaction (author,
    bundle, process, the token in didSave); the transactions since a token list an update with its changed attribute,
    a delete with the tombstone of the .preserveValueOnDeletion attribute only, and another author's insert;
    predicates, sorts and limits filter them, deleteHistory trims them. Apple's JSON-file DataStore sample runs a
    container: UUID identifiers replace the temporary ones on save, a relationship, an in-memory predicate and sort, and
    an update and a delete come back from the file. Under iOS 27, a ResultsObserver follows an insert and a filter
    change, with sections, and a HistoryObserver counts saves; @Query's sections and fetchError."""
    app = launch("HelloSwiftData", data=device_data, env={"HELLOSWIFTDATA_HISTORY": "1"})
    app.wait_log(r"sd2 history first: transactions=1 changes=2 author=app bundle=true process=true didSave token=true")
    app.wait_log(r"sd2 history since: app:update done app:delete code=R1 title=- widget:insert Chore")
    app.wait_log(r"sd2 history widget: 1 newest=widget")
    app.wait_log(r"sd2 history after delete: 3")
    app.wait_log(r"sd2 custom before save: temporary=true")
    app.wait_log(r"sd2 custom saved: temporary=false store=people\.json file=true")
    app.wait_log(r'sd2 custom fetch: \["Cy pets=\[\]", "Ana pets=\[\\"Rex\\"\]"\] count=3')
    app.wait_log(r"sd2 custom identity: Ana rex\.owner=Ana")
    app.wait_log(r'sd2 custom after save: \["Ana@Porto", "Bo@Oslo"\] pets=1')
    if not (ios[0] or "").startswith("27"):
        app.wait_log(r"sd2 observers: need iOS 27")
    assert app.quit() == 0


def test_swiftdata_observers(launch, device_data):
    """ResultsObserver (sections, element(at:), indexPath(for:), a filter change), HistoryObserver and @Query's
    sections and fetchError, under iOS 27 (test_swiftdata_history checks that iOS 18 has none of them)."""
    app = launch("HelloSwiftData", data=device_data, env={"HELLOSWIFTDATA_HISTORY": "1"}, os_version="27.0")
    app.wait_log(r"sd2 history after delete: 3")
    app.wait_log(r'sd2 observer: changed=true results=\["Dust", "Vacuum", "Wash up"\] sections=\["living", "kitchen"\] '
                 r'living=\["Dust", "Vacuum"\] at0\.1=Vacuum dust=0\.0')
    app.wait_log(r'sd2 observer filtered: \["Wash up"\] sections=1')
    app.wait_log(r"sd2 history observer: events=2 tracked=true")
    app.wait_log(r'sd2 query sections: \[""\] first=2 of 2 error=none')
    assert app.quit() == 0
