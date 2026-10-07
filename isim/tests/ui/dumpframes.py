"""Frames from a `dump` view tree (isim script command): screen frames of the views by accessibility identifier.

    from dumpframes import frames
    f = frames(log_text)          # {id: (x, y, w, h)} in screen points, from the last dump in the log
    f = frames(log_text, which=0) # from the first dump

Frames printed by `dump` are relative to the superview; scroll views print their vertical offset ("text=offset Y"),
which moves their subviews. View transforms are not applied (the layout frame is returned)."""
import re

LINE = re.compile(r'^( *)(\S+) \((-?[\d.e+-]+) (-?[\d.e+-]+); (-?[\d.e+-]+) x (-?[\d.e+-]+)\)(.*)$')


def dumps(text):
    """the dumps in a log: lists of line matches, each dump starting at an unindented 'UIWindow' line"""
    out, cur = [], None
    for line in text.splitlines():
        m = LINE.match(line)
        if m and not m.group(1) and m.group(2) == 'UIWindow':      # the app's window starts a dump (other windows,
            cur = []; out.append(cur)                               # e.g. the keyboard's, belong to it)
        if cur is not None and m:
            cur.append(m)
    return out


def frames(text, which=-1):
    ds = dumps(text)
    if not ds:
        return {}
    res, stack = {}, []        # stack of (depth, abs_x, abs_y, scroll_y)
    for m in ds[which]:
        depth = len(m.group(1)) // 2
        x, y, w, h = (float(m.group(i)) for i in range(3, 7))
        while stack and stack[-1][0] >= depth:
            stack.pop()
        px, py, sy = (stack[-1][1], stack[-1][2], stack[-1][3]) if stack else (0, 0, 0)
        ax, ay = px + x, py + y - sy
        rest = m.group(7)
        off = re.search(r'text=offset (-?[\d.e+-]+),', rest)
        stack.append((depth, ax, ay, float(off.group(1)) if off else 0))
        ident = re.search(r' id=(\S+)', rest)
        if ident and ident.group(1) not in res:
            res[ident.group(1)] = (ax, ay, w, h)
    return res
