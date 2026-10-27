"""PencilKit from Objective-C (issue #360): PencilKitTest.app checks stroke paths (interpolation by parametric value,
distance and time, Bézier conversion, subpaths), inks, strokes (bounds, masks, substrokes), drawings (isim's data
format, secure coding, transforms, erasing, images) and the tool picker's items."""
from isimtest import need_apps, selftest


def test_pencilkit(device_data):
    need_apps("PencilKitTest")
    selftest("PencilKitTest", data=device_data)
