# Tables for the Synchronization module's .gyb templates (AtomicStorage / AtomicIntegers).
# isim's own version: the Swift source checkout used by isim does not include utils/SwiftAtomics.py, so these
# tables are written from what the templates and the Synchronization sources require.

# (storage type, size in bits, alignment, builtin type, Swift integer of that size)
atomicTypes = [
    ("_Atomic8BitStorage", "8", "1", "Builtin.Int8", "UInt8"),
    ("_Atomic16BitStorage", "16", "2", "Builtin.Int16", "UInt16"),
    ("_Atomic32BitStorage", "32", "4", "Builtin.Int32", "UInt32"),
    ("_Atomic64BitStorage", "64", "8", "Builtin.Int64", "UInt64"),
    ("_Atomic128BitStorage", "128", "16", "Builtin.Int128", "WordPair"),
]

# "" = Int / UInt (word sized)
atomicBits = ["", "8", "16", "32", "64", "128"]

# (Swift case name, API name, doc, LLVM ordering)
loadOrderings = [
    ("relaxed", "Relaxed", "relaxed", "monotonic"),
    ("acquiring", "Acquiring", "acquiring", "acquire"),
    ("sequentiallyConsistent", "SequentiallyConsistent", "sequentially consistent", "seqcst"),
]
storeOrderings = [
    ("relaxed", "Relaxed", "relaxed", "monotonic"),
    ("releasing", "Releasing", "releasing", "release"),
    ("sequentiallyConsistent", "SequentiallyConsistent", "sequentially consistent", "seqcst"),
]
# (Swift case name, API name, doc, LLVM ordering, LLVM failure ordering)
updateOrderings = [
    ("relaxed", "Relaxed", "relaxed", "monotonic", "monotonic"),
    ("acquiring", "Acquiring", "acquiring", "acquire", "acquire"),
    ("releasing", "Releasing", "releasing", "release", "monotonic"),
    ("acquiringAndReleasing", "AcquiringAndReleasing", "acquiring-and-releasing", "acqrel", "acquire"),
    ("sequentiallyConsistent", "SequentiallyConsistent", "sequentially consistent", "seqcst", "seqcst"),
]

# (method name suffix, builtin, operator, doc)
integerOperations = [
    ("WrappingAdd", "add", "&+", "wrapping add"),
    ("WrappingSubtract", "sub", "&-", "wrapping subtract"),
    ("BitwiseAnd", "and", "&", "bitwise AND"),
    ("BitwiseOr", "or", "|", "bitwise OR"),
    ("BitwiseXor", "xor", "^", "bitwise XOR"),
    ("Min", "min", "", "minimum"),
    ("Max", "max", "", "maximum"),
]

boolOperations = [
    ("LogicalAnd", "and", "&&", "logical AND"),
    ("LogicalOr", "or", "||", "logical OR"),
    ("LogicalXor", "xor", "!=", "logical XOR"),
]


def lowerFirst(s):
    return s[:1].lower() + s[1:]


def atomicOperationName(intType, operation):
    if operation in ("min", "max") and intType.startswith("U"):
        return "u" + operation
    return operation


_strength = {"monotonic": 0, "acquire": 1, "release": 1, "acqrel": 2, "seqcst": 3}


def actualOrders(success, failure):
    """LLVM's cmpxchg needs a success ordering at least as strong as the failure ordering."""
    s = success
    if failure == "seqcst":
        s = "seqcst"
    elif failure == "acquire":
        if success == "monotonic":
            s = "acquire"
        elif success == "release":
            s = "acqrel"
    return s + "_" + failure
