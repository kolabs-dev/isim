#!/usr/bin/env python3
"""isim devicecheck / isim appattest: the server side of isim's local DeviceCheck and App Attest (no Apple servers).

  isim devicecheck validate TOKEN          is the token one this device data's DCDevice made? (device, app, issue date)
  isim devicecheck query TOKEN             the two bits for the token's device and app, like Apple's query_two_bits API
  isim devicecheck update TOKEN BIT0 BIT1  set them (true/false), like update_two_bits
  isim appattest root [--der FILE]         the device data's App Attest root certificate (PEM): what a test server trusts
                                           instead of Apple's App Attest root to verify attestations

TOKEN is the token's text (base64 JSON "." base64 HMAC) or @FILE. State: $ISIM_DATA/Library/isim/DeviceCheck/.
"""
import base64
import datetime
import hashlib
import hmac
import json
import os
import sys

DATA = os.environ.get("ISIM_DATA") or os.path.expanduser("~/.local/share/isim")
DIR = os.path.join(DATA, "Library", "isim", "DeviceCheck")


def token_payload(token):
    if token.startswith("@"):
        with open(token[1:], encoding="utf-8") as f:
            token = f.read()
    token = token.strip()
    try:
        body_b64, mac_b64 = token.split(".")
        body, mac = base64.b64decode(body_b64), base64.b64decode(mac_b64)
        with open(os.path.join(DIR, "token.key"), "rb") as f:
            key = f.read()
    except (ValueError, OSError):
        sys.exit("isim devicecheck: invalid token (400 Missing or badly formatted device token)")
    if not hmac.compare_digest(hmac.new(key, body, hashlib.sha256).digest(), mac):
        sys.exit("isim devicecheck: invalid token (400 Missing or incorrectly formatted device token payload)")
    return json.loads(body)


def bits_path():
    return os.path.join(DIR, "bits.json")


def load_bits():
    try:
        with open(bits_path(), encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def main(argv):
    if len(argv) >= 2 and argv[0] == "appattest" and argv[1] == "root":
        pem = os.path.join(DIR, "AppAttestRootCA.pem")
        if not os.path.exists(pem):
            sys.exit("isim appattest: no App Attest root yet (an app's first attestKey makes it)")
        if "--der" in argv:
            out = argv[argv.index("--der") + 1]
            with open(pem, encoding="ascii") as f:
                b64 = "".join(l for l in f.read().splitlines() if "-----" not in l)
            with open(out, "wb") as f:
                f.write(base64.b64decode(b64))
            print(out)
        else:
            with open(pem, encoding="ascii") as f:
                sys.stdout.write(f.read())
        return
    if len(argv) < 2 or argv[0] != "devicecheck":
        sys.exit(__doc__)
    cmd, args = argv[1], argv[2:]
    if not args:
        sys.exit(__doc__)
    p = token_payload(args[0])
    key = f"{p['device']}:{p['bundle']}"
    if cmd == "validate":
        issued = datetime.datetime.fromtimestamp(p["issued"], datetime.timezone.utc).isoformat()
        print(json.dumps({"valid": True, "device": p["device"], "bundle": p["bundle"], "issued": issued}))
    elif cmd == "query":
        bits = load_bits().get(key)
        if bits is None:
            print("Failed to find bit state")          # what Apple's server answers before the first update
        else:
            print(json.dumps(bits))
    elif cmd == "update":
        if len(args) != 3 or args[1] not in ("true", "false") or args[2] not in ("true", "false"):
            sys.exit("usage: isim devicecheck update TOKEN true|false true|false")
        all_bits = load_bits()
        all_bits[key] = {"bit0": args[1] == "true", "bit1": args[2] == "true",
                         "last_update_time": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m")}
        os.makedirs(DIR, exist_ok=True)
        with open(bits_path(), "w", encoding="utf-8") as f:
            json.dump(all_bits, f)
        print(json.dumps(all_bits[key]))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
