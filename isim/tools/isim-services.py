#!/usr/bin/env python3
"""isim debug tools for the local App Store, Game Center and Sign in with Apple (like Xcode's Transaction Manager).

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
  isim gamecenter players                          players on the local Game Center network (devices, test players)
  isim gamecenter player add|remove <nickname>     add or remove a test player
  isim gamecenter friends                          this device's friends and friend requests
  isim gamecenter befriend <nickname> [<nickname>] make two players friends (default: with this device's player)
  isim gamecenter accept-friend <nickname>         accept a friend request (Settings > Game Center does the same)
  isim gamecenter request-friend <nickname> [message]   a test player asks this device's player to be friends
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

<app> is a bundle identifier, an .app bundle or an installed app's name. Running apps notice changes
within half a second. Data: ISIM_DATA (~/.local/share/isim)/Containers/<bundle id>/Library/isim/. The local Game Center network that isim
devices on this computer share: ISIM_GAMECENTER (~/.local/share/isim-gamecenter).
"""
import base64, json, os, plistlib, random, sys, time, uuid, shutil

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


GC = os.environ.get('ISIM_GAMECENTER') or os.path.expanduser('~/.local/share/isim-gamecenter')
GC_NETWORK = ('players', 'player', 'friends', 'befriend', 'accept-friend', 'request-friend')


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


def main():
    if len(sys.argv) == 3 and sys.argv[1] == 'gamecenter' and sys.argv[2] in GC_NETWORK:
        sys.argv.append('')
    if len(sys.argv) < 4:
        print(__doc__.strip())
        sys.exit(2)
    kind, app, cmd, args = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
    if kind == 'gamecenter' and app in GC_NETWORK and cmd == '':
        cmd, args = (args[0], args[1:]) if args else ('', [])
    {'storekit': storekit, 'gamecenter': gamecenter, 'appleid': appleid}.get(kind, lambda *a: die(f'unknown tool {kind}'))(app, cmd, args)


if __name__ == '__main__':
    main()
