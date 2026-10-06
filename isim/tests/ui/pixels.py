"""Pixel helpers for UI tests: load a screenshot (via ImageMagick) and measure runs of colored pixels.

    from pixels import Image
    im = Image("shot.png")
    im.rgb(x, y); im.runs_x(y, x0, x1, pred); im.first_y(x, y0, y1, pred)
"""
import subprocess


class Image:
    def __init__(self, path):
        data = subprocess.run(["magick", path, "-depth", "8", "ppm:-"], check=True, capture_output=True).stdout
        # P6 header: magic, width, height, maxval (whitespace separated), then RGB bytes
        fields, pos = [], 0
        while len(fields) < 4:
            while data[pos:pos + 1].isspace():
                pos += 1
            start = pos
            while not data[pos:pos + 1].isspace():
                pos += 1
            fields.append(data[start:pos])
        pos += 1
        self.w, self.h = int(fields[1]), int(fields[2])
        self.px = data[pos:]

    def rgb(self, x, y):
        x, y = int(round(x)), int(round(y))
        i = 3 * (y * self.w + x)
        return self.px[i], self.px[i + 1], self.px[i + 2]

    def runs_x(self, y, x0, x1, pred):
        """[(start, end)] of horizontal runs (end exclusive) where pred(r, g, b) holds on row y."""
        out, start = [], None
        for x in range(int(x0), int(x1)):
            if pred(*self.rgb(x, y)):
                if start is None:
                    start = x
            elif start is not None:
                out.append((start, x)); start = None
        if start is not None:
            out.append((start, int(x1)))
        return out

    def runs_y(self, x, y0, y1, pred):
        out, start = [], None
        for y in range(int(y0), int(y1)):
            if pred(*self.rgb(x, y)):
                if start is None:
                    start = y
            elif start is not None:
                out.append((start, y)); start = None
        if start is not None:
            out.append((start, int(y1)))
        return out

    def first_y(self, x, y0, y1, pred):
        """First y from y0 towards y1 (either direction) where pred holds, or None."""
        step = 1 if y1 >= y0 else -1
        for y in range(int(y0), int(y1), step):
            if pred(*self.rgb(x, y)):
                return y
        return None


def white(r, g, b):
    return r > 235 and g > 235 and b > 235


def near(a, b, tol):
    return abs(a - b) <= tol
