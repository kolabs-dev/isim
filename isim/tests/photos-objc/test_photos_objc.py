"""Photos and PhotosUI from Objective-C (PhotosObjCTest.app, issue #545): #import <Photos/Photos.h> and <PhotosUI/PhotosUI.h>
over the Swift overlays. With the permission granted (ISIM_PHOTOS_PERMISSION=allow): fetches through Objective-C's own
PHFetchResult (fast enumeration, blocks, options with a predicate and a limit, identifiers), PHImageManager image and data
requests, resources, change requests that save a picture into a new album and favourite it, a change observer and its
fetch result change details; then PHPickerViewController with a PHPickerConfiguration (photo library, limit, a combined
PHPickerFilter) and its delegate, whose results load as images."""
from isimtest import need_apps


def test_photos_objc(launch):
    need_apps("PhotosObjCTest")
    app = launch("PhotosObjCTest", env={"ISIM_PHOTOS_PERMISSION": "allow"})
    p = "PhotosObjC: "
    app.wait_log(p + r"authorization 3 legacy 3 add 3")
    app.wait_log(p + r"assets 6 fast 6 enumerated 6 images 6 first 800x600 type 1 index 0 contains 1")
    app.wait_log(p + r"limited 2 by id 1")
    app.wait_log(p + r"image 100x75 degraded 0 id yes")
    app.wait_log(p + r"data yes uti public\.png orientation 1")
    app.wait_log(p + r"resource IMG_\d+\.PNG type 1 bytes yes error none")
    app.wait_log(p + r"saved 1 error none asset 40x30 album ObjC Album in album 1 albums 1 edit 1")
    app.wait_log(p + r"change inserted 1 removed 0 after 7 incremental 1 moves 0")
    app.wait_log(p + r"favourite 1 error none isFavorite 1 favorites 1 smart Favorites")
    app.wait_log(p + r"ready")
    app.tap_id("pick")
    app.wait_log(p + r"picker limit 2 filter yes delegate 1")
    app.wait_view(r"id=photo-1")
    app.wait_still()
    app.tap_id("photo-0")
    app.tap_id("photo-1")
    app.tap_id("photos-done")
    app.wait_log(p + r"picked 2 identifiers 1")
    app.wait_log(p + r"picked image \d+x\d+")
    app.wait_view(r"id=photos-done", gone=True)
    assert app.quit() == 0
