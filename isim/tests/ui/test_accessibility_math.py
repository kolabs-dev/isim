"""More of the Accessibility framework (issue #426; HelloSwiftUI -axmath): VoiceOver reads an AXMathExpressionProvider's
math expression as speech; on iOS 26 a phrase is translated to braille with the default English table and back
(liblouis on the host); without the entitlement, a feature override session is refused (iOS 18.2)."""
import os
import re

import pytest

pytestmark = pytest.mark.os_matrix
LIBLOUIS = os.path.isdir(os.environ.get("LOUIS_TABLEPATH", "/usr/share/liblouis/tables"))


def test_accessibility_math(launch, ios):
    version = float(ios[0] or 18)
    app = launch("HelloSwiftUI", args=["-axmath"])
    app.wait_view(r"id=equation")
    if version < 26:
        app.wait_log(r"^ax braille needs iOS 26$")
    elif not LIBLOUIS:
        app.wait_log(r"^ax braille no tables$")
    else:
        m = app.wait_log(r"^ax braille true org\.liblouis\.(\S+) en eight=false (\S+) back=(.*) last=(.)$")
        assert (m.group(1), m.group(2), m.group(3), m.group(4)) == ("en-ueb-g2", "⠠⠓⠑⠇⠇⠕⠀⠸⠺", "Hello world", "w"), \
            "Unified English Braille (contracted: world is ⠸⠺), back-translated; the last cell comes from the w"
    app.wait_still()
    app.screenshot("math-braille")

    app.send("voiceover on")
    app.send("voiceover focus equation")
    if version >= 18.2:
        app.wait_log(r'VoiceOver: "Quadratic formula, x equals start fraction, minus b plus or minus square root of b squared minus 4 a c, '
                     r'end root over 2 a, end fraction')
    else:
        app.wait_log(r'VoiceOver: "Quadratic formula"')
    app.send("voiceover off")

    app.tap_id("override")
    if version >= 18.2:
        app.wait_log(r"^ax override error AXFeatureOverrideSessionErrorDomain 1 notEntitled=true$")
        assert "does not have the com.apple.developer.accessibility.feature-override entitlement" in app.log
    else:
        app.wait_log(r"^ax override needs iOS 18\.2$")
    assert app.quit() == 0
