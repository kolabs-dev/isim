"""A tiny ONNX audio classifier for the Sound Analysis tests, written as protobuf by hand (no onnx package needed).

It has YAMNet's interface: a 16 kHz mono waveform [samples] in, class scores [frames, classes] out (one frame). The
scores are sigmoids of the waveform's mean absolute level: quiet audio scores "Silence", loud audio "Music"; "Speech"
stays low. Labels: a class map CSV like YAMNet's (index,mid,display_name)."""
import struct

LABELS = "index,mid,display_name\n0,/m/028v0c,Silence\n1,/m/04rlf,Music\n2,/m/09x0r,Speech\n"


def _varint(n):
    out = b""
    while True:
        b = n & 0x7F
        n >>= 7
        out += bytes([b | (0x80 if n else 0)])
        if not n:
            return out


def _field(num, wire, payload):
    key = _varint(num << 3 | wire)
    if wire == 0:
        return key + _varint(payload)
    return key + _varint(len(payload)) + payload


def _s(num, text):
    return _field(num, 2, text.encode())


def _msg(num, *parts):
    return _field(num, 2, b"".join(parts))


def _tensor(name, dims, dtype, raw):
    return b"".join([*(_field(1, 0, d) for d in dims), _field(2, 0, dtype), _s(8, name), _field(9, 2, raw)])


def _value_info(num, name, dims):
    shape = b"".join(_msg(1, _field(1, 0, d) if isinstance(d, int) else _s(2, d)) for d in dims)
    return _msg(num, _s(1, name), _msg(2, _msg(1, _field(1, 0, 1), _msg(2, shape))))


def _node(op, inputs, outputs, *attrs):
    return _msg(1, *(_s(1, i) for i in inputs), *(_s(2, o) for o in outputs), _s(3, op.lower()), _s(4, op), *attrs)


def model_bytes():
    floats = lambda *v: struct.pack(f"<{len(v)}f", *v)
    graph = b"".join([
        _node("Abs", ["waveform"], ["abs"]),
        _node("ReduceMean", ["abs"], ["level"]),                    # keepdims: [1]
        _node("Reshape", ["level", "shape"], ["level2"]),            # [1, 1]
        _node("MatMul", ["level2", "W"], ["z"]),                     # [1, 3]
        _node("Add", ["z", "B"], ["logits"]),
        _node("Sigmoid", ["logits"], ["scores"]),
        _s(2, "isim-sound-test"),
        _msg(5, _tensor("W", [1, 3], 1, floats(-200, 200, 0))),
        _msg(5, _tensor("B", [3], 1, floats(4, -4, -3))),
        _msg(5, _tensor("shape", [2], 7, struct.pack("<2q", 1, 1))),
        _value_info(11, "waveform", ["samples"]),
        _value_info(12, "scores", [1, 3]),
    ])
    return b"".join([_field(1, 0, 7), _s(2, "isim"), _msg(7, graph), _msg(8, _s(1, ""), _field(2, 0, 13))])


def write(directory):
    """the model and its class map in directory: (model path, labels path)"""
    model, labels = directory / "sound-test.onnx", directory / "sound-test.csv"
    model.write_bytes(model_bytes())
    labels.write_text(LABELS)
    return model, labels
