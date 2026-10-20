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
    app.wait_view(r"text=Oslo: 0 stops")

    # a property change refreshes the list, and autosave keeps it
    app.wait_tap_id("rename")
    app.wait_log(r"sd2 renamed: \[\"Porto\", \"Oslo\"\]")
    app.wait_view(r"text=Porto: 2 stops")
    app.wait_still()
    assert app.quit() == 0
    app = launch("HelloSwiftData", data=device_data)
    app.wait_log(r"sd2 relaunch: Porto\[leisure 1200EUR .*stops=Alfama>Belem by=Ana Silva\] Oslo\[")
    assert app.quit() == 0
