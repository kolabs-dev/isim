#pragma once
#import <Foundation/Foundation.h>
#import <XCTest/XCUIElement.h>

NS_ASSUME_NONNULL_BEGIN

@class UIImage;

/* A screenshot of the app under test (isim: the device screen the app's process draws, script command `shot`),
 * or of one element (that part of it). */
@interface XCUIScreenshot : NSObject
@property (readonly) UIImage *image;
@property (readonly, copy) NSData *PNGRepresentation;
@end

@protocol XCUIScreenshotProviding <NSObject>
- (XCUIScreenshot *)screenshot;
@end

/* The device's screen. isim: one screen, showing the most recently launched or activated app under test. */
@interface XCUIScreen : NSObject <XCUIScreenshotProviding>
@property (class, readonly) XCUIScreen *mainScreen;
@property (class, readonly) NSArray<XCUIScreen *> *screens;
- (XCUIScreenshot *)screenshot;
@end

@interface XCUIElement (XCUIScreenshotProviding) <XCUIScreenshotProviding>
- (XCUIScreenshot *)screenshot;
@end

NS_ASSUME_NONNULL_END
