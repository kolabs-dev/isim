"""QLPreviewController and UIReferenceLibraryViewController (HelloQuickLook): an image, a PDF (pages rendered), text
and JSON, a video (played to the end) and an unknown file (name, kind, size), swiping between them; Done tells the
delegate; pushed with currentPreviewItemIndex; the dictionary without definitions (like a Simulator without
downloaded dictionaries). The video needs ffmpeg."""
import os
import shutil
import subprocess

import pytest

APP = "dev.isim.samples.HelloQuickLook"


@pytest.mark.skipif(not shutil.which("ffmpeg"), reason="the video needs ffmpeg")
def test_quicklook(launch, device_data):
    docs = device_data / "Containers" / APP / "Documents"
    docs.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc=s=320x240:r=30:d=2", "-f", "lavfi",
                    "-i", "sine=f=440:d=2", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", str(docs / "5-clip.mp4")],
                   check=True)
    (docs / "6-archive.xyz").write_bytes(os.urandom(3000))
    app = launch("HelloQuickLook")
    app.wait_log(r'files \["1-photo.png", "2-report.pdf", "3-notes.txt", "4-data.json", "5-clip.mp4", "6-archive.xyz"\] previewable=6')

    def swipe(n, what):
        app.drag(350, 450, 50, 450, seconds=0.25)
        app.wait_log(rf"QuickLook: item {n} of 6: {what}")

    app.wait_tap_id("preview")
    app.wait_log(r"QuickLook: item 1 of 6: 1-photo.png \(image\)")
    app.wait_view(r"id=ql-image")
    swipe(2, r"2-report.pdf \(pdf\)")
    app.wait_view(r"id=ql-pdf-page-2")                                 # both pages rendered
    swipe(3, r"3-notes.txt \(text\)")
    app.wait_view(r'id=ql-text text="Quick Look shows text files.\\nSecond line."')
    swipe(4, r"4-data.json \(text\)")
    swipe(5, r"5-clip.mp4 \(media\)")
    app.wait_tap_id("ql-play")
    app.wait_log(r"QuickLook: playing 5-clip.mp4")
    app.wait_view(r"id=ql-time text=0:01 / 0:02")
    app.wait_log(r"QuickLook: finished playing 5-clip.mp4")
    swipe(6, r"6-archive.xyz \(generic\)")
    app.wait_view(r"id=ql-generic-info text=XYZ Document · 3 KB")
    app.wait_tap_id("ql-done")
    app.wait_log(r"^quick look will dismiss at 5")
    app.wait_log(r"^quick look did dismiss")

    app.wait_tap_id("push")                                            # pushed, starting at the PDF
    app.wait_log(r"QuickLook: item 2 of 6: 2-report.pdf \(pdf\)", count=2)
    app.wait_view(r"id=ql-share")
    app.tap(30, 80)                                                    # back
    app.wait_tap_id("define")
    m = app.wait_log(r"^dictionary has apple=(true|false)")
    if m.group(1) == "false":                                          # no host WordNet: like the Simulator
        app.wait_view(r"id=dict-none text=No definition found.")
    app.wait_tap_id("dict-done")
    app.wait_view(r"id=dict-done", gone=True)
    assert app.quit() == 0, "exits cleanly"
