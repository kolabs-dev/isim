"""Xcode's generated asset symbols (HelloAssetSymbols, built by `isim build`, issue #210): GeneratedAssetSymbols.swift
gives ColorResource / ImageResource members for Assets.xcassets ("AccentColor" -> .accent, "hero-image" -> .hero) and,
with ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS, UIColor / UIImage / Color / ShapeStyle members;
UIColor(resource:) keeps the dark variant; a missing image is empty; GeneratedAssetSymbols.h names the assets for
Objective-C."""
import re
from pathlib import Path

from isimtest import rgb, screen_frames

OUT = Path(__file__).resolve().parents[2] / "out"


def test_generated_asset_symbols_source():
    gen = OUT / "projects" / "HelloAssetSymbols" / "obj" / "HelloAssetSymbols" / "DerivedSources"
    swift = (gen / "GeneratedAssetSymbols.swift").read_text()
    assert 'static let accent = DeveloperToolsSupport.ColorResource(name: "AccentColor", bundle: resourceBundle)' in swift
    assert 'static let hero = DeveloperToolsSupport.ImageResource(name: "hero-image", bundle: resourceBundle)' in swift
    assert "static var brandBlue: UIKit.UIColor" in swift and "extension SwiftUI.ShapeStyle where Self == SwiftUI.Color" in swift
    assert 'ACImageNameHeroImage AC_SWIFT_PRIVATE = @"hero-image"' in (gen / "GeneratedAssetSymbols.h").read_text()


def test_asset_symbols(launch):
    app = launch("HelloAssetSymbols")
    app.wait_log(r"^asym objc ")
    log = app.log
    assert re.search(r"^asym ColorResource\.brandBlue light=16,64,208 dark=112,160,255$", log, re.M), "UIColor(resource:), both appearances"
    assert re.search(r"^asym UIColor\.brandBlue=16,64,208 UIColor\.accent=255,128,0$", log, re.M), "generated UIColor members"
    assert re.search(r"^asym UIImage\(resource: \.logo\) size=60x60$", log, re.M), "UIImage(resource:)"
    assert re.search(r"^asym UIImage\.hero size=120x40$", log, re.M), "generated UIImage member"
    assert re.search(r"^asym missing size=0$", log, re.M), "a missing asset: an empty image"
    assert re.search(r"^asym objc BrandBlue hero-image color=1 image=120x40$", log, re.M), "GeneratedAssetSymbols.h from Objective-C"
    app.wait_view(r"id=brand-box")
    app.wait_still()
    f = screen_frames(app.view_dump())
    img = app.screenshot("asset-symbols")
    x, y, w, h = f["brand-box"]
    assert rgb(img, round(x + w / 2), round(y + h / 2)) == (16, 64, 208), "Color(.brandBlue) fills the box"
    x, y, w, h = f["logo"]
    assert rgb(img, round(x + w / 2), round(y + h / 2)) == (46, 125, 50), "Image(.logo) draws the catalog image"
    assert app.quit() == 0


def test_asset_symbols_dark(launch):
    app = launch("HelloAssetSymbols", env={"ISIM_APPEARANCE": "dark"})
    app.wait_view(r"id=brand-box")
    app.wait_still()
    f = screen_frames(app.view_dump())
    x, y, w, h = f["brand-box"]
    assert rgb(app.screenshot("dark"), round(x + w / 2), round(y + h / 2)) == (112, 160, 255), "the dark variant in dark mode"
    assert app.quit() == 0
