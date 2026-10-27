"""Image Playground and Visual Intelligence (HelloImagePlayground, "Sticker Shop", issue #369). isim has no image
model: Image Playground is unavailable (isAvailable / supportsImagePlayground false, ImageCreator throws .unavailable,
or .notSupported on a device without Apple Intelligence), and the SwiftUI sheet and the view controller say so and end
as a cancellation. Visual Intelligence (iOS 26): the `visualintelligence LABELS` script command runs the apps' value
queries over SemanticContentDescriptor in the background and logs their results."""
import pytest

APP = "HelloImagePlayground"
BUNDLE = "dev.isim.samples.HelloImagePlayground"


def major(ios):
    return int(str(ios[0] or 18).split(".")[0])


@pytest.mark.os_matrix
def test_image_playground(launch, ios):
    app = launch(APP)
    app.wait_log(r"HelloImagePlayground: done")
    if major(ios) < 26:                                # --os 17 / 18 are x.0: before iOS 18.1
        assert "image playground needs iOS 18.1" in app.log
        assert app.quit() == 0
        return
    log = app.log
    assert "HelloImagePlayground: available false" in log and "HelloImagePlayground: supports false" in log
    assert "concepts 2 styles animation,illustration,sketch" in log
    assert 'all styles ["animation", "illustration", "sketch"] emoji emoji' in log
    assert "creator error unavailable Image creation is unavailable: this simulated device has no image model." in log
    assert "glyph true type public.heic" in log
    if major(ios) >= 27:                               # ImagePlaygroundOptions: iOS 26.4
        assert "options variety high true" in log
    app.wait_view(r"id=support text=Unavailable")

    app.wait_tap_id("sheet")                           # the SwiftUI sheet
    app.wait_view(r"id=imageplayground-unavailable text=Image Playground Unavailable")
    app.wait_still()
    app.screenshot("imageplayground-sheet")
    app.wait_tap_id("imageplayground-cancel")
    app.wait_log(r"HelloImagePlayground: sheet cancelled")

    app.wait_tap_id("controller")                      # ImagePlaygroundViewController
    app.wait_view(r"id=imageplayground-unavailable text=Image Playground Unavailable")
    app.wait_tap_id("imageplayground-cancel")
    app.wait_log(r"HelloImagePlayground: controller cancelled")
    assert app.quit() == 0


def test_image_creator_not_supported(launch):
    """a device without Apple Intelligence: ImageCreator throws .notSupported"""
    app = launch(APP, device="iphone15", os_version="26")
    app.wait_log(r"HelloImagePlayground: done")
    assert "creator error notSupported Image creation is not supported on this device." in app.log
    assert app.quit() == 0


def test_visual_intelligence(launch):
    dev = launch(None, install=[APP], os_version="26")
    dev.send("visualintelligence cat, plant")
    dev.wait_log(r"SpringBoard: Visual Intelligence asks Sticker Shop about “cat, plant”")
    dev.wait_log(r'HelloImagePlayground: visual search \["cat", "plant"\]')
    dev.wait_log(r"SpringBoard: Visual Intelligence: Sticker Shop: Sleepy Cat \(cat, animal, pet\), Pine Tree \(tree, plant, forest\)")
    dev.send("visualintelligence rocket")
    dev.wait_log(r"SpringBoard: Visual Intelligence: Sticker Shop: no results")
