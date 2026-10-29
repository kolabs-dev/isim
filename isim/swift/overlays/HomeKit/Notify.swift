// isim HomeKit: one object per home, room, accessory, service and characteristic (apps compare them with ===), and the
// delegate callbacks for changes made outside the app (`isim home ...`, another app, the simulated accessories).
// Like iOS, an app's own changes are reported to its completion handlers, not to its delegates.
import Foundation

final class _HMObjects: @unchecked Sendable {
    static let shared = _HMObjects()
    private let lock = NSRecursiveLock()
    private var table: [String: AnyObject] = [:]
    private var managers: [Weak] = []
    private var browsers: [Weak] = []

    struct Weak { weak var object: AnyObject? }

    func object<T: AnyObject>(_ id: String, _ make: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        if let o = table[id] as? T { return o }
        let o = make()
        table[id] = o
        return o
    }
    func existing<T: AnyObject>(_ id: String, _ type: T.Type) -> T? {
        lock.lock(); defer { lock.unlock() }
        return table[id] as? T
    }
    func register(_ o: AnyObject, _ id: String) { lock.lock(); table[id] = o; lock.unlock() }

    func addManager(_ m: HMHomeManager) { lock.lock(); managers.append(Weak(object: m)); lock.unlock() }
    var allManagers: [HMHomeManager] { lock.lock(); defer { lock.unlock() }; return managers.compactMap { $0.object as? HMHomeManager } }
    func addBrowser(_ b: HMAccessoryBrowser) { lock.lock(); browsers.append(Weak(object: b)); lock.unlock() }
    var allBrowsers: [HMAccessoryBrowser] { lock.lock(); defer { lock.unlock() }; return browsers.compactMap { $0.object as? HMAccessoryBrowser } }

    // the objects, made on first use
    func home(_ id: String) -> HMHome { object(id) { HMHome(_id: id) } }
    func room(_ id: String) -> HMRoom { object(id) { HMRoom(_id: id) } }
    func zone(_ id: String) -> HMZone { object(id) { HMZone(_id: id) } }
    func group(_ id: String) -> HMServiceGroup { object(id) { HMServiceGroup(_id: id) } }
    func user(_ id: String) -> HMUser { object(id) { HMUser(_id: id) } }
    func accessory(_ id: String) -> HMAccessory { object(id) { HMAccessory(_id: id) } }
    func service(_ id: String) -> HMService { object(id) { HMService(_id: id) } }
    func characteristic(_ id: String) -> HMCharacteristic { object(id) { HMCharacteristic(_id: id) } }
    func actionSet(_ id: String) -> HMActionSet { object(id) { HMActionSet(_id: id) } }
}

/// runs on the main thread: now if already there
func _hmMain(_ body: @escaping () -> Void) {
    if Thread.isMainThread { body() } else { DispatchQueue.main.async(execute: body) }
}
/// a completion handler's call, on the main thread after the current one
func _hmReply(_ body: @escaping () -> Void) { DispatchQueue.main.async(execute: body) }

enum _HMNotify {
    static var objects: _HMObjects { .shared }

    /// one characteristic changed outside the app: the accessory's delegate hears it if the app enabled notifications
    static func valueChanged(_ id: String) {
        guard let (a, s, _) = _HMStore.shared.characteristicPath(id) else { return }
        _hmMain {
            guard let c = objects.existing(id, HMCharacteristic.self), c._notifications,
                  let acc = objects.existing(a, HMAccessory.self) else { return }
            acc.delegate?.accessory?(acc, service: objects.service(s), didUpdateValueFor: c)
        }
    }

    static func changes(from old: _HMData, to new: _HMData) {
        _hmMain { diff(old, new) }
    }

    private static func diff(_ old: _HMData, _ new: _HMData) {
        let managers = objects.allManagers
        let oldHomes = Dictionary(old.homes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let newHomes = Dictionary(new.homes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for h in new.homes where oldHomes[h.id] == nil {
            for m in managers { m.delegate?.homeManager?(m, didAdd: objects.home(h.id)) }
        }
        for h in old.homes where newHomes[h.id] == nil {
            for m in managers { m.delegate?.homeManager?(m, didRemove: objects.home(h.id)) }
        }
        if old.primary != new.primary { for m in managers { m.delegate?.homeManagerDidUpdatePrimaryHome?(m) } }
        for h in new.homes { if let o = oldHomes[h.id], o != h { home(o, h) } }

        // accessories nearby: the browsers that are searching
        let before = Set(old.available.map(\.id)), after = Set(new.available.map(\.id))
        for b in objects.allBrowsers where b._searching {
            for a in new.available where !before.contains(a.id) { b.delegate?.accessoryBrowser?(b, didFindNewAccessory: objects.accessory(a.id)) }
            for a in old.available where !after.contains(a.id) { b.delegate?.accessoryBrowser?(b, didRemoveNewAccessory: objects.accessory(a.id)) }
        }
        for a in new.available { if let o = old.available.first(where: { $0.id == a.id }), o != a { accessory(o, a) } }
    }

    private static func home(_ old: _HMHomeRec, _ new: _HMHomeRec) {
        let home = objects.home(new.id)
        let d = home.delegate
        if old.name != new.name { d?.homeDidUpdateName?(home) }
        if old.hub != new.hub { d?.home?(home, didUpdate: home.homeHubState) }
        func added<T>(_ a: [T], _ b: [T], _ id: (T) -> String) -> [T] { let o = Set(a.map(id)); return b.filter { !o.contains(id($0)) } }
        for r in added(old.rooms, new.rooms, \.id) { d?.home?(home, didAdd: objects.room(r.id)) }
        for r in added(new.rooms, old.rooms, \.id) { d?.home?(home, didRemove: objects.room(r.id)) }
        for r in new.rooms { if let o = old.rooms.first(where: { $0.id == r.id }), o.name != r.name { d?.home?(home, didUpdateNameFor: objects.room(r.id)) } }
        for z in added(old.zones, new.zones, \.id) { d?.home?(home, didAdd: objects.zone(z.id)) }
        for z in added(new.zones, old.zones, \.id) { d?.home?(home, didRemove: objects.zone(z.id)) }
        for z in new.zones {
            guard let o = old.zones.first(where: { $0.id == z.id }) else { continue }
            if o.name != z.name { d?.home?(home, didUpdateNameFor: objects.zone(z.id)) }
            for r in z.rooms where !o.rooms.contains(r) { d?.home?(home, didAdd: objects.room(r), to: objects.zone(z.id)) }
            for r in o.rooms where !z.rooms.contains(r) { d?.home?(home, didRemove: objects.room(r), from: objects.zone(z.id)) }
        }
        for a in added(old.accessories, new.accessories, \.id) { d?.home?(home, didAdd: objects.accessory(a.id)) }
        for a in added(new.accessories, old.accessories, \.id) { d?.home?(home, didRemove: objects.accessory(a.id)) }
        for a in new.accessories {
            guard let o = old.accessories.first(where: { $0.id == a.id }), o != a else { continue }
            if o.room != a.room { d?.home?(home, didUpdate: a.room.map { objects.room($0) } ?? home.roomForEntireHome(), for: objects.accessory(a.id)) }
            if o.blocked == true, a.blocked != true { d?.home?(home, didUnblockAccessory: objects.accessory(a.id)) }
            accessory(o, a)
        }
        for g in added(old.serviceGroups, new.serviceGroups, \.id) { d?.home?(home, didAdd: objects.group(g.id)) }
        for g in added(new.serviceGroups, old.serviceGroups, \.id) { d?.home?(home, didRemove: objects.group(g.id)) }
        for s in added(old.actionSets, new.actionSets, \.id) { d?.home?(home, didAdd: objects.actionSet(s.id)) }
        for s in added(new.actionSets, old.actionSets, \.id) { d?.home?(home, didRemove: objects.actionSet(s.id)) }
        for s in new.actionSets {
            guard let o = old.actionSets.first(where: { $0.id == s.id }) else { continue }
            if o.name != s.name { d?.home?(home, didUpdateNameFor: objects.actionSet(s.id)) }
            if o.actions != s.actions { d?.home?(home, didUpdateActionsFor: objects.actionSet(s.id)) }
        }
        for t in added(old.triggers, new.triggers, \.id) { d?.home?(home, didAdd: _HMAutomation.trigger(t)) }
        for t in added(new.triggers, old.triggers, \.id) { d?.home?(home, didRemove: _HMAutomation.trigger(t)) }
        for t in new.triggers {
            guard let o = old.triggers.first(where: { $0.id == t.id }), o != t else { continue }
            if o.name != t.name { d?.home?(home, didUpdateNameFor: _HMAutomation.trigger(t)) } else { d?.home?(home, didUpdate: _HMAutomation.trigger(t)) }
        }
        for u in added(old.users, new.users, \.id) { d?.home?(home, didAdd: objects.user(u.id)) }
        for u in added(new.users, old.users, \.id) { d?.home?(home, didRemove: objects.user(u.id)) }
    }

    private static func accessory(_ old: _HMAccessoryRec, _ new: _HMAccessoryRec) {
        let acc = objects.accessory(new.id)
        let d = acc.delegate
        if old.name != new.name { d?.accessoryDidUpdateName?(acc) }
        if (old.reachable ?? true) != (new.reachable ?? true) { d?.accessoryDidUpdateReachability?(acc) }
        if old.firmware != new.firmware, let f = new.firmware { d?.accessory?(acc, didUpdateFirmwareVersion: f) }
        if old.services.map(\.id) != new.services.map(\.id) { d?.accessoryDidUpdateServices?(acc); return }
        for (os, ns) in zip(old.services, new.services) {
            if os.name != ns.name { d?.accessory?(acc, didUpdateNameFor: objects.service(ns.id)) }
            if os.associated != ns.associated { d?.accessory?(acc, didUpdateAssociatedServiceTypeFor: objects.service(ns.id)) }
            for (oc, nc) in zip(os.characteristics, ns.characteristics) where oc.value != nc.value {
                if let c = objects.existing(nc.id, HMCharacteristic.self), c._notifications {
                    d?.accessory?(acc, service: objects.service(ns.id), didUpdateValueFor: c)
                }
                _HMAutomation.characteristicChanged(nc.id, nc.value)
            }
        }
    }
}
