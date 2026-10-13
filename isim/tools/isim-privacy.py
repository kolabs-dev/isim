#!/usr/bin/env python3
"""isim privacy-report: the privacy manifests (PrivacyInfo.xcprivacy) of a built app, like Xcode's privacy report.

  isim privacy-report <App.app> [-o REPORT.md] [--json]

Reads the manifests of the app, its frameworks, plug-ins and resource bundles, checks them like App Store Connect
does (structure, known keys and values, reasons for required-reason API categories) and scans the binaries for the
required-reason APIs (file timestamps, system boot time, disk space, active keyboards, user defaults): an API a
binary uses whose category its bundle does not declare is ITMS-91053 ("Missing API declaration"). The report lists
what each bundle tracks, its tracking domains, the data it collects and why, and the APIs it declares.
`isim build` runs the same checks on the apps it builds and prints the problems as warnings. Exit status: 0, or 1
with --strict when there are problems.

Apple documents the keys at https://developer.apple.com/documentation/bundleresources/privacy-manifest-files.
"""
import argparse
import json
import os
import plistlib
import struct
import sys

# required-reason API categories and their approved reasons (Apple's list)
REASONS = {
    "NSPrivacyAccessedAPICategoryFileTimestamp": {"DDA9.1", "C617.1", "3B52.1", "0A2A.1"},
    "NSPrivacyAccessedAPICategorySystemBootTime": {"35F9.1", "8FFB.1", "3D61.1"},
    "NSPrivacyAccessedAPICategoryDiskSpace": {"85F4.1", "E174.1", "7D9E.1", "B728.1"},
    "NSPrivacyAccessedAPICategoryActiveKeyboards": {"3EC4.1", "54BD.1"},
    "NSPrivacyAccessedAPICategoryUserDefaults": {"CA92.1", "1C8F.1", "C56D.1", "AC6B.1"},
}
SHORT = {k: k.replace("NSPrivacyAccessedAPICategory", "") for k in REASONS}

# what a binary references for each category: C symbols it imports, and Objective-C / Swift names in it
API_SYMBOLS = {
    "NSPrivacyAccessedAPICategoryFileTimestamp": {"_stat", "_fstat", "_lstat", "_fstatat", "_getattrlist", "_fgetattrlist",
                                                 "_getattrlistat", "_getattrlistbulk", "_stat64", "_fstat64", "_lstat64"},
    "NSPrivacyAccessedAPICategorySystemBootTime": {"_mach_absolute_time"},
    "NSPrivacyAccessedAPICategoryDiskSpace": {"_statfs", "_statvfs", "_fstatfs", "_fstatvfs", "_statfs64", "_fstatfs64"},
    "NSPrivacyAccessedAPICategoryActiveKeyboards": set(),
    "NSPrivacyAccessedAPICategoryUserDefaults": {"_OBJC_CLASS_$_NSUserDefaults", "_CFPreferencesCopyAppValue",
                                                "_CFPreferencesSetAppValue"},
}
API_NAMES = {    # substrings of symbol names (Swift mangling) or Objective-C selector / constant names in the binary
    "NSPrivacyAccessedAPICategoryFileTimestamp": [b"NSFileCreationDate", b"NSFileModificationDate", b"NSURLContentModificationDateKey",
                                                 b"NSURLCreationDateKey", b"NSFileAttributeKeya10FoundationE16modificationDate",
                                                 b"NSFileAttributeKeya10FoundationE12creationDate", b"contentModificationDateKey"],
    "NSPrivacyAccessedAPICategorySystemBootTime": [b"systemUptime"],
    "NSPrivacyAccessedAPICategoryDiskSpace": [b"NSFileSystemFreeSize", b"NSFileSystemSize", b"volumeAvailableCapacity",
                                             b"volumeTotalCapacity", b"NSFileAttributeKeya10FoundationE14systemFreeSize"],
    "NSPrivacyAccessedAPICategoryActiveKeyboards": [b"activeInputModes"],
    "NSPrivacyAccessedAPICategoryUserDefaults": [b"12UserDefaultsC", b"NSUserDefaults"],
}

DATA_TYPES = set("""NSPrivacyCollectedDataTypeName NSPrivacyCollectedDataTypeEmailAddress NSPrivacyCollectedDataTypePhoneNumber
NSPrivacyCollectedDataTypePhysicalAddress NSPrivacyCollectedDataTypeOtherUserContactInfo NSPrivacyCollectedDataTypeHealth
NSPrivacyCollectedDataTypeFitness NSPrivacyCollectedDataTypePaymentInfo NSPrivacyCollectedDataTypeCreditInfo
NSPrivacyCollectedDataTypeOtherFinancialInfo NSPrivacyCollectedDataTypePreciseLocation NSPrivacyCollectedDataTypeCoarseLocation
NSPrivacyCollectedDataTypeSensitiveInfo NSPrivacyCollectedDataTypeContacts NSPrivacyCollectedDataTypeEmailsOrTextMessages
NSPrivacyCollectedDataTypePhotosorVideos NSPrivacyCollectedDataTypeAudioData NSPrivacyCollectedDataTypeGameplayContent
NSPrivacyCollectedDataTypeCustomerSupport NSPrivacyCollectedDataTypeOtherUserContent NSPrivacyCollectedDataTypeBrowsingHistory
NSPrivacyCollectedDataTypeSearchHistory NSPrivacyCollectedDataTypeUserID NSPrivacyCollectedDataTypeDeviceID
NSPrivacyCollectedDataTypePurchaseHistory NSPrivacyCollectedDataTypeProductInteraction NSPrivacyCollectedDataTypeAdvertisingData
NSPrivacyCollectedDataTypeOtherUsageData NSPrivacyCollectedDataTypeCrashData NSPrivacyCollectedDataTypePerformanceData
NSPrivacyCollectedDataTypeOtherDiagnosticData NSPrivacyCollectedDataTypeEnvironmentScanning NSPrivacyCollectedDataTypeHands
NSPrivacyCollectedDataTypeHead NSPrivacyCollectedDataTypeOtherDataTypes""".split())
PURPOSES = set("""NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising NSPrivacyCollectedDataTypePurposeDeveloperAdvertising
NSPrivacyCollectedDataTypePurposeAnalytics NSPrivacyCollectedDataTypePurposeProductPersonalization
NSPrivacyCollectedDataTypePurposeAppFunctionality NSPrivacyCollectedDataTypePurposeOther""".split())
TOP_KEYS = {"NSPrivacyTracking", "NSPrivacyTrackingDomains", "NSPrivacyCollectedDataTypes", "NSPrivacyAccessedAPITypes"}


def short_type(t):
    return t.replace("NSPrivacyCollectedDataType", "").replace("Purpose", "")


# ---------------- bundles and binaries ----------------

def bundles(app):
    """(relative path, bundle dir) of the app and every bundle in it that can have a manifest"""
    out = [(".", app)]
    for root, dirs, _ in os.walk(app):
        for d in sorted(dirs):
            if d.endswith((".framework", ".bundle", ".appex", ".app")):
                out.append((os.path.relpath(os.path.join(root, d), app), os.path.join(root, d)))
    return out


def executable(bundle):
    info = os.path.join(bundle, "Info.plist")
    name = None
    if os.path.exists(info):
        try:
            with open(info, "rb") as f:
                name = plistlib.load(f).get("CFBundleExecutable")
        except Exception:
            name = None
    if not name and bundle.endswith(".framework"):
        name = os.path.basename(bundle)[:-len(".framework")]
    path = os.path.join(bundle, name) if name else None
    return path if path and os.path.isfile(path) else None


def macho_symbols(data):
    """the symbol names of a 64-bit Mach-O image (its x86_64 slice in a fat file)"""
    off = 0
    if len(data) < 32:
        return []
    if struct.unpack_from("<I", data, 0)[0] in (0xbebafeca, 0xcafebabe):
        for i in range(struct.unpack_from(">I", data, 4)[0]):
            cpu, _, o, _, _ = struct.unpack_from(">iiIII", data, 8 + i * 20)
            if cpu == 0x01000007:
                off = o
    if struct.unpack_from("<I", data, off)[0] != 0xfeedfacf:
        return []
    out = []
    ncmds = struct.unpack_from("<I", data, off + 16)[0]
    p = off + 32
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", data, p)
        if cmd == 0x2:                                           # LC_SYMTAB
            symoff, nsyms, stroff, _ = struct.unpack_from("<IIII", data, p + 8)
            for i in range(nsyms):
                strx = struct.unpack_from("<I", data, off + symoff + i * 16)[0]
                end = data.index(b"\0", off + stroff + strx)
                out.append(data[off + stroff + strx:end].decode("utf-8", "replace"))
        p += size
    return out


def used_categories(binary):
    """the required-reason API categories a binary references"""
    with open(binary, "rb") as f:
        data = f.read()
    syms = set(macho_symbols(data))
    used = set()
    for cat in REASONS:
        if syms & API_SYMBOLS[cat] or any(n in data for n in API_NAMES[cat]):
            used.add(cat)
    return used


# ---------------- manifests ----------------

def read_manifest(bundle):
    path = os.path.join(bundle, "PrivacyInfo.xcprivacy")
    if not os.path.exists(path):
        return None, None, []
    try:
        with open(path, "rb") as f:
            m = plistlib.load(f)
    except Exception as e:
        return path, None, [f"{path}: not a property list ({e})"]
    return path, m, validate(path, m)


def validate(path, m):
    problems = []
    if not isinstance(m, dict):
        return [f"{path}: the manifest must be a dictionary"]
    for k in m:
        if k not in TOP_KEYS:
            problems.append(f"{path}: unknown key {k}")
    if "NSPrivacyTracking" in m and not isinstance(m["NSPrivacyTracking"], bool):
        problems.append(f"{path}: NSPrivacyTracking must be a Boolean")
    domains = m.get("NSPrivacyTrackingDomains", [])
    if not isinstance(domains, list) or not all(isinstance(d, str) and d for d in domains):
        problems.append(f"{path}: NSPrivacyTrackingDomains must be an array of domain names")
    elif domains and not m.get("NSPrivacyTracking"):
        problems.append(f"{path}: NSPrivacyTrackingDomains lists domains but NSPrivacyTracking is not true")
    elif m.get("NSPrivacyTracking") and not domains:
        problems.append(f"{path}: NSPrivacyTracking is true but NSPrivacyTrackingDomains is empty")
    for i, t in enumerate(m.get("NSPrivacyCollectedDataTypes", []) or []):
        where = f"{path}: NSPrivacyCollectedDataTypes[{i}]"
        if not isinstance(t, dict):
            problems.append(f"{where} must be a dictionary"); continue
        if t.get("NSPrivacyCollectedDataType") not in DATA_TYPES:
            problems.append(f"{where}: unknown NSPrivacyCollectedDataType {t.get('NSPrivacyCollectedDataType')!r}")
        for k in ("NSPrivacyCollectedDataTypeLinked", "NSPrivacyCollectedDataTypeTracking"):
            if not isinstance(t.get(k), bool):
                problems.append(f"{where}: {k} must be a Boolean")
        purposes = t.get("NSPrivacyCollectedDataTypePurposes")
        if not isinstance(purposes, list) or not purposes:
            problems.append(f"{where}: NSPrivacyCollectedDataTypePurposes must list at least one purpose")
        else:
            for p in purposes:
                if p not in PURPOSES:
                    problems.append(f"{where}: unknown purpose {p!r}")
    for i, a in enumerate(m.get("NSPrivacyAccessedAPITypes", []) or []):
        where = f"{path}: NSPrivacyAccessedAPITypes[{i}]"
        if not isinstance(a, dict):
            problems.append(f"{where} must be a dictionary"); continue
        cat = a.get("NSPrivacyAccessedAPIType")
        if cat not in REASONS:
            problems.append(f"{where}: unknown NSPrivacyAccessedAPIType {cat!r}"); continue
        reasons = a.get("NSPrivacyAccessedAPITypeReasons")
        if not isinstance(reasons, list) or not reasons:
            problems.append(f"{where}: {SHORT[cat]} needs at least one reason in NSPrivacyAccessedAPITypeReasons")
        else:
            for r in reasons:
                if r not in REASONS[cat]:
                    problems.append(f"{where}: {r!r} is not an approved reason for {SHORT[cat]} "
                                    f"(approved: {', '.join(sorted(REASONS[cat]))})")
    return problems


def analyze(app):
    """per bundle: its manifest summary, the problems, and ITMS-91053 missing declarations"""
    result = []
    for rel, b in bundles(app):
        path, m, problems = read_manifest(b)
        declared = {a.get("NSPrivacyAccessedAPIType") for a in (m or {}).get("NSPrivacyAccessedAPITypes", []) or [] if isinstance(a, dict)}
        exe = executable(b)
        used = used_categories(exe) if exe else set()
        missing = sorted(used - declared)
        for cat in missing:
            problems.append(f"ITMS-91053: Missing API declaration - {rel if rel != '.' else os.path.basename(app)} references "
                            f"{SHORT[cat]} APIs ({cat}) but its privacy manifest does not declare a reason for them")
        if m is None and not used:
            continue
        result.append({
            "bundle": rel, "manifest": os.path.relpath(path, app) if path else None, "binary": os.path.relpath(exe, app) if exe else None,
            "tracking": bool((m or {}).get("NSPrivacyTracking")),
            "trackingDomains": list((m or {}).get("NSPrivacyTrackingDomains", []) or []),
            "collectedData": [{"type": short_type(t.get("NSPrivacyCollectedDataType", "?")), "linked": t.get("NSPrivacyCollectedDataTypeLinked"),
                               "tracking": t.get("NSPrivacyCollectedDataTypeTracking"),
                               "purposes": [short_type(p) for p in t.get("NSPrivacyCollectedDataTypePurposes", []) or []]}
                              for t in (m or {}).get("NSPrivacyCollectedDataTypes", []) or [] if isinstance(t, dict)],
            "accessedAPIs": [{"category": SHORT.get(a.get("NSPrivacyAccessedAPIType"), a.get("NSPrivacyAccessedAPIType")),
                              "reasons": a.get("NSPrivacyAccessedAPITypeReasons", [])}
                             for a in (m or {}).get("NSPrivacyAccessedAPITypes", []) or [] if isinstance(a, dict)],
            "usedAPIs": sorted(SHORT[c] for c in used),
            "problems": problems,
        })
    return result


def markdown(app, result):
    name = os.path.basename(app.rstrip("/"))
    lines = [f"# Privacy report: {name}", ""]
    if not result:
        lines += ["No privacy manifests, and no required-reason APIs used.", ""]
    for r in result:
        lines += [f"## {name if r['bundle'] == '.' else r['bundle']}", ""]
        lines.append(f"- Manifest: {r['manifest'] or 'none'}")
        lines.append(f"- Tracking: {'yes' if r['tracking'] else 'no'}"
                     + (f" (domains: {', '.join(r['trackingDomains'])})" if r['trackingDomains'] else ""))
        if r["collectedData"]:
            lines += ["", "| Data collected | Linked to the user | Used for tracking | Purposes |", "|---|---|---|---|"]
            for d in r["collectedData"]:
                lines.append(f"| {d['type']} | {'yes' if d['linked'] else 'no'} | {'yes' if d['tracking'] else 'no'} | {', '.join(d['purposes'])} |")
        if r["accessedAPIs"]:
            lines += ["", "| Required-reason API | Reasons |", "|---|---|"]
            for a in r["accessedAPIs"]:
                lines.append(f"| {a['category']} | {', '.join(a['reasons'])} |")
        if r["usedAPIs"]:
            lines += ["", f"Required-reason APIs the binary uses: {', '.join(r['usedAPIs'])}"]
        if r["problems"]:
            lines += ["", "Problems:"] + [f"- {p}" for p in r["problems"]]
        lines.append("")
    return "\n".join(lines)


def check(app, log):
    """for isim build: the problems as warnings"""
    n = 0
    for r in analyze(app):
        for p in r["problems"]:
            log(f"warning: {p}")
            n += 1
    return n


def main():
    ap = argparse.ArgumentParser(prog="isim privacy-report", description="the privacy manifests of a built app (like Xcode's privacy report)")
    ap.add_argument("app")
    ap.add_argument("-o", dest="out", help="write the report to this file (Markdown, or JSON with --json)")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--strict", action="store_true", help="exit with status 1 when there are problems")
    a = ap.parse_args()
    if not os.path.isdir(a.app):
        sys.exit(f"isim privacy-report: {a.app} is not an app bundle")
    result = analyze(a.app)
    text = json.dumps(result, indent=2) if a.json else markdown(a.app, result)
    if a.out:
        with open(a.out, "w") as f:
            f.write(text + "\n")
        print(f"isim privacy-report: wrote {a.out}")
    else:
        print(text)
    if a.strict and any(r["problems"] for r in result):
        sys.exit(1)


if __name__ == "__main__":
    main()
