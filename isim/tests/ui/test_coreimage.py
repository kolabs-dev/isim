import pytest


def test_dump(launch, tmp_path):
    app = launch("HelloCoreImage")
    app.wait_log(r"ci checks done", timeout=300)
    app.screenshot().save("/tmp/claude-0/t/filters.png")
    print(app.log)
