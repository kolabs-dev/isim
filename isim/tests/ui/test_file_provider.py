"""FileProvider and FileProviderUI (issue #408, HelloFileProvider): the app adds a domain of its replicated file provider
extension; the document picker lists it under Locations, its files are placeholders (a cloud badge) until one is
picked (the extension's fetchContents); exporting into it is the extension's createItem; a change on the provider's
server and signalEnumerator sync the replica (enumerateChanges from the sync anchor); getUserVisibleURL,
requestDownloadForItem and evictItem work on the replica; an item's menu has the extension's custom action (Star)
and the FileProviderUI extension's action (Share), whose sheet completes or cancels; a sync that fails with
notAuthenticated shows the FileProviderUI extension's sign-in (prepare(forError:)); removing the domain removes its
location."""
import os
import subprocess

from isimtest import ISIM

APP = "HelloFileProvider"
PROVIDER = "dev.isim.samples.HelloFileProvider.Files"


def isim(data, *args):
    r = subprocess.run([str(ISIM), *args], env=dict(os.environ, ISIM_DATA=str(data)), stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True, timeout=60)
    assert r.returncode == 0, r.stdout
    return r.stdout


def test_file_provider(launch, device_data):
    replica = device_data / "Library/isim/FileProvider/Domains" / PROVIDER / "notes"
    app = launch(APP)
    app.wait_log(r"^fp launched$")
    app.tap_id("add")
    app.wait_log(r"^fp added ok$")
    app.tap_id("domains")
    app.wait_log(r"^fp domains notes:Sample Notes$")

    def domain(button):
        app.tap_id(button)
        app.wait_view(r"id=docs-cancel")
        app.wait_tap_id("nav-back")                                    # On My iPhone -> Browse: the locations
        app.wait_tap_id("docs-location-sample-notes")

    app.tap_id("open")                                                 # Browse: the domain is a location
    app.wait_view(r"id=docs-cancel")
    app.wait_tap_id("nav-back")
    app.wait_view(r"id=docs-location-sample-notes")
    app.wait_still()
    app.screenshot("fileprovider-locations")
    app.wait_tap_id("docs-location-sample-notes")                      # the domain: its replica syncs
    app.wait_log(r"fpx init notes")
    app.wait_log(r"fpx enumerate root: 2")
    app.wait_view(r"id=docs-cloud-hello\.txt")                         # not downloaded yet
    assert (replica / "hello.txt").stat().st_size == len("Hello from the server")
    app.wait_still()
    app.screenshot("fileprovider-domain")
    app.wait_tap_id("docs-item-Notes")
    app.wait_tap_id("docs-item-todo.txt")
    app.wait_log(r"fpx fetch Notes/todo\.txt viewer=true")
    app.wait_log(r"^fp picked todo\.txt: buy milk$")
    app.wait_view(r"id=docs-cancel", gone=True)
    assert isim(device_data, "fileprovider", "list").split()[:2] == ["dev.isim.samples.HelloFileProvider", "notes"]
    assert isim(device_data, "fileprovider", "files", "notes").splitlines() == ["Notes/", "Notes/todo.txt", "hello.txt (placeholder)"]

    domain("export")                                                   # export: the provider creates the item
    app.wait_tap_id("docs-export")
    app.wait_log(r"fpx create Report\.txt")
    app.wait_log(r"^fp picked Report\.txt: written in the app$")
    app.wait_log(r"^fp server has Report\.txt: written in the app$")

    app.tap_id("remote")                                               # a change on the server, signalled
    app.wait_log(r"fpx changes since \d+: \d+ updated, 0 deleted")
    app.wait_log(r"^fp signalled ok$")
    assert (replica / "News.txt").exists()
    app.tap_id("visible")
    app.wait_log(r"^fp visible News\.txt in notes$")
    app.wait_log(r"fpx fetch News\.txt viewer=false")
    app.wait_log(r"^fp downloaded News\.txt: news from the server $")
    assert (replica / "News.txt").read_text() == "news from the server"
    app.tap_id("evict")
    app.wait_log(r"^fp evicted ok$")
    st = os.stat(replica / "News.txt")
    assert st.st_size == len("news from the server") and st.st_blocks == 0, "evicted: a placeholder again"

    domain("open")                                                     # the item's menu: the provider's actions
    app.wait_view(r"id=docs-item-hello\.txt")
    app.send("holdid docs-item-hello.txt 0.9")
    app.wait_tap_id("menu-Star")
    app.wait_log(r"fpx action dev\.isim\.samples\.fileprovider\.star on hello\.txt")
    app.send("holdid docs-item-hello.txt 0.9")
    app.wait_tap_id("menu-Share")
    app.wait_log(r"fpui prepare dev\.isim\.samples\.fileprovider\.share hello\.txt domain=notes")
    app.wait_view(r"id=fpui-cancel")
    app.wait_still()
    app.screenshot("fileprovider-action")
    app.wait_tap_id("fpui-cancel")
    app.wait_log(r"isim FileProviderUI: dev\.isim\.samples\.fileprovider\.share cancelled")
    app.send("holdid docs-item-hello.txt 0.9")
    app.wait_tap_id("menu-Share")
    app.wait_tap_id("fpui-done")
    app.wait_log(r"isim FileProviderUI: dev\.isim\.samples\.fileprovider\.share completed")
    app.wait_tap_id("docs-cancel")
    app.wait_log(r"^fp cancelled$")

    app.tap_id("signout")                                              # not signed in: the provider's sign-in sheet
    app.wait_log(r"^fp signed out$")
    domain("open")
    app.wait_log(r"fpx not signed in")
    app.wait_log(r"^fpui error -1000$")
    app.wait_tap_id("fpui-done")
    app.wait_log(r"^fpui signed in$")
    app.wait_log(r"fpx changes since")                                  # synced again
    app.wait_tap_id("docs-cancel")
    app.wait_log(r"^fp cancelled$")

    app.tap_id("remove")                                               # the location goes
    app.wait_log(r"^fp removed ok$")
    assert not replica.exists()
    app.tap_id("domains")
    app.wait_log(r"^fp domains $")
