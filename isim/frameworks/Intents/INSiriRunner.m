/* isim Intents: the SiriKit conversation (adapted), run where the intent is handled — in the app's Intents extension
 * (a helper process the home screen starts: NSExtensionMain -> isim_in_extension_main) or in the app
 * (application(_:handlerFor:), the isim-intent: launch marker -> isim_in_run_request).
 *
 * The home screen ("Siri", SBSiri.m) and the handler talk through a run directory (the intent run protocol, shared
 * with App Intents): it writes request.plist { kind = sirikit; mode = run | handleInApp; intent = (INIntent plist);
 * app; appName; dir }; the runner writes step-1.plist, step-2.plist, ... in order:
 *   { type = value;    param; prompt; kind = text }                       -> answer-N.plist { kind = text; text }
 *   { type = choice;   param; prompt; options = ({ title; subtitle }) }   -> { kind = option; index }
 *   { type = confirm;  prompt; detail; action = Send; cancel = Cancel }   -> { kind = confirm } or { kind = cancel }
 *   { type = result;   dialog; detail; outcome = success | failure | continueInApp | appLaunch | handleInApp | cancelled;
 *     activity = (NSUserActivity plist); interaction = (INInteraction plist) }   (the last step)
 * and the home screen answers each question with answer-N.plist (any answer may be { kind = cancel }). For each
 * parameter of the intent the handler's resolve method runs; needsValue asks for a value, disambiguation for a choice
 * and confirmationRequired for a yes/no, then the parameter is resolved again; unsupported ends the conversation.
 * Then confirm (Siri reads a message back before sending it, as iOS does), then handle. Siri's sentences are isim's
 * English approximations of iOS's. */
#import <Intents/Intents.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <stdlib.h>
#include <ctype.h>

id isim_in_encode(id v);
id isim_in_decode(id v);
@interface NSObject (INValuesRunner)
- (id)_get:(NSString *)k;
- (void)_set:(id)v forKey:(NSString *)k;
- (NSDictionary *)_isim_plist;
@end
@interface INIntentResolutionResult (ISIMRunner)
- (NSString *)_isim_kind;
- (id)_isim_value;
- (NSArray *)_isim_options;
- (NSInteger)_isim_reason;
@end

/* ---------------- the run directory ---------------- */
@interface _INRunChannel : NSObject
@property (nonatomic, copy) NSString *dir;
@property (nonatomic) NSInteger step;
@end
@implementation _INRunChannel
- (NSString *)path:(NSString *)name n:(NSInteger)n { return [self.dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%ld.plist", name, (long)n]]; }
- (NSInteger)write:(NSDictionary *)step {
    NSInteger n = ++self.step;
    [step writeToFile:[self path:@"step" n:n] atomically:YES];
    return n;
}
- (void)ask:(NSDictionary *)step reply:(void (^)(NSDictionary *answer))reply {
    NSInteger n = [self write:step];
    NSString *answer = [self path:@"answer" n:n];
    __block int ticks = 0;
    NSLog(@"isim Intents: Siri asks (%@): %@", step[@"type"], step[@"prompt"]);
    [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *t) {
        NSDictionary *a = [NSDictionary dictionaryWithContentsOfFile:answer];
        if (!a && ++ticks < 20 * 300) return;                 /* five minutes, then the question is abandoned */
        [t invalidate];
        reply(a ?: @{ @"kind": @"cancel" });
    }];
}
- (void)finish:(NSDictionary *)result { [self write:[result mutableCopy]]; NSLog(@"isim Intents: Siri says “%@” (%@)", result[@"dialog"], result[@"outcome"]); }
@end

/* ---------------- the domains: parameters, Siri's sentences ---------------- */
/* a parameter: key, kind (persons | string | speakable | speakables | bool | mediaItems | mediaDestination | taskList | noteContent),
   resolve selectors (the first the handler implements), the question */
static NSArray<NSDictionary *> *intent_params(NSString *cls) {
    static NSDictionary *t;
    if (!t) t = @{
        @"INSendMessageIntent": @[
            @{ @"key": @"recipients", @"kind": @"persons", @"sel": @[@"resolveRecipientsForSendMessage:completion:", @"resolveRecipientsForSendMessage:withCompletion:"], @"prompt": @"Who do you want to message?" },
            @{ @"key": @"content", @"kind": @"string", @"sel": @[@"resolveContentForSendMessage:withCompletion:"], @"prompt": @"What do you want to say?" },
            @{ @"key": @"speakableGroupName", @"kind": @"speakable", @"sel": @[@"resolveSpeakableGroupNameForSendMessage:withCompletion:"], @"prompt": @"Which group?" } ],
        @"INSearchForMessagesIntent": @[
            @{ @"key": @"recipients", @"kind": @"persons", @"sel": @[@"resolveRecipientsForSearchForMessages:withCompletion:"], @"prompt": @"Whose messages?" },
            @{ @"key": @"senders", @"kind": @"persons", @"sel": @[@"resolveSendersForSearchForMessages:withCompletion:"], @"prompt": @"Messages from whom?" } ],
        @"INStartCallIntent": @[
            @{ @"key": @"contacts", @"kind": @"persons", @"sel": @[@"resolveContactsForStartCall:withCompletion:"], @"prompt": @"Who do you want to call?" } ],
        @"INPlayMediaIntent": @[
            @{ @"key": @"mediaItems", @"kind": @"mediaItems", @"sel": @[@"resolveMediaItemsForPlayMedia:withCompletion:"], @"prompt": @"What do you want to play?" },
            @{ @"key": @"playShuffled", @"kind": @"bool", @"sel": @[@"resolvePlayShuffledForPlayMedia:withCompletion:"], @"prompt": @"Shuffle it?" } ],
        @"INEditMessageIntent": @[
            @{ @"key": @"editedContent", @"kind": @"string", @"sel": @[@"resolveEditedContentForEditMessage:withCompletion:"], @"prompt": @"What do you want it to say?" } ],
        @"INUnsendMessagesIntent": @[],
        @"INAddMediaIntent": @[
            @{ @"key": @"mediaItems", @"kind": @"mediaItems", @"sel": @[@"resolveMediaItemsForAddMedia:withCompletion:"], @"prompt": @"What do you want to add?" },
            @{ @"key": @"mediaDestination", @"kind": @"mediaDestination", @"sel": @[@"resolveMediaDestinationForAddMedia:withCompletion:"], @"prompt": @"Which playlist?" } ],
        @"INSearchForMediaIntent": @[
            @{ @"key": @"mediaItems", @"kind": @"mediaItems", @"sel": @[@"resolveMediaItemsForSearchForMedia:withCompletion:"], @"prompt": @"What are you looking for?" } ],
        @"INAddTasksIntent": @[
            @{ @"key": @"targetTaskList", @"kind": @"taskList", @"sel": @[@"resolveTargetTaskListForAddTasks:completion:"], @"prompt": @"Which list?" },
            @{ @"key": @"taskTitles", @"kind": @"speakables", @"sel": @[@"resolveTaskTitlesForAddTasks:withCompletion:"], @"prompt": @"What do you want to add?" } ],
        @"INCreateNoteIntent": @[
            @{ @"key": @"title", @"kind": @"speakable", @"sel": @[@"resolveTitleForCreateNote:withCompletion:"], @"prompt": @"What do you want to call it?" },
            @{ @"key": @"content", @"kind": @"noteContent", @"sel": @[@"resolveContentForCreateNote:withCompletion:"], @"prompt": @"What do you want it to say?" },
            @{ @"key": @"groupName", @"kind": @"speakable", @"sel": @[@"resolveGroupNameForCreateNote:withCompletion:"], @"prompt": @"Which folder?" } ],
    };
    return t[cls];
}
/* ---------------- custom intents: their definition (.intentdefinition files `isim build` copies into the bundle) ---------------- */
static NSArray<NSDictionary *> *definitions(void) {
    static NSMutableArray *defs;
    if (defs) return defs;
    defs = [NSMutableArray array];
    NSMutableArray *dirs = [NSMutableArray arrayWithObject:NSBundle.mainBundle.bundlePath];
    if ([NSBundle.mainBundle.bundlePath.pathExtension isEqualToString:@"appex"])     /* an extension: the app's too */
        [dirs addObject:NSBundle.mainBundle.bundlePath.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent];
    for (NSString *dir in dirs)
        for (NSString *f in [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:NULL])
            if ([f.pathExtension isEqualToString:@"intentdefinition"]) {
                NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:[dir stringByAppendingPathComponent:f]];
                if (d) [defs addObject:d];
            }
    return defs;
}
static NSDictionary *custom_intent(NSString *cls, NSDictionary **definition) {
    for (NSDictionary *d in definitions())
        for (NSDictionary *i in d[@"INIntents"])
            if ([[i[@"INIntentName"] stringByAppendingString:@"Intent"] isEqualToString:cls] || [i[@"INIntentClassName"] isEqualToString:cls]) {
                if (definition) *definition = d;
                return i;
            }
    return nil;
}
static NSString *capitalized(NSString *s) { return s.length ? [[s substringToIndex:1].uppercaseString stringByAppendingString:[s substringFromIndex:1]] : s; }
/* a custom intent's parameters, like intent_params: kind from its type (number, bool, enum, object, person(s), url,
   date, string), Xcode's resolve selector, the question (its primary prompt dialog) */
static NSArray<NSDictionary *> *custom_params(NSString *cls) {
    NSDictionary *def = nil, *intent = custom_intent(cls, &def);
    if (!intent) return nil;
    NSString *base = [cls hasSuffix:@"Intent"] ? [cls substringToIndex:cls.length - 6] : cls;
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *p in intent[@"INIntentParameters"]) {
        NSString *name = p[@"INIntentParameterName"], *type = p[@"INIntentParameterType"] ?: @"String", *kind = @"string";
        BOOL many = [p[@"INIntentParameterSupportsMultipleValues"] boolValue];
        if (p[@"INIntentParameterEnumType"]) kind = @"enum";
        else if ([type isEqualToString:@"Integer"] || [type isEqualToString:@"Decimal"]) kind = @"number";
        else if ([type isEqualToString:@"Boolean"]) kind = @"bool";
        else if ([type isEqualToString:@"Object"]) kind = @"object";
        else if ([type isEqualToString:@"Person"]) kind = many ? @"persons" : @"person";
        else if ([type isEqualToString:@"URL"]) kind = @"url";
        NSString *prompt = nil;
        for (NSDictionary *d in p[@"INIntentParameterPromptDialogs"])
            if ([d[@"INIntentParameterPromptDialogType"] isEqual:@"Primary"]) prompt = d[@"INIntentParameterPromptDialogFormatString"];
        NSMutableDictionary *e = [@{ @"key": name, @"kind": kind, @"many": @(many), @"type": type,
                                     @"sel": @[[NSString stringWithFormat:@"resolve%@For%@:withCompletion:", capitalized(name), base]],
                                     @"prompt": prompt ?: [NSString stringWithFormat:@"What %@?", p[@"INIntentParameterDisplayName"] ?: name] } mutableCopy];
        if (p[@"INIntentParameterEnumType"]) {
            for (NSDictionary *en in def[@"INEnums"])
                if ([en[@"INEnumName"] isEqual:p[@"INIntentParameterEnumType"]]) e[@"enum"] = en[@"INEnumValues"] ?: @[];
        }
        if (p[@"INIntentParameterObjectType"]) e[@"objectType"] = p[@"INIntentParameterObjectType"];
        if ([p[@"INIntentParameterSupportsDynamicEnumeration"] boolValue])    /* dynamic options: an INObjectCollection */
            e[@"options"] = [NSString stringWithFormat:@"provide%@OptionsCollectionFor%@:withCompletion:", capitalized(name), base];
        [out addObject:e];
    }
    return out;
}
static id value_from_text(NSString *kind, NSString *text, INIntent *intent);
/* a custom parameter's value from text: the parameter's type (the script's key=value strings, and answers) */
static id custom_value(NSDictionary *p, id raw) {
    if (![raw isKindOfClass:[NSString class]]) return raw;
    NSString *text = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet], *kind = p[@"kind"];
    if ([kind isEqualToString:@"number"]) return [p[@"type"] isEqual:@"Decimal"] ? @(text.doubleValue) : @(text.integerValue);
    if ([kind isEqualToString:@"bool"]) { NSString *l = text.lowercaseString; return @([l hasPrefix:@"y"] || [l isEqualToString:@"true"] || [l isEqualToString:@"1"]); }
    if ([kind isEqualToString:@"enum"]) {
        for (NSDictionary *v in p[@"enum"])
            if ([[v[@"INEnumValueName"] lowercaseString] isEqualToString:text.lowercaseString] || [[v[@"INEnumValueDisplayName"] lowercaseString] isEqualToString:text.lowercaseString])
                return @([v[@"INEnumValueIndex"] integerValue]);
        return @(text.integerValue);
    }
    if ([kind isEqualToString:@"object"]) {
        Class c = NSClassFromString(p[@"objectType"]) ?: [INObject class];
        id o = [[c alloc] initWithIdentifier:text displayString:text];
        return [p[@"many"] boolValue] ? @[o] : o;
    }
    if ([kind isEqualToString:@"url"]) return [NSURL URLWithString:text];
    if ([kind isEqualToString:@"persons"]) return value_from_text(@"persons", text, nil);
    if ([kind isEqualToString:@"person"]) return [value_from_text(@"persons", text, nil) firstObject];
    return text;
}
static NSString *base_name(NSString *cls) {                 /* SendMessage; OrderSoup for a custom OrderSoupIntent */
    BOOL system = cls.length > 2 && [cls hasPrefix:@"IN"] && isupper([cls characterAtIndex:2]);
    NSString *b = system ? [cls substringFromIndex:2] : cls;
    return [b hasSuffix:@"Intent"] ? [b substringToIndex:b.length - 6] : b;
}
static SEL handle_sel(NSString *cls) { return NSSelectorFromString([NSString stringWithFormat:@"handle%@:completion:", base_name(cls)]); }
static SEL confirm_sel(NSString *cls) { return NSSelectorFromString([NSString stringWithFormat:@"confirm%@:completion:", base_name(cls)]); }
static Protocol *handling_protocol(NSString *cls) { return objc_getProtocol([cls stringByAppendingString:@"Handling"].UTF8String); }

static NSString *person_list(NSArray *people) {
    NSMutableArray *n = [NSMutableArray array];
    for (INPerson *p in people) if ([p isKindOfClass:[INPerson class]]) [n addObject:p.displayName];
    if (n.count <= 1) return n.firstObject ?: @"";
    return [NSString stringWithFormat:@"%@ and %@", [[n subarrayWithRange:NSMakeRange(0, n.count - 1)] componentsJoinedByString:@", "], n.lastObject];
}
static NSString *title_of(id v) {
    if ([v isKindOfClass:[INPerson class]]) return [v displayName];
    if ([v isKindOfClass:[NSString class]]) return v;
    if ([v isKindOfClass:[INSpeakableString class]]) return [v spokenPhrase];
    if ([v isKindOfClass:[INMediaItem class]]) return [v title] ?: [v identifier] ?: @"";
    if ([v isKindOfClass:[INMediaDestination class]]) return [v mediaDestinationType] == INMediaDestinationTypeLibrary ? @"Library" : [v playlistName] ?: @"";
    if ([v isKindOfClass:[INObject class]]) return [v displayString];
    if ([v isKindOfClass:[INTaskList class]]) return ((INTaskList *)v).title.spokenPhrase;
    if ([v isKindOfClass:[INTextNoteContent class]]) return [v text] ?: @"";
    if ([v isKindOfClass:[NSNumber class]]) return [v boolValue] ? @"Yes" : @"No";
    return [v description] ?: @"";
}
static NSString *subtitle_of(id v) {
    if ([v isKindOfClass:[INPerson class]]) return [[v personHandle] value] ?: @"";
    if ([v isKindOfClass:[INMediaItem class]]) return [v artist] ?: @"";
    if ([v isKindOfClass:[INObject class]]) return [v subtitleString] ?: @"";
    return @"";
}
/* a value from what the user said */
static id value_from_text(NSString *kind, NSString *text, INIntent *intent) {
    text = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if ([kind isEqualToString:@"persons"]) {
        NSMutableArray *people = [NSMutableArray array];
        for (NSString *raw in [[text stringByReplacingOccurrencesOfString:@" and " withString:@","] componentsSeparatedByString:@","]) {
            NSString *name = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            if (!name.length) continue;
            NSPersonNameComponents *n = [NSPersonNameComponents new];
            NSRange sp = [name rangeOfString:@" "];
            n.givenName = sp.location == NSNotFound ? name : [name substringToIndex:sp.location];
            if (sp.location != NSNotFound) n.familyName = [name substringFromIndex:sp.location + 1];
            [people addObject:[[INPerson alloc] initWithPersonHandle:[[INPersonHandle alloc] initWithValue:name type:INPersonHandleTypeUnknown]
                                                       nameComponents:n displayName:name image:nil contactIdentifier:nil customIdentifier:nil]];
        }
        return people;
    }
    if ([kind isEqualToString:@"string"]) return text;
    if ([kind isEqualToString:@"speakable"]) return [[INSpeakableString alloc] initWithSpokenPhrase:text];
    if ([kind isEqualToString:@"speakables"]) return @[[[INSpeakableString alloc] initWithSpokenPhrase:text]];
    if ([kind isEqualToString:@"bool"]) { NSString *l = text.lowercaseString; return @([l hasPrefix:@"y"] || [l isEqualToString:@"ok"] || [l isEqualToString:@"sure"]); }
    if ([kind isEqualToString:@"taskList"]) return [[INTaskList alloc] initWithTitle:[[INSpeakableString alloc] initWithSpokenPhrase:text] tasks:@[] groupName:nil createdDateComponents:nil modifiedDateComponents:nil identifier:nil];
    if ([kind isEqualToString:@"noteContent"]) return [[INTextNoteContent alloc] initWithText:text];
    if ([kind isEqualToString:@"mediaDestination"])
        return [text.lowercaseString hasSuffix:@"library"] ? [INMediaDestination libraryDestination] : [INMediaDestination playlistDestinationWithName:text];
    if ([kind isEqualToString:@"mediaItems"]) {             /* Siri searches by name: the app resolves mediaSearch into items */
        [intent _set:[[INMediaSearch alloc] initWithMediaType:INMediaItemTypeUnknown sortOrder:INMediaSortOrderUnknown mediaName:text artistName:nil albumName:nil
                                                   genreNames:nil moodNames:nil releaseDate:nil reference:INMediaReferenceUnknown mediaIdentifier:nil] forKey:@"mediaSearch"];
        return nil;
    }
    return text;
}

/* a custom response's dialog: its code's format string with ${parameter} filled in from the response */
static NSDictionary *custom_code(NSString *cls, NSInteger code) {
    NSDictionary *intent = custom_intent(cls, NULL);
    if (!intent) return nil;
    NSArray *codes = intent[@"INIntentResponse"][@"INIntentResponseCodes"];
    static NSArray *system;
    if (!system) system = @[@"unspecified", @"ready", @"continueInApp", @"inProgress", @"success", @"failure", @"failureRequiringAppLaunch"];
    NSInteger custom = 100;
    for (NSDictionary *c in codes) {
        NSString *name = c[@"INIntentResponseCodeName"];
        NSUInteger i = [system indexOfObject:name];
        NSInteger value = i != NSNotFound ? (NSInteger)i : custom++;
        if (value == code) return c;
    }
    return nil;
}
/* "€4.50": an amount as Siri says it in English */
static NSString *currency_text(INCurrencyAmount *a) {
    NSDictionary *symbols = @{ @"USD": @"$", @"EUR": @"€", @"GBP": @"£", @"JPY": @"¥" };
    NSString *n = a.amount ? [NSString stringWithFormat:@"%.2f", a.amount.doubleValue] : @"0";
    NSString *sym = symbols[a.currencyCode ?: @""];
    return sym ? [sym stringByAppendingString:n] : [NSString stringWithFormat:@"%@ %@", n, a.currencyCode ?: @""];
}
static NSString *custom_dialog(INIntentResponse *r, NSDictionary *c) {
    NSString *f = c[@"INIntentResponseCodeFormatString"] ?: c[@"INIntentResponseCodeConciseFormatString"] ?: @"";
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\$\\{([A-Za-z0-9_]+)\\}" options:0 error:NULL];
    NSMutableString *out = [f mutableCopy];
    for (NSTextCheckingResult *m in [[re matchesInString:f options:0 range:NSMakeRange(0, f.length)] reverseObjectEnumerator]) {
        NSString *key = [f substringWithRange:[m rangeAtIndex:1]];
        id v = [r respondsToSelector:NSSelectorFromString(key)] ? [r valueForKey:key] : nil;
        NSString *text = [v respondsToSelector:@selector(displayString)] ? [v displayString] : [v isKindOfClass:[INCurrencyAmount class]] ? currency_text(v) : v ? [v description] : @"";
        [out replaceCharactersInRange:m.range withString:text];
    }
    return out;
}
/* what the response code means, per domain */
static NSString *outcome_of(NSString *cls, NSInteger code) {
    if (custom_intent(cls, NULL)) {                         /* custom: success 4 (or a custom code marked success), ... */
        NSDictionary *c = custom_code(cls, code);
        if (code >= 100) return [c[@"INIntentResponseCodeSuccess"] boolValue] ? @"success" : @"failure";
        return code == 4 || code == 3 || code == 1 ? @"success" : code == 2 ? @"continueInApp" : code == 6 ? @"appLaunch" : @"failure";
    }
    if ([cls isEqualToString:@"INStartCallIntent"]) return code == 2 || code == 1 ? @"continueInApp" : code == 5 ? @"appLaunch" : code >= 4 ? @"failure" : @"failure";
    if ([cls isEqualToString:@"INPlayMediaIntent"])
        return code == 4 ? @"success" : code == 2 ? @"continueInApp" : code == 5 ? @"handleInApp" : code == 3 || code == 1 ? @"success" : code == 7 ? @"appLaunch" : @"failure";
    if ([cls isEqualToString:@"INAddMediaIntent"])
        return code == 3 || code == 2 || code == 1 ? @"success" : code == 4 ? @"handleInApp" : code == 6 ? @"appLaunch" : @"failure";
    if ([cls isEqualToString:@"INSearchForMediaIntent"])
        return code == 4 || code == 3 || code == 1 ? @"success" : code == 2 ? @"continueInApp" : code == 6 ? @"appLaunch" : @"failure";
    return code == 3 || code == 2 || code == 1 ? @"success" : code == 5 ? @"appLaunch" : @"failure";
}
static NSString *success_dialog(INIntent *intent, INIntentResponse *r, NSString *app, NSString **detail) {
    NSString *cls = NSStringFromClass(intent.class);
    if ([cls isEqualToString:@"INSendMessageIntent"]) {
        INSendMessageIntent *m = (INSendMessageIntent *)intent;
        *detail = [NSString stringWithFormat:@"To: %@\n%@", person_list(m.recipients), m.content ?: @""];
        return [NSString stringWithFormat:@"OK, I sent your message to %@.", person_list(m.recipients)];
    }
    if ([cls isEqualToString:@"INSearchForMessagesIntent"]) {
        NSArray *msgs = [(INSearchForMessagesIntentResponse *)r messages];
        NSMutableArray *lines = [NSMutableArray array];
        for (INMessage *m in msgs) [lines addObject:[NSString stringWithFormat:@"%@: %@", m.sender.displayName ?: @"", m.content ?: @""]];
        *detail = [lines componentsJoinedByString:@"\n"];
        return msgs.count ? [NSString stringWithFormat:@"You have %lu message%@.", (unsigned long)msgs.count, msgs.count == 1 ? @"" : @"s"] : @"You don’t have any messages.";
    }
    if ([cls isEqualToString:@"INStartCallIntent"]) return [NSString stringWithFormat:@"Calling %@…", person_list([(INStartCallIntent *)intent contacts])];
    if ([cls isEqualToString:@"INPlayMediaIntent"]) {
        INPlayMediaIntent *p = (INPlayMediaIntent *)intent;
        NSString *t = [p.mediaItems.firstObject title] ?: p.mediaSearch.mediaName;
        return t.length ? [NSString stringWithFormat:@"Now playing %@.", t] : [NSString stringWithFormat:@"OK, here’s %@.", app];
    }
    if ([cls isEqualToString:@"INAddMediaIntent"]) {
        INAddMediaIntent *a = (INAddMediaIntent *)intent;
        NSString *t = [a.mediaItems.firstObject title] ?: a.mediaSearch.mediaName;
        INMediaDestination *d = a.mediaDestination;
        NSString *where = d.mediaDestinationType == INMediaDestinationTypePlaylist ? [NSString stringWithFormat:@" to your %@ playlist", d.playlistName]
                        : d.mediaDestinationType == INMediaDestinationTypeLibrary ? @" to your library" : @"";
        return [NSString stringWithFormat:@"OK, I added %@%@.", t.length ? t : @"it", where];
    }
    if ([cls isEqualToString:@"INSearchForMediaIntent"]) {
        NSArray *items = [(INSearchForMediaIntentResponse *)r mediaItems] ?: [(INSearchForMediaIntent *)intent mediaItems];
        NSMutableArray *lines = [NSMutableArray array];
        for (INMediaItem *m in items) [lines addObject:m.artist.length ? [NSString stringWithFormat:@"%@ — %@", m.title ?: @"", m.artist] : m.title ?: @""];
        *detail = [lines componentsJoinedByString:@"\n"];
        return items.count ? [NSString stringWithFormat:@"I found %lu result%@ in %@.", (unsigned long)items.count, items.count == 1 ? @"" : @"s", app]
                           : [NSString stringWithFormat:@"I didn’t find anything in %@.", app];
    }
    if ([cls isEqualToString:@"INEditMessageIntent"]) {
        NSString *c = [intent _get:@"editedContent"];          /* INEditMessageIntent (iOS 16) */
        *detail = c ?: @"";
        return @"OK, I edited your message.";
    }
    if ([cls isEqualToString:@"INUnsendMessagesIntent"]) {
        NSUInteger n = [[intent _get:@"messageIdentifiers"] count];   /* INUnsendMessagesIntent (iOS 16) */
        return n > 1 ? [NSString stringWithFormat:@"OK, I unsent %lu messages.", (unsigned long)n] : @"OK, I unsent your message.";
    }
    if ([cls isEqualToString:@"INAddTasksIntent"]) {
        INAddTasksIntent *a = (INAddTasksIntent *)intent;
        NSArray *added = [(INAddTasksIntentResponse *)r addedTasks];
        NSString *task = added.count ? ((INTask *)added.firstObject).title.spokenPhrase : ((INSpeakableString *)a.taskTitles.firstObject).spokenPhrase;
        INTaskList *list = [(INAddTasksIntentResponse *)r modifiedTaskList] ?: a.targetTaskList;
        NSString *where = list ? [NSString stringWithFormat:@" to your %@ list", list.title.spokenPhrase] : @"";
        return [NSString stringWithFormat:@"OK, I added “%@”%@.", task ?: @"it", where];
    }
    if ([cls isEqualToString:@"INCreateNoteIntent"]) {
        INCreateNoteIntent *n = (INCreateNoteIntent *)intent;
        INNote *note = [(INCreateNoteIntentResponse *)r createdNote];
        id c = n.content ?: note.contents.firstObject;
        *detail = [@[note.title.spokenPhrase ?: n.title.spokenPhrase ?: @"", [c isKindOfClass:[INTextNoteContent class]] ? [c text] ?: @"" : @""] componentsJoinedByString:@"\n"];
        return [NSString stringWithFormat:@"OK, I made a note in %@.", app];
    }
    return @"Done.";
}

/* ---------------- the conversation ---------------- */
@interface _INConversation : NSObject
@property (nonatomic, strong) _INRunChannel *channel;
@property (nonatomic, strong) INIntent *intent;
@property (nonatomic, strong) id handler;
@property (nonatomic, copy) NSString *app;
@property (nonatomic, copy) void (^done)(void);
@property (nonatomic) NSInteger rounds;
@end
@implementation _INConversation
- (void)end:(NSDictionary *)result {
    NSMutableDictionary *r = [result mutableCopy];
    r[@"type"] = @"result";
    if (!r[@"dialog"]) r[@"dialog"] = @"";
    [self.channel finish:r];
    if (self.done) self.done();
}
- (void)fail:(NSString *)dialog { [self end:@{ @"dialog": dialog, @"outcome": @"failure" }]; }
- (void)start {
    NSString *cls = NSStringFromClass(self.intent.class);
    NSArray *params = intent_params(cls);
    if (!params && (params = custom_params(cls))) {          /* a custom intent: its values as the parameters' types */
        for (NSDictionary *p in params) { id v = [self.intent _get:p[@"key"]]; if (v) [self.intent _set:custom_value(p, v) forKey:p[@"key"]]; }
    }
    if (!params || !self.handler) {
        NSLog(@"isim Intents: no handler for %@ in %@", cls, self.app);
        [self fail:[NSString stringWithFormat:@"Sorry, %@ can’t do that.", self.app]]; return;
    }
    if (![self.handler respondsToSelector:handle_sel(cls)]) {
        NSLog(@"isim Intents: %@ does not handle %@ (%@)", NSStringFromClass([self.handler class]), cls, NSStringFromProtocol(handling_protocol(cls)) ?: @"");
        [self fail:[NSString stringWithFormat:@"Sorry, %@ can’t do that.", self.app]]; return;
    }
    NSLog(@"isim Intents: %@ handles %@", NSStringFromClass([self.handler class]), cls);
    [self resolve:params index:0];
}
- (void)resolve:(NSArray *)params index:(NSUInteger)i {
    if (i >= params.count) { [self confirm]; return; }
    NSDictionary *p = params[i];
    SEL sel = NULL;
    for (NSString *s in p[@"sel"]) if ([self.handler respondsToSelector:NSSelectorFromString(s)]) { sel = NSSelectorFromString(s); break; }
    if (!sel || ++self.rounds > 24) { [self resolve:params index:i + 1]; return; }
    __weak _INConversation *weakSelf = self;
    void (^completion)(id) = ^(id results) {
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf resolved:results param:p params:params index:i]; });
    };
    NSLog(@"isim Intents: resolving %@", p[@"key"]);
    ((void (*)(id, SEL, id, id))objc_msgSend)(self.handler, sel, self.intent, completion);
}
- (void)resolved:(id)results param:(NSDictionary *)p params:(NSArray *)params index:(NSUInteger)i {
    NSString *key = p[@"key"], *kind = p[@"kind"];
    BOOL array = [results isKindOfClass:[NSArray class]];
    NSArray *list = array ? results : results ? @[results] : @[];
    NSMutableArray *values = [NSMutableArray array];
    for (NSUInteger k = 0; k < list.count; k++) {
        INIntentResolutionResult *r = list[k];
        NSString *rk = [r _isim_kind];
        NSLog(@"isim Intents: %@: %@%@", key, rk, [r _isim_value] ? [NSString stringWithFormat:@" (%@)", title_of([r _isim_value])] : @"");
        if ([rk isEqualToString:@"success"]) { if ([r _isim_value]) [values addObject:[r _isim_value]]; continue; }
        if ([rk isEqualToString:@"notRequired"]) continue;
        if ([rk isEqualToString:@"unsupported"]) {
            NSString *what = title_of([[self.intent _get:key] isKindOfClass:[NSArray class]] && k < [[self.intent _get:key] count] ? [self.intent _get:key][k] : [self.intent _get:key]);
            [self fail:what.length ? [NSString stringWithFormat:@"Sorry, %@ can’t do that with “%@”.", self.app, what] : [NSString stringWithFormat:@"Sorry, %@ can’t do that.", self.app]];
            return;
        }
        if ([rk isEqualToString:@"needsValue"] && p[@"options"] && [self.handler respondsToSelector:NSSelectorFromString(p[@"options"])]) {
            [self offerOptions:p params:params index:i];
            return;
        }
        if ([rk isEqualToString:@"needsValue"]) {
            [self.channel ask:@{ @"type": @"value", @"param": key, @"prompt": p[@"prompt"], @"kind": @"text" } reply:^(NSDictionary *a) {
                if (![a[@"kind"] isEqual:@"text"]) { [self cancelled]; return; }
                id v = p[@"type"] ? custom_value(p, a[@"text"] ?: @"") : value_from_text(kind, a[@"text"] ?: @"", self.intent);
                if ([kind isEqualToString:@"string"] || [kind isEqualToString:@"speakable"] || [kind isEqualToString:@"taskList"] || [kind isEqualToString:@"noteContent"] || [kind isEqualToString:@"bool"] || [kind isEqualToString:@"mediaDestination"]) [self.intent _set:v forKey:key];
                else if (v) [self.intent _set:v forKey:key];
                [self resolve:params index:i];
            }];
            return;
        }
        if ([rk isEqualToString:@"disambiguation"]) {
            NSArray *opts = [r _isim_options] ?: @[];
            NSMutableArray *shown = [NSMutableArray array];
            for (id o in opts) [shown addObject:@{ @"title": title_of(o), @"subtitle": subtitle_of(o) }];
            NSString *prompt = [kind isEqualToString:@"persons"] && opts.count ? [NSString stringWithFormat:@"Which %@?", [[opts.firstObject nameComponents] givenName] ?: @"one"] : @"Which one?";
            [self.channel ask:@{ @"type": @"choice", @"param": key, @"prompt": prompt, @"options": shown } reply:^(NSDictionary *a) {
                NSInteger idx = [a[@"index"] integerValue];
                if (![a[@"kind"] isEqual:@"option"] || idx < 0 || idx >= (NSInteger)opts.count) { [self cancelled]; return; }
                [self replace:key at:k with:opts[idx] array:array];
                [self resolve:params index:i];
            }];
            return;
        }
        if ([rk isEqualToString:@"confirmationRequired"]) {
            id item = [r _isim_value];
            [self.channel ask:@{ @"type": @"confirm", @"param": key, @"prompt": [NSString stringWithFormat:@"Did you mean %@?", title_of(item)], @"action": @"Yes", @"cancel": @"No" } reply:^(NSDictionary *a) {
                if (![a[@"kind"] isEqual:@"confirm"]) { [self cancelled]; return; }
                [self replace:key at:k with:item array:array];
                [self resolve:params index:i + 1];
            }];
            return;
        }
    }
    if (values.count) [self.intent _set:array && ![kind isEqualToString:@"bool"] ? values : values.firstObject forKey:key];
    [self resolve:params index:i + 1];
}
/* a parameter with dynamic options: the handler's INObjectCollection, offered as a choice (section titles as subtitles) */
- (void)offerOptions:(NSDictionary *)p params:(NSArray *)params index:(NSUInteger)i {
    __weak _INConversation *weakSelf = self;
    NSLog(@"isim Intents: options for %@", p[@"key"]);
    ((void (*)(id, SEL, id, id))objc_msgSend)(self.handler, NSSelectorFromString(p[@"options"]), self.intent, ^(INObjectCollection *c, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _INConversation *me = weakSelf;
            if (!me) return;
            NSMutableArray *items = [NSMutableArray array], *shown = [NSMutableArray array];
            for (INObjectSection *sec in c.sections)
                for (id o in sec.items) {
                    [items addObject:o];
                    NSString *sub = subtitle_of(o);
                    [shown addObject:@{ @"title": title_of(o), @"subtitle": sub.length ? sub : sec.title ?: @"" }];
                }
            NSLog(@"isim Intents: %@: %lu option(s) in %lu section(s)%@", p[@"key"], (unsigned long)items.count, (unsigned long)c.sections.count, error ? [@" error " stringByAppendingString:error.localizedDescription] : @"");
            if (!items.count) { [me fail:[NSString stringWithFormat:@"Sorry, %@ doesn’t have any options for that.", me.app]]; return; }
            [me.channel ask:@{ @"type": @"choice", @"param": p[@"key"], @"prompt": p[@"prompt"], @"options": shown } reply:^(NSDictionary *a) {
                NSInteger idx = [a[@"index"] integerValue];
                if ([a[@"kind"] isEqual:@"text"]) {                   /* a value that is not among the options */
                    [me.intent _set:custom_value(p, a[@"text"] ?: @"") forKey:p[@"key"]];
                    [me resolve:params index:i]; return;
                }
                if (![a[@"kind"] isEqual:@"option"] || idx < 0 || idx >= (NSInteger)items.count) { [me cancelled]; return; }
                [me.intent _set:[p[@"many"] boolValue] ? @[items[idx]] : items[idx] forKey:p[@"key"]];
                [me resolve:params index:i];
            }];
        });
    });
}
- (void)replace:(NSString *)key at:(NSUInteger)k with:(id)v array:(BOOL)array {
    if (!v) return;
    if (array) {
        NSMutableArray *a = [[self.intent _get:key] isKindOfClass:[NSArray class]] ? [[self.intent _get:key] mutableCopy] : [NSMutableArray array];
        if (k < a.count) a[k] = v; else [a addObject:v];
        [self.intent _set:a forKey:key];
    } else [self.intent _set:v forKey:key];
}
- (void)cancelled { [self end:@{ @"dialog": @"OK.", @"outcome": @"cancelled" }]; }
- (NSInteger)codeOf:(INIntentResponse *)r { return [r respondsToSelector:@selector(code)] ? ((NSInteger (*)(id, SEL))objc_msgSend)(r, @selector(code)) : 0; }
- (void)confirm {
    NSString *cls = NSStringFromClass(self.intent.class);
    SEL sel = confirm_sel(cls);
    __weak _INConversation *weakSelf = self;
    void (^after)(INIntentResponse *) = ^(INIntentResponse *r) {
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf confirmed:r]; });
    };
    if ([self.handler respondsToSelector:sel]) {
        NSLog(@"isim Intents: confirm");
        ((void (*)(id, SEL, id, id))objc_msgSend)(self.handler, sel, self.intent, after);
    } else after(nil);
}
- (void)confirmed:(INIntentResponse *)r {
    NSString *cls = NSStringFromClass(self.intent.class);
    NSInteger code = r ? [self codeOf:r] : 1;
    if (r) NSLog(@"isim Intents: confirm -> code %ld", (long)code);
    BOOL failed = [cls isEqualToString:@"INPlayMediaIntent"] ? code >= 6 : [cls isEqualToString:@"INAddMediaIntent"] || [cls isEqualToString:@"INSearchForMediaIntent"] ? code >= 5 : code >= 4;
    if (failed) { [self respond:r]; return; }
    if ([cls isEqualToString:@"INSendMessageIntent"]) {       /* iOS reads the message back before sending it */
        INSendMessageIntent *m = (INSendMessageIntent *)self.intent;
        [self.channel ask:@{ @"type": @"confirm", @"prompt": @"Ready to send it?", @"action": @"Send", @"cancel": @"Cancel",
                             @"detail": [NSString stringWithFormat:@"To: %@\n%@", person_list(m.recipients), m.content ?: @""],
                             @"interaction": [[[INInteraction alloc] initWithIntent:self.intent response:r] _isim_plist] }
                    reply:^(NSDictionary *a) {
            if (![a[@"kind"] isEqual:@"confirm"]) { [self end:@{ @"dialog": @"OK, I won’t send it.", @"outcome": @"cancelled" }]; return; }
            [self handle];
        }];
        return;
    }
    if ([cls isEqualToString:@"INStartCallIntent"] && code == INStartCallIntentResponseCodeUserConfirmationRequired) {
        [self.channel ask:@{ @"type": @"confirm", @"prompt": [NSString stringWithFormat:@"Call %@?", person_list([(INStartCallIntent *)self.intent contacts])], @"action": @"Call", @"cancel": @"Cancel" }
                    reply:^(NSDictionary *a) { if ([a[@"kind"] isEqual:@"confirm"]) [self handle]; else [self cancelled]; }];
        return;
    }
    [self handle];
}
- (void)handle {
    NSString *cls = NSStringFromClass(self.intent.class);
    __weak _INConversation *weakSelf = self;
    NSLog(@"isim Intents: handle");
    ((void (*)(id, SEL, id, id))objc_msgSend)(self.handler, handle_sel(cls), self.intent, ^(INIntentResponse *r) {
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf respond:r]; });
    });
}
- (void)respond:(INIntentResponse *)r {
    NSString *cls = NSStringFromClass(self.intent.class);
    NSInteger code = [self codeOf:r];
    NSString *outcome = outcome_of(cls, code), *detail = @"";
    NSLog(@"isim Intents: %@ response code %ld (%@)", cls, (long)code, outcome);
    INInteraction *interaction = [[INInteraction alloc] initWithIntent:self.intent response:r];
    interaction.direction = INInteractionDirectionOutgoing;
    NSMutableDictionary *res = [@{ @"outcome": outcome, @"code": @(code), @"interaction": [interaction _isim_plist] } mutableCopy];
    NSDictionary *cc = custom_code(cls, code);
    if (cc && custom_dialog(r, cc).length) res[@"dialog"] = custom_dialog(r, cc);
    else if ([outcome isEqualToString:@"success"]) res[@"dialog"] = success_dialog(self.intent, r, self.app, &detail);
    else if ([outcome isEqualToString:@"continueInApp"]) res[@"dialog"] = [cls isEqualToString:@"INStartCallIntent"] ? success_dialog(self.intent, r, self.app, &detail) : [NSString stringWithFormat:@"Opening %@…", self.app];
    else if ([outcome isEqualToString:@"appLaunch"]) res[@"dialog"] = [NSString stringWithFormat:@"You’ll need to continue in %@.", self.app];
    else if ([outcome isEqualToString:@"handleInApp"]) res[@"dialog"] = success_dialog(self.intent, r, self.app, &detail);
    else if (([cls isEqualToString:@"INEditMessageIntent"] || [cls isEqualToString:@"INUnsendMessagesIntent"]) && code >= 6 && code <= 7)
        res[@"dialog"] = code == 6 ? @"Sorry, I couldn’t find that message."
                                   : [NSString stringWithFormat:@"Sorry, it’s too late to %@ that message.", [cls isEqualToString:@"INEditMessageIntent"] ? @"edit" : @"unsend"];
    else res[@"dialog"] = [NSString stringWithFormat:@"Sorry, there was a problem with %@.", self.app];
    if (detail.length) res[@"detail"] = detail;
    if ([outcome isEqualToString:@"continueInApp"] || [outcome isEqualToString:@"appLaunch"]) {
        NSUserActivity *a = r.userActivity ?: [[NSUserActivity alloc] initWithActivityType:cls];
        NSMutableDictionary *ap = [[a _isim_plist] mutableCopy];
        ap[@"interaction"] = [interaction _isim_plist];
        res[@"activity"] = ap;
    }
    [self end:res];
}
@end

/* ---------------- entry points ---------------- */
static NSMutableSet *live;          /* conversations in flight */
static void run_with_handler(NSDictionary *req, id (^handlerFor)(INIntent *), void (^done)(void)) {
    _INRunChannel *ch = [_INRunChannel new]; ch.dir = req[@"dir"];
    INIntent *intent = [INIntent _isim_intentWithPlist:req[@"intent"]];
    _INConversation *c = [_INConversation new];
    c.channel = ch; c.intent = intent; c.app = req[@"appName"] ?: @"the app";
    if (!live) live = [NSMutableSet set];
    [live addObject:c];
    __weak _INConversation *weakC = c;
    c.done = ^{ _INConversation *s = weakC; if (s) [live removeObject:s]; if (done) done(); };
    if (!intent) { [c fail:@"Sorry, I didn’t understand that."]; return; }
    c.handler = handlerFor(intent);
    [c start];
}

/* in the app: application(_:handlerFor:), or application(_:handle:completionHandler:) for .handleInApp */
void isim_in_run_request(const char *path) {
    NSDictionary *req = [NSDictionary dictionaryWithContentsOfFile:@(path)];
    if (!req) { NSLog(@"isim Intents: no request at %s", path); return; }
    UIApplication *app = UIApplication.sharedApplication;
    id<UIApplicationDelegate> d = app.delegate;
    __block UIBackgroundTaskIdentifier task = [app beginBackgroundTaskWithName:@"SiriKit" expirationHandler:^{}];
    void (^finish)(void) = ^{ if (task != UIBackgroundTaskInvalid) { [app endBackgroundTask:task]; task = UIBackgroundTaskInvalid; } };
    if ([req[@"mode"] isEqual:@"handleInApp"]) {
        INIntent *intent = [INIntent _isim_intentWithPlist:req[@"intent"]];
        _INRunChannel *ch = [_INRunChannel new]; ch.dir = req[@"dir"];
        if (![d respondsToSelector:@selector(application:handleIntent:completionHandler:)]) {
            NSLog(@"isim Intents: the app delegate does not implement application(_:handle:completionHandler:)");
            [ch finish:@{ @"type": @"result", @"dialog": @"", @"outcome": @"failure" }]; finish(); return;
        }
        NSLog(@"isim Intents: application(_:handle:) %@", NSStringFromClass(intent.class));
        [d application:app handleIntent:intent completionHandler:^(INIntentResponse *r) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSInteger code = [r respondsToSelector:@selector(code)] ? ((NSInteger (*)(id, SEL))objc_msgSend)(r, @selector(code)) : 0;
                NSLog(@"isim Intents: handled in the app, code %ld", (long)code);
                [ch finish:@{ @"type": @"result", @"dialog": @"", @"outcome": [outcome_of(NSStringFromClass(intent.class), code) isEqual:@"success"] ? @"success" : @"failure", @"code": @(code), @"inApp": @YES }];
                finish();
            });
        }];
        return;
    }
    run_with_handler(req, ^id(INIntent *intent) {
        if (![d respondsToSelector:@selector(application:handlerForIntent:)]) { NSLog(@"isim Intents: the app delegate does not implement application(_:handlerFor:)"); return nil; }
        return [d application:app handlerForIntent:intent];
    }, finish);
}

/* an Intents extension: a helper process for one conversation */
@interface __IsimIntentsExtensionHost : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation __IsimIntentsExtensionHost { id _principal; }
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    const char *rp = getenv("ISIM_EXTENSION_REQUEST");
    NSDictionary *req = rp ? [NSDictionary dictionaryWithContentsOfFile:@(rp)] : nil;
    if (!req) { NSLog(@"isim: Intents extension started without a request (ISIM_EXTENSION_REQUEST)"); exit(2); }
    NSString *principal = NSBundle.mainBundle.infoDictionary[@"NSExtension"][@"NSExtensionPrincipalClass"];
    Class cls = NSClassFromString(principal ?: @"");
    if (!cls) NSLog(@"isim: Intents extension: no principal class %@", principal ?: @"(NSExtensionPrincipalClass)");
    _principal = cls ? [cls new] : nil;
    id principalObj = _principal;
    run_with_handler(req, ^id(INIntent *intent) {
        if ([principalObj respondsToSelector:@selector(handlerForIntent:)]) return [principalObj handlerForIntent:intent];
        return principalObj;
    }, ^{
        fflush(NULL);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ exit(0); });
    });
    return YES;
}
@end
int isim_in_extension_main(int argc, char **argv) {
    return UIApplicationMain(argc, argv, nil, @"__IsimIntentsExtensionHost");
}
