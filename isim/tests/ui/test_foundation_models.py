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


# ---- a model backend (issue #277): an OpenAI-compatible server, scripted here ----
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

RECIPE = {"name": "Omelette", "minutes": 10, "steps": ["beat", "pour", "fold"], "vegetarian": True, "difficulty": "easy"}


class _Model(BaseHTTPRequestHandler):
    """/v1/chat/completions, streamed as server-sent events: a tool call when the session has tools and the user
    asks about the weather (then the answer that uses the tool's output), JSON for a response_format, text otherwise"""
    requests = []

    def log_message(self, *a):
        pass

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        _Model.requests.append({"path": self.path, **body})
        msgs = body["messages"]
        last = msgs[-1]
        if last["role"] == "tool":
            chunks = [{"content": "It is "}, {"content": last["content"].lower() + "."}]
        elif body.get("tools") and "weather" in (last.get("content") or ""):
            chunks = [{"tool_calls": [{"index": 0, "id": "call_1", "type": "function",
                                       "function": {"name": "getWeather", "arguments": '{"city": '}}]},
                      {"tool_calls": [{"index": 0, "function": {"arguments": '"Paris"}'}}]}]
        elif body.get("response_format"):
            text = json.dumps(RECIPE)
            chunks = [{"content": text[:12]}, {"content": text[12:30]}, {"content": text[30:]}]
        else:
            chunks = [{"content": "Hello "}, {"content": "from the model"}]
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        for c in chunks:
            self.wfile.write(b"data: " + json.dumps({"choices": [{"index": 0, "delta": c}]}).encode() + b"\n\n")
            self.wfile.flush()
        self.wfile.write(b"data: [DONE]\n\n")


def test_foundation_models_backend(launch):
    """passthrough to an OpenAI-compatible server (ISIM_LLM_URL): text, a Generable response through response_format,
    a stream of partial JSON, and a tool round (the tool's output goes back to the model)"""
    _Model.requests = []
    server = ThreadingHTTPServer(("127.0.0.1", 0), _Model)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        url = f"http://127.0.0.1:{server.server_address[1]}/v1"
        app = launch("HelloFoundationModels", device="iphone17", os_version="26",
                     env={"ISIM_LLM_URL": url, "ISIM_LLM_MODEL": "test-model"})
        app.wait_log(r"HelloFoundationModels: done", timeout=60)
        log = app.log
        assert "availability available isAvailable true" in log
        assert "live error" not in log, re.search(r"live error.*", log)[0]
        assert "live text 'Hello from the model'" in log, "text response"
        assert "live recipe Omelette 10 3 steps easy" in log, "a Generable response"
        assert re.search(r"live stream snapshots>1 true names \[.*\"Omelette\"\]", log), "partial snapshots while streaming"
        assert "live tool 'It is sunny in paris.' entries [\"prompt\", \"calls(getWeather)\", \"output(Sunny in Paris)\", \"response\"]" in log, \
            "the tool call round"
        assert "live transcript 11 responding false" in log, "instructions, 3 requests and their responses, a request with a tool round"
        assert app.quit() == 0
    finally:
        server.shutdown()
    r = _Model.requests
    assert all(q["path"] == "/v1/chat/completions" and q["stream"] and q["model"] == "test-model" for q in r)
    assert r[0]["messages"][0] == {"role": "system", "content": "You are a cook."} and r[0]["temperature"] == 0.2
    assert r[0]["tools"][0]["function"]["name"] == "getWeather" and "city" in r[0]["tools"][0]["function"]["parameters"]["properties"]
    fmt = r[1]["response_format"]
    assert fmt["type"] == "json_schema" and fmt["json_schema"]["name"] == "Recipe"
    assert fmt["json_schema"]["schema"]["properties"]["minutes"]["maximum"] == 240
    assert [m["role"] for m in r[1]["messages"]] == ["system", "user", "assistant", "user"], "the conversation so far"
    tool_round = [q for q in r if q["messages"][-1]["role"] == "tool"]
    assert tool_round and tool_round[0]["messages"][-1] == {"role": "tool", "content": "Sunny in Paris", "tool_call_id": "call_1"}
