"""CoreSpotlight under `isim boot` (issue #412), with HelloSpotlight ("Notes Index"):
- the app indexes three notes in a batch with a client state (a named index with a protection class); every attribute
  is kept, and Spotlight summarizes the ones that ask for it (iOS 18: searchableItemsDidUpdate);
- CSSearchQuery: Spotlight's query language (== with *, c and d modifiers, ||, &&, >=, $time.today(-7)), the context's
  filter queries and fetch attributes, an invalid query (CSSearchQueryErrorDomain -2002); an isUpdate item merges its
  rating into the indexed note;
- CSUserQuery (iOS 18): items and suggestions for what the user types, and engagement;
- `isim spotlight reindex|items|throttle`: the running app's index delegate answers; once the app is gone, its index
  extension (CSIndexExtensionRequestHandler) does;
- the import extension (CSImportExtension) imports a document the app writes to Documents; deleting it removes it;
- `isim spotlight list` prints the app's items."""
import os
import re
import subprocess

import pytest

from isimtest import ISIM

APP = "dev.isim.samples.HelloSpotlight"
SHOTS = os.environ.get("SPOTLIGHT_SHOTS")


def isim(data, *args):
    r = subprocess.run([str(ISIM), *args], env=dict(os.environ, ISIM_DATA=str(data)), stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True, timeout=60)
    assert r.returncode == 0, r.stdout
    return r.stdout


def status(dev, pattern):
    dev.wait_view(rf"id=status text={pattern}")


@pytest.mark.os_matrix
def test_spotlight_queries(launch, device_data, ios):
    ios18 = int(ios[0] or os.environ.get("ISIM_OS_VERSION", "18")) >= 18
    dev = launch(None, install=["HelloSpotlight"])
    dev.send(f"launch {APP}")
    dev.wait_tap_id("index")
    status(dev, r"indexed 3 notes, client state v1 error none")
    if ios18:                                                            # Spotlight's summaries
        dev.wait_log(r"sp delegate updated note-coffee summary: Three beans from Kenya, Ethiopia and Colombia\. The Kenyan one was the brightest\.$")
    dev.tap_id("query")
    status(dev, r"found 2: note-coffee \(Coffee tasting, 5\), note-standup \(Standup notes, 3\)")
    dev.tap_id("filters")
    status(dev, r"found 1: note-coffee \(Coffee tasting, 5\)")                   # the trip is 20 days old
    dev.tap_id("bad")
    status(dev, r"query error CSSearchQueryErrorDomain -2002")
    dev.tap_id("update")
    status(dev, r"found 1: note-trip \(Trip to Lisbon, 2\)")                     # isUpdate merged the rating
    if SHOTS:
        dev.screenshot("spotlight-notes").save(os.path.join(SHOTS, "spotlight-notes.png"))
    dev.tap_id("user")
    if ios18:
        status(dev, r"user query: note-coffee.*; suggestions: .*coffee")
        dev.wait_log(r"isim CoreSpotlight: the user engaged with note-coffee \(select, ")
    else:
        status(dev, r"user queries need iOS 18")
    listing = isim(device_data, "spotlight", "list", APP)
    assert re.search(r"^note-trip\tTrip to Lisbon\tdomain notes\tindex notes$", listing, re.M), listing
    assert dev.quit() == 0


def test_spotlight_delegate_and_extensions(launch, device_data):
    dev = launch(None, install=["HelloSpotlight"])
    dev.send(f"launch {APP}")
    dev.wait_tap_id("index")
    status(dev, r"indexed 3 notes")
    isim(device_data, "spotlight", "reindex", APP)                         # the running app's delegate
    dev.wait_log(r"sp delegate reindex all")
    dev.wait_log(r"the app acknowledged Spotlight's reindex request")
    isim(device_data, "spotlight", "reindex", APP, "note-trip", "note-coffee")
    dev.wait_log(r"sp delegate reindex note-trip,note-coffee")
    isim(device_data, "spotlight", "items", APP, "note-standup")
    dev.wait_log(r"sp delegate items note-standup")
    isim(device_data, "spotlight", "throttle", APP, "on")
    dev.wait_log(r"sp delegate throttled")
    isim(device_data, "spotlight", "throttle", APP, "off")
    dev.wait_log(r"sp delegate finished throttling")

    dev.tap_id("document")                                               # the import extension
    status(dev, r"wrote packing\.spnote")
    dev.wait_log(r"spi imported packing\.spnote: Packing list")
    dev.wait_log(r"SpringBoard: Spotlight indexed packing\.spnote for dev\.isim\.samples\.HelloSpotlight \(“Packing list”\)")
    assert re.search(r"^file://.*/Documents/packing\.spnote\tPacking list\timported$", isim(device_data, "spotlight", "list", APP), re.M)

    dev.tap_id("remove")
    status(dev, r"deleted everything")
    dev.send("home")
    dev.send(f"terminate {APP}")
    dev.wait_log(r"terminated .*HelloSpotlight\.app \(system\)")
    isim(device_data, "spotlight", "reindex", APP)                         # no app: the index extension
    dev.wait_log(r"SpringBoard: Spotlight asks the index extension of Notes Index: reindex \(all items\)")
    dev.wait_log(r"spx reindex all")
    dev.wait_log(r"SpringBoard: Spotlight: the index extension of dev\.isim\.samples\.HelloSpotlight acknowledged")
    listing = isim(device_data, "spotlight", "list", APP)
    assert "note-coffee\tCoffee tasting\tdomain notes\tindex notes" in listing, listing
    assert dev.quit() == 0
