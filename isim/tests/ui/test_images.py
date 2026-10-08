"""UIKit drawing (HelloImages): UIGraphicsImageRenderer, PNG/JPEG export and UIImage(data:) round trips,
UIGraphicsBeginImageContext, NSString/NSAttributedString drawing and measuring, UILabel.attributedText.
Port of tests/ui/images.sh."""
import re

from isimtest import close, count_px


def test_images(launch):
    app = launch("HelloImages")
    app.wait_log(r"measured \d+x\d+")
    shot = app.wait_shot(lambda s: close(s, 40, 140, (255, 59, 48)), "renderer drew the red circle")
    dump = app.view_dump()
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    assert "badge size 120x120 scale 3" in log, "renderer image at screen scale"
    assert close(shot, 40, 140, (255, 59, 48)) and close(shot, 80, 140, (255, 255, 255)), \
        "renderer drew the red circle + bar"
    assert re.search(r"png [0-9]+ bytes sig 89504e47, decoded 120x120", log) and close(shot, 180, 140, (255, 59, 48)), \
        "PNG export + UIImage(data:)"
    assert re.search(r"jpeg [0-9]+ bytes sig ffd8", log), "JPEG export"
    assert "renderer png decodes: true" in log, "renderer pngData decodes"
    assert "context image 40x40 scale 2" in log and close(shot, 320, 140, (52, 199, 89)), "UIGraphicsBeginImageContext"
    assert re.search(r"UILabel \(20 230; 2[0-9][0-9] x 30\) id=attributed", dump), "attributed label: one line, sized"
    red = count_px(shot, (70, 232, 60, 30), lambda c: c[0] > 0.85 * 255 and c[1] < 0.4 * 255 and c[2] < 0.35 * 255)
    assert close(shot, 250, 236, (255, 204, 0)) and red > 0.02 * 60 * 30, "attributed runs: red, highlighted"
    assert re.search(r"measured 1[0-9][0-9]x3[0-9], wrapped height [4-9][0-9]", log), "measuring with attributes"
    blue = count_px(shot, (12, 336, 220, 26), lambda c: c[2] > 0.7 * 255 and c[1] < 0.5 * 255)
    assert blue > 0.01 * 220 * 26, "string drawing in draw(_:)"
