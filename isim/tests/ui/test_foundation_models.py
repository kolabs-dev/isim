"""Foundation Models (HelloFoundationModels, issue #281): with no model configured on the host the system model is
unavailable (Apple Intelligence not enabled on an eligible iPhone, the device not eligible on an iPhone 15) and a
session's requests fail with GenerationError.assetsUnavailable while the transcript records them; @Generable /
@Guide types (a struct, an enum, a tool's arguments) get their schema, generated content round trips, partial JSON,
dynamic schemas, builders and options. Foundation Models is iOS 26: these run under iOS 26."""
import re

import pytest

CHECKS = [   # what, log regex
    ("@Generable schema: guides, descriptions, enum cases, optional left out of required",
     r"schema 1111111 required true"),
    ("GeneratedContent -> Recipe", r"recipe Pancakes 20 mix,rest,fry veg true rating nil easy"),
    ("Recipe -> GeneratedContent, keys in order",
     r'roundtrip \{"name": "Pancakes", "minutes": 20, "steps": \["mix", "rest", "fry"\], "vegetarian": true, "rating": null, "difficulty": "easy"\}'),
    ("value(forProperty:)", r"property Pancakes steps 3 complete true"),
    ("unfinished JSON: PartiallyGenerated", r"partial complete false name Pan minutes nil"),
    ("a missing property fails to decode", r"missing property decodingFailure"),
    ("GeneratedContent(properties:)", r'properties \{"a": 1, "b": "two", "c": \[true, false\]\}'),
    ("respond without a model", r"respond assetsUnavailable: the system language model is unavailable: "),
    ("generating a Generable type fails the same way", r"generating fails too true"),
    ("streamResponse fails, nothing streamed", r"stream fails, snapshots 0"),
    ("transcript: instructions (with the tool), the prompts",
     r"transcript 4 entries, 3 prompts, tools 1, instructions 'You are a cook\. \| Answer briefly\.' responding false"),
    ("a Tool: its parameters from its Generable arguments, its call", r"tool getWeather parameters true output Sunny in Paris"),
    ("PromptBuilder with a condition, recorded in the transcript", r"prompt 'Suggest a dish\. \| List the steps\.'"),
    ("GenerationOptions", r"options temperature 0\.7 tokens 100 greedy false"),
    ("DynamicGenerationSchema with a reference", r"dynamic true required true"),
    ("an undefined reference", r'undefined references \["Pet"\]'),
]


@pytest.mark.parametrize("device,reason", [("iphone17", "appleIntelligenceNotEnabled"), ("iphone15", "deviceNotEligible")])
def test_foundation_models(launch, device, reason):
    app = launch("HelloFoundationModels", device=device, os_version="26")
    app.wait_log(r"HelloFoundationModels: done")
    app.wait_log(rf"availability unavailable\({reason}\) isAvailable false english true")
    for what, rx in CHECKS:
        assert re.search(rx, app.log), what
    app.wait_view(rf"id=status text=unavailable\({reason}\)")
    assert app.quit() == 0


def test_foundation_models_ios18(launch):
    """before iOS 26 the app's availability check keeps it from the framework"""
    app = launch("HelloFoundationModels", device="iphone16pro", os_version="18")
    app.wait_log(r"foundation models need iOS 26")
    assert app.quit() == 0
