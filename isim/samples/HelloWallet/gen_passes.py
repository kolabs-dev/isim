#!/usr/bin/env python3
"""Builds HelloWallet's sample passes into the app bundle (argv[1]): an event ticket (and an update of it), a coupon,
a .pkpasses bundle with a boarding pass, and a tampered ticket whose manifest no longer matches. They are signed with
a placeholder signature, not Apple's: isim checks a pass's manifest, not its signature's chain to Apple."""
import hashlib, io, json, os, struct, sys, zipfile, zlib


def png(w, h, rgb):
    """a solid-color PNG"""
    raw = b"".join(b"\0" + bytes(rgb) * w for _ in range(h))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


def pkpass(pass_json, color, strings=None, tamper=False):
    files = {"pass.json": json.dumps(pass_json, indent=1).encode(), "icon.png": png(29, 29, color), "icon@2x.png": png(58, 58, color),
             "logo.png": png(40, 40, color)}
    for lang, s in (strings or {}).items():
        files[f"{lang}.lproj/pass.strings"] = "".join(f'"{k}" = "{v}";\n' for k, v in s.items()).encode("utf-16")
    files["manifest.json"] = json.dumps({n: hashlib.sha1(d).hexdigest() for n, d in files.items()}, indent=1).encode()
    files["signature"] = b"isim sample pass: placeholder signature, not signed by Apple"
    if tamper:
        files["pass.json"] = files["pass.json"].replace(b"12A", b"1A")
    out = io.BytesIO()
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for n, d in files.items():
            z.writestr(n, d)
    return out.getvalue()


def base(serial, style, desc, org):
    return {"formatVersion": 1, "passTypeIdentifier": "pass.dev.isim.samples.wallet", "serialNumber": serial, "teamIdentifier": "ISIMTEAM01",
            "organizationName": org, "description": desc, "webServiceURL": "https://passes.example.com/", "authenticationToken": "token-" + serial,
            style: {}}


def ticket(seat):
    p = base("conf-2026-0042", "eventTicket", "ticket_description", "isim Conf")
    p.update({"logoText": "isim Conf 2026", "foregroundColor": "rgb(255, 255, 255)", "backgroundColor": "rgb(48, 64, 160)",
              "labelColor": "rgb(200, 210, 255)", "relevantDates": [{"startDate": "2026-11-12T09:00:00Z", "endDate": "2026-11-12T18:00:00Z"}],
              "userInfo": {"attendee": 42},
              "barcodes": [{"format": "PKBarcodeFormatQR", "message": "ISIMCONF-0042", "messageEncoding": "iso-8859-1", "altText": "0042"}]})
    p["eventTicket"] = {
        "headerFields": [{"key": "date", "label": "date_label", "value": "2026-11-12T09:00:00Z", "dateStyle": "PKDateStyleMedium"}],
        "primaryFields": [{"key": "event", "label": "event_label", "value": "Keynote"}],
        "secondaryFields": [{"key": "seat", "label": "seat_label", "value": seat}, {"key": "hall", "label": "Hall", "value": "A"}],
        "auxiliaryFields": [{"key": "price", "label": "Price", "value": 25, "currencyCode": "USD"}],
        "backFields": [{"key": "terms", "label": "Terms", "value": "A sample pass made by isim."}],
    }
    return p


STRINGS = {"en": {"ticket_description": "Ticket for isim Conf 2026", "date_label": "Date", "event_label": "Event", "seat_label": "Seat"},
           "fr": {"ticket_description": "Billet pour isim Conf 2026", "date_label": "Date", "event_label": "Événement", "seat_label": "Place"}}


def coupon():
    p = base("coffee-5off", "coupon", "A coffee coupon", "isim Coffee")
    p.update({"logoText": "isim Coffee", "backgroundColor": "rgb(250, 220, 160)", "foregroundColor": "rgb(60, 30, 10)",
              "barcode": {"format": "PKBarcodeFormatCode128", "message": "COFFEE5", "messageEncoding": "iso-8859-1"}})
    p["coupon"] = {"primaryFields": [{"key": "offer", "label": "Offer", "value": "$5 off"}]}
    return p


def boarding():
    p = base("flight-is42", "boardingPass", "Boarding pass IS42", "isim Air")
    p.update({"backgroundColor": "rgb(240, 240, 245)", "relevantDate": "2026-12-01T07:30:00Z"})
    p["boardingPass"] = {"transitType": "PKTransitTypeAir",
                         "primaryFields": [{"key": "from", "label": "SFO", "value": "San Francisco"}, {"key": "to", "label": "JFK", "value": "New York"}],
                         "auxiliaryFields": [{"key": "gate", "label": "Gate", "value": "B12"}]}
    return p


def main(out):
    os.makedirs(out, exist_ok=True)
    blue, cream, grey = (48, 64, 160), (250, 220, 160), (240, 240, 245)
    passes = {"ticket.pkpass": pkpass(ticket("12A"), blue, STRINGS), "ticket-v2.pkpass": pkpass(ticket("14C"), blue, STRINGS),
              "coupon.pkpass": pkpass(coupon(), cream), "tampered.pkpass": pkpass(ticket("12A"), blue, STRINGS, tamper=True)}
    for n, d in passes.items():
        with open(os.path.join(out, n), "wb") as f:
            f.write(d)
    board = pkpass(boarding(), grey)
    with open(os.path.join(out, "boarding.pkpass"), "wb") as f:
        f.write(board)
    bundle = io.BytesIO()
    with zipfile.ZipFile(bundle, "w", zipfile.ZIP_STORED) as z:
        z.writestr("boarding.pkpass", board)
    with open(os.path.join(out, "trip.pkpasses"), "wb") as f:
        f.write(bundle.getvalue())


if __name__ == "__main__":
    main(sys.argv[1])
