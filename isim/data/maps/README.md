# Map data

`land-50m.bin` and `land-10m.bin` are the land polygons of [Natural Earth](https://www.naturalearthdata.com)
(1:50m and 1:10m physical "land", public domain), converted by `tools/make-land.py` for MapKit's offline basemap
(`swift/overlays/MapKit/Land.swift`). The build copies them into the SDK (`usr/share/isim/maps/`).

To regenerate them from Natural Earth's GeoJSON (e.g. `ne_50m_land.geojson` from
https://github.com/nvkelso/natural-earth-vector):

```bash
python3 isim/tools/make-land.py ne_50m_land.geojson isim/data/maps/land-50m.bin
python3 isim/tools/make-land.py ne_10m_land.geojson isim/data/maps/land-10m.bin
```
