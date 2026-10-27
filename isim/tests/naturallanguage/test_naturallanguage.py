"""NaturalLanguage gazetteers and embeddings (issue #378): NaturalLanguageTest.app checks NLGazetteer (with NLTagger),
custom NLEmbeddings, NLContextualEmbedding and NLModel; once with a tiny fastText vector file as the host's word vectors
(ISIM_WORD_VECTORS) and once without, where the built-in embeddings are unavailable."""
from isimtest import need_apps, selftest

VECTORS = """7 4
king 0.9 0.8 0.1 0.0
queen 0.85 0.9 0.1 0.05
man 0.5 0.1 0.0 0.1
woman 0.45 0.2 0.0 0.15
apple 0.0 0.1 0.9 0.8
banana 0.05 0.0 0.85 0.9
the 0.1 0.1 0.1 0.1
"""


def test_naturallanguage_with_vectors(device_data, tmp_path):
    need_apps("NaturalLanguageTest")
    (tmp_path / "vectors").mkdir()
    (tmp_path / "vectors" / "en.vec").write_text(VECTORS)
    r = selftest("NaturalLanguageTest", data=device_data, env={"ISIM_WORD_VECTORS": str(tmp_path / "vectors")})
    assert "vectors: available" in r.output


def test_naturallanguage_without_vectors(device_data):
    need_apps("NaturalLanguageTest")
    r = selftest("NaturalLanguageTest", data=device_data, env={"ISIM_WORD_VECTORS": ""})
    assert "vectors: none" in r.output
