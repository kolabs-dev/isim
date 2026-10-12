# isim's icon

The app icon of isim Simulator in the desktop's launcher and dock: a phone with a terminal prompt on its screen. It is
isim's own drawing (Apache-2.0, like the rest of isim), not Apple artwork.

- `isim.svg`: the icon, used at 48 px and up.
- `isim-small.svg`: a simplified variant for 16–32 px (thicker phone, no Dynamic Island, heavier prompt), so the
  small sizes stay readable.

`build.py` renders them to `out/share/icons/hicolor/<size>/apps/dev.isim.Simulator.png` (16–512 px, with librsvg
and cairo, `buildlib/icons.py`) and copies `isim.svg` to `scalable/apps/dev.isim.Simulator.svg`. Release tarballs
carry `share/icons`. `isim desktop install` copies them into the user's icon theme, and the runtime sets the 256 px
PNG as its window icon.
