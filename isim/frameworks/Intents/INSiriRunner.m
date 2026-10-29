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
#include <time.h>

id isim_in_encode(id v);
id isim_in_decode(id v);
NSString *isim_in_code_meaning(NSString *cls, NSInteger code);
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
/* a parameter: key, kind (persons | person | string | strings | speakable | speakables | bool | integer | double | currency | placemark |
   dateRange | goalUnit | locationType | mediaItems | mediaDestination | taskList | noteContent),
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
        /* payments, rides, workouts and photos (issue #411) */
        @"INSendPaymentIntent": @[
            @{ @"key": @"payee", @"kind": @"person", @"sel": @[@"resolvePayeeForSendPayment:completion:", @"resolvePayeeForSendPayment:withCompletion:"], @"prompt": @"Who do you want to pay?" },
            @{ @"key": @"currencyAmount", @"kind": @"currency", @"sel": @[@"resolveCurrencyAmountForSendPayment:completion:", @"resolveCurrencyAmountForSendPayment:withCompletion:"], @"prompt": @"How much?" },
            @{ @"key": @"note", @"kind": @"string", @"sel": @[@"resolveNoteForSendPayment:withCompletion:"], @"prompt": @"What’s it for?" } ],
        @"INRequestPaymentIntent": @[
            @{ @"key": @"payer", @"kind": @"person", @"sel": @[@"resolvePayerForRequestPayment:completion:", @"resolvePayerForRequestPayment:withCompletion:"], @"prompt": @"Who do you want to request money from?" },
            @{ @"key": @"currencyAmount", @"kind": @"currency", @"sel": @[@"resolveCurrencyAmountForRequestPayment:completion:", @"resolveCurrencyAmountForRequestPayment:withCompletion:"], @"prompt": @"How much?" },
            @{ @"key": @"note", @"kind": @"string", @"sel": @[@"resolveNoteForRequestPayment:withCompletion:"], @"prompt": @"What’s it for?" } ],
        @"INListRideOptionsIntent": @[
            @{ @"key": @"pickupLocation", @"kind": @"placemark", @"sel": @[@"resolvePickupLocationForListRideOptions:withCompletion:"], @"prompt": @"Where do you want to be picked up?" },
            @{ @"key": @"dropOffLocation", @"kind": @"placemark", @"sel": @[@"resolveDropOffLocationForListRideOptions:withCompletion:"], @"prompt": @"Where do you want to go?" } ],
        @"INRequestRideIntent": @[
            @{ @"key": @"pickupLocation", @"kind": @"placemark", @"sel": @[@"resolvePickupLocationForRequestRide:withCompletion:"], @"prompt": @"Where do you want to be picked up?" },
            @{ @"key": @"dropOffLocation", @"kind": @"placemark", @"sel": @[@"resolveDropOffLocationForRequestRide:withCompletion:"], @"prompt": @"Where do you want to go?" },
            @{ @"key": @"rideOptionName", @"kind": @"speakable", @"sel": @[@"resolveRideOptionNameForRequestRide:withCompletion:"], @"prompt": @"Which kind of ride?" },
            @{ @"key": @"partySize", @"kind": @"integer", @"sel": @[@"resolvePartySizeForRequestRide:withCompletion:"], @"prompt": @"How many people?" },
            @{ @"key": @"scheduledPickupTime", @"kind": @"dateRange", @"sel": @[@"resolveScheduledPickupTimeForRequestRide:withCompletion:"], @"prompt": @"When do you want to be picked up?" } ],
        @"INGetRideStatusIntent": @[],
        @"INCancelRideIntent": @[],
        @"INSendRideFeedbackIntent": @[],
        @"INStartWorkoutIntent": @[
            @{ @"key": @"workoutName", @"kind": @"speakable", @"sel": @[@"resolveWorkoutNameForStartWorkout:withCompletion:"], @"prompt": @"What kind of workout?" },
            @{ @"key": @"goalValue", @"kind": @"double", @"sel": @[@"resolveGoalValueForStartWorkout:withCompletion:"], @"prompt": @"What’s your goal?" },
            @{ @"key": @"workoutGoalUnitType", @"kind": @"goalUnit", @"sel": @[@"resolveWorkoutGoalUnitTypeForStartWorkout:withCompletion:"], @"prompt": @"Miles, kilometers, minutes or calories?" },
            @{ @"key": @"workoutLocationType", @"kind": @"locationType", @"sel": @[@"resolveWorkoutLocationTypeForStartWorkout:withCompletion:"], @"prompt": @"Indoor or outdoor?" },
            @{ @"key": @"isOpenEnded", @"kind": @"bool", @"sel": @[@"resolveIsOpenEndedForStartWorkout:withCompletion:"], @"prompt": @"Open goal?" } ],
        @"INPauseWorkoutIntent": @[ @{ @"key": @"workoutName", @"kind": @"speakable", @"sel": @[@"resolveWorkoutNameForPauseWorkout:withCompletion:"], @"prompt": @"Which workout?" } ],
        @"INResumeWorkoutIntent": @[ @{ @"key": @"workoutName", @"kind": @"speakable", @"sel": @[@"resolveWorkoutNameForResumeWorkout:withCompletion:"], @"prompt": @"Which workout?" } ],
        @"INEndWorkoutIntent": @[ @{ @"key": @"workoutName", @"kind": @"speakable", @"sel": @[@"resolveWorkoutNameForEndWorkout:withCompletion:"], @"prompt": @"Which workout?" } ],
        @"INCancelWorkoutIntent": @[ @{ @"key": @"workoutName", @"kind": @"speakable", @"sel": @[@"resolveWorkoutNameForCancelWorkout:withCompletion:"], @"prompt": @"Which workout?" } ],
        @"INSearchForPhotosIntent": @[
            @{ @"key": @"dateCreated", @"kind": @"dateRange", @"sel": @[@"resolveDateCreatedForSearchForPhotos:withCompletion:"], @"prompt": @"When were they taken?" },
            @{ @"key": @"locationCreated", @"kind": @"placemark", @"sel": @[@"resolveLocationCreatedForSearchForPhotos:withCompletion:"], @"prompt": @"Where were they taken?" },
            @{ @"key": @"albumName", @"kind": @"string", @"sel": @[@"resolveAlbumNameForSearchForPhotos:withCompletion:"], @"prompt": @"Which album?" },
            @{ @"key": @"searchTerms", @"kind": @"strings", @"sel": @[@"resolveSearchTermsForSearchForPhotos:withCompletion:"], @"prompt": @"What are you looking for?" },
            @{ @"key": @"peopleInPhoto", @"kind": @"persons", @"sel": @[@"resolvePeopleInPhotoForSearchForPhotos:withCompletion:"], @"prompt": @"Who’s in them?" } ],
        @"INStartPhotoPlaybackIntent": @[
            @{ @"key": @"dateCreated", @"kind": @"dateRange", @"sel": @[@"resolveDateCreatedForStartPhotoPlayback:withCompletion:"], @"prompt": @"When were they taken?" },
            @{ @"key": @"locationCreated", @"kind": @"placemark", @"sel": @[@"resolveLocationCreatedForStartPhotoPlayback:withCompletion:"], @"prompt": @"Where were they taken?" },
            @{ @"key": @"albumName", @"kind": @"string", @"sel": @[@"resolveAlbumNameForStartPhotoPlayback:withCompletion:"], @"prompt": @"Which album?" },
            @{ @"key": @"peopleInPhoto", @"kind": @"persons", @"sel": @[@"resolvePeopleInPhotoForStartPhotoPlayback:withCompletion:"], @"prompt": @"Who’s in them?" } ],
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
static NSString *currency_text(INCurrencyAmount *a);
static BOOL is_placemark(id v) { Class c = NSClassFromString(@"CLPlacemark"); return c && [v isKindOfClass:c]; }
static NSString *place_name(id p) {
    if (!is_placemark(p)) return nil;
    NSString *n = [p valueForKey:@"name"];
    return n.length ? n : [p valueForKey:@"locality"];
}
static NSString *title_of(id v) {
    if ([v isKindOfClass:[INPerson class]]) return [v displayName];
    if (is_placemark(v)) return place_name(v) ?: @"";
    if ([v isKindOfClass:[INCurrencyAmount class]]) return currency_text(v);
    if ([v isKindOfClass:[INPaymentMethod class]]) return [v name] ?: @"";
    if ([v isKindOfClass:[INRideOption class]]) return [v name];
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
    if (is_placemark(v)) { NSString *l = [v valueForKey:@"locality"]; return [l isEqual:place_name(v)] ? @"" : l ?: @""; }
    if ([v isKindOfClass:[INPaymentMethod class]]) return [v identificationHint] ?: @"";
    return @"";
}
/* "$20", "20 dollars", "€4.50", "15": an amount (dollars when no currency is said) */
INCurrencyAmount *isim_in_currency(NSString *text) {
    NSString *t = text.lowercaseString;
    NSDictionary *codes = @{ @"$": @"USD", @"dollar": @"USD", @"€": @"EUR", @"euro": @"EUR", @"£": @"GBP", @"pound": @"GBP", @"¥": @"JPY", @"yen": @"JPY" };
    NSString *code = @"USD";
    for (NSString *k in codes) if ([t containsString:k]) code = codes[k];
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"[0-9]+(?:\\.[0-9]+)?" options:0 error:NULL];
    NSTextCheckingResult *m = [re firstMatchInString:t options:0 range:NSMakeRange(0, t.length)];
    if (!m) return nil;
    return [[INCurrencyAmount alloc] initWithAmount:[NSDecimalNumber decimalNumberWithString:[t substringWithRange:m.range]] currencyCode:code];
}
/* a place by name: CoreLocation's gazetteer (nil without CoreLocation) */
id isim_in_placemark(NSString *name) {
    Class c = NSClassFromString(@"CLPlacemark");
    SEL sel = NSSelectorFromString(@"_isim_placemarkNamed:");
    if (!c || ![c respondsToSelector:sel] || !name.length) return nil;
    return ((id (*)(id, SEL, id))objc_msgSend)(c, sel, name);
}
/* "2023", "this year", "last year", "today", "yesterday", "this month", "last month": a range of days (local time) */
static NSDateComponents *ymd(int y, int m, int d) { NSDateComponents *c = [NSDateComponents new]; c.year = y; c.month = m; c.day = d; return c; }
INDateComponentsRange *isim_in_date_range(NSString *text) {
    NSString *t = text.lowercaseString;
    time_t now = time(NULL);
    struct tm tm; localtime_r(&now, &tm);
    int year = tm.tm_year + 1900, month = tm.tm_mon + 1;
    if ([t isEqualToString:@"today"] || [t isEqualToString:@"yesterday"]) {
        time_t d = [t isEqualToString:@"today"] ? now : now - 86400;
        struct tm x; localtime_r(&d, &x);
        NSDateComponents *c = ymd(x.tm_year + 1900, x.tm_mon + 1, x.tm_mday);
        return [[INDateComponentsRange alloc] initWithStartDateComponents:c endDateComponents:[c copy]];
    }
    if ([t isEqualToString:@"this month"] || [t isEqualToString:@"last month"]) {
        int y = year, m = month;
        if ([t hasPrefix:@"last"]) { m--; if (m == 0) { m = 12; y--; } }
        static const int days[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
        int last = days[m - 1] + (m == 2 && ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0));
        return [[INDateComponentsRange alloc] initWithStartDateComponents:ymd(y, m, 1) endDateComponents:ymd(y, m, last)];
    }
    NSInteger y = [t isEqualToString:@"this year"] ? year : [t isEqualToString:@"last year"] ? year - 1 : t.integerValue;
    if (y < 1900 || y > 3000) return nil;
    return [[INDateComponentsRange alloc] initWithStartDateComponents:ymd((int)y, 1, 1) endDateComponents:ymd((int)y, 12, 31)];
}
/* "mile", "km", "minutes", "calories", …: a workout goal's unit */
INWorkoutGoalUnitType isim_in_goal_unit(NSString *text) {
    NSString *t = text.lowercaseString;
    NSArray *units = @[@[@"inch", @(INWorkoutGoalUnitTypeInch)], @[@"kilometer", @(INWorkoutGoalUnitTypeMeter)], @[@"km", @(INWorkoutGoalUnitTypeMeter)],
                       @[@"meter", @(INWorkoutGoalUnitTypeMeter)], @[@"foot", @(INWorkoutGoalUnitTypeFoot)], @[@"feet", @(INWorkoutGoalUnitTypeFoot)],
                       @[@"mile", @(INWorkoutGoalUnitTypeMile)], @[@"yard", @(INWorkoutGoalUnitTypeYard)], @[@"second", @(INWorkoutGoalUnitTypeSecond)],
                       @[@"minute", @(INWorkoutGoalUnitTypeMinute)], @[@"hour", @(INWorkoutGoalUnitTypeHour)], @[@"kilojoule", @(INWorkoutGoalUnitTypeJoule)],
                       @[@"joule", @(INWorkoutGoalUnitTypeJoule)], @[@"calorie", @(INWorkoutGoalUnitTypeKiloCalorie)], @[@"kcal", @(INWorkoutGoalUnitTypeKiloCalorie)]];
    for (NSArray *u in units) if ([t containsString:u[0]]) return [u[1] integerValue];
    return INWorkoutGoalUnitTypeUnknown;
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
    if ([kind isEqualToString:@"person"]) return [value_from_text(@"persons", text, intent) firstObject];
    if ([kind isEqualToString:@"string"]) return text;
    if ([kind isEqualToString:@"strings"]) {
        NSMutableArray *a = [NSMutableArray array];
        for (NSString *w in [text componentsSeparatedByString:@","]) { NSString *x = [w stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]; if (x.length) [a addObject:x]; }
        return a;
    }
    if ([kind isEqualToString:@"integer"]) {
        NSUInteger w = [@[@"zero", @"one", @"two", @"three", @"four", @"five", @"six", @"seven", @"eight", @"nine", @"ten"] indexOfObject:text.lowercaseString];
        return @(w != NSNotFound ? (NSInteger)w : text.integerValue);
    }
    if ([kind isEqualToString:@"double"]) return @(text.doubleValue);
    if ([kind isEqualToString:@"currency"]) return isim_in_currency(text);
    if ([kind isEqualToString:@"placemark"]) return isim_in_placemark(text);
    if ([kind isEqualToString:@"dateRange"]) return isim_in_date_range(text);
    if ([kind isEqualToString:@"goalUnit"]) return @(isim_in_goal_unit(text));
    if ([kind isEqualToString:@"locationType"]) { NSString *l = text.lowercaseString; return @([l hasPrefix:@"in"] ? INWorkoutLocationTypeIndoor : [l hasPrefix:@"out"] ? INWorkoutLocationTypeOutdoor : INWorkoutLocationTypeUnknown); }
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
    NSString *meaning = isim_in_code_meaning(cls, code);   /* payments, rides, workouts, photos */
    if (meaning) {
        if ([meaning isEqualToString:@"success"] || [meaning isEqualToString:@"ready"] || [meaning isEqualToString:@"inProgress"]) return @"success";
        if ([meaning isEqualToString:@"continueInApp"] || [meaning isEqualToString:@"handleInApp"] || [meaning isEqualToString:@"appLaunch"]) return meaning;
        return @"failure";
    }
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
/* "$20.00 to Anna / For: dinner": a payment Siri reads back */
static NSString *payment_detail(INPerson *who, INCurrencyAmount *amt, NSString *note, INCurrencyAmount *fee, BOOL send) {
    NSMutableArray *lines = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@: %@", send ? @"To" : @"From", who.displayName ?: @""]];
    if (amt) [lines addObject:currency_text(amt)];
    if (note.length) [lines addObject:[@"For: " stringByAppendingString:note]];
    if (fee) [lines addObject:[@"Fee: " stringByAppendingString:currency_text(fee)]];
    return [lines componentsJoinedByString:@"\n"];
}
static NSString *price_text(INPriceRange *p) {
    if (!p) return nil;
    INCurrencyAmount *(^amt)(NSDecimalNumber *) = ^(NSDecimalNumber *n) { return [[INCurrencyAmount alloc] initWithAmount:n currencyCode:p.currencyCode]; };
    if (p.minimumPrice && p.maximumPrice && [p.minimumPrice isEqual:p.maximumPrice]) return currency_text(amt(p.minimumPrice));
    if (p.minimumPrice && p.maximumPrice) return [NSString stringWithFormat:@"%@–%@", currency_text(amt(p.minimumPrice)), currency_text(amt(p.maximumPrice))];
    if (p.minimumPrice) return [currency_text(amt(p.minimumPrice)) stringByAppendingString:@"+"];
    return p.maximumPrice ? [@"up to " stringByAppendingString:currency_text(amt(p.maximumPrice))] : nil;
}
static NSString *minutes_until(NSDate *d) {
    if (!d) return nil;
    long m = lround(d.timeIntervalSinceNow / 60);
    return m <= 0 ? @"now" : [NSString stringWithFormat:@"%ld min", m];
}
/* "Comfort · $18.00–$22.00 · 4 min" */
static NSString *ride_option_line(INRideOption *o) {
    NSMutableArray *a = [NSMutableArray arrayWithObject:o.name];
    if (price_text(o.priceRange)) [a addObject:price_text(o.priceRange)];
    if (o.specialPricing.length) [a addObject:o.specialPricing];
    [a addObject:minutes_until(o.estimatedPickupDate)];
    return [a componentsJoinedByString:@" · "];
}
static NSString *ride_detail(INRideStatus *st) {
    if (!st) return @"";
    NSMutableArray *lines = [NSMutableArray array];
    if (st.rideOption) [lines addObject:st.rideOption.name];
    if (st.driver) [lines addObject:st.driver.rating.length ? [NSString stringWithFormat:@"%@ · %@ ★", st.driver.displayName, st.driver.rating] : st.driver.displayName];
    if (st.vehicle) {
        NSString *car = [[@[st.vehicle.manufacturer ?: @"", st.vehicle.model ?: @""] componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        [lines addObject:st.vehicle.registrationPlate.length ? (car.length ? [NSString stringWithFormat:@"%@ · %@", car, st.vehicle.registrationPlate] : st.vehicle.registrationPlate) : car];
    }
    if (st.estimatedPickupDate && st.phase != INRidePhaseOngoing && st.phase != INRidePhaseCompleted) [lines addObject:[@"Pickup: " stringByAppendingString:minutes_until(st.estimatedPickupDate)]];
    if (st.estimatedDropOffDate && st.phase == INRidePhaseOngoing) [lines addObject:[@"Arrival: " stringByAppendingString:minutes_until(st.estimatedDropOffDate)]];
    if (place_name(st.dropOffLocation)) [lines addObject:[@"To: " stringByAppendingString:place_name(st.dropOffLocation)]];
    return [lines componentsJoinedByString:@"\n"];
}
static NSString *ride_phase_text(INRideStatus *st, BOOL booked) {
    if (st.completionStatus.isCanceled) return @"Your ride was cancelled.";
    switch (st.phase) {
        case INRidePhaseReceived: return booked ? @"OK, I requested your ride." : @"Your ride request was received.";
        case INRidePhaseConfirmed: return st.estimatedPickupDate ? [NSString stringWithFormat:@"Your ride is confirmed. It’ll be there in %@.", minutes_until(st.estimatedPickupDate)] : @"Your ride is confirmed.";
        case INRidePhaseApproachingPickup: return @"Your driver is almost there.";
        case INRidePhasePickup: return @"Your driver has arrived.";
        case INRidePhaseOngoing: return @"You’re on your way.";
        case INRidePhaseCompleted: return @"Your ride is complete.";
        default: return booked ? @"OK, I requested your ride." : @"Here’s your ride.";
    }
}
static NSString *workout_goal(INStartWorkoutIntent *w) {
    NSNumber *g = w.goalValue;
    if (!g || [w.isOpenEnded boolValue]) return nil;
    NSArray *names = @[@"", @"inch", @"meter", @"foot", @"mile", @"yard", @"second", @"minute", @"hour", @"joule", @"calorie"];
    NSString *u = w.workoutGoalUnitType > 0 && w.workoutGoalUnitType < (NSInteger)names.count ? names[w.workoutGoalUnitType] : @"";
    double v = g.doubleValue;
    if (w.workoutGoalUnitType == INWorkoutGoalUnitTypeMeter && v >= 1000) { v /= 1000; u = @"kilometer"; }
    NSString *n = v == floor(v) ? [NSString stringWithFormat:@"%.0f", v] : [NSString stringWithFormat:@"%.1f", v];
    if (!u.length) return n;
    return [NSString stringWithFormat:@"%@ %@%@", n, [u isEqual:@"foot"] && v != 1 ? @"feet" : u, v == 1 || [u isEqual:@"foot"] ? @"" : @"s"];
}
/* "your photos from Apple Park", "your Vacation album", "photos of Anna" */
static NSString *photos_description(INIntent *intent) {
    INSearchForPhotosIntent *p = (INSearchForPhotosIntent *)intent;
    if (p.albumName.length) return [NSString stringWithFormat:@"your %@ album", p.albumName];
    NSMutableString *s = [NSMutableString stringWithString:@"photos"];
    if (p.peopleInPhoto.count) [s appendFormat:@" of %@", person_list(p.peopleInPhoto)];
    else if (p.searchTerms.count) [s appendFormat:@" of %@", [p.searchTerms componentsJoinedByString:@" and "]];
    if (place_name(p.locationCreated)) [s appendFormat:@" from %@", place_name(p.locationCreated)];
    if (p.dateCreated.startDateComponents.year != NSDateComponentUndefined && p.dateCreated.startDateComponents.year > 0)
        [s appendFormat:@" from %ld", (long)p.dateCreated.startDateComponents.year];
    return s;
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
    if ([cls isEqualToString:@"INSendPaymentIntent"] || [cls isEqualToString:@"INRequestPaymentIntent"]) {
        BOOL send = [cls isEqualToString:@"INSendPaymentIntent"];
        INPaymentRecord *rec = [(id)r paymentRecord];
        INPerson *who = send ? (rec.payee ?: [(INSendPaymentIntent *)intent payee]) : (rec.payer ?: [(INRequestPaymentIntent *)intent payer]);
        INCurrencyAmount *amt = rec.currencyAmount ?: [(id)intent currencyAmount];
        *detail = payment_detail(who, amt, rec.note ?: [(id)intent note], rec.feeAmount, send);
        return [NSString stringWithFormat:send ? @"OK, I sent %@ to %@." : @"OK, I requested %@ from %@.", amt ? currency_text(amt) : @"the money", who.displayName ?: @"them"];
    }
    if ([cls isEqualToString:@"INRequestRideIntent"] || [cls isEqualToString:@"INGetRideStatusIntent"]) {
        INRideStatus *st = [(id)r rideStatus];
        *detail = ride_detail(st);
        if ([cls isEqualToString:@"INRequestRideIntent"] && !st) {
            NSString *to = place_name([(INRequestRideIntent *)intent dropOffLocation]);
            return to.length ? [NSString stringWithFormat:@"OK, I requested a ride to %@.", to] : @"OK, I requested your ride.";
        }
        return ride_phase_text(st, [cls isEqualToString:@"INRequestRideIntent"]);
    }
    if ([cls isEqualToString:@"INListRideOptionsIntent"]) {
        NSMutableArray *lines = [NSMutableArray array];
        for (INRideOption *o in [(INListRideOptionsIntentResponse *)r rideOptions]) [lines addObject:ride_option_line(o)];
        *detail = [lines componentsJoinedByString:@"\n"];
        return [NSString stringWithFormat:@"Here are your options in %@.", app];
    }
    if ([cls isEqualToString:@"INCancelRideIntent"]) {
        INCurrencyAmount *fee = [(INCancelRideIntentResponse *)r cancellationFee];
        return fee ? [NSString stringWithFormat:@"OK, I cancelled your ride. There’s a %@ cancellation fee.", currency_text(fee)] : @"OK, I cancelled your ride.";
    }
    if ([cls isEqualToString:@"INSendRideFeedbackIntent"]) {
        INSendRideFeedbackIntent *f = (INSendRideFeedbackIntent *)intent;
        NSMutableArray *lines = [NSMutableArray array];
        if (f.rating) [lines addObject:[NSString stringWithFormat:@"Rating: %@ ★", f.rating]];
        if (f.tip) [lines addObject:[@"Tip: " stringByAppendingString:currency_text(f.tip)]];
        *detail = [lines componentsJoinedByString:@"\n"];
        return @"Thanks for your feedback.";
    }
    if ([cls hasSuffix:@"WorkoutIntent"]) {
        NSString *name = [(id)intent workoutName].spokenPhrase.lowercaseString;
        NSString *what = name.length ? [@"your " stringByAppendingString:name] : @"your workout";
        if ([cls isEqualToString:@"INStartWorkoutIntent"]) {
            INStartWorkoutIntent *w = (INStartWorkoutIntent *)intent;
            NSString *goal = workout_goal(w);
            return [NSString stringWithFormat:@"OK, starting %@%@%@.", w.workoutLocationType == INWorkoutLocationTypeIndoor ? @"an indoor " : w.workoutLocationType == INWorkoutLocationTypeOutdoor ? @"an outdoor " : @"",
                    w.workoutLocationType == INWorkoutLocationTypeUnknown ? what : (name.length ? name : @"workout"), goal.length ? [@" with a goal of " stringByAppendingString:goal] : @""];
        }
        NSString *verb = [cls isEqualToString:@"INPauseWorkoutIntent"] ? @"paused" : [cls isEqualToString:@"INResumeWorkoutIntent"] ? @"resumed"
                       : [cls isEqualToString:@"INEndWorkoutIntent"] ? @"ended" : @"cancelled";
        return [NSString stringWithFormat:@"OK, I %@ %@.", verb, what];
    }
    if ([cls isEqualToString:@"INSearchForPhotosIntent"] || [cls isEqualToString:@"INStartPhotoPlaybackIntent"]) {
        NSNumber *n = [(id)r searchResultsCount];
        NSString *what = photos_description(intent);
        if ([cls isEqualToString:@"INStartPhotoPlaybackIntent"]) return [NSString stringWithFormat:@"OK, here’s a slideshow of %@ in %@.", what, app];
        if (n && n.integerValue == 0) return [NSString stringWithFormat:@"I didn’t find any %@ in %@.", what, app];
        if (n && n.integerValue == 1 && [what hasPrefix:@"photos"]) what = [@"photo" stringByAppendingString:[what substringFromIndex:6]];
        return n ? [NSString stringWithFormat:@"I found %ld %@ in %@.", (long)n.integerValue, what, app] : [NSString stringWithFormat:@"Here are %@ in %@.", what, app];
    }
    return @"Done.";
}
/* why it failed, in these domains */
static NSString *failure_dialog(NSString *cls, NSInteger code, NSString *app) {
    if ([cls isEqualToString:@"INSendPaymentIntent"] || [cls isEqualToString:@"INRequestPaymentIntent"]) {
        BOOL send = [cls isEqualToString:@"INSendPaymentIntent"];
        NSInteger c = send || code < 10 ? code : code + 1;     /* the request codes lack InsufficientFunds */
        switch (c) {
            case 6: return [NSString stringWithFormat:@"You’ll need to verify your account in %@ first.", app];
            case 7: return [NSString stringWithFormat:@"Sorry, that amount is too small for %@.", app];
            case 8: return [NSString stringWithFormat:@"Sorry, that amount is too large for %@.", app];
            case 9: return [NSString stringWithFormat:@"Sorry, %@ doesn’t support that currency.", app];
            case 10: return [NSString stringWithFormat:@"Sorry, you don’t have enough money in %@.", app];
            case 11: return [NSString stringWithFormat:@"You’ll need to add a bank account in %@ first.", app];
            case 12: return [NSString stringWithFormat:@"Sorry, you can’t use %@ for that.", app];
            case 13: return [NSString stringWithFormat:@"You’ll need to accept the terms and conditions in %@ first.", app];
        }
    }
    if ([cls isEqualToString:@"INStartWorkoutIntent"]) {
        if (code == 5) return [NSString stringWithFormat:@"You already have a workout in progress in %@.", app];
        if (code == 6) return [NSString stringWithFormat:@"Sorry, %@ doesn’t have that workout.", app];
    }
    if ([cls hasSuffix:@"WorkoutIntent"] && code == 5) return [NSString stringWithFormat:@"Sorry, you don’t have a workout in progress in %@.", app];
    if ([cls isEqualToString:@"INListRideOptionsIntent"] && code == 10) return @"You’ll need to rate your last ride first.";
    if (([cls isEqualToString:@"INSearchForPhotosIntent"] || [cls isEqualToString:@"INStartPhotoPlaybackIntent"]) && code == 5)
        return [NSString stringWithFormat:@"You’ll need to set up %@ first.", app];
    return nil;
}

/* the device's simulated location as a place (nil without CoreLocation) */
static id current_place(void) {
    Class m = NSClassFromString(@"CLLocationManager"), p = NSClassFromString(@"CLPlacemark");
    SEL loc = NSSelectorFromString(@"_isim_simulatedLocation"), make = NSSelectorFromString(@"placemarkWithLocation:name:postalAddress:");
    if (![m respondsToSelector:loc] || ![p respondsToSelector:make]) return nil;
    id here = ((id (*)(id, SEL))objc_msgSend)(m, loc);
    return here ? ((id (*)(id, SEL, id, id, id))objc_msgSend)(p, make, here, @"Current Location", nil) : nil;
}
/* INGetRideStatusIntentResponseObserver: the app's updates while Siri shows the ride (update-N.plist in the run dir) */
@interface _INRideStatusObserver : NSObject <INGetRideStatusIntentResponseObserver>
@property (nonatomic, copy) NSString *dir;
@property (nonatomic) NSInteger n;
@end
@implementation _INRideStatusObserver
- (void)getRideStatusResponseDidUpdate:(INGetRideStatusIntentResponse *)response {
    dispatch_async(dispatch_get_main_queue(), ^{
        INRideStatus *st = response.rideStatus;
        NSString *dialog = ride_phase_text(st, NO), *detail = ride_detail(st);
        self.n++;
        [@{ @"dialog": dialog, @"detail": detail, @"phase": @(st.phase) } writeToFile:[self.dir stringByAppendingPathComponent:[NSString stringWithFormat:@"update-%ld.plist", (long)self.n]] atomically:YES];
        NSLog(@"isim Intents: ride status update %ld: “%@”", (long)self.n, dialog);
    });
}
@end

/* ---------------- the conversation ---------------- */
@interface _INConversation : NSObject
@property (nonatomic, strong) _INRunChannel *channel;
@property (nonatomic, strong) INIntent *intent;
@property (nonatomic, strong) id handler;
@property (nonatomic, copy) NSString *app;
@property (nonatomic, copy) void (^done)(void);
@property (nonatomic) NSInteger rounds;
@property (nonatomic) BOOL listedOptions;
@property (nonatomic, strong) id rideObserver;
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
    if (([cls isEqualToString:@"INRequestRideIntent"] || [cls isEqualToString:@"INListRideOptionsIntent"]) && ![self.intent _get:@"pickupLocation"]) {
        id here = current_place();                          /* as on iOS, a ride starts where the device is */
        if (here) { [self.intent _set:here forKey:@"pickupLocation"]; NSLog(@"isim Intents: pickup at the current location"); }
    }
    [self resolve:params index:0];
}
- (void)resolve:(NSArray *)params index:(NSUInteger)i {
    if (i >= params.count) {
        if ([self.intent isKindOfClass:[INRequestRideIntent class]] && ![self.intent _get:@"rideOptionName"] && !self.listedOptions &&
            [self.handler respondsToSelector:@selector(handleListRideOptions:completion:)]) { [self listRideOptions:params]; return; }
        [self confirm]; return;
    }
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
/* booking a ride: like iOS, Siri first lists the app's ride options (INListRideOptionsIntent) and asks which one */
- (void)listRideOptions:(NSArray *)params {
    self.listedOptions = YES;
    INRequestRideIntent *ride = (INRequestRideIntent *)self.intent;
    INListRideOptionsIntent *list = [[INListRideOptionsIntent alloc] initWithPickupLocation:ride.pickupLocation dropOffLocation:ride.dropOffLocation];
    __weak _INConversation *weakSelf = self;
    NSLog(@"isim Intents: listing ride options");
    [self.handler handleListRideOptions:list completion:^(INListRideOptionsIntentResponse *r) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _INConversation *me = weakSelf;
            if (!me) return;
            NSString *outcome = outcome_of(@"INListRideOptionsIntent", r.code);
            NSArray *opts = r.rideOptions ?: @[];
            NSLog(@"isim Intents: %lu ride option(s), code %ld", (unsigned long)opts.count, (long)r.code);
            if (![outcome isEqualToString:@"success"]) { [me respond:r forIntent:list]; return; }
            if (r.paymentMethods.count && !ride.paymentMethod) [me.intent _set:r.paymentMethods.firstObject forKey:@"paymentMethod"];
            if (opts.count <= 1) {
                if (opts.count) [me.intent _set:[[INSpeakableString alloc] initWithSpokenPhrase:[opts.firstObject name]] forKey:@"rideOptionName"];
                [me confirm]; return;
            }
            NSMutableArray *shown = [NSMutableArray array];
            for (INRideOption *o in opts) {
                NSMutableArray *sub = [NSMutableArray array];
                if (price_text(o.priceRange)) [sub addObject:price_text(o.priceRange)];
                [sub addObject:[minutes_until(o.estimatedPickupDate) stringByAppendingString:@" away"]];
                [shown addObject:@{ @"title": o.name, @"subtitle": [sub componentsJoinedByString:@" · "] }];
            }
            [me.channel ask:@{ @"type": @"choice", @"param": @"rideOptionName", @"prompt": @"Which ride?", @"options": shown } reply:^(NSDictionary *a) {
                NSInteger idx = [a[@"kind"] isEqual:@"option"] ? [a[@"index"] integerValue] : -1;
                if ([a[@"kind"] isEqual:@"text"])                /* the option said by name */
                    for (NSUInteger k = 0; k < opts.count; k++) {
                        if ([[opts[k] name] caseInsensitiveCompare:a[@"text"] ?: @""] == NSOrderedSame) idx = (NSInteger)k;
                    }
                if (idx < 0 || idx >= (NSInteger)opts.count) { [me cancelled]; return; }
                [me.intent _set:[[INSpeakableString alloc] initWithSpokenPhrase:[opts[idx] name]] forKey:@"rideOptionName"];
                [me resolve:params index:2];                  /* the app resolves the chosen option */
            }];
        });
    }];
}
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
    NSString *meaning = r ? isim_in_code_meaning(cls, code) : nil;
    BOOL failed = meaning ? [meaning isEqualToString:@"failure"] || [meaning isEqualToString:@"appLaunch"]
                : [cls isEqualToString:@"INPlayMediaIntent"] ? code >= 6 : [cls isEqualToString:@"INAddMediaIntent"] || [cls isEqualToString:@"INSearchForMediaIntent"] ? code >= 5 : code >= 4;
    if (failed) { [self respond:r]; return; }
    if ([cls isEqualToString:@"INSendPaymentIntent"] || [cls isEqualToString:@"INRequestPaymentIntent"]) {   /* iOS confirms a payment */
        BOOL send = [cls isEqualToString:@"INSendPaymentIntent"];
        INPaymentRecord *rec = [(id)r paymentRecord];
        INPerson *who = send ? [(INSendPaymentIntent *)self.intent payee] : [(INRequestPaymentIntent *)self.intent payer];
        INCurrencyAmount *amt = [(id)self.intent currencyAmount];
        NSString *prompt = [NSString stringWithFormat:send ? @"Send %@ to %@?" : @"Request %@ from %@?", amt ? currency_text(amt) : @"money", who.displayName ?: @"them"];
        [self.channel ask:@{ @"type": @"confirm", @"prompt": prompt, @"action": send ? @"Send" : @"Request", @"cancel": @"Cancel",
                             @"detail": payment_detail(who, amt, [(id)self.intent note], rec.feeAmount, send),
                             @"interaction": [[[INInteraction alloc] initWithIntent:self.intent response:r] _isim_plist] }
                    reply:^(NSDictionary *a) {
            if (![a[@"kind"] isEqual:@"confirm"]) { [self end:@{ @"dialog": send ? @"OK, I won’t send it." : @"OK, I won’t request it.", @"outcome": @"cancelled" }]; return; }
            [self handle];
        }];
        return;
    }
    if ([cls isEqualToString:@"INRequestRideIntent"]) {        /* and a ride, with what the app's confirm said */
        INRequestRideIntent *ride = (INRequestRideIntent *)self.intent;
        INRideStatus *st = [(INRequestRideIntentResponse *)r rideStatus];
        NSString *option = ride.rideOptionName.spokenPhrase, *to = place_name(ride.dropOffLocation);
        NSMutableArray *lines = [NSMutableArray array];
        if (st.rideOption) [lines addObject:ride_option_line(st.rideOption)];
        if (place_name(ride.pickupLocation)) [lines addObject:[@"From: " stringByAppendingString:place_name(ride.pickupLocation)]];
        if (to) [lines addObject:[@"To: " stringByAppendingString:to]];
        if (ride.partySize) [lines addObject:[NSString stringWithFormat:@"%@ %@", ride.partySize, ride.partySize.integerValue == 1 ? @"person" : @"people"]];
        if (ride.paymentMethod.name) [lines addObject:[@"Pay with: " stringByAppendingString:ride.paymentMethod.name]];
        NSString *prompt = [NSString stringWithFormat:@"Request %@%@?", option.length ? [NSString stringWithFormat:@"a %@ ride", option] : @"this ride", to ? [@" to " stringByAppendingString:to] : @""];
        [self.channel ask:@{ @"type": @"confirm", @"prompt": prompt, @"action": @"Request", @"cancel": @"Cancel", @"detail": [lines componentsJoinedByString:@"\n"],
                             @"interaction": [[[INInteraction alloc] initWithIntent:self.intent response:r] _isim_plist] }
                    reply:^(NSDictionary *a) {
            if (![a[@"kind"] isEqual:@"confirm"]) { [self end:@{ @"dialog": @"OK, I won’t request it.", @"outcome": @"cancelled" }]; return; }
            [self handle];
        }];
        return;
    }
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
- (void)respond:(INIntentResponse *)r { [self respond:r forIntent:self.intent]; }
- (void)respond:(INIntentResponse *)r forIntent:(INIntent *)intent {
    NSString *cls = NSStringFromClass(intent.class);
    NSInteger code = [self codeOf:r];
    NSString *outcome = outcome_of(cls, code), *detail = @"";
    NSLog(@"isim Intents: %@ response code %ld (%@)", cls, (long)code, outcome);
    INInteraction *interaction = [[INInteraction alloc] initWithIntent:intent response:r];
    interaction.direction = INInteractionDirectionOutgoing;
    NSMutableDictionary *res = [@{ @"outcome": outcome, @"code": @(code), @"interaction": [interaction _isim_plist] } mutableCopy];
    NSDictionary *cc = custom_code(cls, code);
    if (cc && custom_dialog(r, cc).length) res[@"dialog"] = custom_dialog(r, cc);
    else if ([outcome isEqualToString:@"success"]) res[@"dialog"] = success_dialog(intent, r, self.app, &detail);
    else if ([outcome isEqualToString:@"continueInApp"]) res[@"dialog"] = [cls isEqualToString:@"INStartCallIntent"] || [cls hasSuffix:@"PhotosIntent"] || [cls hasSuffix:@"PhotoPlaybackIntent"] || [cls hasSuffix:@"WorkoutIntent"]
                                                                          ? success_dialog(intent, r, self.app, &detail) : [NSString stringWithFormat:@"Opening %@…", self.app];
    else if ([outcome isEqualToString:@"appLaunch"]) res[@"dialog"] = failure_dialog(cls, code, self.app) ?: [NSString stringWithFormat:@"You’ll need to continue in %@.", self.app];
    else if ([outcome isEqualToString:@"handleInApp"]) res[@"dialog"] = success_dialog(intent, r, self.app, &detail);
    else if (failure_dialog(cls, code, self.app)) res[@"dialog"] = failure_dialog(cls, code, self.app);
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
    if ([cls isEqualToString:@"INGetRideStatusIntent"] && [outcome isEqualToString:@"success"] && [self.handler respondsToSelector:@selector(startSendingUpdatesForGetRideStatus:toObserver:)]) {
        /* the app's updates while Siri shows the ride: for 8 seconds (SBSiri reads update-N.plist) */
        _INRideStatusObserver *o = [_INRideStatusObserver new]; o.dir = self.channel.dir;
        self.rideObserver = o; res[@"updates"] = @YES;
        id handler = self.handler; INIntent *it = intent;
        void (^done)(void) = self.done; self.done = nil;
        [self end:res];
        NSLog(@"isim Intents: sending ride status updates");
        [handler startSendingUpdatesForGetRideStatus:(INGetRideStatusIntent *)it toObserver:o];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([handler respondsToSelector:@selector(stopSendingUpdatesForGetRideStatus:)]) [handler stopSendingUpdatesForGetRideStatus:(INGetRideStatusIntent *)it];
            NSLog(@"isim Intents: stopped ride status updates");
            self.rideObserver = nil;
            if (done) done();
        });
        return;
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
