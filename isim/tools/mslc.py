#!/usr/bin/env python3
"""isim's Metal Shading Language compiler for Metal on the CPU (issue #328): translates .metal sources to C++ against
isim's metal_stdlib shim (SDK/usr/lib/isim/metal/include/__isim_metal.h) and builds them, with isim's clang (isim cc),
into a guest dylib that Metal.framework loads (frameworks/Metal). Adapted: kernels run on the CPU, not a GPU.

  mslc.py -o out.dylib [-I dir] [-D NAME[=VALUE]] [-O0|-O2] [--ast] file.metal ...

Each kernel gets an entry point, __isim_k_<name>(const __isim_mtl_thread *), that binds its [[buffer(n)]],
[[texture(n)]], [[sampler(n)]], [[threadgroup(n)]] and thread-position arguments from the dispatch
(isim_metal_abi.h); the library lists its functions in __isim_mtl_functions. Errors point at the .metal lines.
isim build (isim-build.py) imports compile(); isim metal-compile and Metal's run-time compiles run the command."""
import os
import re
import shutil
import subprocess
import sys
import tempfile

BIN = os.path.dirname(os.path.realpath(__file__))
ADDRESS_SPACES = {"device", "constant", "thread", "threadgroup_imageblock", "ray_data", "object_data"}
VECTOR_TYPES = {f"{t}{n}": (c, n) for t, c in (("bool", "signed char"), ("char", "signed char"), ("uchar", "unsigned char"),
                                              ("short", "short"), ("ushort", "unsigned short"), ("int", "int"),
                                              ("uint", "unsigned int"), ("long", "long"), ("ulong", "unsigned long"),
                                              ("half", "_Float16"), ("float", "float")) for n in (2, 3, 4)}
QUALIFIERS = {"kernel": 3, "vertex": 1, "fragment": 2}
# MTLDataType of the function-constant types
DATA_TYPES = {"float": 3, "float2": 4, "float3": 5, "float4": 6, "half": 16, "half2": 17, "half3": 18, "half4": 19,
              "int": 29, "int2": 30, "int3": 31, "int4": 32, "uint": 33, "uint2": 34, "uint3": 35, "uint4": 36,
              "short": 37, "short2": 38, "short3": 39, "short4": 40, "ushort": 41, "ushort2": 42, "ushort3": 43,
              "ushort4": 44, "char": 45, "char2": 46, "char3": 47, "char4": 48, "uchar": 49, "uchar2": 50, "uchar3": 51,
              "uchar4": 52, "bool": 53, "bool2": 54, "bool3": 55, "bool4": 56, "long": 81, "ulong": 85}
# thread-position attributes: the expression for each, from the dispatch (__a) and the thread (__t)
POSITIONS = {
    "thread_position_in_grid": "__isim_pos<{T}>(__t->position_in_grid)",
    "thread_position_in_threadgroup": "__isim_pos<{T}>(__t->position_in_threadgroup)",
    "threadgroup_position_in_grid": "__isim_pos<{T}>(__t->threadgroup_position_in_grid)",
    "threads_per_threadgroup": "__isim_pos<{T}>(__t->threads_per_threadgroup)",
    "dispatch_threads_per_threadgroup": "__isim_pos<{T}>(__a->threads_per_threadgroup)",
    "threads_per_grid": "__isim_pos<{T}>(__a->threads_per_grid)",
    "grid_size": "__isim_pos<{T}>(__a->threads_per_grid)",
    "threadgroups_per_grid": "__isim_pos<{T}>(__a->threadgroups_per_grid)",
    "grid_origin": "({T}){{}}",
    "thread_index_in_threadgroup": "({T})__t->index_in_threadgroup",
    "thread_execution_width": "({T})1",
    "threads_per_simdgroup": "({T})1",
    "thread_index_in_simdgroup": "({T})0",
    "simdgroup_index_in_threadgroup": "({T})__t->index_in_threadgroup",
    "simdgroups_per_threadgroup": "({T})(__t->threads_per_threadgroup[0] * __t->threads_per_threadgroup[1] * __t->threads_per_threadgroup[2])",
    "dispatch_simdgroups_per_threadgroup": "({T})(__a->threads_per_threadgroup[0] * __a->threads_per_threadgroup[1] * __a->threads_per_threadgroup[2])",
    "thread_index_in_quadgroup": "({T})(__t->index_in_threadgroup % 4)",
    "quadgroup_index_in_threadgroup": "({T})(__t->index_in_threadgroup / 4)",
}


class MSLError(Exception):
    pass


def sdk_dir():
    if os.environ.get("ISIM_SDK"):
        return os.environ["ISIM_SDK"]
    for d in (os.path.join(BIN, "..", "sdk"), os.path.join(BIN, "..", "out", "sdk")):
        if os.path.isdir(d):
            return os.path.realpath(d)
    raise MSLError("isim's SDK was not found next to mslc.py (set ISIM_SDK)")


# ---- tokens ----
TOKEN = re.compile(r"""
    (?P<nl>\n) | (?P<ws>[ \t\r\f\v]+) |
    (?P<num>\.?[0-9](?:[eEpP][+-]|[0-9A-Za-z_.])*) |
    (?P<id>[A-Za-z_][A-Za-z_0-9]*) |
    (?P<str>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*') |
    (?P<punct>\[\[|\]\]|::|->|\+\+|--|<<=|>>=|<=|>=|==|!=|&&|\|\||\+=|-=|\*=|/=|%=|&=|\|=|\^=|<<|>>|\.\.\.|.)
""", re.X | re.S)


def tokenize(text):
    """(kind, text) tokens; preprocessor lines (line markers, #pragma) are kept whole as kind 'pp'"""
    out, pos, bol = [], 0, True
    while pos < len(text):
        if bol:
            m = re.match(r"[ \t]*#[^\n]*", text[pos:])
            if m:
                out.append(("pp", m.group(0)))
                pos += m.end()
                continue
        m = TOKEN.match(text, pos)
        kind = m.lastgroup
        out.append((kind, m.group(0)))
        pos = m.end()
        bol = kind == "nl" or (bol and kind == "ws")
    return out


def float_literal(t):
    """1.0 -> 1.0f, 1.5h -> ((half)1.5f) (MSL's unsuffixed floating literals are float, not double)"""
    if t.lower().startswith("0x") and "p" not in t.lower():
        return t
    m = re.fullmatch(r"(.*?)([fFhH]?)", t)
    body, suffix = m.group(1), m.group(2)
    is_float = "." in body or (not body.lower().startswith("0x") and "e" in body.lower()) or "p" in body.lower() or suffix
    if not is_float or re.search(r"[uUlL]$", body):
        return t
    if suffix in ("h", "H"):
        return f"((half){body}f)"
    return body + "f"


class Unit:
    """one translated .metal file"""

    def __init__(self, index):
        self.index = index
        self.functions = []     # dict(name, type, params, barrier, max_threads, host_name, line)
        self.constants = []     # (index, type, name)
        self.text = ""


def significant(tokens, i, step):
    """the index of the next non-space token from i (step +1 or -1)"""
    while 0 <= i < len(tokens) and tokens[i][0] in ("ws", "nl"):
        i += step
    return i


def matching(tokens, i, open_, close):
    depth = 0
    for j in range(i, len(tokens)):
        t = tokens[j][1]
        if t == open_:
            depth += 1
        elif t == close:
            depth -= 1
            if depth == 0:
                return j
    raise MSLError(f"unbalanced {open_}")


def source_line(tokens, i):
    """the 'file:line' of token i, from the line markers"""
    line, name = 1, "?"
    for j in range(i):
        k, t = tokens[j]
        if k == "pp":
            m = re.match(r'\s*#\s*(?:line\s+)?(\d+)\s+"([^"]*)"', t)
            if m:
                line, name = int(m.group(1)) - 1, m.group(2)
                continue
        if k == "nl":
            line += 1
    return f"{name}:{line}"


def split_params(tokens):
    """a parameter list's tokens (without the parentheses) -> one token list per parameter"""
    params, cur, depth = [], [], 0
    for k, t in tokens:
        if t in ("(", "[", "{", "<", "[["):
            depth += 1
        elif t in (")", "]", "}", ">", "]]"):
            depth -= 1
        elif t == ">>":
            depth -= 2
        if t == "," and depth == 0:
            params.append(cur)
            cur = []
        else:
            cur.append((k, t))
    if any(k not in ("ws", "nl") for k, _ in cur):
        params.append(cur)
    return params


def parse_param(tokens, where):
    """-> (type text, name, attribute name, attribute argument)"""
    toks = [(k, t) for k, t in tokens if k not in ("ws", "nl")]
    attr, arg = None, None
    if "[[" in [t for _, t in toks]:
        a = [t for _, t in toks].index("[[")
        inner = [t for _, t in toks[a + 1:]]
        inner = inner[:inner.index("]]")] if "]]" in inner else inner
        attr = inner[0] if inner else None
        if len(inner) > 2 and inner[1] == "(":
            arg = "".join(inner[2:-1])
        toks = toks[:a]
    names = [i for i, (k, _) in enumerate(toks) if k == "id"]
    if not names:
        raise MSLError(f"{where}: cannot read a kernel parameter")
    n = names[-1]
    type_toks = [t for _, t in toks[:n] if t not in ADDRESS_SPACES and t != "threadgroup"]
    return " ".join(type_toks).replace(" :: ", "::").replace("< ", "<").replace(" >", ">"), toks[n][1], attr, arg


def binding(type_, name, attr, arg, where):
    """the wrapper's expression for one kernel argument"""
    base = type_.replace("&", "").strip()
    if attr == "buffer":
        if "*" in type_:
            return f"({type_})__a->buffers[{arg}]"
        return f"*({base} *)__a->buffers[{arg}]"
    if attr == "texture":
        return f"{base}(__a->textures[{arg}])"
    if attr == "sampler":
        return f"metal::sampler(__a->samplers[{arg}])"
    if attr == "threadgroup":
        if "*" in type_:
            return f"({type_})__a->tgmem[{arg}]"
        return f"*({base} *)__a->tgmem[{arg}]"
    if attr in POSITIONS:
        return POSITIONS[attr].format(T=base.replace("const ", ""))
    raise MSLError(f"{where}: parameter '{name}': [[{attr or ''}]] is not supported by isim's Metal on the CPU")


def translate(text, unit):
    """MSL (preprocessed, with line markers) -> C++ for the shim; fills unit.functions and unit.constants"""
    toks = tokenize(text)
    out = []
    paren, brace, attr = 0, 0, 0     # attr: inside [[...]], where words are attribute names, not keywords
    fc_names = set()
    i = 0
    pending = None          # a function qualifier seen, waiting for its parameter list
    while i < len(toks):
        k, t = toks[i]
        if k == "pp":
            out.append(t if not re.match(r"\s*#\s*pragma\s+METAL", t) else "")
            i += 1
            continue
        if t in ("(", "[") or t == "[[":
            paren += 1
        elif t in (")", "]") or t == "]]":
            paren -= 1
        elif t == "{":
            brace += 1
        elif t == "}":
            brace -= 1
        # [[kernel]], [[host_name("x")]], [[max_total_threads_per_threadgroup(n)]], [[function_constant(n)]]
        if t == "[[":
            j = matching(toks, i, "[[", "]]")
            inner = "".join(x for _, x in toks[i + 1:j]).strip()
            m = re.fullmatch(r"(\w+)(?:\((.*)\))?", inner)
            if m and m.group(1) in ("stitchable", "visible"):
                pending = {"type": 5, "attrs": {}, "stitchable": m.group(1) == "stitchable"}
                out.append("static")
                paren -= 1
                i = j + 1
                continue
            if m and m.group(1) in QUALIFIERS:
                pending = {"type": QUALIFIERS[m.group(1)], "attrs": {}}
                out.append("static")
                paren -= 1
                i = j + 1
                continue
            if m and m.group(1) in ("host_name", "max_total_threads_per_threadgroup", "visible") and pending is not None:
                pending["attrs"][m.group(1)] = m.group(2)
                paren -= 1
                i = j + 1
                continue
            if m and m.group(1) == "function_constant" and brace == 0:
                # constant T name [[function_constant(n)]];  ->  per-thread globals set before each dispatch
                start = len(out)
                while start > 0 and out[start - 1] not in (";", "}") and not out[start - 1].lstrip().startswith("#"):
                    start -= 1
                decl = [x for x in "".join(out[start:]).split() if x not in ADDRESS_SPACES]
                name, type_ = decl[-1], " ".join(decl[:-1])
                unit.constants.append((int(m.group(2)), type_, name))
                fc_names.add(name)
                del out[start:]
                out.append(f"\nstatic thread_local {type_} {name}; static thread_local bool __isim_fcdef_{name}")
                paren -= 1
                i = j + 1
                continue
            attr += 1
            out.append(t)
            i += 1
            continue
        if t == "]]":
            attr -= 1
        if k == "id" and attr == 0:
            prev = significant(toks, i - 1, -1)
            nxt = significant(toks, i + 1, 1)
            prev_t = toks[prev][1] if prev >= 0 else ""
            nxt_t = toks[nxt][1] if nxt < len(toks) else ""
            if t in QUALIFIERS and brace == 0 and paren == 0 and prev_t not in (".", "->", "::"):
                pending = {"type": QUALIFIERS[t], "attrs": {}}
                out.append("static")
                i += 1
                continue
            if t in ADDRESS_SPACES and prev_t not in (".", "->", "::"):
                i += 1
                continue
            if t == "threadgroup" and prev_t not in (".", "->", "::"):
                out.append("static thread_local" if paren == 0 and brace > 0 else "")
                i += 1
                continue
            if t == "is_function_constant_defined" and nxt_t == "(":
                close = matching(toks, nxt, "(", ")")
                arg = "".join(x for _, x in toks[nxt + 1:close]).strip()
                out.append(f"__isim_fcdef_{arg}")
                i = close + 1
                continue
            if t in VECTOR_TYPES and nxt_t == "(" and prev_t not in (".", "->"):
                if prev_t == "::":
                    p2 = significant(toks, prev - 1, -1)
                    if p2 >= 0 and toks[p2][1] == "metal":
                        while out and out[-1].strip() in ("", "::", "metal"):
                            out.pop()
                    elif p2 >= 0:
                        out.append(t)
                        i += 1
                        continue
                c, n = VECTOR_TYPES[t]
                out.append(f"__isim_make<{c}, {n}>")
                i += 1
                continue
            if pending is not None and nxt_t == "(" and paren == 0:
                # the function's name: read its parameters
                close = matching(toks, nxt, "(", ")")
                params = split_params(toks[nxt + 1:close])
                where = source_line(toks, i)
                pending.update(name=t, where=where, params=[parse_param(p, where) for p in params])
                unit.functions.append(pending)
                pending = None
        elif k == "num":
            out.append(float_literal(t))
            i += 1
            continue
        out.append(t)
        i += 1
    unit.text = "".join(out)
    barrier = re.search(r"\bthreadgroup_barrier\b", unit.text) is not None
    for f in unit.functions:
        f["barrier"] = barrier
    return unit


def wrappers(unit):
    """the generated entry points of one unit"""
    lines = ['\n#line 1 "<isim metal entry points>"']
    for f in unit.functions:
        if f["type"] != 3:
            continue
        args = [binding(ty, nm, at, ar, f["where"]) for ty, nm, at, ar in f["params"]]
        lines.append(f'extern "C" __attribute__((visibility("default"))) void __isim_k_{f["name"]}(const __isim_mtl_thread *__t) {{')
        lines.append("    const __isim_mtl_args *__a = __isim_mtl_cur; (void)__a; (void)__t;")
        lines.append(f'    {f["name"]}({", ".join(args)});')
        lines.append("}")
    for f in unit.functions:
        if f.get("stitchable"):
            lines += stitch_wrapper(f)
    lines.append(f'extern "C" void __isim_mtl_prepare_{unit.index}(const __isim_mtl_args *__a) {{')
    for idx, ty, name in unit.constants:
        lines.append(f"    __isim_fcdef_{name} = __a->constant_value && __a->constant_value(__a->constants, {idx}, &{name}, sizeof {name});")
    lines.append("    (void)__a;\n}")
    return "\n".join(lines) + "\n"


def stitch_wrapper(f):
    """a [[stitchable]] function's entry point for SwiftUI's shader effects: one pixel. Parameters bind by role: the
    position, then the pixel's color (colorEffect) or the layer (layerEffect), then the Shader.Arguments in order
    (values, arrays as a pointer and a count, images as textures)"""
    body = ['    uint32_t __i = 0; int32_t __n = 0; (void)__i; (void)__n;']
    names = []
    params = f["params"]
    for k, (ty, nm, at, ar) in enumerate(params):
        v = f"__p{k}"
        names.append(v)
        base = ty.replace("const ", "").replace("&", "").strip()
        if k == 0:
            body.append(f"    {base} {v} = {base}{{__s->position[0], __s->position[1]}};")
        elif "Layer" in base and "SwiftUI" in base:
            body.append(f"    SwiftUI::Layer {v}(__s->layer);")
        elif "*" in ty:
            body.append(f"    {ty} {v} = ({ty})__isim_arg_ptr(__s, __i, __n);")
        elif k > 0 and "*" in params[k - 1][0] and re.fullmatch(r"(u?int|u?short|u?long|size_t|int32_t|uint32_t)", base):
            body.append(f"    {base} {v} = ({base})__n;")
        elif re.match(r"(metal::)?texture", base):
            body.append(f"    {base} {v}(__isim_arg_tex(__s, __i));")
        elif k == 1 and base in ("half4", "float4"):
            body.append(f"    {base} {v} = __s->effect == ISIM_MTL_EFFECT_COLOR ? __isim_effect_color<{base}>(__s) : __isim_arg_value<{base}>(__s, __i);")
        else:
            body.append(f"    {base} {v} = __isim_arg_value<{base}>(__s, __i);")
    return ([f'extern "C" __attribute__((visibility("default"))) void __isim_s_{f["name"]}(__isim_mtl_stitch *__s) {{']
            + body + [f'    __isim_effect_result(__s, {f["name"]}({", ".join(names)}));', "}"])


def table(units):
    """the library's function table and its prepare step"""
    lines = ['#include <isim_metal_abi.h>', "thread_local const __isim_mtl_args *__isim_mtl_cur;"]
    consts = ";".join(f"{i}:{DATA_TYPES.get(ty.replace('const ', '').strip(), 0)}:{n}" for u in units for i, ty, n in u.constants)
    for u in units:
        lines.append(f'extern "C" void __isim_mtl_prepare_{u.index}(const __isim_mtl_args *);')
        for f in u.functions:
            if f["type"] == 3:
                lines.append(f'extern "C" void __isim_k_{f["name"]}(const __isim_mtl_thread *);')
            if f.get("stitchable"):
                lines.append(f'extern "C" void __isim_s_{f["name"]}(__isim_mtl_stitch *);')
    lines.append('extern "C" __attribute__((visibility("default"))) const int __isim_mtl_abi = ISIM_MTL_ABI;')
    lines.append('extern "C" __attribute__((visibility("default"))) void __isim_mtl_prepare(const __isim_mtl_args *a) {')
    lines.append("    __isim_mtl_cur = a;")
    lines += [f"    __isim_mtl_prepare_{u.index}(a);" for u in units]
    lines.append("}")
    lines.append('extern "C" __attribute__((visibility("default"))) const __isim_mtl_function __isim_mtl_functions[] = {')
    for u in units:
        for f in u.functions:
            name = f["attrs"].get("host_name", "").strip('"') or f["name"]
            entry = f'__isim_k_{f["name"]}' if f["type"] == 3 else "0"
            mt = f["attrs"].get("max_total_threads_per_threadgroup") or 0
            stitch = f'__isim_s_{f["name"]}' if f.get("stitchable") else "0"
            lines.append(f'    {{"{name}", {f["type"]}, {entry}, {int(f["barrier"])}, {mt}, "{consts}", {stitch}}},')
    lines.append("    {0, 0, 0, 0, 0, 0, 0}\n};")
    return "\n".join(lines) + "\n"


def isim_cc():
    """isim cc of the installation whose SDK is used (out/bin next to out/sdk, or bin next to sdk)"""
    for p in (os.path.join(sdk_dir(), "..", "bin", "isim"), os.path.join(BIN, "isim"), shutil.which("isim")):
        if p and os.path.exists(p):
            return [p, "cc"]
    raise MSLError("isim cc was not found")


def run(cmd, what):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise MSLError(f"{what} failed:\n{r.stderr.strip() or r.stdout.strip()}")
    return r.stdout


def compile(sources, out, includes=(), defines=(), optimize=True, keep=None, install_name=None):
    """.metal sources -> a guest dylib at out; raises MSLError with the compiler's messages"""
    sdk = sdk_dir()
    shim, pre = os.path.join(sdk, "usr/lib/isim/metal/include"), os.path.join(sdk, "usr/lib/isim/metal/msl")
    cc = isim_cc()
    work = keep or tempfile.mkdtemp(prefix="isim-msl-")
    try:
        os.makedirs(work, exist_ok=True)
        units, objs = [], []
        common = ["-x", "c++", "-std=c++20", "-nostdinc++", "-fno-exceptions", "-fno-rtti", "-fvisibility=hidden",
                  "-Wno-unknown-attributes", "-Wno-unknown-pragmas", "-Wno-unused-command-line-argument", "-fno-objc-arc"]
        for n, src in enumerate(sources):
            pp = run(cc + ["-E", "-x", "c++", "-nostdinc", "-nostdinc++", "-I", pre, "-I", os.path.dirname(os.path.abspath(src)),
                           *[f"-I{d}" for d in includes], "-D__METAL_VERSION__=310", "-D__METAL_IOS__=1", "-D__METAL__=1",
                           *[f"-D{d}" for d in defines], "-Wno-unused-command-line-argument", src], f"preprocessing {os.path.basename(src)}")
            u = translate(pp, Unit(n))
            cpp = os.path.join(work, f"unit{n}.cpp")
            with open(cpp, "w") as f:
                f.write("#include <__isim_metal.h>\n" + u.text + wrappers(u))
            obj = cpp[:-4] + ".o"
            run(cc + ["-c", *common, "-O2" if optimize else "-O0", "-I", shim, cpp, "-o", obj], f"compiling {os.path.basename(src)}")
            units.append(u)
            objs.append(obj)
        tab = os.path.join(work, "library.cpp")
        with open(tab, "w") as f:
            f.write(table(units))
        objs.append(os.path.join(work, "library.o"))
        run(cc + ["-c", *common, "-O2", "-I", shim, tab, "-o", objs[-1]], "compiling the function table")
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        run(cc + ["-dynamiclib", "-o", out, *objs, "-install_name", install_name or f"@rpath/{os.path.basename(out)}",
                  "-Wno-unused-command-line-argument"], "linking the library")
        return [f["attrs"].get("host_name", "").strip('"') or f["name"] for u in units for f in u.functions]
    finally:
        if keep is None:
            shutil.rmtree(work, ignore_errors=True)


def main(argv):
    out, includes, defines, srcs, optimize, keep = None, [], [], [], True, None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "-o":
            out = argv[i + 1]; i += 2; continue
        if a.startswith("-I"):
            includes.append(a[2:] or argv[i + 1]); i += 1 if a[2:] else 2; continue
        if a.startswith("-D"):
            defines.append(a[2:] or argv[i + 1]); i += 1 if a[2:] else 2; continue
        if a == "-O0":
            optimize = False
        elif a == "--keep":
            keep = argv[i + 1]; i += 2; continue
        elif a in ("-h", "--help"):
            print(__doc__); return 0
        elif not a.startswith("-"):
            srcs.append(a)
        i += 1
    if not out or not srcs:
        print("usage: mslc.py -o out.dylib [-I dir] [-D NAME[=VALUE]] [-O0] file.metal ...", file=sys.stderr)
        return 2
    try:
        names = compile(srcs, out, includes, defines, optimize, keep)
    except MSLError as e:
        print(e, file=sys.stderr)
        return 1
    print(f"{len(names)} function(s): {', '.join(names)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
