#pragma once
#import <XCTest/XCTestDefines.h>

typedef NS_ENUM(NSUInteger, XCUIElementType) {
    XCUIElementTypeAny = 0, XCUIElementTypeOther = 1, XCUIElementTypeApplication = 2, XCUIElementTypeGroup = 3,
    XCUIElementTypeWindow = 4, XCUIElementTypeSheet = 5, XCUIElementTypeDrawer = 6, XCUIElementTypeAlert = 7,
    XCUIElementTypeDialog = 8, XCUIElementTypeButton = 9, XCUIElementTypeRadioButton = 10, XCUIElementTypeRadioGroup = 11,
    XCUIElementTypeCheckBox = 12, XCUIElementTypeDisclosureTriangle = 13, XCUIElementTypePopUpButton = 14,
    XCUIElementTypeComboBox = 15, XCUIElementTypeMenuButton = 16, XCUIElementTypeToolbarButton = 17,
    XCUIElementTypePopover = 18, XCUIElementTypeKeyboard = 19, XCUIElementTypeKey = 20, XCUIElementTypeNavigationBar = 21,
    XCUIElementTypeTabBar = 22, XCUIElementTypeTabGroup = 23, XCUIElementTypeToolbar = 24, XCUIElementTypeStatusBar = 25,
    XCUIElementTypeTable = 26, XCUIElementTypeTableRow = 27, XCUIElementTypeTableColumn = 28, XCUIElementTypeOutline = 29,
    XCUIElementTypeOutlineRow = 30, XCUIElementTypeBrowser = 31, XCUIElementTypeCollectionView = 32,
    XCUIElementTypeSlider = 33, XCUIElementTypePageIndicator = 34, XCUIElementTypeProgressIndicator = 35,
    XCUIElementTypeActivityIndicator = 36, XCUIElementTypeSegmentedControl = 37, XCUIElementTypePicker = 38,
    XCUIElementTypePickerWheel = 39, XCUIElementTypeSwitch = 40, XCUIElementTypeToggle = 41, XCUIElementTypeLink = 42,
    XCUIElementTypeImage = 43, XCUIElementTypeIcon = 44, XCUIElementTypeSearchField = 45, XCUIElementTypeScrollView = 46,
    XCUIElementTypeScrollBar = 47, XCUIElementTypeStaticText = 48, XCUIElementTypeTextField = 49,
    XCUIElementTypeSecureTextField = 50, XCUIElementTypeDatePicker = 51, XCUIElementTypeTextView = 52,
    XCUIElementTypeMenu = 53, XCUIElementTypeMenuItem = 54, XCUIElementTypeMenuBar = 55, XCUIElementTypeMenuBarItem = 56,
    XCUIElementTypeMap = 57, XCUIElementTypeWebView = 58, XCUIElementTypeIncrementArrow = 59,
    XCUIElementTypeDecrementArrow = 60, XCUIElementTypeTimeline = 61, XCUIElementTypeRatingIndicator = 62,
    XCUIElementTypeValueIndicator = 63, XCUIElementTypeSplitGroup = 64, XCUIElementTypeSplitter = 65,
    XCUIElementTypeRelevanceIndicator = 66, XCUIElementTypeColorWell = 67, XCUIElementTypeHelpTag = 68,
    XCUIElementTypeMatte = 69, XCUIElementTypeDockItem = 70, XCUIElementTypeRuler = 71, XCUIElementTypeRulerMarker = 72,
    XCUIElementTypeGrid = 73, XCUIElementTypeLevelIndicator = 74, XCUIElementTypeCell = 75, XCUIElementTypeLayoutArea = 76,
    XCUIElementTypeLayoutItem = 77, XCUIElementTypeHandle = 78, XCUIElementTypeStepper = 79, XCUIElementTypeTab = 80,
    XCUIElementTypeTouchBar = 81, XCUIElementTypeStatusItem = 82,
} NS_SWIFT_NAME(XCUIElement.ElementType);

@class XCUIElementQuery;

NS_ASSUME_NONNULL_BEGIN

/* Queries for descendants of an element (or of a query's matches), by element type. */
@protocol XCUIElementTypeQueryProvider
@property (readonly, copy) XCUIElementQuery *touchBars;
@property (readonly, copy) XCUIElementQuery *groups;
@property (readonly, copy) XCUIElementQuery *windows;
@property (readonly, copy) XCUIElementQuery *sheets;
@property (readonly, copy) XCUIElementQuery *alerts;
@property (readonly, copy) XCUIElementQuery *dialogs;
@property (readonly, copy) XCUIElementQuery *buttons;
@property (readonly, copy) XCUIElementQuery *navigationBars;
@property (readonly, copy) XCUIElementQuery *tabBars;
@property (readonly, copy) XCUIElementQuery *tabs;
@property (readonly, copy) XCUIElementQuery *toolbars;
@property (readonly, copy) XCUIElementQuery *statusBars;
@property (readonly, copy) XCUIElementQuery *tables;
@property (readonly, copy) XCUIElementQuery *collectionViews;
@property (readonly, copy) XCUIElementQuery *sliders;
@property (readonly, copy) XCUIElementQuery *pageIndicators;
@property (readonly, copy) XCUIElementQuery *progressIndicators;
@property (readonly, copy) XCUIElementQuery *activityIndicators;
@property (readonly, copy) XCUIElementQuery *segmentedControls;
@property (readonly, copy) XCUIElementQuery *pickers;
@property (readonly, copy) XCUIElementQuery *pickerWheels;
@property (readonly, copy) XCUIElementQuery *switches;
@property (readonly, copy) XCUIElementQuery *toggles;
@property (readonly, copy) XCUIElementQuery *links;
@property (readonly, copy) XCUIElementQuery *images;
@property (readonly, copy) XCUIElementQuery *icons;
@property (readonly, copy) XCUIElementQuery *searchFields;
@property (readonly, copy) XCUIElementQuery *scrollViews;
@property (readonly, copy) XCUIElementQuery *staticTexts;
@property (readonly, copy) XCUIElementQuery *textFields;
@property (readonly, copy) XCUIElementQuery *secureTextFields;
@property (readonly, copy) XCUIElementQuery *datePickers;
@property (readonly, copy) XCUIElementQuery *textViews;
@property (readonly, copy) XCUIElementQuery *menus;
@property (readonly, copy) XCUIElementQuery *menuItems;
@property (readonly, copy) XCUIElementQuery *maps;
@property (readonly, copy) XCUIElementQuery *webViews;
@property (readonly, copy) XCUIElementQuery *steppers;
@property (readonly, copy) XCUIElementQuery *cells;
@property (readonly, copy) XCUIElementQuery *keyboards;
@property (readonly, copy) XCUIElementQuery *keys;
@property (readonly, copy) XCUIElementQuery *otherElements;
@end

NS_ASSUME_NONNULL_END
