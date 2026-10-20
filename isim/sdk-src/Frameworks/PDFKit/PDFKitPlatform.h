#pragma once
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

#define PDFKIT_EXTERN extern __attribute__((visibility("default")))
#define PDFKIT_AVAILABLE(macos, ios)
#define PDFKIT_CLASS_AVAILABLE(macos, ios)

#define PDFKitPlatformView UIView
#define PDFKitPlatformViewController UIViewController
#define PDFKitPlatformScrollView UIScrollView
#define PDFKitPlatformColor UIColor
#define PDFKitPlatformBezierPath UIBezierPath
#define PDFKitPlatformBezierPathElement CGPathElement
#define PDFKitPlatformImage UIImage
#define PDFKitPlatformImageView UIImageView
#define PDFKitPlatformEvent UIEvent
#define PDFKitPlatformFont UIFont
#define PDFKitPlatformControl UIControl
#define PDFKitPlatformTextField UITextField
#define PDFKitPlatformTextView UITextView
#define PDFKitPlatformTextViewDelegate UITextViewDelegate
#define PDFKitPlatformChoiceWidgetComboBoxView UIPickerView
#define PDFKitPlatformChoiceWidgetListView UITableView
#define PDFKitPlatformButton UIButton
#define PDFKitPlatformButtonCell UIButton
#define PDFKitPlatformAccessibilityElement UIAccessibilityElement
#define PDFKitResponder UIResponder
#define PDFKitEvent UIEvent
#define PDFKitEdgeInsets UIEdgeInsets

#define PDFPoint CGPoint
#define PDFRect CGRect
#define PDFSize CGSize
#define PDFEdgeInsets UIEdgeInsets
#define PDFEdgeInsetsZero UIEdgeInsetsZero
#define PDFRectZero CGRectZero
#define PDFPointZero CGPointZero
#define PDFSizeZero CGSizeZero
#define PDFRectEqualToRect CGRectEqualToRect
#define PDFPointEqualToPoint CGPointEqualToPoint
