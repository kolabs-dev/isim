"""Core ML models compiled by `isim build` (HelloCoreMLModels, issue #213): .mlmodel files and an .mlpackage in an
Xcode project become <Name>.mlmodelc in the app (isim's format: the model spec) and Xcode's generated classes
(<Name>, <Name>Input, <Name>Output: init(configuration:), load(configuration:), prediction(<inputs>:),
prediction(input:), predictions(inputs:)), which run the models with MLModelConfiguration."""
import re
from pathlib import Path

from isimtest import ROOT

OUT = ROOT / "out"


def test_generated_model_classes():
    gen = OUT / "projects" / "HelloCoreMLModels" / "obj" / "HelloCoreMLModels" / "DerivedSources" / "CoreMLGenerated"
    swift = (gen / "Pricing.swift").read_text()
    assert "class PricingInput : MLFeatureProvider" in swift and "var rooms: Int64" in swift and "var area: Double" in swift
    assert "func prediction(rooms: Int64, area: Double) throws -> PricingOutput" in swift
    assert "convenience init(configuration: MLModelConfiguration) throws" in swift
    app = OUT / "apps" / "HelloCoreMLModels.app"
    for n in ("Regressor", "Classifier", "Pricing"):
        assert (app / f"{n}.mlmodelc" / "model.mlmodel").is_file(), f"{n}.mlmodelc in the app"
    assert not list(app.glob("*.mlmodel")) and not list(app.glob("*.mlpackage")), "the source models are not copied"


def test_coreml_models(launch):
    app = launch("HelloCoreMLModels")
    app.wait_log(r"^cml done$")
    log = app.log
    for pattern in (r"Regressor\(x1: 1, x2: 2\)\.y = 9\.0", r"Regressor input class: y = 5\.0", r"Regressor batch: \[1\.0, 6\.0\]",
                    r"Regressor description: inputs \[\"x1\", \"x2\"\]", r"Classifier: dog cat=0\.119",
                    r"Pricing\(rooms: 3, area: 80\)\.price = 90\.0", r"bundle: Pricing\.mlmodelc"):
        assert re.search(r"^cml " + pattern + "$", log, re.M), f"{pattern}: {[l for l in log.splitlines() if l.startswith('cml ')]}"
    app.wait_view(r"text=Pricing")
    app.screenshot("coreml-models")
    assert app.quit() == 0
