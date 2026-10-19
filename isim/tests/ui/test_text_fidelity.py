"""Text drawing fidelity (HelloTextFidelity, issue #243): UILabel's shadowColor / shadowOffset (a hard, offset copy of
the text), NSShadow on attributed text in a label, a text view and string drawing into an image (blurred, in its
colour, only under the ranges that carry it), an NSTextAttachment image laid out inside a label's text,
UIButton.imageView (the current image at its frame; its isHidden applies) and UIRefreshControl.attributedTitle drawn
under the spinner."""


def pixels(img, rect, match):
    x, y, w, h = rect
    return sum(1 for j in range(y, y + h) for i in range(x, x + w) if match(*img.getpixel((i, j))))


def red(r, g, b):
    return r > 180 and g < 90 and b < 90


def blue(r, g, b):
    return b > 150 and r < 140 and g < 140


def green(r, g, b):
    return g > 180 and r < 60 and b < 60


def orange(r, g, b):
    return r > 200 and 100 < g < 190 and b < 60


def purple(r, g, b):
    return r > 90 and b > 90 and g < 80


def test_text_fidelity(launch):
    app = launch("HelloTextFidelity")
    app.wait_log(r"^label shadow color=true offset=4,4 default=-1$")             # UILabel's default: (0, -1)
    app.wait_log(r"^nsshadow default offset=-3 equal=true$")                      # NSShadow's default: (0, -3)
    app.wait_log(r"^attachment label wider=true$")                                # the attachment takes room
    app.wait_log(r"^button imageView image=20x20 frame=20x20 same=true$")
    app.wait_log(r"^no image imageView=true$")
    app.wait_log(r"^render shadow red=true none=true partial=true$")              # string drawing: per range
    app.wait_log(r"^render attachment green=true$")
    app.wait_log(r"^refresh title=Updating label=Updating$")
    app.wait_view(r"UIRefreshControl .*title 'Updating'")

    shot = app.wait_shot_still()
    assert pixels(shot, (20, 70, 360, 60), red) > 100, "UILabel.shadowColor: a red copy of the text"
    assert pixels(shot, (20, 136, 360, 66), blue) > 100, "NSShadow in a label: a blue, blurred shadow"
    assert pixels(shot, (20, 202, 360, 40), green) > 300, "NSTextAttachment: the image inside the label's text"
    assert pixels(shot, (20, 250, 360, 60), red) > 50, "NSShadow in a text view"
    assert pixels(shot, (20, 320, 200, 44), orange) > 200, "the button's image"
    assert pixels(shot, (230, 320, 150, 44), green) == 0, "imageView.isHidden hides the button's image"
    assert pixels(shot, (0, 560, 402, 70), purple) > 20, "the refresh control's attributed title, in its colour"
    assert app.quit() == 0, "exits cleanly"
