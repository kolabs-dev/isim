#!/usr/bin/env python3
"""isim debug tools for the local App Store and Game Center (like Xcode's Transaction Manager).

  isim storekit <app> list                         transactions and subscriptions of an app
  isim storekit <app> refund <transaction id>      refund (revoke) a transaction; the app gets it in Transaction.updates
  isim storekit <app> expire <group|product|id>    end a subscription now (auto-renew off)
  isim storekit <app> cancel <group|product|id>    turn auto-renew off (expires at the end of the period)
  isim storekit <app> resume <group|product|id>    turn auto-renew back on
  isim storekit <app> billing-issue <group|product|id> on|off   renewals fail (billing retry) while on
  isim storekit <app> delete <transaction id>      remove a transaction
  isim storekit <app> clear                        remove all transactions and subscriptions
  isim gamecenter <app> saved-games                list saved games
  isim gamecenter <app> conflict <name> [text]     add a conflicting saved-game version from "Other Device"
  isim gamecenter <app> reset                      erase the app's local Game Center data

<app> is a bundle identifier, an .app bundle or an installed app's name. Running apps notice changes
within half a second. Data: ISIM_DATA (~/.local/share/isim)/Containers/<bundle id>/Library/isim/.
"""
import json, os, plistlib, sys, time, uuid, shutil

DATA = os.environ.get('ISIM_DATA') or os.path.expanduser('~/.local/share/isim')


def die(msg):
    print(f'isim: {msg}', file=sys.stderr)
    sys.exit(1)


def bundle_id(app):
    if os.path.isdir(app) and os.path.exists(os.path.join(app, 'Info.plist')):
        return plistlib.load(open(os.path.join(app, 'Info.plist'), 'rb'))['CFBundleIdentifier']
    apps = os.path.join(DATA, 'Applications')
    if os.path.isdir(apps):
        for a in os.listdir(apps):
            p = os.path.join(apps, a, 'Info.plist')
            if not os.path.exists(p):
                continue
            info = plistlib.load(open(p, 'rb'))
            if app in (a, a[:-4], info.get('CFBundleDisplayName'), info.get('CFBundleName')):
                return info['CFBundleIdentifier']
    return app


def container(app):
    return os.path.join(DATA, 'Containers', bundle_id(app))


def write_json(path, obj):
    tmp = f'{path}.isim-tmp-{os.getpid()}'
    with open(tmp, 'w') as f:
        json.dump(obj, f, indent=2, sort_keys=True)
    os.replace(tmp, path)


def when(t):
    return time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(t)) if t else '-'


def storekit(app, cmd, args):
    path = os.path.join(container(app), 'Library/isim/StoreKit/ledger.json')
    if not os.path.exists(path):
        die(f'no StoreKit transactions for {bundle_id(app)} ({path})')
    led = json.load(open(path))
    txs, subs = led.setdefault('transactions', []), led.setdefault('subscriptions', {})
    now = time.time()

    def find_tx(i):
        for t in txs:
            if str(t['id']) == str(i):
                return t
        die(f'no transaction {i}')

    def find_group(key):
        if key in subs:
            return key
        for g, s in subs.items():
            if key in (s.get('productID'), s.get('autoRenewProductID')):
                return g
        for t in txs:
            if str(t['id']) == key or t['productID'] == key:
                if t.get('groupID'):
                    return t['groupID']
        die(f'no subscription matches {key}')

    def latest(g):
        cand = [t for t in txs if t.get('groupID') == g and not t.get('isUpgraded')]
        return max(cand, key=lambda t: (t['purchaseDate'], t['id'])) if cand else None

    if cmd == 'list':
        print(f'{"ID":>5} {"ORIG":>5}  {"PRODUCT":38} {"TYPE":28} {"PURCHASED":19}  {"EXPIRES":19}  STATE')
        for t in txs:
            state = 'refunded' if t.get('revocationDate') else ('upgraded' if t.get('isUpgraded') else ('unfinished' if not t.get('finished') else 'finished'))
            if t.get('expirationDate') and not t.get('revocationDate'):
                state += ', active' if t['expirationDate'] > now else ', expired'
            if t.get('offerType'):
                state += f', offer {t.get("offerID") or t.get("offerType")}'
            print(f'{t["id"]:>5} {t["originalID"]:>5}  {t["productID"]:38} {t["type"]:28} {when(t["purchaseDate"]):19}  {when(t.get("expirationDate")):19}  {state}')
        for g, s in sorted(subs.items()):
            print(f'subscription group {g}: {s["productID"]}, auto-renew {"on" if s["willAutoRenew"] else "off"}'
                  f'{" -> " + s["autoRenewProductID"] if s["autoRenewProductID"] != s["productID"] else ""}'
                  f'{", billing issue" if s.get("billingIssue") else ""}')
        return
    if cmd == 'refund':
        t = find_tx(args[0])
        if t.get('revocationDate'):
            die(f'transaction {t["id"]} is already refunded')
        t['revocationDate'] = now
        t['revocationReason'] = 1 if '--developer-issue' in args else 0
        if t.get('groupID') in subs:
            subs[t['groupID']]['willAutoRenew'] = False
        print(f'refunded transaction {t["id"]} ({t["productID"]})')
    elif cmd in ('expire', 'cancel', 'resume'):
        g = find_group(args[0])
        s = subs[g]
        s['willAutoRenew'] = cmd == 'resume'
        s.pop('expirationReason', None)
        if cmd == 'expire':
            t = latest(g)
            if t and t.get('expirationDate', 0) > now:
                t['expirationDate'] = now
            s['expirationReason'] = 1
        print(f'{cmd}: subscription group {g} ({s["productID"]})')
    elif cmd == 'billing-issue':
        g = find_group(args[0])
        subs[g]['billingIssue'] = (args[1:] or ['on'])[0] == 'on'
        print(f'billing issue {"on" if subs[g]["billingIssue"] else "off"} for subscription group {g}')
    elif cmd == 'delete':
        t = find_tx(args[0])
        txs.remove(t)
        print(f'deleted transaction {t["id"]}')
    elif cmd == 'clear':
        txs.clear()
        subs.clear()
        print('cleared all transactions')
    else:
        die(f'unknown storekit command {cmd}')
    write_json(path, led)


def gamecenter(app, cmd, args):
    bid = bundle_id(app)
    root = os.path.join(DATA, 'Library/GameCenter', bid)
    saves = os.path.join(root, 'SavedGames')
    if cmd == 'saved-games':
        if not os.path.isdir(saves):
            return
        for name in sorted(os.listdir(saves)):
            meta = os.path.join(saves, name, 'versions.json')
            for v in json.load(open(meta)) if os.path.exists(meta) else []:
                print(f'{v["name"]:24} {v["deviceName"]:16} {when(v["modificationDate"])}  {v["file"]}')
    elif cmd == 'conflict':
        name = args[0]
        text = args[1] if len(args) > 1 else 'saved on another device'
        d = os.path.join(saves, name.replace('/', '_'))
        os.makedirs(d, exist_ok=True)
        meta = os.path.join(d, 'versions.json')
        versions = json.load(open(meta)) if os.path.exists(meta) else []
        f = f'{uuid.uuid4()}.data'
        open(os.path.join(d, f), 'wb').write(text.encode())
        versions.append({'name': name, 'deviceName': 'Other Device', 'modificationDate': time.time(), 'file': f})
        write_json(meta, versions)
        print(f'saved game "{name}" now has {len(versions)} versions (conflict)')
    elif cmd == 'reset':
        shutil.rmtree(root, ignore_errors=True)
        print(f'erased Game Center data of {bid}')
    else:
        die(f'unknown gamecenter command {cmd}')


def main():
    if len(sys.argv) < 4:
        print(__doc__.strip())
        sys.exit(2)
    kind, app, cmd, args = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
    {'storekit': storekit, 'gamecenter': gamecenter}.get(kind, lambda *a: die(f'unknown tool {kind}'))(app, cmd, args)


if __name__ == '__main__':
    main()
