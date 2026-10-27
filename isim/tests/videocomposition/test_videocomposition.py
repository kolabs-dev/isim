"""AVFoundation video compositions (issue #381): VideoCompositionTest.app exports a two-track composition through
instructions (a cross-fade, a transform, a crop, a background color), a custom AVVideoCompositing class, Core Image
filtering and the Core Animation tool, and checks the frames' pixels, the requests the compositor sees, validation and
the iOS 26 configuration types."""
import pytest

from isimtest import need_apps, selftest


@pytest.mark.os_matrix
def test_videocomposition(device_data, ios):
    need_apps("VideoCompositionTest")
    selftest("VideoCompositionTest", data=device_data, os_version=ios[0], timeout=240)
