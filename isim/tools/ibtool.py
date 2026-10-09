#!/usr/bin/env python3
"""isim ibtool: compiles Interface Builder documents (.storyboard / .xib, Xcode 15/16 XML document format)
into isim's own runtime format, read by isim UIKit (UIStoryboard, UINib, UIViewController nib loading).

  ibtool.py Main.storyboard -o Bundle.app/            -> Bundle.app/Main.storyboardc/isim-storyboard.plist
  ibtool.py Cell.xib -o Bundle.app/                   -> Bundle.app/Cell.nib/isim-nib.plist

THIS IS NOT APPLE'S FORMAT. Apple's ibtool writes binary .nib archives (and .storyboardc folders of them);
isim writes an XML property list describing the object graph instead. Only isim's UIKit reads it.

isim IB archive format, version 1 (all property-list types):
  storyboard file: {format: "isim-storyboard", version: 1, source, initialViewController?: id,
                    identifiers: {storyboardID: vcID}, scenes: {vcID: archive}}
  nib file:        {format: "isim-nib", version: 1, source, archive}
  archive: {root?: node (scene view controller), objects: [node] (top-level objects, in document order),
            placeholders: {id: "owner" | "firstResponder" | "exit" | <external object identifier>},
            connections: [connection], guides: {guideID: {view: viewID, kind: safeArea|layoutMargins|keyboard|
            contentLayout|frameLayout|readableContent}}}
  node: {id, class (UIKit class of the element), customClass?, customModule?, props: {key: value},
         subviews?: [node], keyed?: {key: node | [node]}, constraints?: [constraint], userDefined?: [attr],
         prototypes?: [archive] (table/collection prototype cells, each with root), staticSections?: [section]}
  value: a plain string/number/bool, or a typed dict {"$t": color|font|image|rect|size|point|insets|
         dinsets|date|nil|locale|symbolConfig, ...}
  constraint: {first?, firstAttr, second?, secondAttr?, relation, multiplier, constant, priority, identifier?}
              (missing first = the view that owns the constraint; placeholder constraints are dropped)
  connection: {type: outlet|outletCollection|action|segue, source, destination, property?, selector?,
               events?, kind?, identifier?, relationship?, ...}
"""
import argparse
import os
import plistlib
import sys
import xml.etree.ElementTree as ET

FORMAT_VERSION = 1

# ---------------- element -> class ----------------
VIEW_CLASSES = {
    'view': 'UIView', 'label': 'UILabel', 'button': 'UIButton', 'imageView': 'UIImageView', 'textField': 'UITextField',
    'textView': 'UITextView', 'switch': 'UISwitch', 'slider': 'UISlider', 'stepper': 'UIStepper',
    'segmentedControl': 'UISegmentedControl', 'stackView': 'UIStackView', 'scrollView': 'UIScrollView',
    'tableView': 'UITableView', 'tableViewCell': 'UITableViewCell', 'tableViewCellContentView': 'UIView',
    'collectionView': 'UICollectionView', 'collectionViewCell': 'UICollectionViewCell',
    'collectionReusableView': 'UICollectionReusableView', 'collectionViewCellContentView': 'UIView',
    'activityIndicatorView': 'UIActivityIndicatorView', 'progressView': 'UIProgressView', 'pickerView': 'UIPickerView',
    'datePicker': 'UIDatePicker', 'pageControl': 'UIPageControl', 'visualEffectView': 'UIVisualEffectView',
    'containerView': 'UIView', 'navigationBar': 'UINavigationBar', 'toolbar': 'UIToolbar', 'tabBar': 'UITabBar',
    'searchBar': 'UISearchBar', 'colorWell': 'UIColorWell', 'wkWebView': 'WKWebView', 'mapView': 'MKMapView',
    'tableViewHeaderFooterView': 'UITableViewHeaderFooterView', 'window': 'UIWindow',
}
CONTROLLER_CLASSES = {
    'viewController': 'UIViewController', 'navigationController': 'UINavigationController',
    'tabBarController': 'UITabBarController', 'tableViewController': 'UITableViewController',
    'collectionViewController': 'UICollectionViewController', 'pageViewController': 'UIPageViewController',
    'splitViewController': 'UISplitViewController', 'hostingController': 'UIViewController',
    'avPlayerViewController': 'AVPlayerViewController',
}
OBJECT_CLASSES = {
    'navigationItem': 'UINavigationItem', 'barButtonItem': 'UIBarButtonItem', 'tabBarItem': 'UITabBarItem',
    'tapGestureRecognizer': 'UITapGestureRecognizer', 'panGestureRecognizer': 'UIPanGestureRecognizer',
    'swipeGestureRecognizer': 'UISwipeGestureRecognizer', 'pinchGestureRecognizer': 'UIPinchGestureRecognizer',
    'rotationGestureRecognizer': 'UIRotationGestureRecognizer', 'pongPressGestureRecognizer': 'UILongPressGestureRecognizer',
    'screenEdgePanGestureRecognizer': 'UIScreenEdgePanGestureRecognizer', 'hoverGestureRecognizer': 'UIHoverGestureRecognizer',
    'collectionViewFlowLayout': 'UICollectionViewFlowLayout', 'customObject': 'NSObject',
}
ALL_CLASSES = {**VIEW_CLASSES, **CONTROLLER_CLASSES, **OBJECT_CLASSES}

# ---------------- enums (string -> raw value, as UIKit defines them) ----------------
E = {
    'contentMode': {'scaleToFill': 0, 'scaleAspectFit': 1, 'scaleAspectFill': 2, 'redraw': 3, 'center': 4, 'top': 5,
                    'bottom': 6, 'left': 7, 'right': 8, 'topLeft': 9, 'topRight': 10, 'bottomLeft': 11, 'bottomRight': 12},
    'textAlignment': {'left': 0, 'center': 1, 'right': 2, 'justified': 3, 'natural': 4},
    'lineBreakMode': {'wordWrap': 0, 'characterWrap': 1, 'clip': 2, 'headTruncation': 3, 'tailTruncation': 4, 'middleTruncation': 5},
    'baselineAdjustment': {'alignBaselines': 0, 'alignCenters': 1, 'none': 2},
    'buttonType': {'custom': 0, 'system': 1, 'roundedRect': 1, 'detailDisclosure': 2, 'infoLight': 3, 'infoDark': 4, 'contactAdd': 5, 'close': 7},
    'contentHorizontalAlignment': {'center': 0, 'left': 1, 'right': 2, 'fill': 3, 'leading': 4, 'trailing': 5},
    'contentVerticalAlignment': {'center': 0, 'top': 1, 'bottom': 2, 'fill': 3},
    'borderStyle': {'none': 0, 'line': 1, 'bezel': 2, 'roundedRect': 3},
    'clearButtonMode': {'never': 0, 'whileEditing': 1, 'unlessEditing': 2, 'always': 3},
    'axis': {'horizontal': 0, 'vertical': 1},
    'alignment': {'fill': 0, 'leading': 1, 'top': 1, 'firstBaseline': 2, 'center': 3, 'trailing': 4, 'bottom': 4, 'lastBaseline': 5},
    'distribution': {'fill': 0, 'fillEqually': 1, 'fillProportionally': 2, 'equalSpacing': 3, 'equalCentering': 4},
    'tableStyle': {'plain': 0, 'grouped': 1, 'insetGrouped': 2},
    'separatorStyle': {'none': 0, 'default': 1, 'singleLine': 1, 'singleLineEtched': 2},
    'cellStyle': {'IBUITableViewCellStyleDefault': 0, 'IBUITableViewCellStyleValue1': 1, 'IBUITableViewCellStyleValue2': 2,
                  'IBUITableViewCellStyleSubtitle': 3},
    'selectionStyle': {'none': 0, 'blue': 1, 'gray': 2, 'default': 3},
    'accessoryType': {'none': 0, 'disclosureIndicator': 1, 'detailDisclosureButton': 2, 'checkmark': 3, 'detailButton': 4},
    'activityStyle': {'whiteLarge': 0, 'white': 1, 'gray': 2, 'medium': 100, 'large': 101},
    'progressViewStyle': {'default': 0, 'bar': 1},
    'datePickerMode': {'time': 0, 'date': 1, 'dateAndTime': 2, 'countDownTimer': 3},
    'datePickerStyle': {'automatic': 0, 'wheels': 1, 'compact': 2, 'inline': 3},
    'scrollDirection': {'vertical': 0, 'horizontal': 1},
    'contentInsetAdjustmentBehavior': {'automatic': 0, 'scrollableAxes': 1, 'never': 2, 'always': 3},
    'keyboardDismissMode': {'none': 0, 'onDrag': 1, 'interactive': 2, 'interactiveWithAccessory': 3, 'onDragWithAccessory': 4},
    'largeTitleDisplayMode': {'automatic': 0, 'always': 1, 'never': 2},
    'barButtonStyle': {'plain': 0, 'bordered': 1, 'done': 2},
    'barButtonSystemItem': {'done': 0, 'cancel': 1, 'edit': 2, 'save': 3, 'add': 4, 'flexibleSpace': 5, 'fixedSpace': 6,
                            'compose': 7, 'reply': 8, 'action': 9, 'organize': 10, 'bookmarks': 11, 'search': 12, 'refresh': 13,
                            'stop': 14, 'camera': 15, 'trash': 16, 'play': 17, 'pause': 18, 'rewind': 19, 'fastForward': 20,
                            'undo': 21, 'redo': 22, 'pageCurl': 23, 'close': 24},
    'tabBarSystemItem': {'more': 0, 'favorites': 1, 'featured': 2, 'topRated': 3, 'recents': 4, 'contacts': 5, 'history': 6,
                         'bookmarks': 7, 'search': 8, 'downloads': 9, 'mostRecent': 10, 'mostViewed': 11},
    'modalPresentationStyle': {'fullScreen': 0, 'pageSheet': 1, 'formSheet': 2, 'currentContext': 3, 'custom': 4,
                               'overFullScreen': 5, 'overCurrentContext': 6, 'popover': 7, 'none': -1, 'automatic': -2},
    'modalTransitionStyle': {'coverVertical': 0, 'flipHorizontal': 1, 'crossDissolve': 2, 'partialCurl': 3},
    'transitionStyle': {'pageCurl': 0, 'scroll': 1},
    'navigationOrientation': {'horizontal': 0, 'vertical': 1},
    'spineLocation': {'none': 0, 'min': 1, 'mid': 2, 'max': 3},
    'semanticContentAttribute': {'unspecified': 0, 'playback': 1, 'spatial': 2, 'forceLeftToRight': 3, 'forceRightToLeft': 4},
    'swipeDirection': {'right': 1, 'left': 2, 'up': 4, 'down': 8},
    'autocapitalizationType': {'none': 0, 'words': 1, 'sentences': 2, 'allCharacters': 3},
    'autocorrectionType': {'default': 0, 'no': 1, 'yes': 2},
    'spellCheckingType': {'default': 0, 'no': 1, 'yes': 2},
    'keyboardType': {'default': 0, 'alphabet': 1, 'ASCIICapable': 1, 'numbersAndPunctuation': 2, 'URL': 3, 'numberPad': 4,
                     'phonePad': 5, 'namePhonePad': 6, 'emailAddress': 7, 'decimalPad': 8, 'twitter': 9, 'webSearch': 10,
                     'asciiCapableNumberPad': 11},
    'keyboardAppearance': {'default': 0, 'dark': 1, 'light': 2, 'alert': 1},
    'returnKeyType': {'default': 0, 'go': 1, 'google': 2, 'join': 3, 'next': 4, 'route': 5, 'search': 6, 'send': 7,
                      'yahoo': 8, 'done': 9, 'emergencyCall': 10, 'continue': 11},
    'barStyle': {'default': 0, 'black': 1, 'blackTranslucent': 2},
    'cornerStyle': {'fixed': -1, 'dynamic': 0, 'small': 1, 'medium': 2, 'large': 3, 'capsule': 4},
    'buttonSize': {'medium': 0, 'small': 1, 'mini': 2, 'large': 3},
    'imagePlacement': {'leading': 2, 'trailing': 8, 'top': 1, 'bottom': 4},
    'symbolScale': {'default': -1, 'unspecified': 0, 'small': 1, 'medium': 2, 'large': 3},
    'symbolWeight': {'unspecified': 0, 'ultraLight': 1, 'thin': 2, 'light': 3, 'regular': 4, 'medium': 5, 'semibold': 6,
                     'bold': 7, 'heavy': 8, 'black': 9},
}
CONTROL_EVENTS = {
    'touchDown': 1 << 0, 'touchDownRepeat': 1 << 1, 'touchDragInside': 1 << 2, 'touchDragOutside': 1 << 3,
    'touchDragEnter': 1 << 4, 'touchDragExit': 1 << 5, 'touchUpInside': 1 << 6, 'touchUpOutside': 1 << 7,
    'touchCancel': 1 << 8, 'valueChanged': 1 << 12, 'primaryActionTriggered': 1 << 13, 'menuActionTriggered': 1 << 14,
    'editingDidBegin': 1 << 16, 'editingChanged': 1 << 17, 'editingDidEnd': 1 << 18, 'editingDidEndOnExit': 1 << 19,
}
LAYOUT_ATTRIBUTES = {
    'left': 1, 'right': 2, 'top': 3, 'bottom': 4, 'leading': 5, 'trailing': 6, 'width': 7, 'height': 8, 'centerX': 9,
    'centerY': 10, 'baseline': 11, 'lastBaseline': 11, 'firstBaseline': 12, 'leftMargin': 13, 'rightMargin': 14,
    'topMargin': 15, 'bottomMargin': 16, 'leadingMargin': 17, 'trailingMargin': 18, 'centerXWithinMargins': 19,
    'centerYWithinMargins': 20,
}
GUIDE_KINDS = {'safeArea': 'safeArea', 'layoutMarginsGuide': 'layoutMargins', 'keyboard': 'keyboard',
               'contentLayoutGuide': 'contentLayout', 'frameLayoutGuide': 'frameLayout',
               'readableContentGuide': 'readableContent'}

# attributes common to every view element: xml name -> (property key, converter)
def b(v): return v == 'YES'
def f(v): return float(v)
def i(v): return int(float(v))
def s(v): return v
def enum(name):
    def conv(v):
        table = E[name]
        if v not in table:
            raise ValueError(f'unknown {name} value {v!r}')
        return table[v]
    return conv

VIEW_ATTRS = {
    'contentMode': ('contentMode', enum('contentMode')), 'alpha': ('alpha', f), 'hidden': ('hidden', b),
    'clipsSubviews': ('clipsToBounds', b), 'userInteractionEnabled': ('userInteractionEnabled', b),
    'multipleTouchEnabled': ('multipleTouchEnabled', b), 'tag': ('tag', i),
    'translatesAutoresizingMaskIntoConstraints': ('translatesAutoresizingMaskIntoConstraints', b),
    'semanticContentAttribute': ('semanticContentAttribute', enum('semanticContentAttribute')),
    'insetsLayoutMarginsFromSafeArea': ('insetsLayoutMarginsFromSafeArea', b),
    'preservesSuperviewLayoutMargins': ('preservesSuperviewLayoutMargins', b),
    'horizontalHuggingPriority': ('$huggingH', f), 'verticalHuggingPriority': ('$huggingV', f),
    'horizontalCompressionResistancePriority': ('$resistanceH', f), 'verticalCompressionResistancePriority': ('$resistanceV', f),
    'restorationIdentifier': ('restorationIdentifier', s), 'overrideUserInterfaceStyle': ('$userInterfaceStyle', s),
}
CONTROL_ATTRS = {
    'contentHorizontalAlignment': ('contentHorizontalAlignment', enum('contentHorizontalAlignment')),
    'contentVerticalAlignment': ('contentVerticalAlignment', enum('contentVerticalAlignment')),
    'enabled': ('enabled', b), 'selected': ('selected', b), 'highlighted': ('highlighted', b),
}
INPUT_TRAIT_ATTRS = {
    'autocapitalizationType': ('autocapitalizationType', enum('autocapitalizationType')),
    'autocorrectionType': ('autocorrectionType', enum('autocorrectionType')),
    'spellCheckingType': ('spellCheckingType', enum('spellCheckingType')),
    'keyboardType': ('keyboardType', enum('keyboardType')), 'keyboardAppearance': ('keyboardAppearance', enum('keyboardAppearance')),
    'returnKeyType': ('returnKeyType', enum('returnKeyType')), 'secureTextEntry': ('secureTextEntry', b),
    'enablesReturnKeyAutomatically': ('enablesReturnKeyAutomatically', b), 'textContentType': ('textContentType', s),
}
SCROLL_ATTRS = {
    'showsHorizontalScrollIndicator': ('showsHorizontalScrollIndicator', b),
    'showsVerticalScrollIndicator': ('showsVerticalScrollIndicator', b), 'pagingEnabled': ('pagingEnabled', b),
    'bounces': ('bounces', b), 'alwaysBounceVertical': ('alwaysBounceVertical', b),
    'alwaysBounceHorizontal': ('alwaysBounceHorizontal', b), 'scrollEnabled': ('scrollEnabled', b),
    'directionalLockEnabled': ('directionalLockEnabled', b), 'bouncesZoom': ('bouncesZoom', b),
    'contentInsetAdjustmentBehavior': ('contentInsetAdjustmentBehavior', enum('contentInsetAdjustmentBehavior')),
    'keyboardDismissMode': ('keyboardDismissMode', enum('keyboardDismissMode')),
    'minimumZoomScale': ('minimumZoomScale', f), 'maximumZoomScale': ('maximumZoomScale', f),
}
TAG_ATTRS = {
    'label': {'text': ('text', s), 'textAlignment': ('textAlignment', enum('textAlignment')), 'numberOfLines': ('numberOfLines', i),
              'lineBreakMode': ('lineBreakMode', enum('lineBreakMode')), 'adjustsFontSizeToFit': ('adjustsFontSizeToFitWidth', b),
              'minimumScaleFactor': ('minimumScaleFactor', f), 'baselineAdjustment': ('baselineAdjustment', enum('baselineAdjustment')),
              'adjustsFontForContentSizeCategory': ('adjustsFontForContentSizeCategory', b), 'enabled': ('enabled', b),
              'highlighted': ('highlighted', b), 'minimumFontSize': None, 'preferredMaxLayoutWidth': ('preferredMaxLayoutWidth', f)},
    'button': {'buttonType': ('$buttonType', enum('buttonType')), 'showsMenuAsPrimaryAction': ('showsMenuAsPrimaryAction', b),
               'changesSelectionAsPrimaryAction': ('changesSelectionAsPrimaryAction', b), 'lineBreakMode': None,
               'role': None, 'pointerInteraction': None, 'adjustsImageWhenHighlighted': None, 'showsTouchWhenHighlighted': None},
    'imageView': {'image': ('$image', s), 'highlightedImage': ('$highlightedImage', s), 'catalog': None,
                  'adjustsImageSizeForAccessibilityContentSizeCategory': None, 'highlighted': ('highlighted', b)},
    'textField': {'text': ('text', s), 'placeholder': ('placeholder', s), 'borderStyle': ('borderStyle', enum('borderStyle')),
                  'textAlignment': ('textAlignment', enum('textAlignment')), 'clearButtonMode': ('clearButtonMode', enum('clearButtonMode')),
                  'minimumFontSize': ('minimumFontSize', f), 'adjustsFontSizeToFit': ('adjustsFontSizeToFitWidth', b),
                  'clearsOnBeginEditing': ('clearsOnBeginEditing', b), 'adjustsFontForContentSizeCategory': ('adjustsFontForContentSizeCategory', b)},
    'textView': {'text': ('text', s), 'textAlignment': ('textAlignment', enum('textAlignment')), 'editable': ('editable', b),
                 'selectable': ('selectable', b), 'adjustsFontForContentSizeCategory': ('adjustsFontForContentSizeCategory', b)},
    'switch': {'on': ('on', b), 'title': None, 'preferredStyle': None},
    'slider': {'value': ('value', f), 'minValue': ('minimumValue', f), 'maxValue': ('maximumValue', f), 'continuous': ('continuous', b)},
    'stepper': {'value': ('value', f), 'minimumValue': ('minimumValue', f), 'maximumValue': ('maximumValue', f),
                'stepValue': ('stepValue', f), 'wraps': ('wraps', b), 'autorepeat': ('autorepeat', b), 'continuous': ('continuous', b)},
    'segmentedControl': {'selectedSegmentIndex': ('$selectedSegmentIndex', i), 'segmentControlStyle': None,
                         'apportionsSegmentWidthsByContent': ('apportionsSegmentWidthsByContent', b), 'momentary': ('momentary', b)},
    'stackView': {'axis': ('axis', enum('axis')), 'alignment': ('alignment', enum('alignment')),
                  'distribution': ('distribution', enum('distribution')), 'spacing': ('spacing', f),
                  'baselineRelativeArrangement': ('baselineRelativeArrangement', b), 'layoutMarginsRelativeArrangement': ('layoutMarginsRelativeArrangement', b)},
    'scrollView': {},
    'tableView': {'style': ('$tableStyle', enum('tableStyle')), 'separatorStyle': ('separatorStyle', enum('separatorStyle')),
                  'rowHeight': ('rowHeight', f), 'estimatedRowHeight': ('estimatedRowHeight', f),
                  'sectionHeaderHeight': None, 'sectionFooterHeight': None,
                  'estimatedSectionHeaderHeight': ('estimatedSectionHeaderHeight', f), 'estimatedSectionFooterHeight': ('estimatedSectionFooterHeight', f),
                  'allowsSelection': ('allowsSelection', b), 'allowsMultipleSelection': ('allowsMultipleSelection', b),
                  'allowsSelectionDuringEditing': ('allowsSelectionDuringEditing', b), 'dataMode': ('$dataMode', s),
                  'sectionIndexMinimumDisplayRowCount': None},
    'tableViewCell': {'reuseIdentifier': ('$reuseIdentifier', s), 'style': ('$cellStyle', enum('cellStyle')),
                      'selectionStyle': ('selectionStyle', enum('selectionStyle')), 'accessoryType': ('accessoryType', enum('accessoryType')),
                      'editingAccessoryType': ('editingAccessoryType', enum('accessoryType')), 'indentationLevel': ('indentationLevel', i),
                      'indentationWidth': ('indentationWidth', f), 'textLabel': ('$builtin_textLabel', s),
                      'detailTextLabel': ('$builtin_detailTextLabel', s), 'imageView': ('$builtin_imageView', s),
                      'shouldIndentWhileEditing': None, 'focusStyle': None, 'rowHeight': ('$rowHeight', f)},
    'tableViewCellContentView': {'tableViewCell': None},
    'collectionViewCellContentView': {},
    'collectionView': {'dataMode': ('$dataMode', s), 'allowsSelection': ('allowsSelection', b),
                       'allowsMultipleSelection': ('allowsMultipleSelection', b)},
    'collectionViewCell': {'reuseIdentifier': ('$reuseIdentifier', s)},
    'collectionReusableView': {'reuseIdentifier': ('$reuseIdentifier', s)},
    'activityIndicatorView': {'style': ('$activityStyle', enum('activityStyle')), 'animating': ('$animating', b),
                              'hidesWhenStopped': ('hidesWhenStopped', b)},
    'progressView': {'progress': ('progress', f), 'progressViewStyle': ('progressViewStyle', enum('progressViewStyle'))},
    'pageControl': {'numberOfPages': ('numberOfPages', i), 'currentPage': ('currentPage', i), 'hidesForSinglePage': ('hidesForSinglePage', b)},
    'datePicker': {'datePickerMode': ('datePickerMode', enum('datePickerMode')), 'style': ('preferredDatePickerStyle', enum('datePickerStyle')),
                   'minuteInterval': ('minuteInterval', i), 'useCurrentDate': None},
    'pickerView': {},
    'searchBar': {'placeholder': ('placeholder', s), 'text': ('text', s), 'prompt': ('prompt', s), 'showsCancelButton': ('showsCancelButton', b),
                  'searchBarStyle': None},
    'navigationBar': {'largeTitles': ('prefersLargeTitles', b), 'barStyle': ('barStyle', enum('barStyle')), 'translucent': ('translucent', b)},
    'toolbar': {'barStyle': ('barStyle', enum('barStyle')), 'translucent': ('translucent', b)},
    'tabBar': {'translucent': ('translucent', b), 'barStyle': ('barStyle', enum('barStyle'))},
    'visualEffectView': {},
    'containerView': {},
}
CONTROLLER_ATTRS = {
    'title': ('title', s), 'modalPresentationStyle': ('modalPresentationStyle', enum('modalPresentationStyle')),
    'modalTransitionStyle': ('modalTransitionStyle', enum('modalTransitionStyle')),
    'hidesBottomBarWhenPushed': ('hidesBottomBarWhenPushed', b), 'definesPresentationContext': ('definesPresentationContext', b),
    'providesPresentationContextTransitionStyle': ('providesPresentationContextTransitionStyle', b),
    'storyboardIdentifier': ('$storyboardIdentifier', s), 'restorationIdentifier': ('restorationIdentifier', s),
    'modalInPresentation': ('modalInPresentation', b), 'extendedLayoutIncludesOpaqueBars': ('extendedLayoutIncludesOpaqueBars', b),
    'clearsSelectionOnViewWillAppear': ('clearsSelectionOnViewWillAppear', b),
    'toolbarHidden': ('$toolbarHidden', b), 'navigationBarHidden': ('$navigationBarHidden', b),
    'transitionStyle': ('$pageTransitionStyle', enum('transitionStyle')),
    'navigationOrientation': ('$pageNavigationOrientation', enum('navigationOrientation')),
    'spineLocation': ('$pageSpineLocation', enum('spineLocation')),
    'automaticallyAdjustsScrollViewInsets': None, 'autoresizesArchivedViewToFullSize': None, 'wantsFullScreenLayout': None,
    'sceneMemberID': None, 'customClass': None, 'customModule': None, 'customModuleProvider': None, 'id': None,
    'userLabel': None, 'useStoryboardIdentifierAsRestorationIdentifier': None, 'interfaceStyle': ('$userInterfaceStyle', s),
}
OBJECT_ATTRS = {
    'navigationItem': {'title': ('title', s), 'prompt': ('prompt', s), 'largeTitleDisplayMode': ('largeTitleDisplayMode', enum('largeTitleDisplayMode')),
                       'leftItemsSupplementBackButton': ('leftItemsSupplementBackButton', b), 'backButtonTitle': ('backButtonTitle', s),
                       'hidesBackButton': ('hidesBackButton', b), 'style': None, 'backButtonDisplayMode': None},
    'barButtonItem': {'title': ('title', s), 'image': ('$image', s), 'style': ('$barButtonStyle', enum('barButtonStyle')),
                      'systemItem': ('$systemItem', enum('barButtonSystemItem')), 'width': ('width', f), 'enabled': ('enabled', b),
                      'tag': ('tag', i), 'catalog': None, 'landscapeImage': None, 'largeContentSizeImage': None, 'springLoaded': None,
                      'selected': None, 'changesSelectionAsPrimaryAction': None},
    'tabBarItem': {'title': ('title', s), 'image': ('$image', s), 'selectedImage': ('$selectedImage', s), 'catalog': None,
                   'systemItem': ('$systemItem', enum('tabBarSystemItem')), 'tag': ('tag', i), 'badgeValue': ('badgeValue', s),
                   'enabled': ('enabled', b), 'largeContentSizeImage': None},
    'tapGestureRecognizer': {'numberOfTapsRequired': ('numberOfTapsRequired', i), 'numberOfTouchesRequired': ('numberOfTouchesRequired', i)},
    'swipeGestureRecognizer': {'direction': ('direction', enum('swipeDirection')), 'numberOfTouchesRequired': ('numberOfTouchesRequired', i)},
    'pongPressGestureRecognizer': {'minimumPressDuration': ('minimumPressDuration', f), 'allowableMovement': ('allowableMovement', f),
                                   'numberOfTapsRequired': ('numberOfTapsRequired', i), 'numberOfTouchesRequired': ('numberOfTouchesRequired', i)},
    'panGestureRecognizer': {'minimumNumberOfTouches': ('minimumNumberOfTouches', i), 'maximumNumberOfTouches': ('maximumNumberOfTouches', i)},
    'screenEdgePanGestureRecognizer': {'edges': None},
    'collectionViewFlowLayout': {'minimumLineSpacing': ('minimumLineSpacing', f), 'minimumInteritemSpacing': ('minimumInteritemSpacing', f),
                                 'scrollDirection': ('scrollDirection', enum('scrollDirection')),
                                 'automaticEstimatedItemSize': ('$automaticEstimatedItemSize', b),
                                 'sectionHeadersPinToVisibleBounds': ('sectionHeadersPinToVisibleBounds', b),
                                 'sectionFootersPinToVisibleBounds': ('sectionFootersPinToVisibleBounds', b), 'sectionInsetReference': None},
    'customObject': {},
}
GESTURE_COMMON = {'cancelsTouchesInView': ('cancelsTouchesInView', b), 'delaysTouchesBegan': ('delaysTouchesBegan', b),
                  'delaysTouchesEnded': ('delaysTouchesEnded', b), 'enabled': ('enabled', b)}
IGNORED_ATTRS = {'id', 'customClass', 'customModule', 'customModuleProvider', 'userLabel', 'key', 'opaque', 'fixedFrame',
                 'misplaced', 'ambiguous', 'placeholderIntrinsicWidth', 'placeholderIntrinsicHeight', 'sceneMemberID',
                 'adjustsLetterSpacingToFitWidth', 'catalog', 'insetsLayoutMarginsFromSafeArea_', 'focusStyle', 'clearsContextBeforeDrawing',
                 'autoresizesSubviews', 'contentModeAppearance', 'springLoaded', 'colorLabel', 'verticalHuggingPriority_',
                 'translatesAutoresizingMaskIntoConstraints_', 'canCancelContentTouches', 'delaysContentTouches', 'keyboardDismissMode_',
                 'preservesSuperviewLayoutMargins_', 'layoutMarginsFollowReadableWidth', 'indicatorStyle', 'insetsContentViewsToSafeArea',
                 'contentViewInsetsToSafeArea', 'tableViewCell', 'customSize', 'dataMode_', 'symbolScale', 'renderingMode'}


class CompileError(Exception):
    pass


# ---------------- typed values ----------------
def color_value(el, system_colors):
    if el.get('systemColor'):
        return {'$t': 'color', 'system': el.get('systemColor')}
    if el.get('cocoaTouchSystemColor'):
        return {'$t': 'color', 'system': el.get('cocoaTouchSystemColor')}
    if el.get('name'):
        return {'$t': 'color', 'named': el.get('name')}
    if el.get('white') is not None:
        w = float(el.get('white'))
        return {'$t': 'color', 'rgba': [w, w, w, float(el.get('alpha', '1'))]}
    if el.get('red') is not None:
        return {'$t': 'color', 'rgba': [float(el.get('red')), float(el.get('green', '0')), float(el.get('blue', '0')),
                                         float(el.get('alpha', '1'))], 'space': el.get('customColorSpace') or el.get('colorSpace', 'sRGB')}
    return {'$t': 'nil'}


def font_value(el):
    d = {'$t': 'font'}
    if el.get('style'):
        d['textStyle'] = el.get('style')                      # UICTFontTextStyleBody, ...
    elif el.get('name'):
        d['name'] = el.get('name')
        d['size'] = float(el.get('pointSize', '17'))
    else:
        kind = el.get('type', 'system')
        d['system'] = {'system': 'regular', 'boldSystem': 'bold', 'italicSystem': 'italic'}.get(kind, 'regular')
        if el.get('weight'):
            d['weight'] = el.get('weight')
        d['size'] = float(el.get('pointSize', '17'))
    return d


def image_value(name, catalog):
    if not name:
        return {'$t': 'nil'}
    return {'$t': 'image', 'name': name, 'system': catalog == 'system'}


def rect_value(el):
    return {'$t': 'rect', 'v': [float(el.get(k, '0')) for k in ('x', 'y', 'width', 'height')]}


def size_value(el):
    return {'$t': 'size', 'v': [float(el.get('width', '0')), float(el.get('height', '0'))]}


def insets_from_minmax(el):        # <inset key="sectionInset" minX minY maxX maxY>
    return {'$t': 'insets', 'v': [float(el.get('minY', '0')), float(el.get('minX', '0')), float(el.get('maxY', '0')), float(el.get('maxX', '0'))]}


def autoresizing_value(el):
    m = 0
    for attr, bit in (('flexibleMinX', 1), ('widthSizable', 2), ('flexibleMaxX', 4), ('flexibleMinY', 8),
                      ('heightSizable', 16), ('flexibleMaxY', 32)):
        if el.get(attr) == 'YES':
            m |= bit
    return m


def runtime_attr_value(el, system_colors):
    t = el.get('type')
    child = next(iter(el), None)
    if t in ('boolean',):
        v = el.get('value')
        if v is None and child is not None:
            v = child.get('value')
        return b(v)
    if t == 'number':
        if child is not None:
            v = child.get('value')
            return int(v) if child.tag == 'integer' else float(v)
        return float(el.get('value', '0'))
    if t in ('string', 'localizedString'):
        return el.get('value', '')
    if t == 'color' and child is not None:
        return color_value(child, system_colors)
    if t == 'image':
        return image_value(el.get('value') or (child.get('value') if child is not None else None), None)
    if t == 'point' and child is not None:
        return {'$t': 'point', 'v': [float(child.get('x', '0')), float(child.get('y', '0'))]}
    if t == 'size' and child is not None:
        return size_value(child)
    if t == 'rect' and child is not None:
        return rect_value(child)
    if t == 'range' and child is not None:
        return {'$t': 'range', 'v': [int(child.get('location', '0')), int(child.get('length', '0'))]}
    if t == 'nil':
        return {'$t': 'nil'}
    raise CompileError(f'user defined runtime attribute {el.get("keyPath")!r}: unsupported type {t!r}')


def attributed_text(el):
    return ''.join(fr.get('content', '') or ''.join(fr.itertext()) for fr in el.iter('fragment'))


# ---------------- compiler ----------------
class Compiler:
    def __init__(self, path, root, warn):
        self.path = path
        self.root = root
        self.warn = warn
        self.system_colors = {}
        self.unknown = {}

    def note_unknown(self, tag, attr):
        self.unknown.setdefault(f'{tag}.{attr}', 0)
        self.unknown[f'{tag}.{attr}'] += 1

    # an archive context collects connections, guides and placeholders for one instantiable unit
    def new_archive(self):
        return {'objects': [], 'placeholders': {}, 'connections': [], 'guides': {}}

    def attrs(self, el, node, tables):
        for name, value in el.attrib.items():
            conv = None
            known = False
            for t in tables:
                if name in t:
                    known = True
                    conv = t[name]
                    break
            if not known:
                if name not in IGNORED_ATTRS:
                    self.note_unknown(el.tag, name)
                continue
            if conv is None:
                continue
            key, fn = conv
            try:
                node['props'][key] = fn(value)
            except ValueError as e:
                self.warn(f'{el.tag} {el.get("id")}: {e}')

    def custom_class(self, el, node):
        if el.get('customClass'):
            node['customClass'] = el.get('customClass')
            if el.get('customModule'):
                node['customModule'] = el.get('customModule')
            elif el.get('customModuleProvider') == 'target':
                node['customModuleProvider'] = 'target'

    def connections(self, el, source, arc):
        for c in el:
            conn = {'source': source, 'destination': c.get('destination'), 'id': c.get('id', '')}
            if c.tag == 'outlet':
                conn.update(type='outlet', property=c.get('property'))
            elif c.tag == 'outletCollection':
                conn.update(type='outletCollection', property=c.get('property'), appends=c.get('appends') == 'YES')
            elif c.tag == 'action':
                conn.update(type='action', selector=c.get('selector'))
                if c.get('eventType'):
                    conn['events'] = CONTROL_EVENTS.get(c.get('eventType'), 1 << 6)
            elif c.tag == 'segue':
                conn.update(type='segue', kind=c.get('kind', 'show'))
                for k in ('identifier', 'relationship', 'unwindAction', 'customClass', 'customModule', 'trigger'):
                    if c.get(k):
                        conn[k] = c.get(k)
                if c.get('modalPresentationStyle'):
                    conn['modalPresentationStyle'] = E['modalPresentationStyle'][c.get('modalPresentationStyle')]
                if c.get('modalTransitionStyle'):
                    conn['modalTransitionStyle'] = E['modalTransitionStyle'][c.get('modalTransitionStyle')]
                if c.get('animates') == 'NO':
                    conn['animates'] = False
            else:
                self.note_unknown('connections', c.tag)
                continue
            arc['connections'].append(conn)

    def runtime_attrs(self, el, node):
        out = []
        for a in el:
            try:
                out.append({'keyPath': a.get('keyPath'), 'value': runtime_attr_value(a, self.system_colors)})
            except CompileError as e:
                self.warn(str(e))
        if out:
            node['userDefined'] = out

    def constraints(self, el, owner, arc):
        out = []
        for c in el:
            if c.tag != 'constraint':
                continue
            if c.get('placeholder') == 'YES':
                continue                                    # removed at build time, as Xcode does
            first_attr = LAYOUT_ATTRIBUTES.get(c.get('firstAttribute'))
            if first_attr is None:
                self.warn(f'constraint {c.get("id")}: unknown attribute {c.get("firstAttribute")}')
                continue
            d = {'first': c.get('firstItem') or owner, 'firstAttr': first_attr,
                 'relation': {'lessThanOrEqual': -1, 'greaterThanOrEqual': 1}.get(c.get('relation'), 0),
                 'constant': float(c.get('constant', '0')), 'priority': float(c.get('priority', '1000'))}
            if c.get('secondItem') or c.get('secondAttribute'):
                d['second'] = c.get('secondItem') or owner
                d['secondAttr'] = LAYOUT_ATTRIBUTES.get(c.get('secondAttribute'), 0)
            m = c.get('multiplier')
            if m:
                if ':' in m:
                    a_, b_ = m.split(':')
                    d['multiplier'] = float(a_) / float(b_)
                else:
                    d['multiplier'] = float(m)
            else:
                d['multiplier'] = 1.0
            if c.get('identifier'):
                d['identifier'] = c.get('identifier')
            d['id'] = c.get('id', '')
            out.append(d)
        return out

    # ---- generic element -> node ----
    def node(self, el, arc):
        tag = el.tag
        node = {'id': el.get('id', ''), 'class': ALL_CLASSES.get(tag, 'NSObject'), 'tag': tag, 'props': {}}
        self.custom_class(el, node)
        if tag in VIEW_CLASSES:
            tables = [TAG_ATTRS.get(tag, {}), VIEW_ATTRS]
            if tag in ('button', 'switch', 'slider', 'stepper', 'segmentedControl', 'textField', 'datePicker', 'pageControl', 'colorWell'):
                tables.append(CONTROL_ATTRS)
            if tag in ('scrollView', 'tableView', 'collectionView', 'textView'):
                tables.append(SCROLL_ATTRS)
            self.attrs(el, node, tables)
            if tag == 'imageView' and el.get('image'):
                node['props']['image'] = image_value(el.get('image'), el.get('catalog'))
                node['props'].pop('$image', None)
            if tag == 'imageView' and el.get('highlightedImage'):
                node['props']['highlightedImage'] = image_value(el.get('highlightedImage'), el.get('catalog'))
                node['props'].pop('$highlightedImage', None)
            self.view_children(el, node, arc)
        elif tag in CONTROLLER_CLASSES:
            self.attrs(el, node, [CONTROLLER_ATTRS])
            if el.get('useStoryboardIdentifierAsRestorationIdentifier') == 'YES' and el.get('storyboardIdentifier'):
                node['props']['restorationIdentifier'] = el.get('storyboardIdentifier')   # "Use Storyboard ID"
            self.controller_children(el, node, arc)
        else:
            tables = [OBJECT_ATTRS.get(tag, {})]
            if tag.endswith('GestureRecognizer'):
                tables.append(GESTURE_COMMON)
            self.attrs(el, node, tables)
            if tag in ('barButtonItem', 'tabBarItem'):
                for attr, key in (('image', 'image'), ('selectedImage', 'selectedImage')):
                    if el.get(attr):
                        node['props'][key] = image_value(el.get(attr), el.get('catalog'))
                        node['props'].pop('$' + attr, None)
            self.object_children(el, node, arc)
        return node

    def common_child(self, c, node, arc):
        """Children every object can have. Returns True when handled."""
        key = c.get('key')
        if c.tag == 'connections':
            self.connections(c, node['id'], arc)
        elif c.tag == 'userDefinedRuntimeAttributes':
            self.runtime_attrs(c, node)
        elif c.tag == 'color' and key:
            node['props'][key] = color_value(c, self.system_colors)
        elif c.tag == 'nil' and key:
            node['props'][key] = {'$t': 'nil'}
        elif c.tag == 'string' and key:
            node['props'][key] = c.text or ''
        elif c.tag == 'attributedString' and key:
            node['props'][{'attributedText': 'text', 'attributedTitle': 'title', 'attributedPlaceholder': 'placeholder'}.get(key, key)] = attributed_text(c)
        elif c.tag in ('real', 'integer') and key:
            node['props'][key] = float(c.get('value')) if c.tag == 'real' else int(c.get('value'))
        elif c.tag == 'bool' and key:
            node['props'][key] = b(c.get('value'))
        elif c.tag == 'imageReference' and key:
            node['props'][key] = image_value(c.get('image'), c.get('catalog'))
            if c.get('symbolScale') or c.get('renderingMode'):
                node['props'][key]['scale'] = c.get('symbolScale')
                node['props'][key]['rendering'] = c.get('renderingMode')
        elif c.tag == 'date' and key:
            node['props'][key] = {'$t': 'date', 'v': float(c.get('timeIntervalSinceReferenceDate', '0'))}
        elif c.tag == 'locale' and key:
            node['props'][key] = {'$t': 'locale', 'v': c.get('localeIdentifier', 'en_US')}
        elif c.tag == 'accessibility':
            for k, prop in (('identifier', 'accessibilityIdentifier'), ('label', 'accessibilityLabel'),
                            ('hint', 'accessibilityHint'), ('value', 'accessibilityValue')):
                if c.get(k) is not None:
                    node['props'][prop] = c.get(k)
            for sub in c:
                if sub.tag == 'bool' and sub.get('key') == 'isElement':
                    node['props']['isAccessibilityElement'] = b(sub.get('value'))
        elif c.tag in ('point', 'simulatedMetricsContainer', 'simulatedStatusBarMetrics', 'simulatedTopBarMetrics',
                       'simulatedOrientationMetrics', 'simulatedScreenMetrics', 'freeformSimulatedSizeMetrics',
                       'simulatedNavigationBarMetrics', 'simulatedTabBarMetrics', 'variation', 'freeformSize',
                       'size') and key in ('canvasLocation', 'freeformSize', None, 'customSize'):
            pass
        elif c.tag == 'variation':
            pass                                            # size-class variations: the base values are used
        else:
            return False
        return True

    def view_children(self, el, node, arc):
        tag = el.tag
        for c in el:
            key = c.get('key')
            if self.common_child(c, node, arc):
                continue
            if c.tag == 'rect' and key == 'frame':
                node['props']['frame'] = rect_value(c)
            elif c.tag == 'autoresizingMask':
                node['props']['autoresizingMask'] = autoresizing_value(c)
            elif c.tag == 'fontDescription':
                fkey = 'font'
                if tag == 'button':
                    fkey = '$titleFont'
                elif key not in ('fontDescription', None):
                    fkey = key.replace('FontDescription', 'Font')
                node['props'][fkey] = font_value(c)
            elif c.tag == 'subviews':
                node['subviews'] = [self.node(v, arc) for v in c if v.tag in VIEW_CLASSES]
                for v in c:
                    if v.tag not in VIEW_CLASSES:
                        self.warn(f'{self.path}: unsupported view element <{v.tag}> (skipped)')
            elif c.tag == 'constraints':
                node['constraints'] = self.constraints(c, node['id'], arc)
            elif c.tag == 'viewLayoutGuide':
                kind = GUIDE_KINDS.get(key)
                if kind:
                    arc['guides'][c.get('id')] = {'view': node['id'], 'kind': kind}
            elif c.tag == 'edgeInsets' and key:
                node['props'][key] = {'$t': 'insets', 'v': [float(c.get(k, '0')) for k in ('top', 'left', 'bottom', 'right')]}
            elif c.tag == 'directionalEdgeInsets' and key:
                node['props'][key] = {'$t': 'dinsets', 'v': [float(c.get(k, '0')) for k in ('top', 'leading', 'bottom', 'trailing')]}
            elif c.tag == 'inset' and key:
                node['props'][key] = insets_from_minmax(c)
            elif c.tag == 'size' and key:
                node['props'][key] = size_value(c)
            elif c.tag == 'textInputTraits':
                self.attrs(c, node, [INPUT_TRAIT_ATTRS])
            elif c.tag == 'state':
                st = {'state': {'normal': 0, 'highlighted': 1, 'disabled': 2, 'selected': 4}.get(key, 0)}
                if c.get('title') is not None:
                    st['title'] = c.get('title')
                if c.get('image'):
                    st['image'] = image_value(c.get('image'), c.get('catalog'))
                if c.get('backgroundImage'):
                    st['backgroundImage'] = image_value(c.get('backgroundImage'), c.get('catalog'))
                for sub in c:
                    if sub.tag == 'color' and sub.get('key') == 'titleColor':
                        st['titleColor'] = color_value(sub, self.system_colors)
                    elif sub.tag == 'imageReference' and sub.get('key') == 'image':
                        st['image'] = image_value(sub.get('image'), sub.get('catalog'))
                    elif sub.tag == 'color' and sub.get('key') == 'titleShadowColor':
                        pass
                    elif sub.tag == 'attributedString':
                        st['title'] = attributed_text(sub)
                node['props'].setdefault('$states', []).append(st)
            elif c.tag == 'buttonConfiguration':
                node['props']['$configuration'] = self.button_configuration(c)
            elif c.tag == 'segments':
                segs = []
                for sg in c:
                    d = {}
                    if sg.get('title') is not None:
                        d['title'] = sg.get('title')
                    if sg.get('image'):
                        d['image'] = image_value(sg.get('image'), sg.get('catalog'))
                    if sg.get('enabled') == 'NO':
                        d['enabled'] = False
                    segs.append(d)
                node['props']['$segments'] = segs
            elif c.tag == 'preferredSymbolConfiguration':
                node['props'][key or 'preferredSymbolConfiguration'] = {
                    '$t': 'symbolConfig', 'scale': E['symbolScale'].get(c.get('scale', 'unspecified'), 0),
                    'weight': E['symbolWeight'].get(c.get('weight', 'unspecified'), 0), 'size': float(c.get('pointSize', '0')),
                    'textStyle': c.get('configurationType') == 'font' and (next(iter(c), None) is not None and next(iter(c)).get('style')) or None}
            elif c.tag == 'prototypes' or (c.tag == 'cells' and tag == 'collectionView'):
                node['prototypes'] = [self.template(cell) for cell in c]
            elif c.tag == 'sections' and tag == 'tableView':
                node['staticSections'] = []
                for sec in c:
                    sd = {'cells': [self.template(cell) for cell in sec.iter('tableViewCell')]}
                    for k in ('headerTitle', 'footerTitle'):
                        if sec.get(k) is not None:
                            sd[k] = sec.get(k)
                    node['staticSections'].append(sd)
            elif c.tag == 'collectionReusableView' and key in ('sectionHeaderView', 'sectionFooterView'):
                t = self.template(c)
                t['supplementaryKind'] = 'UICollectionElementKindSectionHeader' if key == 'sectionHeaderView' else 'UICollectionElementKindSectionFooter'
                node.setdefault('prototypes', []).append(t)
            elif key and (c.tag in ALL_CLASSES):
                node.setdefault('keyed', {})[key] = self.node(c, arc)
            elif c.tag in ('items', 'toolbarItems') or (c.tag.endswith('Items') and key is None):
                node.setdefault('keyed', {})[c.tag] = [self.node(x, arc) for x in c]
            elif c.tag == 'gestureRecognizers':
                pass
            else:
                self.note_unknown(tag, '<' + c.tag + (f' key={key}' if key else '') + '>')

    def button_configuration(self, c):
        d = {'style': c.get('style', 'plain')}
        for k in ('title', 'subtitle'):
            if c.get(k) is not None:
                d[k] = c.get(k)
        if c.get('image'):
            d['image'] = image_value(c.get('image'), c.get('catalog'))
        for k, table in (('cornerStyle', 'cornerStyle'), ('buttonSize', 'buttonSize'), ('imagePlacement', 'imagePlacement')):
            if c.get(k):
                d[k] = E[table].get(c.get(k), 0)
        if c.get('imagePadding'):
            d['imagePadding'] = float(c.get('imagePadding'))
        for sub in c:
            if sub.tag == 'color' and sub.get('key') in ('baseForegroundColor', 'baseBackgroundColor'):
                d[sub.get('key')] = color_value(sub, self.system_colors)
            elif sub.tag == 'imageReference' and sub.get('key') == 'image':
                d['image'] = image_value(sub.get('image'), sub.get('catalog'))
            elif sub.tag == 'directionalEdgeInsets' and sub.get('key') == 'contentInsets':
                d['contentInsets'] = {'$t': 'dinsets', 'v': [float(sub.get(k, '0')) for k in ('top', 'leading', 'bottom', 'trailing')]}
            elif sub.tag == 'fontDescription':
                d['font'] = font_value(sub)
            elif sub.tag == 'attributedString':
                d['title'] = attributed_text(sub)
        return d

    def template(self, el):
        """A prototype/static cell: its own archive (instantiated per cell)."""
        arc = self.new_archive()
        arc['root'] = self.node(el, arc)
        return arc

    def controller_children(self, el, node, arc):
        for c in el:
            key = c.get('key')
            if self.common_child(c, node, arc):
                continue
            if key and c.tag in ALL_CLASSES:
                node.setdefault('keyed', {})[key] = self.node(c, arc)
            elif c.tag == 'toolbarItems':
                node.setdefault('keyed', {})['toolbarItems'] = [self.node(x, arc) for x in c]
            elif c.tag == 'layoutGuides':
                for g in c:
                    if g.tag == 'viewControllerLayoutGuide':
                        arc['guides'][g.get('id')] = {'view': '$vc', 'kind': 'top' if g.get('type') == 'top' else 'bottom'}
            elif c.tag in ('extendedEdge', 'size', 'tabBarItem'):
                pass
            else:
                self.note_unknown(el.tag, '<' + c.tag + (f' key={key}' if key else '') + '>')

    def object_children(self, el, node, arc):
        for c in el:
            key = c.get('key')
            if self.common_child(c, node, arc):
                continue
            if key and c.tag in ALL_CLASSES:
                node.setdefault('keyed', {})[key] = self.node(c, arc)
            elif c.tag in ('leftBarButtonItems', 'rightBarButtonItems'):
                node.setdefault('keyed', {})[c.tag] = [self.node(x, arc) for x in c]
            elif c.tag == 'size' and key:
                node['props'][key] = size_value(c)
            elif c.tag == 'inset' and key:
                node['props'][key] = insets_from_minmax(c)
            elif c.tag == 'navigationBarAppearance' or c.tag == 'tabBarAppearance' or c.tag == 'toolbarAppearance':
                pass
            else:
                self.note_unknown(el.tag, '<' + c.tag + (f' key={key}' if key else '') + '>')

    def resources(self):
        for r in self.root.iter('resources'):
            for sc in r:
                if sc.tag == 'systemColor':
                    col = next(iter(sc), None)
                    if col is not None:
                        self.system_colors[sc.get('name')] = color_value(col, {})

    def top_level(self, objects, arc):
        """Objects of a scene or a xib: placeholders, the controller/views, other objects."""
        nodes = []
        for el in objects:
            if el.tag == 'placeholder':
                ident = el.get('placeholderIdentifier')
                arc['placeholders'][el.get('id')] = {'IBFilesOwner': 'owner', 'IBFirstResponder': 'firstResponder'}.get(ident, ident)
                for c in el:
                    if c.tag == 'connections':
                        self.connections(c, el.get('id'), arc)
            elif el.tag == 'exit':
                arc['placeholders'][el.get('id')] = 'exit'
            elif el.tag == 'viewControllerPlaceholder':
                arc['reference'] = {'id': el.get('id'), 'storyboardName': el.get('storyboardName'),
                                    'referencedIdentifier': el.get('referencedIdentifier'), 'bundleIdentifier': el.get('bundleIdentifier')}
            elif el.tag in ALL_CLASSES:
                nodes.append(self.node(el, arc))
            else:
                self.warn(f'{self.path}: unsupported top-level object <{el.tag}> (skipped)')
        return nodes


def compile_document(path, warn=lambda m: print(f'ibtool: warning: {m}', file=sys.stderr)):
    tree = ET.parse(path)
    root = tree.getroot()
    if root.tag != 'document':
        raise CompileError(f'{path}: not an Interface Builder XML document')
    doc_type = root.get('type', '')
    if not doc_type.startswith('com.apple.InterfaceBuilder3.CocoaTouch'):
        raise CompileError(f'{path}: unsupported document type {doc_type!r} (only iOS documents)')
    comp = Compiler(path, root, warn)
    comp.resources()
    name = os.path.splitext(os.path.basename(path))[0]
    if doc_type.endswith('.Storyboard.XIB'):
        out = {'format': 'isim-storyboard', 'version': FORMAT_VERSION, 'source': os.path.basename(path),
               'scenes': {}, 'identifiers': {}}
        if root.get('initialViewController'):
            out['initialViewController'] = root.get('initialViewController')
        for scene in root.iter('scene'):
            objects = scene.find('objects')
            if objects is None:
                continue
            arc = comp.new_archive()
            nodes = comp.top_level(objects, arc)
            vc = next((n for n in nodes if n['tag'] in CONTROLLER_CLASSES), None)
            if 'reference' in arc:                         # storyboard reference scene
                out['scenes'][arc['reference']['id']] = {'reference': arc['reference'], 'objects': [], 'placeholders': {}, 'connections': []}
                continue
            if vc is None:
                warn(f'{path}: scene {scene.get("sceneID")} has no view controller (skipped)')
                continue
            arc['root'] = vc
            arc['objects'] = [n for n in nodes if n is not vc]
            out['scenes'][vc['id']] = arc
            sbid = vc['props'].get('$storyboardIdentifier')
            if sbid:
                out['identifiers'][sbid] = vc['id']
        kind = 'storyboard'
    else:
        arc = comp.new_archive()
        objects = root.find('objects')
        arc['objects'] = comp.top_level(objects if objects is not None else [], arc)
        out = {'format': 'isim-nib', 'version': FORMAT_VERSION, 'source': os.path.basename(path), 'archive': arc}
        kind = 'nib'
    for k, n in sorted(comp.unknown.items()):
        warn(f'{os.path.basename(path)}: ignored {k} (x{n})')
    return name, kind, out


def strip_none(v):
    if isinstance(v, dict):
        return {k: strip_none(x) for k, x in v.items() if x is not None}
    if isinstance(v, list):
        return [strip_none(x) for x in v if x is not None]
    return v


def write_output(name, kind, data, outdir):
    """Writes <outdir>/<Name>.storyboardc/isim-storyboard.plist or <outdir>/<Name>.nib/isim-nib.plist."""
    if kind == 'storyboard':
        d = os.path.join(outdir, name + '.storyboardc')
        fn = 'isim-storyboard.plist'
    else:
        d = os.path.join(outdir, name + '.nib')
        fn = 'isim-nib.plist'
    if os.path.isfile(d):
        os.remove(d)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, fn), 'wb') as fh:
        plistlib.dump(strip_none(data), fh, fmt=plistlib.FMT_XML, sort_keys=True)
    return d


def compile_to(path, outdir, warn=None):
    kw = {'warn': warn} if warn else {}
    name, kind, data = compile_document(path, **kw)
    return write_output(name, kind, data, outdir)


def main():
    ap = argparse.ArgumentParser(prog='ibtool.py', description='Compile .storyboard/.xib to isim\'s IB runtime format (not Apple\'s .nib).')
    ap.add_argument('documents', nargs='+')
    ap.add_argument('-o', '--output', required=True, help='output directory (the app bundle or a .lproj in it)')
    ap.add_argument('-q', '--quiet', action='store_true')
    a = ap.parse_args()
    warn = (lambda m: None) if a.quiet else None
    for doc in a.documents:
        try:
            d = compile_to(doc, a.output, warn)
        except (CompileError, ET.ParseError) as e:
            sys.exit(f'ibtool: error: {e}')
        if not a.quiet:
            print(f'ibtool: {doc} -> {d}')


if __name__ == '__main__':
    main()
