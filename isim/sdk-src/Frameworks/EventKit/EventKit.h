#pragma once
/* isim EventKit for Objective-C: the classes are the EventKit Swift overlay's (EventKit.framework re-exports
   libswiftEventKit.dylib), on the same device calendar and reminders as Swift, with the same permission prompts
   (full or write-only access). Swift uses the overlay; these declarations are hidden from Swift. The classes are not
   subclassable from Objective-C. Not from Objective-C yet: attendees, structured locations, virtual conferences. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class EKEventStore, EKCalendar, EKSource;

typedef NS_ENUM(NSUInteger, EKEntityType) { EKEntityTypeEvent = 0, EKEntityTypeReminder = 1 };
typedef NS_OPTIONS(NSUInteger, EKEntityMask) { EKEntityMaskEvent = 1 << EKEntityTypeEvent, EKEntityMaskReminder = 1 << EKEntityTypeReminder };
typedef NS_ENUM(NSInteger, EKAuthorizationStatus) {
    EKAuthorizationStatusNotDetermined = 0, EKAuthorizationStatusRestricted, EKAuthorizationStatusDenied, EKAuthorizationStatusFullAccess,
    EKAuthorizationStatusWriteOnly,
    EKAuthorizationStatusAuthorized API_DEPRECATED_WITH_REPLACEMENT("EKAuthorizationStatusFullAccess", ios(6.0, 17.0)) = EKAuthorizationStatusFullAccess,
};
typedef NS_ENUM(NSInteger, EKSpan) { EKSpanThisEvent = 0, EKSpanFutureEvents };
typedef NS_ENUM(NSInteger, EKCalendarType) {
    EKCalendarTypeLocal = 0, EKCalendarTypeCalDAV, EKCalendarTypeExchange, EKCalendarTypeSubscription, EKCalendarTypeBirthday,
};
typedef NS_ENUM(NSInteger, EKSourceType) {
    EKSourceTypeLocal = 0, EKSourceTypeExchange, EKSourceTypeCalDAV, EKSourceTypeMobileMe, EKSourceTypeSubscribed, EKSourceTypeBirthdays,
};
typedef NS_ENUM(NSInteger, EKEventAvailability) {
    EKEventAvailabilityNotSupported = -1, EKEventAvailabilityBusy = 0, EKEventAvailabilityFree, EKEventAvailabilityTentative,
    EKEventAvailabilityUnavailable,
};
typedef NS_ENUM(NSInteger, EKEventStatus) { EKEventStatusNone = 0, EKEventStatusConfirmed, EKEventStatusTentative, EKEventStatusCanceled };
typedef NS_ENUM(NSInteger, EKRecurrenceFrequency) {
    EKRecurrenceFrequencyDaily = 0, EKRecurrenceFrequencyWeekly, EKRecurrenceFrequencyMonthly, EKRecurrenceFrequencyYearly,
};
typedef NS_ENUM(NSUInteger, EKReminderPriority) { EKReminderPriorityNone = 0, EKReminderPriorityHigh = 1, EKReminderPriorityMedium = 5, EKReminderPriorityLow = 9 };

FOUNDATION_EXPORT NSErrorDomain const EKErrorDomain;
typedef NS_ENUM(NSInteger, EKErrorCode) {
    EKErrorEventNotMutable = 0, EKErrorNoCalendar, EKErrorNoStartDate, EKErrorNoEndDate, EKErrorDatesInverted, EKErrorInternalFailure,
    EKErrorCalendarReadOnly, EKErrorDurationGreaterThanRecurrence, EKErrorAlarmGreaterThanRecurrence, EKErrorStartDateTooFarInFuture,
    EKErrorStartDateCollidesWithOtherOccurrence, EKErrorObjectBelongsToDifferentStore, EKErrorInvitesCannotBeMoved, EKErrorInvalidSpan,
    EKErrorCalendarHasNoSource, EKErrorCalendarSourceCannotBeModified, EKErrorCalendarIsImmutable, EKErrorSourceDoesNotAllowCalendarAddDelete,
    EKErrorRecurringReminderRequiresDueDate, EKErrorStructuredLocationsNotSupported, EKErrorReminderLocationsNotSupported,
    EKErrorAlarmProximityNotSupported, EKErrorCalendarDoesNotAllowEvents, EKErrorCalendarDoesNotAllowReminders,
    EKErrorSourceDoesNotAllowReminders, EKErrorSourceDoesNotAllowEvents, EKErrorPriorityIsInvalid, EKErrorInvalidEntityType,
    EKErrorProcedureAlarmsNotMutable, EKErrorEventStoreNotAuthorized, EKErrorOSNotSupported,
};
FOUNDATION_EXPORT NSString * const EKEventStoreChangedNotification;

@interface EKObject : NSObject
@property (nonatomic, readonly) BOOL hasChanges;
- (BOOL)isNew;
- (void)reset;
- (void)rollback;
- (BOOL)refresh;
@end

@interface EKSource : EKObject
@property (nonatomic, readonly) NSString *sourceIdentifier;
@property (nonatomic, readonly) EKSourceType sourceType;
@property (nonatomic, readonly) NSString *title;
- (NSSet<EKCalendar *> *)calendarsForEntityType:(EKEntityType)entityType;
@end

@interface EKCalendar : EKObject
+ (EKCalendar *)calendarForEntityType:(EKEntityType)entityType eventStore:(EKEventStore *)eventStore;
@property (nonatomic, readonly) NSString *calendarIdentifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, readonly) EKCalendarType type;
@property (nonatomic, readonly) BOOL allowsContentModifications;
@property (nonatomic, readonly, getter=isSubscribed) BOOL subscribed;
@property (nonatomic, readonly, getter=isImmutable) BOOL immutable;
@property (null_unspecified, nonatomic, strong) EKSource *source;
@property (nonatomic, readonly) EKEntityMask allowedEntityTypes;
@end

@interface EKAlarm : EKObject <NSCopying>
+ (EKAlarm *)alarmWithAbsoluteDate:(NSDate *)date;
+ (EKAlarm *)alarmWithRelativeOffset:(NSTimeInterval)offset;
@property (nonatomic) NSTimeInterval relativeOffset;
@property (nonatomic, copy, nullable) NSDate *absoluteDate;
@end

@interface EKRecurrenceEnd : NSObject <NSCopying>
+ (instancetype)recurrenceEndWithEndDate:(NSDate *)endDate;
+ (instancetype)recurrenceEndWithOccurrenceCount:(NSUInteger)occurrenceCount;
@property (nonatomic, readonly, nullable) NSDate *endDate;
@property (nonatomic, readonly) NSUInteger occurrenceCount;
@end
@interface EKRecurrenceRule : EKObject <NSCopying>
- (instancetype)initRecurrenceWithFrequency:(EKRecurrenceFrequency)type interval:(NSInteger)interval end:(nullable EKRecurrenceEnd *)end;
@property (nonatomic, readonly) EKRecurrenceFrequency frequency;
@property (nonatomic, readonly) NSInteger interval;
@property (nonatomic, copy, nullable) EKRecurrenceEnd *recurrenceEnd;
@end

@interface EKCalendarItem : EKObject
@property (nonatomic, readonly) NSString *calendarItemIdentifier;
@property (nonatomic, readonly, null_unspecified) NSString *calendarItemExternalIdentifier;
@property (nonatomic, strong, null_unspecified) EKCalendar *calendar;
@property (nonatomic, copy, null_unspecified) NSString *title;
@property (nonatomic, copy, nullable) NSString *location;
@property (nonatomic, copy, nullable) NSString *notes;
@property (nonatomic, copy, nullable) NSURL *URL;
@property (nonatomic, copy, nullable) NSTimeZone *timeZone;
@property (nonatomic, readonly) BOOL hasNotes;
@property (nonatomic, readonly) BOOL hasAlarms;
@property (nonatomic, readonly) BOOL hasRecurrenceRules;
@property (nonatomic, readonly, nullable) NSDate *creationDate;
@property (nonatomic, readonly, nullable) NSDate *lastModifiedDate;
@property (nonatomic, copy, nullable) NSArray<EKAlarm *> *alarms;
- (void)addAlarm:(EKAlarm *)alarm;
- (void)removeAlarm:(EKAlarm *)alarm;
@property (nonatomic, copy, nullable) NSArray<EKRecurrenceRule *> *recurrenceRules;
- (void)addRecurrenceRule:(EKRecurrenceRule *)rule;
- (void)removeRecurrenceRule:(EKRecurrenceRule *)rule;
@end

@interface EKEvent : EKCalendarItem
+ (EKEvent *)eventWithEventStore:(EKEventStore *)eventStore;
@property (nonatomic, readonly, null_unspecified) NSString *eventIdentifier;
@property (nonatomic, getter=isAllDay) BOOL allDay;
@property (nonatomic, copy, null_unspecified) NSDate *startDate;
@property (nonatomic, copy, null_unspecified) NSDate *endDate;
@property (nonatomic) EKEventAvailability availability;
@property (nonatomic, readonly) EKEventStatus status;
@property (nonatomic, readonly) BOOL isDetached;
@property (nonatomic, readonly, null_unspecified) NSDate *occurrenceDate;
- (NSComparisonResult)compareStartDateWithEvent:(EKEvent *)other;
@end

@interface EKReminder : EKCalendarItem
+ (EKReminder *)reminderWithEventStore:(EKEventStore *)eventStore;
@property (nonatomic, copy, nullable) NSDateComponents *startDateComponents;
@property (nonatomic, copy, nullable) NSDateComponents *dueDateComponents;
@property (nonatomic, getter=isCompleted) BOOL completed;
@property (nonatomic, copy, nullable) NSDate *completionDate;
@property (nonatomic) NSUInteger priority;
@end

typedef void (^EKEventStoreRequestAccessCompletionHandler)(BOOL granted, NSError * _Nullable error);
typedef void (^EKEventSearchCallback)(EKEvent *event, BOOL *stop);
@interface EKEventStore : NSObject
+ (EKAuthorizationStatus)authorizationStatusForEntityType:(EKEntityType)entityType;
- (instancetype)init;
@property (nonatomic, readonly) NSString *eventStoreIdentifier;
- (void)requestFullAccessToEventsWithCompletion:(EKEventStoreRequestAccessCompletionHandler)completion;
- (void)requestWriteOnlyAccessToEventsWithCompletion:(EKEventStoreRequestAccessCompletionHandler)completion;
- (void)requestFullAccessToRemindersWithCompletion:(EKEventStoreRequestAccessCompletionHandler)completion;
- (void)requestAccessToEntityType:(EKEntityType)entityType completion:(EKEventStoreRequestAccessCompletionHandler)completion
    API_DEPRECATED("use -requestFullAccessToEventsWithCompletion:, -requestWriteOnlyAccessToEventsWithCompletion: or -requestFullAccessToRemindersWithCompletion:", ios(6.0, 17.0));
@property (nonatomic, readonly) NSArray<EKSource *> *sources;
- (NSArray<EKCalendar *> *)calendarsForEntityType:(EKEntityType)entityType;
@property (nullable, nonatomic, readonly) EKCalendar *defaultCalendarForNewEvents;
- (nullable EKCalendar *)defaultCalendarForNewReminders;
- (nullable EKCalendar *)calendarWithIdentifier:(NSString *)identifier;
- (BOOL)saveCalendar:(EKCalendar *)calendar commit:(BOOL)commit error:(NSError **)error;
- (BOOL)removeCalendar:(EKCalendar *)calendar commit:(BOOL)commit error:(NSError **)error;
- (BOOL)saveEvent:(EKEvent *)event span:(EKSpan)span error:(NSError **)error;
- (BOOL)saveEvent:(EKEvent *)event span:(EKSpan)span commit:(BOOL)commit error:(NSError **)error;
- (BOOL)removeEvent:(EKEvent *)event span:(EKSpan)span error:(NSError **)error;
- (BOOL)removeEvent:(EKEvent *)event span:(EKSpan)span commit:(BOOL)commit error:(NSError **)error;
- (BOOL)saveReminder:(EKReminder *)reminder commit:(BOOL)commit error:(NSError **)error;
- (BOOL)removeReminder:(EKReminder *)reminder commit:(BOOL)commit error:(NSError **)error;
- (BOOL)commit:(NSError **)error;
- (void)reset;
- (void)refreshSourcesIfNecessary;
- (nullable EKCalendarItem *)calendarItemWithIdentifier:(NSString *)identifier;
- (nullable EKEvent *)eventWithIdentifier:(NSString *)identifier;
- (NSPredicate *)predicateForEventsWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate calendars:(nullable NSArray<EKCalendar *> *)calendars;
- (NSArray<EKEvent *> *)eventsMatchingPredicate:(NSPredicate *)predicate;
- (void)enumerateEventsMatchingPredicate:(NSPredicate *)predicate usingBlock:(EKEventSearchCallback)block;
- (NSPredicate *)predicateForRemindersInCalendars:(nullable NSArray<EKCalendar *> *)calendars;
- (NSPredicate *)predicateForIncompleteRemindersWithDueDateStarting:(nullable NSDate *)startDate ending:(nullable NSDate *)endDate
                                                          calendars:(nullable NSArray<EKCalendar *> *)calendars;
- (NSPredicate *)predicateForCompletedRemindersWithCompletionDateStarting:(nullable NSDate *)startDate ending:(nullable NSDate *)endDate
                                                                calendars:(nullable NSArray<EKCalendar *> *)calendars;
- (id)fetchRemindersMatchingPredicate:(NSPredicate *)predicate completion:(void (^)(NSArray<EKReminder *> * _Nullable reminders))completion;
- (void)cancelFetchRequest:(id)fetchIdentifier;
@end

NS_ASSUME_NONNULL_END
#endif
