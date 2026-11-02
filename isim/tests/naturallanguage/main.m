// NaturalLanguage from Objective-C (NaturalLanguageCTest.app, issue #701): NLTokenizer, NLLanguageRecognizer and NLTagger
// with NSRange-based methods, a gazetteer labelling names for the tagger, a custom NLEmbedding written and read back,
// the host's word embedding (ISIM_WORD_VECTORS), NLContextualEmbedding and NLModel's error. test_naturallanguage.py runs it.
#import <Foundation/Foundation.h>
#import <NaturalLanguage/NaturalLanguage.h>
#include <stdio.h>

static int checks, failures;
#define CHECK(cond, what) do { checks++; if (cond) printf("PASS  %s\n", what); else { failures++; printf("FAIL  %s  (line %d)\n", what, __LINE__); } } while (0)

int main(void) {
    @autoreleasepool {
        /* ---- tokenizer ---- */
        NSString *text = @"Hello, world! Café prices are 3.50 today. 你好";
        NLTokenizer *tok = [[NLTokenizer alloc] initWithUnit:NLTokenUnitWord];
        tok.string = text;
        CHECK(tok.unit == NLTokenUnitWord, "tokenizer unit");
        NSArray<NSValue *> *words = [tok tokensForRange:NSMakeRange(0, text.length)];
        NSMutableArray *ws = [NSMutableArray array];
        for (NSValue *v in words) [ws addObject:[text substringWithRange:v.rangeValue]];
        printf("words: %s\n", [[ws componentsJoinedByString:@"|"] UTF8String]);
        CHECK([ws isEqual:(@[@"Hello", @"world", @"Café", @"prices", @"are", @"3.50", @"today", @"你", @"好"])], "word tokens (NSRange, UTF-16)");
        NSRange r = [tok tokenRangeAtIndex:8];
        CHECK(NSEqualRanges(r, NSMakeRange(7, 5)), "tokenRangeAtIndex:");
        CHECK(NSEqualRanges([tok tokenRangeForRange:NSMakeRange(9, 8)], NSMakeRange(7, 11)), "tokenRangeForRange:");
        __block int numeric = 0, enumerated = 0;
        [tok enumerateTokensInRange:NSMakeRange(0, text.length) usingBlock:^(NSRange tokenRange, NLTokenizerAttributes flags, BOOL *stop) {
            enumerated++;
            if (flags & NLTokenizerAttributeNumeric) numeric++;
            if (enumerated == 7) *stop = YES;
        }];
        CHECK(enumerated == 7 && numeric == 1, "enumerateTokensInRange: (attributes, stop)");
        NLTokenizer *sent = [[NLTokenizer alloc] initWithUnit:NLTokenUnitSentence];
        sent.string = text;
        CHECK([sent tokensForRange:NSMakeRange(0, text.length)].count == 3, "sentence tokens");

        /* ---- language recognizer ---- */
        CHECK([[NLLanguageRecognizer dominantLanguageForString:@"Le chat est sur la table et il dort."] isEqual:NLLanguageFrench],
              "dominantLanguageForString: (French)");
        NLLanguageRecognizer *rec = [[NLLanguageRecognizer alloc] init];
        [rec processString:@"Der Hund schläft und die Katze ist auch "];
        [rec processString:@"in dem Haus."];
        CHECK([rec.dominantLanguage isEqualToString:NLLanguageGerman], "processString: + dominantLanguage (German)");
        NSDictionary<NLLanguage, NSNumber *> *hyp = [rec languageHypothesesWithMaximum:2];
        CHECK(hyp.count >= 1 && hyp[NLLanguageGerman].doubleValue > 0, "languageHypothesesWithMaximum:");
        rec.languageConstraints = @[NLLanguageEnglish, NLLanguageSpanish];
        rec.languageHints = @{NLLanguageSpanish: @0.9};
        CHECK(rec.languageConstraints.count == 2 && [rec.languageHints[NLLanguageSpanish] doubleValue] == 0.9, "constraints and hints");
        CHECK(![rec.dominantLanguage isEqualToString:NLLanguageGerman], "constraints exclude German");
        [rec reset];
        CHECK(rec.dominantLanguage == nil || [rec.dominantLanguage isEqualToString:NLLanguageUndetermined], "reset");

        /* ---- tagger ---- */
        NSString *s = @"Tim Cook visited Paris. The food was great!";
        NLTagger *tagger = [[NLTagger alloc] initWithTagSchemes:@[NLTagSchemeTokenType, NLTagSchemeLexicalClass, NLTagSchemeNameType,
                                                                  NLTagSchemeSentimentScore]];
        tagger.string = s;
        CHECK(tagger.tagSchemes.count == 4, "tagSchemes");
        CHECK([[NLTagger availableTagSchemesForUnit:NLTokenUnitWord language:NLLanguageEnglish] containsObject:NLTagSchemeLexicalClass],
              "availableTagSchemesForUnit:language:");
        CHECK([tagger.dominantLanguage isEqualToString:NLLanguageEnglish], "tagger dominantLanguage");
        NSArray<NSValue *> *ranges = nil;
        NSArray<NLTag> *types = [tagger tagsInRange:NSMakeRange(0, s.length) unit:NLTokenUnitWord scheme:NLTagSchemeTokenType
                                            options:NLTaggerOmitWhitespace tokenRanges:&ranges];
        CHECK(types.count == ranges.count && types.count == 10 && [types[0] isEqualToString:NLTagWord] &&
              [types[4] isEqualToString:NLTagPunctuation], "tagsInRange:...tokenRanges: (token types)");
        NSRange tr = {0, 0};
        NLTag cls = [tagger tagAtIndex:[s rangeOfString:@"food"].location + 1 unit:NLTokenUnitWord scheme:NLTagSchemeLexicalClass tokenRange:&tr];
        CHECK([cls isEqualToString:NLTagNoun] && NSEqualRanges(tr, [s rangeOfString:@"food"]), "tagAtIndex:...tokenRange: (lexical class)");
        NLTag mood = [tagger tagAtIndex:[s rangeOfString:@"great"].location unit:NLTokenUnitSentence scheme:NLTagSchemeSentimentScore tokenRange:NULL];
        CHECK(mood.doubleValue > 0, "sentiment score of a sentence");
        NSDictionary<NLTag, NSNumber *> *th = [tagger tagHypothesesAtIndex:0 unit:NLTokenUnitWord scheme:NLTagSchemeTokenType maximumCount:3 tokenRange:NULL];
        CHECK([th[NLTagWord] doubleValue] == 1, "tagHypothesesAtIndex:");
        CHECK(NSEqualRanges([tagger tokenRangeAtIndex:5 unit:NLTokenUnitWord], NSMakeRange(4, 4)), "tagger tokenRangeAtIndex:unit:");

        /* ---- gazetteer ---- */
        NSError *error = nil;
        NLGazetteer *gaz = [[NLGazetteer alloc] initWithDictionary:@{NLTagPersonalName: @[@"Tim Cook"], NLTagPlaceName: @[@"Paris"]}
                                                          language:NLLanguageEnglish error:&error];
        CHECK(gaz && !error && [[gaz labelForString:@"paris"] isEqualToString:NLTagPlaceName] && [gaz.language isEqual:NLLanguageEnglish],
              "gazetteer initWithDictionary:language:error: + labelForString:");
        NLGazetteer *copy = [[NLGazetteer alloc] initWithData:gaz.data error:&error];
        CHECK([[copy labelForString:@"Tim Cook"] isEqualToString:NLTagPersonalName], "gazetteer data round trip");
        NSURL *gurl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"names.gaz"]];
        CHECK([NLGazetteer writeGazetteerForDictionary:@{@"Fruit": @[@"apple"]} language:nil toURL:gurl error:&error] &&
              [[[NLGazetteer gazetteerWithContentsOfURL:gurl error:&error] labelForString:@"Apple"] isEqualToString:@"Fruit"],
              "writeGazetteerForDictionary: + gazetteerWithContentsOfURL:");
        [tagger setGazetteers:@[gaz] forTagScheme:NLTagSchemeNameType];
        CHECK([tagger gazetteersForTagScheme:NLTagSchemeNameType].count == 1, "gazetteersForTagScheme:");
        NSMutableArray *names = [NSMutableArray array];
        [tagger enumerateTagsInRange:NSMakeRange(0, s.length) unit:NLTokenUnitWord scheme:NLTagSchemeNameType
                             options:NLTaggerOmitWhitespace | NLTaggerOmitPunctuation | NLTaggerJoinNames
                          usingBlock:^(NLTag tag, NSRange tokenRange, BOOL *stop) {
            if (tag) [names addObject:[NSString stringWithFormat:@"%@=%@", [s substringWithRange:tokenRange], tag]];
        }];
        printf("names: %s\n", [[names componentsJoinedByString:@", "] UTF8String]);
        CHECK([names isEqual:(@[@"Tim Cook=PersonalName", @"Paris=PlaceName"])], "enumerateTagsInRange: with a gazetteer (joinNames)");

        /* ---- custom embedding ---- */
        NSURL *eurl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"tiny.embedding"]];
        NSDictionary *vecs = @{@"cat": @[@1, @0, @0], @"kitten": @[@0.9, @0.1, @0], @"car": @[@0, @0, @1], @"truck": @[@0, @0.1, @0.9]};
        CHECK([NLEmbedding writeEmbeddingForDictionary:vecs language:NLLanguageEnglish revision:1 toURL:eurl error:&error], "writeEmbeddingForDictionary:");
        NLEmbedding *emb = [NLEmbedding embeddingWithContentsOfURL:eurl error:&error];
        CHECK(emb && emb.dimension == 3 && emb.vocabularySize == 4 && [emb.language isEqual:NLLanguageEnglish] && emb.revision == 1,
              "embeddingWithContentsOfURL: (dimension, vocabulary, language, revision)");
        CHECK([emb containsString:@"cat"] && ![emb containsString:@"dog"], "containsString:");
        CHECK([emb distanceBetweenString:@"cat" andString:@"kitten" distanceType:NLDistanceTypeCosine] <
              [emb distanceBetweenString:@"cat" andString:@"car" distanceType:NLDistanceTypeCosine], "distanceBetweenString:");
        NSArray<NSString *> *near = [emb neighborsForString:@"cat" maximumCount:2 distanceType:NLDistanceTypeCosine];
        CHECK([near.firstObject isEqualToString:@"kitten"] && near.count == 2, "neighborsForString:");
        CHECK([emb neighborsForString:@"cat" maximumCount:3 maximumDistance:0.1 distanceType:NLDistanceTypeCosine].count == 1,
              "neighborsForString:maximumDistance:");
        float fv[3] = {0};
        CHECK([emb getVector:fv forString:@"truck"] && fv[2] > 0.8f && [[emb vectorForString:@"car"][2] doubleValue] == 1, "getVector: + vectorForString:");
        __block NSString *firstNear = nil;
        [emb enumerateNeighborsForVector:@[@0, @0, @1] maximumCount:4 distanceType:NLDistanceTypeCosine
                              usingBlock:^(NSString *neighbor, NLDistance distance, BOOL *stop) { firstNear = neighbor; *stop = YES; }];
        CHECK([firstNear isEqualToString:@"car"], "enumerateNeighborsForVector: (stop)");

        /* ---- the host's word embedding ---- */
        NLEmbedding *word = [NLEmbedding wordEmbeddingForLanguage:NLLanguageEnglish];
        if (word) {
            printf("vectors: available\n");
            CHECK([[word neighborsForString:@"king" maximumCount:1 distanceType:NLDistanceTypeCosine].firstObject isEqualToString:@"queen"] &&
                  [NLEmbedding currentRevisionForLanguage:NLLanguageEnglish] == 1 &&
                  [[NLEmbedding supportedRevisionsForLanguage:NLLanguageEnglish] containsIndex:1], "wordEmbeddingForLanguage: (host vectors)");
            NLEmbedding *sentence = [NLEmbedding sentenceEmbeddingForLanguage:NLLanguageEnglish];
            CHECK([sentence distanceBetweenString:@"the king" andString:@"the queen" distanceType:NLDistanceTypeCosine] <
                  [sentence distanceBetweenString:@"the king" andString:@"a banana" distanceType:NLDistanceTypeCosine], "sentenceEmbeddingForLanguage:");
        } else {
            printf("vectors: none\n");
            CHECK([NLEmbedding currentRevisionForLanguage:NLLanguageEnglish] == 0 && ![NLEmbedding sentenceEmbeddingForLanguage:NLLanguageEnglish],
                  "no host vectors: no built-in embeddings");
        }

        /* ---- contextual embedding ---- */
        NLContextualEmbedding *ce = [NLContextualEmbedding contextualEmbeddingWithLanguage:NLLanguageEnglish];
        CHECK(ce && [ce.languages containsObject:NLLanguageEnglish] && [ce.scripts containsObject:NLScriptLatin] && ce.maximumSequenceLength == 256 &&
              [[NLContextualEmbedding contextualEmbeddingWithModelIdentifier:ce.modelIdentifier].modelIdentifier isEqual:ce.modelIdentifier],
              "contextualEmbeddingWithLanguage: + modelIdentifier");
        CHECK([NLContextualEmbedding contextualEmbeddingsForValues:@{NLContextualEmbeddingKeyScripts: @[NLScriptLatin]}].count == 1,
              "contextualEmbeddingsForValues:");
        __block BOOL answered = NO;
        __block NLContextualEmbeddingAssetsResult assets = NLContextualEmbeddingAssetsResultError;
        [ce requestEmbeddingAssetsWithCompletionHandler:^(NLContextualEmbeddingAssetsResult result, NSError *e) { assets = result; answered = YES; }];
        NSDate *end = [NSDate dateWithTimeIntervalSinceNow:5];
        while (!answered && [end timeIntervalSinceNow] > 0) [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        CHECK(answered && (assets == NLContextualEmbeddingAssetsResultAvailable) == ce.hasAvailableAssets, "requestEmbeddingAssetsWithCompletionHandler:");
        if (ce.hasAvailableAssets) {
            CHECK([ce loadWithError:&error], "loadWithError:");
            NLContextualEmbeddingResult *res = [ce embeddingResultForString:@"the king" language:nil error:&error];
            NSRange vr = {0, 0};
            NSArray<NSNumber *> *tv = [res tokenVectorAtIndex:5 tokenRange:&vr];
            CHECK(res.sequenceLength == 2 && tv.count == ce.dimension && NSEqualRanges(vr, NSMakeRange(4, 4)) && [res.language isEqual:NLLanguageEnglish],
                  "embeddingResultForString: + tokenVectorAtIndex:");
            __block int tokens = 0;
            [res enumerateTokenVectorsInRange:NSMakeRange(0, 8) usingBlock:^(NSArray<NSNumber *> *v, NSRange tokenRange, BOOL *stop) { tokens++; }];
            CHECK(tokens == 2, "enumerateTokenVectorsInRange:");
            [ce unload];
        } else {
            CHECK(![ce loadWithError:&error] && error, "loadWithError: without assets");
        }

        /* ---- model ---- */
        error = nil;
        NLModel *model = [NLModel modelWithContentsOfURL:[NSURL fileURLWithPath:@"/nonexistent.mlmodelc"] error:&error];
        CHECK(model == nil && error != nil, "modelWithContentsOfURL:error: (missing file)");
        CHECK([NLModelConfiguration currentRevisionForType:NLModelTypeClassifier] == 0, "NLModelConfiguration currentRevisionForType:");

        printf("NaturalLanguageCTest: %d/%d passed\n", checks - failures, checks);
        return failures ? 1 : 0;
    }
}
