// UniformTypeIdentifiers from Objective-C (UTTypesObjCTest.app, issue #278): the UTType class, the UTCoreTypes.h
// constants, the tag classes, and the app's Info.plist declarations (the same as UTTypesTest's).
#import <Foundation/Foundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <stdio.h>

static int checks, failures;
#define CHECK(cond, what) do { checks++; if (cond) printf("PASS  %s\n", what); else { failures++; printf("FAIL  %s  (line %d)\n", what, __LINE__); } } while (0)

int main(void) {
    @autoreleasepool {
        CHECK([UTTypePNG.identifier isEqual:@"public.png"] && [UTTypePNG.preferredFilenameExtension isEqual:@"png"], "UTTypePNG");
        CHECK([UTTypePNG conformsToType:UTTypeImage] && [UTTypeImage isSupertypeOfType:UTTypeJPEG] && [UTTypeMPEG4Movie isSubtypeOfType:UTTypeMovie], "conformance");
        CHECK([[UTType typeWithFilenameExtension:@"md"] isEqual:UTTypeMarkdown] && [[UTType typeWithMIMEType:@"application/gzip"] isEqual:UTTypeGZIP], "lookups");
        CHECK([[UTType typeWithFilenameExtension:@"txt" conformingToType:UTTypeText] isEqual:UTTypePlainText], "extension conforming to a type");
        UTType *recipe = [UTType exportedTypeWithIdentifier:@"dev.isim.recipe"];
        CHECK([recipe conformsToType:UTTypeJSON] && recipe.declared && !recipe.dynamic && [recipe.localizedDescription isEqual:@"Recipe"], "exported declaration");
        CHECK([[UTType typeWithIdentifier:@"com.example.note"] conformsToType:UTTypePlainText], "imported declaration");
        CHECK([recipe.tags[UTTagClassFilenameExtension] isEqual:@[ @"recipe" ]] && [recipe.tags[UTTagClassMIMEType] isEqual:@[ @"application/x-isim-recipe" ]], "tags");
        NSArray<UTType *> *found = [UTType typesWithTag:@"recipe" tagClass:UTTagClassFilenameExtension conformingToType:nil];
        CHECK(found.count == 1 && [found[0] isEqual:recipe], "typesWithTag:tagClass:conformingToType:");
        UTType *dyn = [UTType typeWithFilenameExtension:@"zzqq"];
        CHECK(dyn.dynamic && !dyn.declared && [dyn.identifier hasPrefix:@"dyn."], "dynamic type");
        CHECK([UTTypeYAML.supertypes containsObject:UTTypeText] && UTTypeYAML.publicType, "supertypes");
        NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:UTTypeEPUB requiringSecureCoding:YES error:NULL];
        UTType *back = archived ? [NSKeyedUnarchiver unarchivedObjectOfClass:[UTType class] fromData:archived error:NULL] : nil;
        CHECK([back isEqual:UTTypeEPUB], "secure coding");
        CHECK([UTTypeAVI conformsToType:UTTypeMovie] && [UTType3DContent conformsToType:UTTypeContent] && [UTTypeX509Certificate.preferredFilenameExtension isEqual:@"cer"], "more system types");
        printf("uttypes objc: %d/%d passed\n", checks - failures, checks);
    }
    return failures ? 1 : 0;
}
