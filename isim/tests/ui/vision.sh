#!/usr/bin/env bash
# UI test: Vision, Core ML, NaturalLanguage, Speech and VisionKit (HelloVision sample).
# - Vision barcodes run on the host's libzbar (two generated QR codes; boxes drawn from the observations are checked in
#   the screenshot); region of interest and orientation; text recognition needs the host's tesseract (otherwise the
#   request must fail with a clear message); face detection must fail with VNErrorCode.unsupportedRequest (19).
# - Core ML: model specs written by gen_models.py: GLM regressor and classifier predictions, a neural network spec that
#   loads but cannot run, an Xcode-compiled bundle that cannot load.
# - NaturalLanguage tokenization, language recognition, lexical classes, sentiment.
# - Speech: the authorization alert (tapped); recognition needs whisper.cpp or Vosk (otherwise a clear error).
# - VisionKit: DataScannerViewController.isSupported is false and startScanning throws.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
app=out/apps/HelloVision.app
[ -x $app/HelloVision ] || { echo "SKIP  HelloVision not built"; exit 0; }
export ISIM_DATA=$PWD/out/test-data/vision; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA"
shots=out/test-shots/HelloVision; mkdir -p "$shots"; rm -f "$shots"/*.png
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone17} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 \
      ISIM_SCRIPT="wait 1; dump; taptext Allow; wait 1.5; shot $shots/vision.png; dump; quit" timeout 60 out/bin/isim run $app 2>&1); rc=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
has() { grep -Eq "$1" <<<"$log"; }
px() { magick "$1" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info:; }
greenish() { local c; read -r -a c <<<"$(px "$1" "$2" "$3")"; [ "${c[1]}" -gt 150 ] && [ "${c[0]}" -lt 110 ] && [ "${c[2]}" -lt 130 ]; }
if [ -f $app/codes.png ] && ldconfig -p 2>/dev/null | grep 'libzbar\.so\.0' >/dev/null; then
  check "VNDetectBarcodesRequest: two QR codes, payloads, boxes"  'has "barcodes 2: qr .left code. box=0.(0[6-9]|1[0-2]),0.2[6-9],0.(19|2[0-3]),0.(39|4[0-4]); qr .right code. box=0.(6[7-9]|7[0-3]),0.2[6-9],0.(19|2[0-3]),0.(39|4[0-4])"'
  check "observation boxes drawn over the picture (pixels)"       'greenish $shots/vision.png 79 190 && greenish $shots/vision.png 264 190'
  check "regionOfInterest (right half)"                            'has "roi barcodes \[\"right code\"\]"'
  check "orientation .right"                                       'has "rotated barcodes 2"'
  check "symbology filter (EAN-13 only: none)"                     'has "ean13 only 0"'
else echo "SKIP  barcode checks (need qrencode at build time and libzbar)"; fi
if command -v tesseract >/dev/null; then
  check "VNRecognizeTextRequest (tesseract)"                       'has "text recognized \[\"HELLO ISIM\"\]"'
else
  check "VNRecognizeTextRequest without tesseract: clear error"   'has "text unavailable: text recognition on isim needs the host.s tesseract command"'
fi
check "VNDetectFaceRectanglesRequest: unsupportedRequest (19)"     'has "face completion error=face detection is not available on isim" && has "faces error com.apple.Vision 19"'
check "MLMultiArray shape/strides/subscripts"                      'has "multiarray count=6 strides=\[3, 1\] \[1,2\]=7.5 \[0\]=1.0"'
check "MLModel.compileModel + description + metadata"              'has "regressor inputs=\[\"x1\", \"x2\"\] output=y meta=.y = 2 x1 \+ 3 x2 \+ 1."'
check "GLM regressor prediction"                                   'has "regressor y=9.00"'
check "GLM classifier prediction + probabilities"                  'has "classifier label=dog p\(dog\)=0.88 p\(cat\)=0.12 labels=2"'
check "neural network: described, prediction fails clearly"        'has "neural loaded inputs=\[\"image\"\] type=4" && has "neural prediction error: isim cannot run neuralNetwork models"'
check "Xcode-compiled .mlmodelc: clear load error"                 'has "xcode-compiled model error: XcodeCompiled.mlmodelc is a model compiled by Xcode"'
check "NLTokenizer words (contractions, abbreviations, decimals)"   'has "words \[\"Hello\", \"world\", \"Don..?t\", \"stop\", \"Mr\", \"Smith\", \"paid\", \"3.50\", \"dollars\"\]"'
check "NLTokenizer sentences (Mr. is not a sentence end)"          'has "sentences 3"'
check "NLLanguageRecognizer (en, fr, de, es, ja, ru)"              'has "languages en,fr,de,es,ja,ru"'
check "language hypotheses"                                        'has "hypotheses top=fr count=2 sum<=1 true"'
check "NLTagger lexical classes"                                   'has "lexical Determiner Adjective Adjective Noun Verb Preposition Determiner Adjective Noun"'
check "NLTagger sentiment"                                         'has "sentiment .I love this, it is wonderful. 1.0" && has "sentiment .This is terrible and awful. -1.0"'
check "Speech authorization alert, allowed"                        'has "text=“Vision Demo” Would Like to Access Speech Recognition" && has "speech authorization 3"'
if [ -n "${ISIM_WHISPER_MODEL:-}${ISIM_VOSK_MODEL:-}" ]; then
  check "speech recognition (host engine)"                        'has "speech transcription .*hello.* final=true"'
else
  check "speech recognition unavailable without an engine"        'has "speech recognizer en-US available=false xx=nil" && has "speech error: speech recognition is not available on this host" && has "id=speech text=unavailable"'
fi
check "VisionKit DataScannerViewController unsupported"            'has "datascanner supported=false available=false documentCamera=false" && has "datascanner startScanning throws unsupported"'
check "exits cleanly"                                              '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; grep -v "^ " <<<"$log" | tail -50; }
exit $fail
