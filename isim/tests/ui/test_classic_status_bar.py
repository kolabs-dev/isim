"""The status bar of iPhones with a Home button (iPhone SE, issue #123): the classic 20 pt bar, with the cellular bars,
the carrier name and Wi-Fi at the left, the time centred ("9:41 AM") and the battery at the right, unlike the Face ID
iPhones' clock at the left. System UI: os_matrix."""
import pytest
from isimtest import count_px


@pytest.mark.os_matrix
def test_classic_status_bar(launch, ios):
    app = launch("HelloKeyboardTypes", device="iphonese", os_version=ios[0])
    ink = lambda c: max(c) < 120                           # the dark status bar text and icons over the white app
    # points (boxes are x, y, width, height): bars 6-20, "Carrier" 25-65, Wi-Fi 70-83, the time 166-208, the battery
    # 346-361; rows 4-14
    img = app.wait_shot(lambda s: count_px(s, (160, 3, 55, 12), ink) > 20, "the time drawn in the middle")
    assert count_px(img, (5, 3, 16, 12), ink) > 10, "the cellular bars at the left edge"
    assert count_px(img, (24, 3, 43, 12), ink) > 20, "the carrier name right of them"
    assert count_px(img, (69, 3, 16, 12), ink) > 5, "Wi-Fi right of the carrier name"
    assert count_px(img, (90, 1, 67, 17), ink) == 0, "nothing between Wi-Fi and the time"
    assert count_px(img, (220, 1, 120, 17), ink) == 0, "nothing between the time and the battery"
    assert count_px(img, (344, 3, 26, 12), ink) > 20, "the battery at the right edge"
    assert app.quit() == 0, "exits cleanly"
