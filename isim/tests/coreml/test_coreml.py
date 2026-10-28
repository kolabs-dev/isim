"""Core ML runtime (issue #376): CoreMLTest.app writes model specs (tree ensembles, neural networks with a custom
layer), compiles and runs them, and checks MLShapedArray, MLTensor, MLState, compute plans and update tasks."""
from isimtest import need_apps, selftest


def test_coreml_runtime(device_data):
    need_apps("CoreMLTest")
    selftest("CoreMLTest", data=device_data)
