#!/usr/bin/env python3
"""isim momc: compile an Xcode Core Data model (.xcdatamodeld / .xcdatamodel `contents` XML) for isim.

  momc.py MODEL.xcdatamodeld OUT_DIR [--swift-codegen DIR] [--module NAME]

Writes OUT_DIR/<Name>.momd/ with one <Version>.mom per model version and VersionInfo.plist naming the
current version (from .xccurrentversion). The .mom files are XML property lists in isim's OWN format
(top-level key "isimFormat" = "isim-managed-object-model", see docs/COREDATA.md) -- they are not Apple's
binary .mom files and Apple's Core Data cannot read them; isim's CoreData framework can.

With --swift-codegen, also writes the Swift sources Xcode's "Class Definition" / "Category/Extension"
code generation would produce for the current version's entities (<Entity>+CoreDataClass.swift and
<Entity>+CoreDataProperties.swift); "Manual/None" entities get nothing.
"""
import os
import plistlib
import sys
import xml.etree.ElementTree as ET

FORMAT = 'isim-managed-object-model'


def yes(v):
    return str(v).upper() in ('YES', 'TRUE', '1')


def typed_default(atype, s):
    if s is None:
        return None
    try:
        if atype.startswith('Integer'):
            return int(float(s))
        if atype in ('Double', 'Float', 'Decimal'):
            return float(s)
        if atype == 'Boolean':
            return yes(s)
    except ValueError:
        return None
    return s


def parse_contents(path):
    """contents XML -> isim model dict (plist-able)."""
    root = ET.parse(path).getroot()
    entities = []
    for e in root.findall('entity'):
        ent = {'name': e.get('name'), 'className': e.get('representedClassName') or e.get('name'),
               'codeGenerationType': e.get('codeGenerationType') or 'none'}
        if e.get('parentEntity'):
            ent['parent'] = e.get('parentEntity')
        if yes(e.get('isAbstract')):
            ent['abstract'] = True
        if e.get('elementID'):
            ent['renamingIdentifier'] = e.get('elementID')
        if e.get('versionHashModifier'):
            ent['versionHashModifier'] = e.get('versionHashModifier')
        attrs, rels, fetched = [], [], []
        for a in e.findall('attribute'):
            t = a.get('attributeType', 'Undefined')
            d = {'name': a.get('name'), 'type': t, 'optional': yes(a.get('optional')),
                 'scalar': yes(a.get('usesScalarValueType', 'YES' if t in ('Integer 16', 'Integer 32', 'Integer 64', 'Double', 'Float', 'Boolean') else 'NO'))}
            for key, flag in (('transient', 'transient'), ('indexed', 'indexed'), ('allowsExternalBinaryDataStorage', 'allowsExternalBinaryDataStorage')):
                if yes(a.get(flag)):
                    d[key] = True
            dv = typed_default(t, a.get('defaultValueString'))
            if a.get('defaultDateTimeInterval') is not None:
                dv = float(a.get('defaultDateTimeInterval'))
            if dv is not None:
                d['defaultValue'] = dv
            for key, xmlk in (('valueTransformerName', 'valueTransformerName'), ('customClassName', 'customClassName'),
                              ('minValue', 'minValueString'), ('maxValue', 'maxValueString'),
                              ('regularExpression', 'regularExpressionString'), ('renamingIdentifier', 'elementID')):
                if a.get(xmlk):
                    d[key] = a.get(xmlk)
            attrs.append(d)
        for r in e.findall('relationship'):
            d = {'name': r.get('name'), 'destination': r.get('destinationEntity'), 'optional': yes(r.get('optional')),
                 'toMany': yes(r.get('toMany')), 'ordered': yes(r.get('ordered')),
                 'deleteRule': r.get('deletionRule', 'Nullify'),
                 'minCount': int(r.get('minCount', '0')), 'maxCount': int(r.get('maxCount', '0' if yes(r.get('toMany')) else '1'))}
            if r.get('inverseName'):
                d['inverse'] = r.get('inverseName')
            if yes(r.get('transient')):
                d['transient'] = True
            if r.get('elementID'):
                d['renamingIdentifier'] = r.get('elementID')
            rels.append(d)
        for f in e.findall('fetchedProperty'):
            req = f.find('fetchRequest')
            if req is not None:
                fetched.append({'name': f.get('name'), 'entity': req.get('entity'), 'predicate': req.get('predicateString', '')})
        ent['attributes'], ent['relationships'] = attrs, rels
        if fetched:
            ent['fetchedProperties'] = fetched
        cons = []
        for uc in e.findall('uniquenessConstraints/uniquenessConstraint'):
            cons.append([c.get('value') for c in uc.findall('constraint')])
        if cons:
            ent['uniquenessConstraints'] = cons
        info = {x.get('key'): x.get('value') for x in e.findall('userInfo/entry')}
        if info:
            ent['userInfo'] = info
        entities.append(ent)
    model = {'isimFormat': FORMAT, 'formatVersion': 1, 'entities': entities,
             'note': 'Compiled by isim momc from an Xcode .xcdatamodel; isim format, not an Apple .mom.'}
    reqs = [{'name': r.get('name'), 'entity': r.get('entity'), 'predicate': r.get('predicateString', '')}
            for r in root.findall('fetchRequest')]
    if reqs:
        model['fetchRequests'] = reqs
    configs = {c.get('name'): [m.get('name') for m in c.findall('memberEntity')] for c in root.findall('configuration')}
    if configs:
        model['configurations'] = configs
    if root.get('userDefinedModelVersionIdentifier'):
        model['versionIdentifiers'] = [root.get('userDefinedModelVersionIdentifier')]
    return model


def versions(src):
    """[(version name, contents path)], current version name."""
    src = src.rstrip('/')
    if src.endswith('.xcdatamodel'):
        name = os.path.splitext(os.path.basename(src))[0]
        return [(name, os.path.join(src, 'contents'))], name
    out = []
    for d in sorted(os.listdir(src)):
        if d.endswith('.xcdatamodel') and os.path.exists(os.path.join(src, d, 'contents')):
            out.append((os.path.splitext(d)[0], os.path.join(src, d, 'contents')))
    current = out[-1][0] if out else None
    cv = os.path.join(src, '.xccurrentversion')
    if os.path.exists(cv):
        with open(cv, 'rb') as f:
            try:
                cur = plistlib.load(f).get('_XCCurrentVersionName')
                if cur:
                    current = os.path.splitext(cur)[0]
            except Exception:
                pass
    return out, current


# ---------------- Swift codegen (what Xcode generates) ----------------
SCALARS = {'Integer 16': 'Int16', 'Integer 32': 'Int32', 'Integer 64': 'Int64', 'Double': 'Double', 'Float': 'Float', 'Boolean': 'Bool'}
OBJECTS = {'String': 'String', 'Date': 'Date', 'Binary': 'Data', 'UUID': 'UUID', 'URI': 'URL',
           'Decimal': 'NSNumber',    # isim has no NSDecimalNumber; Xcode uses NSDecimalNumber
           'Undefined': 'NSObject', 'ObjectID': 'NSManagedObjectID'}


def swift_type(a):
    t = a['type']
    if t in SCALARS:
        return SCALARS[t] if a.get('scalar') else 'NSNumber?'
    if t == 'Transformable':
        return (a.get('customClassName') or 'NSObject') + '?'
    return OBJECTS.get(t, 'NSObject') + '?'


def codegen(model, outdir):
    os.makedirs(outdir, exist_ok=True)
    by_name = {e['name']: e for e in model['entities']}
    written = []
    for e in model['entities']:
        kind = e.get('codeGenerationType', 'none')
        if kind not in ('class', 'category'):
            continue
        cls = e['className'].split('.')[-1]
        if kind == 'class':
            parent = by_name.get(e.get('parent'), {}).get('className', 'NSManagedObject').split('.')[-1]
            p = os.path.join(outdir, f'{cls}+CoreDataClass.swift')
            with open(p, 'w') as f:
                f.write(f'// {cls}+CoreDataClass.swift -- generated by isim momc (like Xcode codegen); do not edit.\n'
                        f'import Foundation\nimport CoreData\n\n@objc({cls})\npublic class {cls}: {parent} {{\n}}\n')
            written.append(p)
        lines = [f'// {cls}+CoreDataProperties.swift -- generated by isim momc (like Xcode codegen); do not edit.',
                 'import Foundation', 'import CoreData', '', f'extension {cls} {{', '',
                 f'    @nonobjc public class func fetchRequest() -> NSFetchRequest<{cls}> {{',
                 f'        return NSFetchRequest<{cls}>(entityName: "{e["name"]}")', '    }', '']
        for a in e['attributes']:
            lines.append(f'    @NSManaged public var {a["name"]}: {swift_type(a)}')
        accessors = []
        for r in e['relationships']:
            dest = by_name.get(r['destination'], {}).get('className', r['destination']).split('.')[-1]
            n = r['name']
            if not r['toMany']:
                lines.append(f'    @NSManaged public var {n}: {dest}?')
                continue
            lines.append(f'    @NSManaged public var {n}: {"NSOrderedSet" if r["ordered"] else "NSSet"}?')
            N = n[0].upper() + n[1:]
            acc = [f'// MARK: Generated accessors for {n}', f'extension {cls} {{', '']
            if r['ordered']:
                acc += [f'    @objc(insertObject:in{N}AtIndex:) @NSManaged public func insertInto{N}(_ value: {dest}, at idx: Int)',
                        f'    @objc(removeObjectFrom{N}AtIndex:) @NSManaged public func removeFrom{N}(at idx: Int)',
                        f'    @objc(insert{N}:atIndexes:) @NSManaged public func insertInto{N}(_ values: [{dest}], at indexes: NSIndexSet)',
                        f'    @objc(remove{N}AtIndexes:) @NSManaged public func removeFrom{N}(at indexes: NSIndexSet)',
                        f'    @objc(replaceObjectIn{N}AtIndex:withObject:) @NSManaged public func replace{N}(at idx: Int, with value: {dest})']
            acc += [f'    @objc(add{N}Object:) @NSManaged public func addTo{N}(_ value: {dest})',
                    f'    @objc(remove{N}Object:) @NSManaged public func removeFrom{N}(_ value: {dest})',
                    f'    @objc(add{N}:) @NSManaged public func addTo{N}(_ values: {"NSOrderedSet" if r["ordered"] else "NSSet"})',
                    f'    @objc(remove{N}:) @NSManaged public func removeFrom{N}(_ values: {"NSOrderedSet" if r["ordered"] else "NSSet"})',
                    '', '}', '']
            accessors += acc
        lines += ['', '}', ''] + accessors
        p = os.path.join(outdir, f'{cls}+CoreDataProperties.swift')
        with open(p, 'w') as f:
            f.write('\n'.join(lines))
        written.append(p)
    return written


def compile_model(src, outdir, codegen_dir=None):
    """Returns (momd path, [generated swift files])."""
    vs, current = versions(src)
    if not vs:
        raise SystemExit(f'momc: no .xcdatamodel with a contents file in {src}')
    name = os.path.splitext(os.path.basename(src.rstrip('/')))[0]
    momd = os.path.join(outdir, name + '.momd')
    os.makedirs(momd, exist_ok=True)
    models = {}
    for vname, contents in vs:
        m = parse_contents(contents)
        models[vname] = m
        with open(os.path.join(momd, vname + '.mom'), 'wb') as f:
            plistlib.dump(m, f, fmt=plistlib.FMT_XML)
    with open(os.path.join(momd, 'VersionInfo.plist'), 'wb') as f:
        plistlib.dump({'NSManagedObjectModel_CurrentVersionName': current, 'NSManagedObjectModel_VersionHashes': {v: {} for v in models},
                       'isimFormat': FORMAT}, f, fmt=plistlib.FMT_XML)
    generated = codegen(models[current], codegen_dir) if codegen_dir else []
    return momd, generated


def main(argv):
    args = [a for a in argv if not a.startswith('--')]
    cg = None
    if '--swift-codegen' in argv:
        cg = argv[argv.index('--swift-codegen') + 1]
        args.remove(cg)
    if len(args) != 2:
        sys.exit(__doc__)
    momd, gen = compile_model(args[0], args[1], cg)
    print(f'momc: {momd}' + (f' (+{len(gen)} generated Swift files)' if gen else ''))


if __name__ == '__main__':
    main(sys.argv[1:])
