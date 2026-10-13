#!/usr/bin/env python3
"""isim adattribution: development postbacks for an advertised app, like Settings › Developer › Ad Attribution Testing ›
Development Postbacks on a device in Developer Mode (AdAttributionKit; SKAdNetwork's updates count too).

  isim adattribution add BUNDLE_ID URL [--interaction click|view] [--conversion-type download|redownload|re-engagement]
                         [--source-id 1234] [--windows 1|3] [--tag TAG] [--country US]
  isim adattribution list
  isim adattribution transmit        send the eligible postbacks to their URL now ("Transmit Development Postbacks")
  isim adattribution clear           delete every development postback ("Clear Development Postbacks")

The app's conversion value updates (Postback.updateConversionValue, SKAdNetwork.updatePostbackConversionValue) fill
the open conversion window of its development postbacks; locking a window closes it. A window is eligible once it is
locked or has a conversion value (isim compresses time: transmitting ends the open window). The request is a POST of
Apple's JSON stanza (jws-string, conversion-value / coarse-conversion-value, ad-interaction-type, country-code) with
the JWS payload Apple documents for development postbacks (ad-network-identifier development.adattributionkit,
advertised-item-identifier 0 for an app built locally). Adapted: the JWS is not signed — isim cannot sign as Apple —
so its header says {"alg": "none", "kid": "isim-development-identifier/1"}. Postbacks live in
$ISIM_DATA/Library/isim/AdAttribution/postbacks.json.
"""
import argparse
import base64
import json
import os
import sys
import urllib.request
import uuid


def path():
    data = os.environ.get("ISIM_DATA") or os.path.expanduser("~/.local/share/isim")
    return os.path.join(data, "Library", "isim", "AdAttribution", "postbacks.json")


def load():
    try:
        with open(path()) as f:
            return json.load(f)
    except (OSError, ValueError):
        return []


def save(postbacks):
    os.makedirs(os.path.dirname(path()), exist_ok=True)
    with open(path(), "w") as f:
        json.dump(postbacks, f, indent=2, sort_keys=True)


def b64(obj):
    return base64.urlsafe_b64encode(json.dumps(obj, separators=(",", ":")).encode()).decode().rstrip("=")


def stanza(p, w):
    """the JSON Apple's device POSTs for one conversion window: fine values only in the first postback"""
    payload = {
        "postback-identifier": str(uuid.uuid4()).upper(), "publisher-item-identifier": 0, "impression-type": "app-impression",
        "ad-network-identifier": "development.adattributionkit", "did-win": True, "postback-sequence-index": w["index"],
        "conversion-type": p["conversionType"], "source-identifier": str(p["sourceID"]), "advertised-item-identifier": 0,
    }
    out = {"jws-string": b64({"kid": "isim-development-identifier/1", "alg": "none"}) + "." + b64(payload) + ".",
           "ad-interaction-type": p["interaction"], "country-code": p["country"]}
    if w["index"] == 0 and w.get("conversion-value") is not None:
        out["conversion-value"] = w["conversion-value"]
    if w.get("coarse-conversion-value"):
        out["coarse-conversion-value"] = w["coarse-conversion-value"]
    return out


def main():
    ap = argparse.ArgumentParser(prog="isim adattribution", description="development postbacks (AdAttributionKit / SKAdNetwork)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("add", help="create a development postback for an app")
    a.add_argument("bundle")
    a.add_argument("url")
    a.add_argument("--interaction", choices=["click", "view"], default="click")
    a.add_argument("--conversion-type", choices=["download", "redownload", "re-engagement"], default="download")
    a.add_argument("--source-id", type=int, default=1234)
    a.add_argument("--windows", type=int, choices=[1, 3], default=3)
    a.add_argument("--tag")
    a.add_argument("--country", default="US")
    sub.add_parser("list")
    sub.add_parser("transmit")
    sub.add_parser("clear")
    args = ap.parse_args()

    postbacks = load()
    if args.cmd == "add":
        if not 0 <= args.source_id <= 9999:
            sys.exit("isim adattribution: --source-id has two to four digits")
        p = {"id": str(uuid.uuid4()).upper(), "bundle": args.bundle, "url": args.url, "interaction": args.interaction,
             "conversionType": args.conversion_type, "sourceID": args.source_id, "tag": args.tag or "", "country": args.country,
             "windows": [{"index": i, "conversion-value": None, "coarse-conversion-value": None, "locked": False, "sent": False}
                         for i in range(args.windows)]}
        postbacks.append(p)
        save(postbacks)
        print(f"isim adattribution: development postback {p['id']} for {args.bundle} ({args.windows} window(s)) -> {args.url}")
    elif args.cmd == "list":
        if not postbacks:
            print("no development postbacks")
        for p in postbacks:
            ws = ", ".join(f"{w['index']}: fine={w['conversion-value']} coarse={w['coarse-conversion-value']}"
                           f"{' locked' if w['locked'] else ''}{' sent' if w['sent'] else ''}" for w in p["windows"])
            print(f"{p['id']} {p['bundle']} {p['interaction']} {p['conversionType']} source={p['sourceID']}"
                  f"{' tag=' + p['tag'] if p['tag'] else ''} -> {p['url']} [{ws}]")
    elif args.cmd == "transmit":
        n = 0
        for p in postbacks:
            for w in p["windows"]:
                if w["sent"] or not (w["locked"] or w["conversion-value"] is not None):
                    continue
                body = json.dumps(stanza(p, w)).encode()
                req = urllib.request.Request(p["url"], data=body, headers={"Content-Type": "application/json"}, method="POST")
                try:
                    with urllib.request.urlopen(req, timeout=10) as r:
                        status = r.status
                except Exception as e:
                    print(f"isim adattribution: {p['bundle']} window {w['index']}: {e}")
                    continue
                w["sent"] = True
                w["locked"] = True
                n += 1
                print(f"isim adattribution: sent {p['bundle']} postback window {w['index']} to {p['url']} (HTTP {status})")
        save(postbacks)
        print(f"isim adattribution: {n} postback(s) transmitted")
    elif args.cmd == "clear":
        save([])
        print("isim adattribution: development postbacks cleared")


if __name__ == "__main__":
    main()
