#pragma once
/* isim EventKit for Objective-C: the classes are the EventKit Swift overlay's (EventKit.framework re-exports
   libswiftEventKit.dylib), on the same device calendar and reminders as Swift, with the same permission prompts
   (full or write-only access). Swift uses the overlay; these declarations are hidden from Swift. The classes are not
   subclassable from Objective-C. Not from Objective-C yet: virtual conferences. */
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class EKEventStore, EKCalendar, EKSource, EKStructuredLocation, EKParticipant, MKMapItem;

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

typedef NS_ENUM(NSInteger, EKAlarmProximity) { EKAlarmProximityNone = 0, EKAlarmProximityEnter, EKAlarmProximityLeave };
typedef NS_ENUM(NSInteger, EKAlarmType) { EKAlarmTypeDisplay = 0, EKAlarmTypeAudio, EKAlarmTypeProcedure, EKAlarmTypeEmail };
typedef NS_ENUM(NSInteger, EKWeekday) {
    EKWeekdaySunday = 1, EKWeekdayMonday, EKWeekdayTuesday, EKWeekdayWednesday, EKWeekdayThursday, EKWeekdayFriday, EKWeekdaySaturday,
};
typedef NS_ENUM(NSInteger, EKParticipantStatus) {
    EKParticipantStatusUnknown = 0, EKParticipantStatusPending, EKParticipantStatusAccepted, EKParticipantStatusDeclined,
    EKParticipantStatusTentative, EKParticipantStatusDelegated, EKParticipantStatusCompleted, EKParticipantStatusInProcess,
};
typedef NS_ENUM(NSInteger, EKParticipantRole) {
    EKParticipantRoleUnknown = 0, EKParticipantRoleRequired, EKParticipantRoleOptional, EKParticipantRoleChair, EKParticipantRoleNonParticipant,
};
typedef NS_ENUM(NSInteger, EKParticipantType) {
    EKParticipantTypeUnknown = 0, EKParticipantTypePerson, EKParticipantTypeRoom, EKParticipantTypeResource, EKParticipantTypeGroup,
};

/* a place with a title and optional coordinates and radius (an event's location, a location alarm's place) */
@interface EKStructuredLocation : EKObject <NSCopying>
+ (instancetype)locationWithTitle:(NSString *)title;
+ (instancetype)locationWithMapItem:(MKMapItem *)mapItem;   /* with MapKit */
@property (nonatomic, strong, nullable) NSString *title;
@property (nonatomic, strong, nullable) CLLocation *geoLocation;
@property (nonatomic) double radius;
@end

/* alarms: display alarms fire while an app that uses EventKit runs (the Calendar alert banner); proximity alarms never fire */
@interface EKAlarm : EKObject <NSCopying>
+ (EKAlarm *)alarmWithAbsoluteDate:(NSDate *)date;
+ (EKAlarm *)alarmWithRelativeOffset:(NSTimeInterval)offset;
@property (nonatomic) NSTimeInterval relativeOffset;
@property (nonatomic, copy, nullable) NSDate *absoluteDate;
@property (nonatomic, copy, nullable) EKStructuredLocation *structuredLocation;
@property (nonatomic) EKAlarmProximity proximity;
@property (nonatomic, readonly) EKAlarmType type;
@property (nonatomic, copy, nullable) NSString *emailAddress;
@property (nonatomic, copy, nullable) NSString *soundName;
@end

/* a person (room, resource, group) invited to an event: read from the calendar database */
@interface EKParticipant : EKObject <NSCopying>
@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, readonly, nullable) NSString *name;
@property (nonatomic, readonly) EKParticipantStatus participantStatus;
@property (nonatomic, readonly) EKParticipantRole participantRole;
@property (nonatomic, readonly) EKParticipantType participantType;
@property (nonatomic, readonly, getter=isCurrentUser) BOOL currentUser;
@property (nonatomic, readonly) NSPredicate *contactPredicate;
@end

@interface EKRecurrenceDayOfWeek : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)dayOfWeek:(EKWeekday)dayOfTheWeek;
+ (instancetype)dayOfWeek:(EKWeekday)dayOfTheWeek weekNumber:(NSInteger)weekNumber;
- (instancetype)initWithDayOfTheWeek:(EKWeekday)dayOfTheWeek weekNumber:(NSInteger)weekNumber;
@property (nonatomic, readonly) EKWeekday dayOfTheWeek;
@property (nonatomic, readonly) NSInteger weekNumber;
@end

@interface EKRecurrenceEnd : NSObject <NSCopying>
+ (instancetype)recurrenceEndWithEndDate:(NSDate *)endDate;
+ (instancetype)recurrenceEndWithOccurrenceCount:(NSUInteger)occurrenceCount;
@property (nonatomic, readonly, nullable) NSDate *endDate;
@property (nonatomic, readonly) NSUInteger occurrenceCount;
@end
@interface EKRecurrenceRule : EKObject <NSCopying>
- (instancetype)initRecurrenceWithFrequency:(EKRecurrenceFrequency)type interval:(NSInteger)interval end:(nullable EKRecurrenceEnd *)end;
- (instancetype)initRecurrenceWithFrequency:(EKRecurrenceFrequency)type interval:(NSInteger)interval
                              daysOfTheWeek:(nullable NSArray<EKRecurrenceDayOfWeek *> *)days daysOfTheMonth:(nullable NSArray<NSNumber *> *)monthDays
                            monthsOfTheYear:(nullable NSArray<NSNumber *> *)months weeksOfTheYear:(nullable NSArray<NSNumber *> *)weeksOfTheYear
                              daysOfTheYear:(nullable NSArray<NSNumber *> *)daysOfTheYear setPositions:(nullable NSArray<NSNumber *> *)setPositions
                                        end:(nullable EKRecurrenceEnd *)end;
@property (nonatomic, readonly) NSString *calendarIdentifier;
@property (nonatomic, readonly) EKRecurrenceFrequency frequency;
@property (nonatomic, readonly) NSInteger interval;
@property (nonatomic, copy, nullable) EKRecurrenceEnd *recurrenceEnd;
@property (nonatomic, readonly) NSInteger firstDayOfTheWeek;
@property (nonatomic, readonly, nullable) NSArray<EKRecurrenceDayOfWeek *> *daysOfTheWeek;
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *daysOfTheMonth;
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *daysOfTheYear;
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *weeksOfTheYear;
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *monthsOfTheYear;
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *setPositions;
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
@property (nonatomic, readonly) BOOL hasAttendees;
@property (nonatomic, readonly, nullable) NSArray<EKParticipant *> *attendees;
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
@property (nonatomic, readonly, nullable) EKParticipant *organizer;
@property (nonatomic, copy, nullable) EKStructuredLocation *structuredLocation;
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
