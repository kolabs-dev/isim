"""Photos & camera (HelloPhotos): the photo library seeded with sample pictures, SwiftUI PhotosPicker (tap a photo ->
loadTransferable(Data) and (Image)), multi-selection, PHPickerViewController + NSItemProvider loadObject(UIImage),
UIImagePickerController (.photoLibrary; camera unavailable), the Photos permission alert (iOS 17+ buttons), PHAsset
fetch/sort, PHImageManager.requestImage scaling, PHAssetChangeRequest create + favorite, UIImageWriteToSavedPhotosAlbum
(add-only alert), AVCaptureDevice (no cameras; camera alert), pixels of the picked image, and limited access
(ISIM_PHOTOS_PERMISSION=limited). Port of tests/ui/photos.sh."""
import re

from isimtest import rgb


def test_photos(launch):
    app = launch("HelloPhotos")
    app.wait_tap_id("photosPicker")
    grid = app.wait_view(r"id=photo-5")
    app.wait_still()
    app.screenshot("photospicker")
    app.tap_id("photo-0")
    app.wait_log(r"^photosPicker Image ")
    picked_view = app.wait_view(r"id=pickedImage")
    picked = app.wait_shot(lambda s: (c := rgb(s, 45, 200))[0] > 230 and 90 < c[1] < 170 and c[2] < 130,
                           "picked image shown (sunset sample pixels)")
    app.wait_still()
    app.tap_id("photosPickerMulti")
    app.wait_view(r"id=photo-2")
    app.wait_still()
    app.tap_id("photo-1")
    app.tap_id("photo-2")
    app.tap_id("photos-done")
    app.wait_log(r"^photosPicker multi 2 items")                         # PhotosPicker multi-selection
    app.wait_view(r"id=photos-done", gone=True)
    app.wait_still()
    app.tap_id("phpicker")
    app.wait_view(r"id=photo-4")
    app.wait_still()
    app.tap_id("photo-3")
    app.tap_id("photo-4")
    app.tap_id("photos-done")
    app.wait_log(r"^phpicker loaded ")
    app.wait_view(r"id=photos-done", gone=True)
    app.wait_still()
    app.tap_id("imagePicker")
    image_picker = app.wait_view(r"id=photo-5")
    app.wait_still()
    app.tap_id("photo-5")
    app.wait_log(r"^imagePicker picked ")
    app.wait_view(r"id=photo-5", gone=True)
    app.wait_still()
    app.tap_id("library")
    permission = app.wait_view(r"text=Allow Full Access")
    app.screenshot("permission")
    app.tap_text("Allow Full Access")
    app.wait_log(r"^requestImage ")
    app.wait_tap_id("save")
    app.wait_log(r"^favorites ")
    app.tap_id("writeAlbum")
    app.wait_log(r"^writeToAlbum ")
    app.tap_id("camera")
    camera = app.wait_view(r"text=Allow")
    app.tap_text("Allow")
    app.wait_log(r"^capture session running ")
    assert app.quit() == 0, "exits cleanly"
    log = app.log + "\n" + "\n".join((grid, picked_view, image_picker, permission, camera))

    def has(p):
        return re.search(p, log, re.M)
    assert has(r"created the photo library with 6 sample pictures"), "library seeded with 6 sample pictures"
    assert "id=photo-5" in grid and "text=Photos" in grid, "PhotosPicker grid"
    assert has(r'^photosPicker data [0-9]* bytes types \["public.png"\] id nil') and \
        has(r"^photosPicker image 800x600") and has(r"^photosPicker Image ok"), "PhotosPicker -> loadTransferable(Data / Image)"
    c = rgb(picked, 45, 200)
    assert "id=pickedImage" in picked_view and c[0] > 230 and 90 < c[1] < 170 and c[2] < 130, \
        "picked image shown (sunset sample pixels)"
    assert has(r"^phpicker 2 results, assetIdentifier nil") and \
        has(r'^phpicker canLoad UIImage true types \["public.png"\]') and has(r"^phpicker loaded 800x600 main false"), \
        "PHPicker -> NSItemProvider loadObject(UIImage)"
    assert has(r"^imagePicker camera available false library true") and \
        has(r"^imagePicker picked 800x600 url IMG_0006.PNG"), "UIImagePickerController (.photoLibrary)"
    assert "text=“Photos Demo” Would Like to Access Your Photos" in permission and "text=Limit Access…" in permission \
        and "text=Shows your pictures." in permission, "Photos permission alert (iOS 17+)"
    assert has(r"^library status 3 old API 3") and has(r"^library 6 assets first 800x600") and \
        has(r"^requestImage 200x150 degraded false main true"), "full access -> fetch + sort + requestImage"
    assert has(r"^performChanges saved true placeholder true refetch 1 error 0") and has(r"^favorite true") and \
        has(r"^library 7 assets first 192x144") and has(r"^favorites 1 in Favorites"), \
        "PHAssetChangeRequest create + favorite"
    assert has(r"^writeToAlbum saved"), "UIImageWriteToSavedPhotosAlbum (full access)"
    assert has(r"^camera device none discovered 0") and \
        "text=“Photos Demo” Would Like to Access the Camera" in camera and has(r"^camera access true status 3") and \
        has(r"^capture session running true outputs 1 inputs 0"), "camera: no devices, permission alert"

    app = launch("HelloPhotos")                                         # answers + library persist
    app.wait_tap_id("library")
    app.wait_log(r"^library \d+ assets")
    app.tap_id("writeAlbum")
    app.wait_log(r"^writeToAlbum ")
    assert app.quit() == 0, "exits cleanly"
    log2 = app.log
    assert re.search(r"^library status 3", log2, re.M) and re.search(r"^library 8 assets", log2, re.M) and \
        re.search(r"^writeToAlbum saved", log2, re.M) and "Would Like" not in log2, "answers + library persist"


def test_photos_limited(launch):
    app = launch("HelloPhotos", env={"ISIM_PHOTOS_PERMISSION": "limited"})
    app.wait_tap_id("library")
    app.wait_log(r"^library \d+ assets")
    app.tap_id("save")
    app.wait_log(r"^library \d+ assets", count=2)
    app.quit()
    log = app.log
    assert re.search(r"^library status 4 old API 3", log, re.M) and re.search(r"^library 0 assets", log, re.M) and \
        re.search(r"^performChanges saved true placeholder true refetch 1", log, re.M) and \
        re.search(r"^library 1 assets first 192x144", log, re.M), "limited access: only the app’s own photos"


def test_photos_add_only(launch):
    app = launch("HelloPhotos")
    app.wait_tap_id("writeAlbum")
    alert = app.wait_view(r"text=Allow")
    app.tap_text("Allow")
    app.wait_log(r"^writeToAlbum ")
    app.wait_view(r"text=Allow", gone=True)
    app.tap_id("library")
    app.wait_view(r"text=Don’t Allow")
    app.tap_text("Don’t Allow")
    app.wait_log(r"^library \d+ assets")
    app.quit()
    log = app.log
    assert "text=“Photos Demo” Would Like to Add to your Photos" in alert and "text=Saves your drawings." in alert and \
        re.search(r"^writeToAlbum saved", log, re.M), "UIImageWriteToSavedPhotosAlbum add-only alert"
    assert re.search(r"^library status 2 old API 2", log, re.M) and re.search(r"^library 0 assets", log, re.M), \
        "Don’t Allow -> denied, nothing visible"
