#!/usr/bin/env python3
"""isim debug tools for the local App Store, Game Center and Sign in with Apple (like Xcode's Transaction Manager).

  isim storekit <app> list                         transactions and subscriptions of an app
  isim storekit <app> refund <transaction id>      refund (revoke) a transaction; the app gets it in Transaction.updates
  isim storekit <app> expire <group|product|id>    end a subscription now (auto-renew off)
  isim storekit <app> cancel <group|product|id>    turn auto-renew off (expires at the end of the period)
  isim storekit <app> resume <group|product|id>    turn auto-renew back on
  isim storekit <app> billing-issue <group|product|id> on|off   renewals fail (grace period, billing retry) while on
  isim storekit <app> resolve <group|product|id>   resolve the billing issue (the subscription renews)
  isim storekit <app> delete <transaction id>      remove a transaction
  isim storekit <app> clear                        remove all transactions and subscriptions
  isim storekit certificate [--der] [FILE]         the device's StoreKit testing certificate (PEM, or DER), which
                                                   signs its JWS values and app receipts (like Xcode's StoreKitTestCertificate.cer)
  isim storekit offer-key [--id|--pem]             the device's subscription offers key: key ID and private key (PEM)
                                                   for the server that signs promotional offers
  isim gamecenter <app> saved-games                list saved games
  isim gamecenter <app> conflict <name> [text]     add a conflicting saved-game version from "Other Device"
  isim gamecenter <app> reset                      erase the app's local Game Center data
  isim gamecenter players                          players on the local Game Center network (devices, test players)
  isim gamecenter player add|remove <nickname>     add or remove a test player
  isim gamecenter friends                          this device's friends and friend requests
  isim gamecenter befriend <nickname> [<nickname>] make two players friends (default: with this device's player)
  isim gamecenter accept-friend <nickname>         accept a friend request (Settings > Game Center does the same)
  isim gamecenter request-friend <nickname> [message]   a test player asks this device's player to be friends
  isim gamecenter identity                         the certificate (PEM) of the device's identity verification key
  isim gamecenter <app> score <nickname> <leaderboard> <value> [context]   post a score for a player
  isim gamecenter <app> scores                     every player's scores in the game
  isim gamecenter <app> challenge <nickname> score <leaderboard> <value> [message]
  isim gamecenter <app> challenge <nickname> achievement <id> [message]    challenge this device's player
  isim gamecenter <app> challenges                 the game's challenges
  isim gamecenter <app> matches                    the game's turn-based matches
  isim gamecenter <app> activity <id> [party code] [key=value ...]   play a game activity, as from the Games app
  isim appleid <app> list                          Sign in with Apple state of an app (local simulation)
  isim appleid <app> revoke                        Settings > Apple Account > Sign in with Apple > Stop Using
  isim appleid <app> reset                         forget the app (next sign-in is a new account again)
  isim wallet list                                 the passes in the device's Wallet (PKPassLibrary)
  isim wallet add <file.pkpass>                    add a pass, as opening it from Mail or Safari would
  isim wallet remove <pass type id> <serial>       remove a pass
  isim wallet orders                               the orders Apple Pay payments added (PKPaymentOrderDetails)
  isim wallet clear                                remove every pass and order
  isim agerange set <age>|none [--declaration KIND] [--controls communicationLimits,...] [--regulated]
                                                   the device account's age for DeclaredAgeRange (and a child's
                                                   parental controls for PermissionKit)
  isim finance seed|list|clear                     FinanceKit: the device's simulated Wallet financial data (an
                                                   Apple Card and a savings account with transactions)
  isim finance add-transaction <account> <amount> <merchant> [--type T] [--status S] [--mcc NNNN]
  isim agerange show                               the age, declaration, parental controls
  isim permission <app> list                       PermissionKit questions the app asked a parent
  isim permission <app> approve|decline [id|all]   answer as the parent (the latest pending question by default)
  isim autofill providers                          credential provider extensions (password managers) and whether
                                                   AutoFill uses them, with their saved credential identities
  isim autofill enable|disable <app>               Settings > Passwords > Password Options: turn an app's provider on/off
  isim sso list                                    the single sign-on profiles (identity provider URLs -> SSO extension)
  isim sso add <extension bundle id> <url>... [--realm R]   install a profile, as an MDM's Extensible SSO payload
  isim sso remove <extension bundle id>|all        remove profiles

<app> is a bundle identifier, an .app bundle or an installed app's name. Running apps notice changes
within half a second. Data: ISIM_DATA (~/.local/share/isim)/Containers/<bundle id>/Library/isim/; Wallet: ISIM_DATA/Library/Wallet/; StoreKit purchase
histories (the device's account, kept when an app is deleted), certificate and offer key: ISIM_DATA/Library/isim/StoreKit/.
The local Game Center network that isim
devices on this computer share: ISIM_GAMECENTER (~/.local/share/isim-gamecenter).
"""
import base64, datetime, json, os, plistlib, random, string, subprocess, sys, time, uuid, shutil

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


STOREKIT = os.path.join(DATA, 'Library/isim/StoreKit')


def storekit_device(cmd, args):
    """the device's StoreKit testing certificate and subscription offers key (made with openssl when missing)"""
    os.makedirs(STOREKIT, exist_ok=True)

    def openssl(*a):
        r = subprocess.run(['openssl', *a], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if r.returncode:
            die(f'openssl {a[0]} failed: {r.stderr.strip()}')
        return r.stdout
    if cmd == 'certificate':
        key, cert = os.path.join(STOREKIT, 'testing-key.pem'), os.path.join(STOREKIT, 'testing-cert.der')
        if not (os.path.exists(key) and os.path.exists(cert)):
            openssl('req', '-x509', '-newkey', 'ec', '-pkeyopt', 'ec_paramgen_curve:prime256v1', '-nodes', '-days', '3650',
                    '-subj', '/O=isim/CN=isim StoreKit Testing', '-addext', 'basicConstraints=critical,CA:TRUE',
                    '-addext', 'keyUsage=critical,digitalSignature,keyCertSign,cRLSign',
                    '-keyout', key + '.tmp', '-outform', 'DER', '-out', cert + '.tmp')
            os.replace(key + '.tmp', key)
            os.replace(cert + '.tmp', cert)
        files = [a for a in args if not a.startswith('--')]
        der = '--der' in args or (files and files[0].endswith(('.cer', '.der')))
        if der:
            data = open(cert, 'rb').read()
        else:
            data = openssl('x509', '-inform', 'DER', '-in', cert).encode()
        if files:
            open(files[0], 'wb').write(data)
            print(f'wrote the StoreKit testing certificate to {files[0]} ({"DER" if der else "PEM"})')
        else:
            sys.stdout.buffer.write(data)
    elif cmd == 'offer-key':
        key, kid = os.path.join(STOREKIT, 'offer-key.pem'), os.path.join(STOREKIT, 'offer-key.id')
        if not (os.path.exists(key) and os.path.exists(kid)):
            openssl('genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:P-256', '-out', key + '.tmp')
            os.replace(key + '.tmp', key)
            with open(kid, 'w') as f:
                f.write(''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(10)) + '\n')
        key_id, pem = open(kid).read().strip(), open(key).read()
        if '--id' in args:
            print(key_id)
        elif '--pem' in args:
            sys.stdout.write(pem)
        else:
            print(f'Key ID: {key_id}')
            sys.stdout.write(pem)
    else:
        die(f'unknown storekit command {cmd}')


def storekit(app, cmd, args):
    if app in ('certificate', 'offer-key'):
        return storekit_device(app, [a for a in [cmd, *args] if a])
    bid = bundle_id(app)
    if cmd == 'purchase-intent':        # a purchase started on the App Store (a promoted in-app purchase)
        if not args:
            die('usage: isim storekit <app> purchase-intent PRODUCT [OFFER]')
        d = os.path.join(STOREKIT, bid, 'intents')
        os.makedirs(d, exist_ok=True)
        intent = {'productID': args[0], **({'offerID': args[1]} if len(args) > 1 else {})}
        write_json(os.path.join(d, f'{time.time():.6f}-{random.randint(0, 1 << 30)}.json'), intent)
        print(f'purchase intent for {args[0]}{" with offer " + args[1] if len(args) > 1 else ""} (the app gets it while it listens)')
        return
    if cmd == 'age-rating':             # AppStore.ageRatingCode (iOS 26.2): the app's age rating code
        f = os.path.join(STOREKIT, bid, 'age-rating')
        if not args:
            print(open(f).read().strip() if os.path.exists(f) else 'none')
            return
        os.makedirs(os.path.dirname(f), exist_ok=True)
        if args[0] == 'none':
            if os.path.exists(f):
                os.remove(f)
        else:
            open(f, 'w').write(str(int(args[0])) + '\n')
        print(f'age rating code: {args[0]}')
        return
    if cmd == 'promotions':             # the promoted in-app purchases' order and visibility the app set
        p = os.path.join(STOREKIT, bid, 'promotions.json')
        pr = json.load(open(p)) if os.path.exists(p) else {}
        vis = pr.get('visibility', {})
        print('order: ' + (', '.join(pr.get('order', [])) or '(App Store Connect order)'))
        for k in sorted(vis):
            print(f'{k}: {vis[k]}')
        return
    path = os.path.join(STOREKIT, bid, 'ledger.json')
    old = os.path.join(container(app), 'Library/isim/StoreKit/ledger.json')
    if not os.path.exists(path) and os.path.exists(old):
        path = old             # not moved yet (the app moves it at its next launch)
    if not os.path.exists(path):
        die(f'no StoreKit transactions for {bundle_id(app)} ({path})')
    # the ledger's file lock, which the running app takes too: held from reading the ledger until this command has
    # written it and exits, so neither side overwrites the other's change (#735)
    lock = open(path + '.lock', 'a')
    try:
        import fcntl
        fcntl.flock(lock, fcntl.LOCK_EX)
    except ImportError:         # no POSIX locks on this host
        pass
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

    if cmd in ('approve', 'decline'):   # Ask to Buy: the family organizer answers a request
        asks = led.get('askToBuy') or []
        pending = [a for a in asks if a.get('state') == 'pending']
        pick = pending if args[:1] == ['all'] or not args else [a for a in pending if str(a['id']) in args]
        if not pick:
            die('no Ask to Buy request ' + (' '.join(args) or 'waiting'))
        for a in pick:
            a['state'] = 'approved' if cmd == 'approve' else 'declined'
            print(f'{"approved" if cmd == "approve" else "declined"} Ask to Buy request {a["id"]} ({a["productID"]})')
        write_json(path, led)
        return
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
            billing = ''
            if s.get('billingIssue'):
                billing = ', billing issue'
                if s.get('graceUntil') and s['graceUntil'] > now:
                    billing += f' (grace period until {when(s["graceUntil"])})'
                elif s.get('retryUntil') and s['retryUntil'] > now:
                    billing += f' (billing retry until {when(s["retryUntil"])})'
                elif s.get('retryUntil'):
                    billing += ' (billing retry ended)'
            print(f'subscription group {g}: {s["productID"]}, auto-renew {"on" if s["willAutoRenew"] else "off"}'
                  f'{" -> " + s["autoRenewProductID"] if s["autoRenewProductID"] != s["productID"] else ""}{billing}')
        for a in led.get('askToBuy') or []:
            print(f'Ask to Buy request {a["id"]}: {a["productID"]} x{a.get("quantity", 1)}, {a.get("state", "pending")} (since {when(a.get("requested"))})')
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
    elif cmd in ('billing-issue', 'resolve'):
        g = find_group(args[0])
        subs[g]['billingIssue'] = cmd == 'billing-issue' and (args[1:] or ['on'])[0] == 'on'
        print(f'billing issue {"on" if subs[g]["billingIssue"] else "off (resolved)"} for subscription group {g}')
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


GC = os.environ.get('ISIM_GAMECENTER') or os.path.expanduser('~/.local/share/isim-gamecenter')
GC_NETWORK = ('players', 'player', 'friends', 'befriend', 'accept-friend', 'request-friend', 'identity')


def gc_path(*parts):
    return os.path.join(GC, *parts)


def gc_read(path, default=None):
    try:
        return json.load(open(path))
    except (OSError, ValueError):
        return default


def gc_me():
    """this device's player (made like the GameKit overlay does when a game first uses Game Center)"""
    f = os.path.join(DATA, 'Library/GameCenter/player.json')
    me = (gc_read(f) or {}).get('id')
    if not me:
        me = '%010u' % random.randint(1000000000, 4294967295)
        os.makedirs(os.path.dirname(f), exist_ok=True)
        write_json(f, {'id': me})
    p = gc_path('players', f'{me}.json')
    if not os.path.exists(p):
        prefs = os.path.join(DATA, 'Library/Preferences/.GlobalPreferences.plist')
        try:
            alias = plistlib.load(open(prefs, 'rb')).get('ISIMGameCenterNickname') or 'Player'
        except (OSError, plistlib.InvalidFileException):
            alias = 'Player'
        os.makedirs(os.path.dirname(p), exist_ok=True)
        write_json(p, {'id': me, 'alias': alias, 'device': '', 'test': False, 'data': DATA})
    return me


def gc_players():
    d = gc_path('players')
    return [gc_read(os.path.join(d, f)) for f in sorted(os.listdir(d)) if f.endswith('.json')] if os.path.isdir(d) else []


def gc_player(name):
    """a player by nickname (case-insensitive) or id"""
    for p in gc_players():
        if p and (p['id'] == name or p.get('alias', '').lower() == name.lower()):
            return p
    die(f'no player "{name}" on the local Game Center network (isim gamecenter players)')


def gc_alias(pid):
    p = gc_read(gc_path('players', f'{pid}.json'))
    return p.get('alias', pid) if p else pid


def gc_friends(pid):
    d = gc_path('friends')
    out = []
    for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
        a, _, b = f.partition('+')
        if pid in (a, b):
            out.append(b if a == pid else a)
    return out


def gc_befriend(a, b):
    os.makedirs(gc_path('friends'), exist_ok=True)
    write_json(gc_path('friends', '+'.join(sorted([a, b]))), {'since': time.time()})
    for f in (f'{a}+{b}.json', f'{b}+{a}.json'):
        if os.path.exists(gc_path('friend-requests', f)):
            os.remove(gc_path('friend-requests', f))


def gc_post(pid, event):
    """an event for a player's running apps (the GameKit overlay drains its inbox)"""
    d = gc_path('inbox', pid)
    os.makedirs(d, exist_ok=True)
    event['date'] = time.time()
    write_json(os.path.join(d, f'{time.time():.6f}-{uuid.uuid4()}.json'), event)


def gamecenter_network(cmd, args):
    if cmd == 'players':
        me = gc_me()
        for p in gc_players():
            kind = 'test player' if p.get('test') else ('this device' if p['id'] == me else f'device {p.get("data", "")}')
            print(f'{p.get("alias", ""):20} {p["id"]}  {kind}')
    elif cmd == 'player':
        if len(args) < 2 or args[0] not in ('add', 'remove'):
            die('usage: isim gamecenter player add|remove <nickname>')
        if args[0] == 'add':
            if any(p and p.get('alias', '').lower() == args[1].lower() for p in gc_players()):
                die(f'a player "{args[1]}" exists already')
            pid = '%010u' % random.randint(1000000000, 4294967295)
            os.makedirs(gc_path('players'), exist_ok=True)
            write_json(gc_path('players', f'{pid}.json'), {'id': pid, 'alias': args[1], 'device': '', 'test': True})
            print(f'added test player {args[1]} ({pid})')
        else:
            p = gc_player(args[1])
            if not p.get('test'):
                die(f'{args[1]} is a device\'s player, not a test player')
            os.remove(gc_path('players', f'{p["id"]}.json'))
            print(f'removed test player {args[1]}')
    elif cmd == 'friends':
        me = gc_me()
        for f in gc_friends(me):
            print(f'friend   {gc_alias(f)}')
        d = gc_path('friend-requests')
        for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
            r = gc_read(os.path.join(d, f)) or {}
            if r.get('to') == me:
                print(f'request  from {gc_alias(r.get("from"))} "{r.get("message", "")}"')
            elif r.get('from') == me:
                print(f'request  to {gc_alias(r.get("to"))} (waiting)')
    elif cmd == 'befriend':
        if not args:
            die('usage: isim gamecenter befriend <nickname> [<nickname>]')
        a = gc_player(args[0])['id']
        b = gc_player(args[1])['id'] if len(args) > 1 else gc_me()
        gc_befriend(a, b)
        print(f'{gc_alias(a)} and {gc_alias(b)} are friends')
    elif cmd == 'accept-friend':
        me, p = gc_me(), gc_player(args[0] if args else die('usage: isim gamecenter accept-friend <nickname>'))
        if not os.path.exists(gc_path('friend-requests', f'{p["id"]}+{me}.json')):
            die(f'no friend request from {p.get("alias")}')
        gc_befriend(me, p['id'])
        print(f'accepted the friend request from {p.get("alias")}')
    elif cmd == 'request-friend':
        me, p = gc_me(), gc_player(args[0] if args and args[0] else die('usage: isim gamecenter request-friend <nickname> [message]'))
        os.makedirs(gc_path('friend-requests'), exist_ok=True)
        write_json(gc_path('friend-requests', f'{p["id"]}+{me}.json'),
                   {'from': p['id'], 'to': me, 'message': args[1] if len(args) > 1 else '', 'date': time.time()})
        gc_post(me, {'kind': 'friendRequest', 'from': p['id'], 'game': '*'})
        print(f'{p.get("alias")} asked {gc_alias(me)} to be friends')
    elif cmd == 'identity':
        # the certificate GKLocalPlayer.fetchItems(forIdentityVerificationSignature:) points to (made on first use)
        cer = os.path.join(DATA, 'Library', 'GameCenter', 'identity.cer')
        if not os.path.exists(cer):
            die('no identity verification key yet: it is made when a game first asks for a signature')
        der = open(cer, 'rb').read()
        b64 = base64.b64encode(der).decode()
        print(cer)
        print('-----BEGIN CERTIFICATE-----')
        for i in range(0, len(b64), 64):
            print(b64[i:i + 64])
        print('-----END CERTIFICATE-----')


def gc_entries(bid, board):
    """every player's best score on a leaderboard (highest first)"""
    d = gc_path('games', bid, 'scores')
    best = []
    for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
        recs = (gc_read(os.path.join(d, f)) or {}).get(board, [])
        if recs:
            best.append((max(r['value'] for r in recs), f[:-5]))
    return sorted(best, reverse=True)


def gamecenter(app, cmd, args):
    if app in GC_NETWORK:
        return gamecenter_network(app, [cmd] + args)
    bid = bundle_id(app)
    root = os.path.join(DATA, 'Library/GameCenter', bid)
    saves = os.path.join(root, 'SavedGames')
    game = gc_path('games', bid)
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
        me = gc_me()
        p = os.path.join(game, 'scores', f'{me}.json')
        if os.path.exists(p):
            os.remove(p)
        print(f'erased Game Center data of {bid}')
    elif cmd == 'score':
        if len(args) < 3:
            die('usage: isim gamecenter <app> score <nickname> <leaderboard> <value> [context]')
        p = gc_player(args[0])
        f = os.path.join(game, 'scores', f'{p["id"]}.json')
        os.makedirs(os.path.dirname(f), exist_ok=True)
        scores = gc_read(f, {})
        scores.setdefault(args[1], []).append({'value': int(args[2]), 'context': int(args[3]) if len(args) > 3 else 0, 'date': time.time()})
        write_json(f, scores)
        print(f'{p.get("alias")} scored {args[2]} on {args[1]}')
    elif cmd == 'scores':
        d = os.path.join(game, 'scores')
        boards = sorted({b for f in (os.listdir(d) if os.path.isdir(d) else []) for b in (gc_read(os.path.join(d, f)) or {})})
        for b in boards:
            print(f'{b}: ' + ', '.join(f'{gc_alias(pid)} {v}' for v, pid in gc_entries(bid, b)))
    elif cmd == 'challenge':
        if len(args) < 3 or args[1] not in ('score', 'achievement') or (args[1] == 'score' and len(args) < 4):
            die('usage: isim gamecenter <app> challenge <nickname> score <leaderboard> <value> [message] | achievement <id> [message]')
        p, me, cid = gc_player(args[0]), gc_me(), str(uuid.uuid4()).upper()
        rec = {'id': cid, 'kind': args[1], 'from': p['id'], 'to': me, 'state': 1, 'issued': time.time()}
        if args[1] == 'score':
            rec.update(board=args[2], score=int(args[3]), context=0, message=args[4] if len(args) > 4 else '')
        else:
            rec.update(achievement=args[2], message=args[3] if len(args) > 3 else '')
        os.makedirs(os.path.join(game, 'challenges'), exist_ok=True)
        write_json(os.path.join(game, 'challenges', f'{cid}.json'), rec)
        gc_post(me, {'kind': 'challenge', 'challenge': cid, 'game': bid})
        print(f'{p.get("alias")} challenged {gc_alias(me)} ({args[1]} {args[2]})')
    elif cmd == 'challenges':
        d = os.path.join(game, 'challenges')
        states = {0: 'invalid', 1: 'pending', 2: 'completed', 3: 'declined'}
        for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
            c = gc_read(os.path.join(d, f)) or {}
            what = f'beat {c.get("score")} on {c.get("board")}' if c.get('kind') == 'score' else f'earn {c.get("achievement")}'
            print(f'{gc_alias(c.get("from")):12} -> {gc_alias(c.get("to")):12} {what:40} {states.get(c.get("state"), "?")}')
    elif cmd == 'matches':
        d = os.path.join(game, 'turnbased')
        for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
            if not f.endswith('.json'):
                continue
            m = gc_read(os.path.join(d, f)) or {}
            ps = m.get('participants', [])
            names = ', '.join(gc_alias(p['pid']) if p.get('pid') else '(open seat)' for p in ps)
            cur = m.get('current', -1)
            turn = 'ended' if m.get('ended') else (f'turn: {gc_alias(ps[cur]["pid"]) if ps[cur].get("pid") else "next player found"}' if 0 <= cur < len(ps) else '')
            data = base64.b64decode(m['data']).decode(errors='replace') if m.get('data') else ''
            print(f'{m.get("id")}  {names}  {turn}  data={data!r}')
    elif cmd == 'activity':
        if not args:
            die('usage: isim gamecenter <app> activity <definition id> [party code] [key=value ...]')
        party = args[1] if len(args) > 1 and '=' not in args[1] else ''
        props = dict(a.split('=', 1) for a in args[1:] if '=' in a)
        gc_post(gc_me(), {'kind': 'activity', 'definition': args[0], 'partyCode': party, 'properties': props, 'game': bid})
        print(f'asked {bid} to play activity {args[0]}' + (f' (party code {party})' if party else ''))
    else:
        die(f'unknown gamecenter command {cmd}')


def appleid(app, cmd, args):
    bid = bundle_id(app)
    path = os.path.join(DATA, 'Library/isim/AppleAccount/SignInWithApple.json')
    apps = json.load(open(path)) if os.path.exists(path) else {}
    e = apps.get(bid)
    if cmd == 'list':
        if not e:
            print(f'{bid}: not signed in with Apple')
        else:
            print(f'{bid}: user {e.get("user")} state {e.get("state")} email {e.get("email") or "-"} since {when(e.get("created"))}')
        return
    elif cmd == 'revoke':
        if not e:
            die(f'{bid} has no Sign in with Apple credential')
        e['state'] = 'revoked'
        print(f'revoked Sign in with Apple for {bid} (user {e.get("user")})')
    elif cmd == 'reset':
        apps.pop(bid, None)
        print(f'forgot Sign in with Apple for {bid}')
    else:
        die(f'unknown appleid command {cmd}')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    write_json(path, apps)



# ---- Wallet: the device's passes and orders (PassKit's PKPassLibrary, Apple Pay orders) ----

WALLET = os.path.join(DATA, 'Library', 'Wallet')
PASS_STYLES = ('boardingPass', 'coupon', 'eventTicket', 'generic', 'storeCard')


def wallet_safe(s):
    return ''.join(c if c.isalnum() or c in '.-' else '_' for c in s)


def wallet_read(path):
    """pass.json, the English strings and the archive's problem (None when PassKit would accept it)"""
    import hashlib, re, zipfile
    try:
        z = zipfile.ZipFile(path)
        files = {n: z.read(n) for n in z.namelist() if not n.endswith('/')}
        info = json.loads(files['pass.json'])
    except Exception:
        return None, {}, 'not a pass archive with a pass.json'
    strings = {}
    raw = files.get('en.lproj/pass.strings')
    if raw:
        text = raw.decode('utf-16') if raw[:2] in (b'\xff\xfe', b'\xfe\xff') else raw.decode('utf-8', 'replace')
        strings = dict(re.findall(r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', text))
    try:
        manifest = json.loads(files['manifest.json'])
    except Exception:
        return info, strings, 'no manifest'
    for n, d in files.items():
        if n not in ('manifest.json', 'signature') and manifest.get(n, '').lower() != hashlib.sha1(d).hexdigest():
            return info, strings, f"the manifest's hash of {n} does not match"
    if not files.get('signature'):
        return info, strings, 'not signed'
    if info.get('formatVersion') != 1 or not all(info.get(k) for k in ('passTypeIdentifier', 'serialNumber', 'organizationName', 'description')):
        return info, strings, 'pass.json lacks formatVersion 1, passTypeIdentifier, serialNumber, organizationName or description'
    return info, strings, None


def wallet(cmd, args):
    passes = os.path.join(WALLET, 'Passes')
    orders = os.path.join(WALLET, 'Orders')
    if cmd in ('', 'list'):
        names = sorted(n for n in os.listdir(passes) if n.endswith('.pkpass')) if os.path.isdir(passes) else []
        if not names:
            print('no passes')
        for n in names:
            info, strings, _ = wallet_read(os.path.join(passes, n))
            if not info:
                continue
            style = next((s for s in PASS_STYLES if s in info), '?')
            loc = lambda k: strings.get(info.get(k, ''), info.get(k, ''))
            print(f"{info['passTypeIdentifier']} {info['serialNumber']}  {style}  {loc('organizationName')}: {loc('description')}")
    elif cmd == 'orders':
        names = sorted(n for n in os.listdir(orders) if n.endswith('.json')) if os.path.isdir(orders) else []
        if not names:
            print('no orders')
        for n in names:
            o = json.load(open(os.path.join(orders, n)))
            print(f"{o.get('orderTypeIdentifier')} {o.get('orderIdentifier')}  {o.get('total', '')}  {o.get('merchantIdentifier', '')}  {o.get('webServiceURL', '')}")
    elif cmd == 'add':
        if not args:
            die('usage: isim wallet add FILE.pkpass')
        info, _, problem = wallet_read(args[0])
        if problem:
            print(f'refused {args[0]}: {problem}')
            sys.exit(1)
        os.makedirs(passes, exist_ok=True)
        shutil.copyfile(args[0], os.path.join(passes, wallet_safe(f"{info['passTypeIdentifier']}_{info['serialNumber']}") + '.pkpass'))
        print(f"added {info['passTypeIdentifier']} {info['serialNumber']}")
    elif cmd == 'remove':
        if len(args) != 2:
            die('usage: isim wallet remove PASS_TYPE_ID SERIAL')
        path = os.path.join(passes, wallet_safe(f'{args[0]}_{args[1]}') + '.pkpass')
        if not os.path.exists(path):
            die(f'no pass {args[0]} {args[1]} in Wallet')
        os.remove(path)
        print(f'removed {args[0]} {args[1]}')
    elif cmd == 'clear':
        shutil.rmtree(WALLET, ignore_errors=True)
        print('Wallet cleared (passes and orders)')
    else:
        die(f'unknown wallet command {cmd}')


AGERANGE = os.path.join(DATA, 'Library/isim/AgeRange.json')
DECLARATIONS = ('selfDeclared', 'guardianDeclared', 'confirmed', 'paymentChecked', 'governmentIDChecked', 'checkedByOtherMethod',
                'guardianPaymentChecked', 'guardianGovernmentIDChecked', 'guardianCheckedByOtherMethod')
CONTROLS = ('communicationLimits', 'significantAppChangeApprovalRequired')


def agerange(cmd, args):
    """the device account's age for DeclaredAgeRange (and PermissionKit's child account)"""
    if cmd == 'show':
        if not os.path.exists(AGERANGE):
            print('no age set (requestAgeRange throws notAvailable)')
            return
        a = json.load(open(AGERANGE))
        print(f'age {a.get("age")} declaration {a.get("declaration") or "-"} controls {",".join(a.get("controls", [])) or "-"} '
              f'regulated {str(a.get("regulated", False)).lower()}')
        return
    if cmd != 'set' or not args:
        die('usage: isim agerange set <age>|none [--declaration KIND] [--controls a,b] [--regulated] | isim agerange show')
    if args[0] == 'none':
        if os.path.exists(AGERANGE):
            os.remove(AGERANGE)
        print('age range cleared')
        return
    try:
        a = {'age': int(args[0])}
    except ValueError:
        die(f'not an age: {args[0]}')
    a['declaration'] = 'selfDeclared' if a['age'] >= 18 else 'guardianDeclared'
    a['controls'], a['regulated'] = [], False
    i = 1
    while i < len(args):
        if args[i] == '--declaration' and i + 1 < len(args):
            if args[i + 1] not in DECLARATIONS:
                die(f'unknown declaration {args[i + 1]} (one of {", ".join(DECLARATIONS)})')
            a['declaration'] = args[i + 1]; i += 2
        elif args[i] == '--controls' and i + 1 < len(args):
            a['controls'] = [c for c in args[i + 1].split(',') if c]
            bad = [c for c in a['controls'] if c not in CONTROLS]
            if bad:
                die(f'unknown parental control {bad[0]} (one of {", ".join(CONTROLS)})')
            i += 2
        elif args[i] == '--regulated':
            a['regulated'] = True; i += 1
        else:
            die(f'unknown option {args[i]}')
    os.makedirs(os.path.dirname(AGERANGE), exist_ok=True)
    write_json(AGERANGE, a)
    print(f'age {a["age"]} ({a["declaration"]}{", " + ",".join(a["controls"]) if a["controls"] else ""}{", regulated" if a["regulated"] else ""})')


def permission(app, cmd, args):
    """PermissionKit: the simulated parent answers an app's questions"""
    bid = bundle_id(app)
    path = os.path.join(DATA, 'Library/isim/PermissionKit', bid + '.json')
    o = json.load(open(path)) if os.path.exists(path) else {}
    qs = o.get('questions', [])
    if cmd == 'list':
        if not qs:
            print(f'{bid}: no questions')
        for q in qs:
            print(f'{q["id"]} {q.get("state")} {q.get("kind")}: {q.get("summary")} ({when(q.get("created"))})')
        return
    if cmd not in ('approve', 'decline'):
        die(f'unknown permission command {cmd}')
    pending = [q for q in qs if q.get('state') == 'pending' and (not args or args[0] in ('all', q['id']))]
    if not pending:
        die(f'{bid}: no pending question{" " + args[0] if args and args[0] != "all" else ""}')
    targets = pending if args and args[0] == 'all' else pending[-1:] if not args else pending
    for q in targets:
        q['state'] = 'approved' if cmd == 'approve' else 'declined'
        print(f'{q["state"]} {q["id"]}: {q.get("summary")}')
    write_json(path, o)


FINANCE = os.path.join(DATA, 'Library/isim/FinanceKit/data.json')
TXN_TYPES = ('adjustment', 'atm', 'billPayment', 'check', 'deposit', 'directDebit', 'directDeposit', 'dividend', 'fee',
             'interest', 'loan', 'pointOfSale', 'refund', 'standingOrder', 'transfer', 'unknown', 'withdrawal')


def fk_now(days=0):
    return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(time.time() - days * 86400))


def fk_amount(a, code='USD'):
    return {'amount': a, 'currencyCode': code}


def fk_load():
    if os.path.exists(FINANCE):
        return json.load(open(FINANCE))
    return {'storeID': str(uuid.uuid4()).upper(), 'sequence': 0, 'accounts': [], 'balances': [], 'transactions': [], 'log': []}


def fk_log(d, kind, op, ident, account=None):
    d['sequence'] += 1
    e = {'seq': d['sequence'], 'kind': kind, 'op': op, 'id': ident}
    if account:
        e['accountID'] = account
    d['log'].append(e)


def fk_account_id(d, name):
    for a in d['accounts']:
        body = next(iter(a.values()))['_0']
        if body['id'] == name or body['displayName'].lower() == name.lower():
            return body['id']
    die(f'no account {name} (isim finance list)')


def fk_add_account(d, kind, name, institution, description, balance, credit=None):
    ident = str(uuid.uuid4()).upper()
    body = {'id': ident, 'displayName': name, 'accountDescription': description, 'institutionName': institution,
            'currencyCode': 'USD', 'openingDate': fk_now(400)}
    if kind == 'liability':
        body['creditInformation'] = credit or {}
    d['accounts'].append({kind: {'_0': body}})
    fk_log(d, 'account', 'insert', ident)
    bal = {'amount': fk_amount(balance), 'asOfDate': fk_now(), 'creditDebitIndicator': 'debit' if kind == 'liability' else 'credit'}
    bid = str(uuid.uuid4()).upper()
    d['balances'].append({'id': bid, 'accountID': ident, 'currentBalance': {'availableAndBooked': {'available': bal, 'booked': bal}}})
    fk_log(d, 'balance', 'insert', bid, ident)
    return ident


def fk_add_txn(d, account, amount, merchant, ttype='pointOfSale', status='booked', mcc=None, days=0):
    ident = str(uuid.uuid4()).upper()
    t = {'id': ident, 'accountID': account, 'transactionAmount': fk_amount(abs(amount)),
         'creditDebitIndicator': 'credit' if amount < 0 else 'debit', 'transactionDescription': merchant,
         'originalTransactionDescription': merchant.upper(), 'merchantName': merchant, 'transactionDate': fk_now(days),
         'postedDate': fk_now(days) if status == 'booked' else None, 'transactionType': ttype, 'status': status}
    if mcc is not None:
        t['merchantCategoryCode'] = int(mcc)
    d['transactions'].append({k: v for k, v in t.items() if v is not None})
    fk_log(d, 'transaction', 'insert', ident, account)
    return ident


def finance(cmd, args):
    """FinanceKit: the device's simulated Wallet financial data"""
    if cmd == 'seed':
        d = fk_load()
        card = fk_add_account(d, 'liability', 'Apple Card', 'Apple', 'Credit card', 1234.56,
                              {'creditLimit': fk_amount(5000), 'minimumNextPaymentAmount': fk_amount(35),
                               'nextPaymentDueDate': fk_now(-14)})
        savings = fk_add_account(d, 'asset', 'Savings', 'Apple', 'High-yield savings', 8200)
        fk_add_txn(d, card, 4.75, 'Blue Bottle Coffee', mcc=5814, days=1)
        fk_add_txn(d, card, 62.18, 'Whole Foods Market', mcc=5411, days=2)
        fk_add_txn(d, card, 18.00, 'City Parking', mcc=7523, status='pending')
        fk_add_txn(d, savings, -27.40, 'Interest', ttype='interest', days=3)
        os.makedirs(os.path.dirname(FINANCE), exist_ok=True)
        write_json(FINANCE, d)
        print(f'seeded 2 accounts (Apple Card {card}, Savings {savings}) and 4 transactions')
    elif cmd == 'list':
        d = fk_load()
        if not d['accounts']:
            print('no financial data (isim finance seed)')
        for a in d['accounts']:
            kind, body = next(iter(a.items()))
            body = body['_0']
            print(f'{kind} {body["displayName"]} ({body["institutionName"]}) {body["id"]}')
            for t in d['transactions']:
                if t['accountID'] == body['id']:
                    sign = '-' if t['creditDebitIndicator'] == 'credit' else ''
                    print(f'  {t["transactionDate"][:10]} {t.get("merchantName", t["transactionDescription"])} {sign}{t["transactionAmount"]["amount"]} '
                          f'{t["transactionType"]} {t["status"]}')
    elif cmd == 'add-transaction':
        if len(args) < 3:
            die('usage: isim finance add-transaction <account> <amount> <merchant> [--type T] [--status S] [--mcc NNNN]')
        d = fk_load()
        account = fk_account_id(d, args[0])
        try:
            amount = float(args[1])
        except ValueError:
            die(f'not an amount: {args[1]}')
        opts = {'ttype': 'pointOfSale', 'status': 'booked', 'mcc': None}
        i = 3
        while i + 1 < len(args) + 1 and i < len(args):
            k = args[i]
            if k == '--type' and i + 1 < len(args) and args[i + 1] in TXN_TYPES:
                opts['ttype'] = args[i + 1]
            elif k == '--status' and i + 1 < len(args) and args[i + 1] in ('authorized', 'booked', 'memo', 'pending', 'rejected'):
                opts['status'] = args[i + 1]
            elif k == '--mcc' and i + 1 < len(args) and args[i + 1].isdigit():
                opts['mcc'] = args[i + 1]
            else:
                die(f'bad option {k}')
            i += 2
        ident = fk_add_txn(d, account, amount, args[2], **opts)
        write_json(FINANCE, d)
        print(f'added transaction {ident}: {args[2]} {amount}')
    elif cmd == 'clear':
        if os.path.exists(FINANCE):
            os.remove(FINANCE)
        print('financial data cleared')
    else:
        die('usage: isim finance seed|list|add-transaction|clear')


PROVIDER_POINT = 'com.apple.authentication-services-credential-provider-ui'
PROVIDERS = os.path.join(DATA, 'Library/isim/CredentialProviders')
GLOBAL_PREFS = os.path.join(DATA, 'Library/Preferences/.GlobalPreferences.plist')


def global_prefs():
    try:
        return plistlib.load(open(GLOBAL_PREFS, 'rb'))
    except (OSError, plistlib.InvalidFileException):
        return {}


def app_extensions(app_path, point):
    """the app's extensions of an extension point: (bundle id, appex path, executable)"""
    out = []
    plugins = os.path.join(app_path, 'PlugIns')
    for n in sorted(os.listdir(plugins)) if os.path.isdir(plugins) else []:
        p = os.path.join(plugins, n)
        try:
            info = plistlib.load(open(os.path.join(p, 'Info.plist'), 'rb'))
        except (OSError, plistlib.InvalidFileException):
            continue
        if n.endswith('.appex') and info.get('NSExtension', {}).get('NSExtensionPointIdentifier') == point:
            out.append((info.get('CFBundleIdentifier', n[:-6]), p, os.path.join(p, info.get('CFBundleExecutable', n[:-6]))))
    return out


def app_path(app):
    """an .app bundle, or an installed app by name or bundle identifier"""
    if app.endswith('.app') and os.path.isdir(app):
        return os.path.abspath(app)
    apps = os.environ.get('ISIM_APPS') or os.path.join(DATA, 'Applications')
    for n in sorted(os.listdir(apps)) if os.path.isdir(apps) else []:
        p = os.path.join(apps, n)
        try:
            info = plistlib.load(open(os.path.join(p, 'Info.plist'), 'rb'))
        except (OSError, plistlib.InvalidFileException):
            continue
        if app in (n, n[:-4], info.get('CFBundleIdentifier'), info.get('CFBundleDisplayName'), info.get('CFBundleName')):
            return p
    die(f'no app "{app}" (an .app bundle, or an installed app\'s name or bundle identifier)')


def autofill(cmd, args):
    """credential provider extensions (AuthenticationServices' ASCredentialIdentityStore, UIKit's AutoFill)"""
    prefs = global_prefs()
    on = prefs.get('AutoFillProviders', [])
    if cmd == 'providers':
        stores = {}
        for f in sorted(os.listdir(PROVIDERS)) if os.path.isdir(PROVIDERS) else []:
            if f.endswith('.json'):
                st = json.load(open(os.path.join(PROVIDERS, f)))
                stores[st.get('bundleID')] = st
        if not stores:
            print('no credential providers have been turned on or saved identities')
        for bid, st in stores.items():
            print(f'{st.get("name", bid)} ({bid}): {"on" if bid in on else "off"}')
            for i in st.get('identities', []):
                print(f'  {i.get("kind")} {i.get("user")} @ {i.get("service")}' + (f' [{i["record"]}]' if i.get('record') else ''))
        return
    if cmd not in ('enable', 'disable') or not args:
        die('usage: isim autofill providers | isim autofill enable|disable <app>')
    path = app_path(args[0])
    exts = app_extensions(path, PROVIDER_POINT)
    if not exts:
        die(f'{os.path.basename(path)} has no credential provider extension ({PROVIDER_POINT})')
    bid, appex, exe = exts[0]
    on = [b for b in on if b != bid] + ([bid] if cmd == 'enable' else [])
    prefs['AutoFillProviders'] = on
    os.makedirs(os.path.dirname(GLOBAL_PREFS), exist_ok=True)
    plistlib.dump(prefs, open(GLOBAL_PREFS, 'wb'))
    os.makedirs(PROVIDERS, exist_ok=True)
    f = os.path.join(PROVIDERS, bid + '.json')
    st = json.load(open(f)) if os.path.exists(f) else {'identities': []}
    try:
        name = plistlib.load(open(os.path.join(path, 'Info.plist'), 'rb')).get('CFBundleDisplayName') or os.path.basename(path)[:-4]
    except (OSError, plistlib.InvalidFileException):
        name = os.path.basename(path)[:-4]
    st.update({'bundleID': bid, 'name': name, 'extension': appex, 'executable': exe})
    write_json(f, st)
    print(f'{name} ({bid}): AutoFill {"on" if cmd == "enable" else "off"}')


SSO_PROFILES = os.path.join(DATA, 'Library/isim/SSO/profiles.json')


def sso(cmd, args):
    """Extensible single sign-on profiles: identity provider URLs handled by an SSO extension"""
    profiles = json.load(open(SSO_PROFILES)) if os.path.exists(SSO_PROFILES) else []
    if cmd == 'list':
        if not profiles:
            print('no SSO profiles')
        for p in profiles:
            print(f'{p["extension"]}: {" ".join(p["urls"])}' + (f' realm {p["realm"]}' if p.get('realm') else ''))
        return
    if cmd == 'add' and len(args) >= 2:
        ext, urls, realm, i = args[0], [], '', 1
        while i < len(args):
            if args[i] == '--realm' and i + 1 < len(args):
                realm = args[i + 1]; i += 2
            else:
                urls.append(args[i]); i += 1
        profiles = [p for p in profiles if p['extension'] != ext] + [{'extension': ext, 'urls': urls, 'realm': realm, 'type': 'redirect'}]
    elif cmd == 'remove' and args:
        profiles = [] if args[0] == 'all' else [p for p in profiles if p['extension'] != args[0]]
    else:
        die('usage: isim sso list | isim sso add <extension bundle id> <url>... [--realm R] | isim sso remove <extension>|all')
    os.makedirs(os.path.dirname(SSO_PROFILES), exist_ok=True)
    write_json(SSO_PROFILES, profiles)
    print(f'{len(profiles)} SSO profile(s)')


SMARTCARD_READERS = os.path.join(DATA, 'Library/isim/SmartCards/readers.json')
DEFAULT_READER = 'isim Virtual Reader'


def demo_card():
    """a PIV card (NIST SP 800-73): the PIV applet, a CHUID longer than one response, a PIN-protected certificate"""
    def tlv(tag, value):
        n = len(value)
        length = bytes([n]) if n < 0x80 else bytes([0x81, n]) if n < 0x100 else bytes([0x82, n >> 8, n & 0xFF])
        return bytes.fromhex(tag) + length + value
    chuid = tlv('53', tlv('30', bytes(range(25))) + tlv('34', bytes(range(16, 32))) + tlv('35', b'20301231')
                + tlv('3E', bytes(227)) + tlv('FE', b''))
    cert = tlv('53', tlv('70', bytes(i % 251 for i in range(252))) + tlv('71', b'\x00') + tlv('FE', b''))
    return {'atr': '3BFD1300008131FE158073C021C057597562694B657940', 'serial': '0A1B2C3D', 'token': 'dev.isim.virtual.piv',
            'pinTries': 3,
            'applets': [{'aid': 'A000000308000010000100', 'fci': '611179' + '074F05A000000308' + '4F06000010000100',
                         'pin': '123456', 'pinReference': 0x80,
                         'objects': {'5FC102': chuid.hex().upper(), '5FC105': cert.hex().upper()}, 'protected': ['5FC105']}]}


def smartcard(cmd, args):
    """isim's virtual smart card readers (CryptoTokenKit): list them, insert or remove a card, add or remove a reader"""
    conf = json.load(open(SMARTCARD_READERS)) if os.path.exists(SMARTCARD_READERS) else {'readers': []}
    readers = conf.setdefault('readers', [])
    reader_name, pin_pad, rest = DEFAULT_READER, None, []
    i = 0
    while i < len(args):
        if args[i] == '--reader' and i + 1 < len(args):
            reader_name = args[i + 1]; i += 2; continue
        if args[i] == '--pin-pad':
            pin_pad = True
        elif args[i] == '--no-pin-pad':
            pin_pad = False
        else:
            rest.append(args[i])
        i += 1
    def find(create):
        for r in readers:
            if r.get('name') == reader_name:
                return r
        if not create:
            die(f'no reader named {reader_name!r} (isim smartcard list)')
        r = {'name': reader_name, 'pinPad': True, 'card': None}
        readers.append(r)
        return r
    if cmd == 'list':
        if not readers:
            print('no readers (isim smartcard insert --demo adds one with a card)')
        for r in readers:
            card = r.get('card')
            what = f"card {card.get('atr', '?')} serial {card.get('serial', '-')}" + (f" token {card['token']}" if card.get('token') else '') \
                if card else 'empty'
            print(f"{r['name']}{' (PIN pad)' if r.get('pinPad') else ''}: {what}")
        return
    if cmd == 'insert':
        if rest == ['--demo'] or not rest:
            card = demo_card()
        else:
            path = rest[0]
            card = json.load(sys.stdin if path == '-' else open(path))
        r = find(True)
        r['card'] = card
        if pin_pad is not None:
            r['pinPad'] = pin_pad
        print(f"inserted a card in {reader_name}")
    elif cmd == 'remove':
        find(False)['card'] = None
        print(f"removed the card from {reader_name}")
    elif cmd == 'add-reader':
        r = find(True)
        if pin_pad is not None:
            r['pinPad'] = pin_pad
        print(f"reader {reader_name}")
    elif cmd == 'remove-reader':
        conf['readers'] = [r for r in readers if r.get('name') != reader_name]
        print(f"removed reader {reader_name}")
    else:
        die('usage: isim smartcard list | insert [--reader NAME] [--pin-pad|--no-pin-pad] [--demo | CARD.json | -] | '
            'remove [--reader NAME] | add-reader [--reader NAME] [--pin-pad] | remove-reader [--reader NAME]')
    os.makedirs(os.path.dirname(SMARTCARD_READERS), exist_ok=True)
    write_json(SMARTCARD_READERS, conf)


def iddocs(cmd, args):
    """IdentityDocumentServices: the mobile documents provider apps registered"""
    d = os.path.join(DATA, 'Library/isim/IdentityDocuments')
    if cmd != 'list':
        die('usage: isim iddocs list')
    found = False
    for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
        for e in json.load(open(os.path.join(d, f))):
            found = True
            until = e.get('invalidationDate')
            print(f"{f[:-5]}: {e['mobileDocumentType']} {e['documentIdentifier']}"
                  + (f" until {datetime.datetime.fromtimestamp(until, datetime.timezone.utc):%Y-%m-%d}" if until else ''))
    if not found:
        print('no identity documents registered')


def alarms(cmd, args):
    """AlarmKit: the alarms and timers apps scheduled (the shell rings them)"""
    d = os.path.join(DATA, 'Library/isim/Alarms')
    if cmd != 'list':
        die('usage: isim alarms list')
    found = False
    for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
        for r in json.load(open(os.path.join(d, f))):
            found = True
            a = r['alarm']
            state = next(iter(a['state'])) if isinstance(a['state'], dict) else a['state']
            when = ''
            if r.get('fire'):
                when = f" at {datetime.datetime.fromtimestamp(r['fire']):%Y-%m-%d %H:%M:%S}"
            elif state == 'paused':
                when = f" ({max(0, r.get('total', 0) - r.get('elapsed', 0)):.0f} s left)"
            print(f"{f[:-5]}: {r.get('kind', 'alarm')} {a['id']} \"{r.get('title', '')}\" {state}{when}")
    if not found:
        print('no alarms scheduled')


def messages(cmd, args):
    """Messages: the conversation in isim's Messages app (list), and a message from its other participant (receive)"""
    d = os.path.join(DATA, 'Library/isim/Messages')
    conv = os.path.join(d, 'conversation.json')
    entries = json.load(open(conv)).get('entries', []) if os.path.isfile(conv) else []
    if cmd == 'list':
        if not entries:
            print('no messages')
        for e in entries:
            who = 'me' if e.get('mine', True) else 'Ana'
            if e['kind'] == 'message':
                parts = [p for p in (e.get('caption'), e.get('subcaption'), e.get('url')) if p]
                print(f"{who}: [{e.get('app', '?')}] {' | '.join(parts)}" + (f" (session {e['session']})" if e.get('session') else ''))
            elif e['kind'] == 'sticker':
                print(f"{who}: [sticker] {e.get('text', '')}")
            elif e['kind'] == 'attachment':
                print(f"{who}: [attachment] {e.get('text', '')}")
            else:
                print(f"{who}: {e.get('text', '')}")
    elif cmd == 'receive':
        e = {'id': str(uuid.uuid4()).upper(), 'mine': False, 'live': False, 'date': time.time()}
        opts, rest = {}, []
        i = 0
        while i < len(args):
            if args[i] in ('--app', '--url', '--caption', '--subcaption', '--summary', '--session') and i + 1 < len(args):
                opts[args[i][2:]] = args[i + 1]
                i += 2
            else:
                rest.append(args[i])
                i += 1
        if 'app' in opts:
            e.update(kind='message', app=opts['app'])
            for k in ('url', 'caption', 'subcaption', 'summary'):
                if k in opts:
                    e[k] = opts[k]
            s = opts.get('session')
            if s == 'last':
                s = next((x.get('session') for x in reversed(entries) if x.get('app') == opts['app'] and x.get('session')), None)
                if not s:
                    die(f"no message of {opts['app']} with a session")
            if s:
                e['session'] = s
        elif rest:
            e.update(kind='text', text=' '.join(rest))
        else:
            die('usage: isim messages receive TEXT | --app EXTENSION [--url URL] [--caption C] [--subcaption S] [--summary T] [--session last|UUID]')
        os.makedirs(d, exist_ok=True)
        inbox = os.path.join(d, 'inbox.json')
        queued = json.load(open(inbox)) if os.path.isfile(inbox) else []
        write_json(inbox, queued + [e])
        print('queued for Messages')
    else:
        die('usage: isim messages list | receive ...')


def main():
    if len(sys.argv) == 3 and sys.argv[1] == 'gamecenter' and sys.argv[2] in GC_NETWORK:
        sys.argv.append('')
    if len(sys.argv) == 3 and sys.argv[1] == 'storekit' and sys.argv[2] in ('certificate', 'offer-key'):
        sys.argv.append('')
    if len(sys.argv) >= 2 and sys.argv[1] == 'finance':
        return finance(sys.argv[2] if len(sys.argv) > 2 else '', sys.argv[3:])
    if len(sys.argv) >= 2 and sys.argv[1] in ('smartcard', 'iddocs', 'alarms', 'messages'):
        return {'smartcard': smartcard, 'iddocs': iddocs, 'alarms': alarms, 'messages': messages}[sys.argv[1]](sys.argv[2] if len(sys.argv) > 2 else '', sys.argv[3:])
    if len(sys.argv) >= 2 and sys.argv[1] in ('autofill', 'sso'):
        return {'autofill': autofill, 'sso': sso}[sys.argv[1]](sys.argv[2] if len(sys.argv) > 2 else '', sys.argv[3:])
    if len(sys.argv) >= 2 and sys.argv[1] == 'agerange':
        return agerange(sys.argv[2] if len(sys.argv) > 2 else '', sys.argv[3:])
    if len(sys.argv) >= 2 and sys.argv[1] == 'wallet':
        return wallet(sys.argv[2] if len(sys.argv) > 2 else '', sys.argv[3:])
    if len(sys.argv) < 4:
        print(__doc__.strip())
        sys.exit(2)
    kind, app, cmd, args = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
    if kind == 'gamecenter' and app in GC_NETWORK and cmd == '':
        cmd, args = (args[0], args[1:]) if args else ('', [])
    {'storekit': storekit, 'gamecenter': gamecenter, 'appleid': appleid, 'permission': permission}.get(kind, lambda *a: die(f'unknown tool {kind}'))(app, cmd, args)


if __name__ == '__main__':
    main()

