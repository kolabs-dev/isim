#pragma once
/* isim EventKitUI for Objective-C: the classes are the EventKitUI Swift overlay's (EventKitUI.framework re-exports
   libswiftEventKitUI.dylib): the event editor and the event view. Swift uses the overlay; these declarations are hidden
   from Swift. */
#import <UIKit/UIKit.h>
#import <EventKit/EventKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class EKEventEditViewController, EKEventViewController;

typedef NS_ENUM(NSInteger, EKEventEditViewAction) {
    EKEventEditViewActionCanceled = 0, EKEventEditViewActionSaved, EKEventEditViewActionDeleted,
    EKEventEditViewActionCancelled API_DEPRECATED_WITH_REPLACEMENT("EKEventEditViewActionCanceled", ios(4.0, 6.0)) = EKEventEditViewActionCanceled,
};
@protocol EKEventEditViewDelegate <NSObject>
@required
- (void)eventEditViewController:(EKEventEditViewController *)controller didCompleteWithAction:(EKEventEditViewAction)action;
@optional
- (EKCalendar *)eventEditViewControllerDefaultCalendarForNewEvents:(EKEventEditViewController *)controller;
@end
@interface EKEventEditViewController : UINavigationController
@property (nonatomic, weak, nullable) id<EKEventEditViewDelegate> editViewDelegate;
@property (nonatomic, strong) EKEventStore *eventStore;
@property (nonatomic, strong, nullable) EKEvent *event;
- (void)cancelEditing;
@end

typedef NS_ENUM(NSInteger, EKEventViewAction) { EKEventViewActionDone = 0, EKEventViewActionResponded, EKEventViewActionDeleted };
@protocol EKEventViewDelegate <NSObject>
@required
- (void)eventViewController:(EKEventViewController *)controller didCompleteWithAction:(EKEventViewAction)action;
@end
@interface EKEventViewController : UIViewController
@property (nonatomic, weak, nullable) id<EKEventViewDelegate> delegate;
@property (nonatomic, strong, null_unspecified) EKEvent *event;
@property (nonatomic) BOOL allowsEditing;
@property (nonatomic) BOOL allowsCalendarPreview;
@end

/* the calendar chooser (adapted: lists the device's calendars in the app, like the event editor) */
typedef NS_ENUM(NSInteger, EKCalendarChooserSelectionStyle) { EKCalendarChooserSelectionStyleSingle = 0, EKCalendarChooserSelectionStyleMultiple };
typedef NS_ENUM(NSInteger, EKCalendarChooserDisplayStyle) { EKCalendarChooserDisplayAllCalendars = 0, EKCalendarChooserDisplayWritableCalendarsOnly };
@class EKCalendarChooser;
@protocol EKCalendarChooserDelegate <NSObject>
@optional
- (void)calendarChooserSelectionDidChange:(EKCalendarChooser *)calendarChooser;
- (void)calendarChooserDidFinish:(EKCalendarChooser *)calendarChooser;
- (void)calendarChooserDidCancel:(EKCalendarChooser *)calendarChooser;
@end
@interface EKCalendarChooser : UIViewController
- (instancetype)initWithSelectionStyle:(EKCalendarChooserSelectionStyle)selectionStyle displayStyle:(EKCalendarChooserDisplayStyle)displayStyle
                            eventStore:(EKEventStore *)eventStore;
- (instancetype)initWithSelectionStyle:(EKCalendarChooserSelectionStyle)selectionStyle displayStyle:(EKCalendarChooserDisplayStyle)displayStyle
                            entityType:(EKEntityType)entityType eventStore:(EKEventStore *)eventStore;
@property (nonatomic, readonly) EKCalendarChooserSelectionStyle selectionStyle;
@property (nonatomic, weak, nullable) id<EKCalendarChooserDelegate> delegate;
@property (nonatomic) BOOL showsDoneButton;
@property (nonatomic) BOOL showsCancelButton;
@property (nonatomic, copy) NSSet<EKCalendar *> *selectedCalendars;
@end

NS_ASSUME_NONNULL_END
#endif
