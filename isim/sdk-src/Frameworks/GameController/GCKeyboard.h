#pragma once
#import <GameController/GCController.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef CFIndex GCKeyCode NS_TYPED_ENUM;
static const GCKeyCode GCKeyCodeKeyA = 4;
static const GCKeyCode GCKeyCodeKeyB = 5;
static const GCKeyCode GCKeyCodeKeyC = 6;
static const GCKeyCode GCKeyCodeKeyD = 7;
static const GCKeyCode GCKeyCodeKeyE = 8;
static const GCKeyCode GCKeyCodeKeyF = 9;
static const GCKeyCode GCKeyCodeKeyG = 10;
static const GCKeyCode GCKeyCodeKeyH = 11;
static const GCKeyCode GCKeyCodeKeyI = 12;
static const GCKeyCode GCKeyCodeKeyJ = 13;
static const GCKeyCode GCKeyCodeKeyK = 14;
static const GCKeyCode GCKeyCodeKeyL = 15;
static const GCKeyCode GCKeyCodeKeyM = 16;
static const GCKeyCode GCKeyCodeKeyN = 17;
static const GCKeyCode GCKeyCodeKeyO = 18;
static const GCKeyCode GCKeyCodeKeyP = 19;
static const GCKeyCode GCKeyCodeKeyQ = 20;
static const GCKeyCode GCKeyCodeKeyR = 21;
static const GCKeyCode GCKeyCodeKeyS = 22;
static const GCKeyCode GCKeyCodeKeyT = 23;
static const GCKeyCode GCKeyCodeKeyU = 24;
static const GCKeyCode GCKeyCodeKeyV = 25;
static const GCKeyCode GCKeyCodeKeyW = 26;
static const GCKeyCode GCKeyCodeKeyX = 27;
static const GCKeyCode GCKeyCodeKeyY = 28;
static const GCKeyCode GCKeyCodeKeyZ = 29;
static const GCKeyCode GCKeyCodeOne = 30;
static const GCKeyCode GCKeyCodeTwo = 31;
static const GCKeyCode GCKeyCodeThree = 32;
static const GCKeyCode GCKeyCodeFour = 33;
static const GCKeyCode GCKeyCodeFive = 34;
static const GCKeyCode GCKeyCodeSix = 35;
static const GCKeyCode GCKeyCodeSeven = 36;
static const GCKeyCode GCKeyCodeEight = 37;
static const GCKeyCode GCKeyCodeNine = 38;
static const GCKeyCode GCKeyCodeZero = 39;
static const GCKeyCode GCKeyCodeReturnOrEnter = 40;
static const GCKeyCode GCKeyCodeEscape = 41;
static const GCKeyCode GCKeyCodeDeleteOrBackspace = 42;
static const GCKeyCode GCKeyCodeTab = 43;
static const GCKeyCode GCKeyCodeSpacebar = 44;
static const GCKeyCode GCKeyCodeHyphen = 45;
static const GCKeyCode GCKeyCodeEqualSign = 46;
static const GCKeyCode GCKeyCodeOpenBracket = 47;
static const GCKeyCode GCKeyCodeCloseBracket = 48;
static const GCKeyCode GCKeyCodeBackslash = 49;
static const GCKeyCode GCKeyCodeNonUSPound = 50;
static const GCKeyCode GCKeyCodeSemicolon = 51;
static const GCKeyCode GCKeyCodeQuote = 52;
static const GCKeyCode GCKeyCodeGraveAccentAndTilde = 53;
static const GCKeyCode GCKeyCodeComma = 54;
static const GCKeyCode GCKeyCodePeriod = 55;
static const GCKeyCode GCKeyCodeSlash = 56;
static const GCKeyCode GCKeyCodeCapsLock = 57;
static const GCKeyCode GCKeyCodeF1 = 58;
static const GCKeyCode GCKeyCodeF2 = 59;
static const GCKeyCode GCKeyCodeF3 = 60;
static const GCKeyCode GCKeyCodeF4 = 61;
static const GCKeyCode GCKeyCodeF5 = 62;
static const GCKeyCode GCKeyCodeF6 = 63;
static const GCKeyCode GCKeyCodeF7 = 64;
static const GCKeyCode GCKeyCodeF8 = 65;
static const GCKeyCode GCKeyCodeF9 = 66;
static const GCKeyCode GCKeyCodeF10 = 67;
static const GCKeyCode GCKeyCodeF11 = 68;
static const GCKeyCode GCKeyCodeF12 = 69;
static const GCKeyCode GCKeyCodePrintScreen = 70;
static const GCKeyCode GCKeyCodeScrollLock = 71;
static const GCKeyCode GCKeyCodePause = 72;
static const GCKeyCode GCKeyCodeInsert = 73;
static const GCKeyCode GCKeyCodeHome = 74;
static const GCKeyCode GCKeyCodePageUp = 75;
static const GCKeyCode GCKeyCodeDeleteForward = 76;
static const GCKeyCode GCKeyCodeEnd = 77;
static const GCKeyCode GCKeyCodePageDown = 78;
static const GCKeyCode GCKeyCodeRightArrow = 79;
static const GCKeyCode GCKeyCodeLeftArrow = 80;
static const GCKeyCode GCKeyCodeDownArrow = 81;
static const GCKeyCode GCKeyCodeUpArrow = 82;
static const GCKeyCode GCKeyCodeKeypadNumLock = 83;
static const GCKeyCode GCKeyCodeKeypadSlash = 84;
static const GCKeyCode GCKeyCodeKeypadAsterisk = 85;
static const GCKeyCode GCKeyCodeKeypadHyphen = 86;
static const GCKeyCode GCKeyCodeKeypadPlus = 87;
static const GCKeyCode GCKeyCodeKeypadEnter = 88;
static const GCKeyCode GCKeyCodeKeypad1 = 89;
static const GCKeyCode GCKeyCodeKeypad2 = 90;
static const GCKeyCode GCKeyCodeKeypad3 = 91;
static const GCKeyCode GCKeyCodeKeypad4 = 92;
static const GCKeyCode GCKeyCodeKeypad5 = 93;
static const GCKeyCode GCKeyCodeKeypad6 = 94;
static const GCKeyCode GCKeyCodeKeypad7 = 95;
static const GCKeyCode GCKeyCodeKeypad8 = 96;
static const GCKeyCode GCKeyCodeKeypad9 = 97;
static const GCKeyCode GCKeyCodeKeypad0 = 98;
static const GCKeyCode GCKeyCodeKeypadPeriod = 99;
static const GCKeyCode GCKeyCodeApplication = 101;
static const GCKeyCode GCKeyCodePower = 102;
static const GCKeyCode GCKeyCodeKeypadEqualSign = 103;
static const GCKeyCode GCKeyCodeLeftControl = 224;
static const GCKeyCode GCKeyCodeLeftShift = 225;
static const GCKeyCode GCKeyCodeLeftAlt = 226;
static const GCKeyCode GCKeyCodeLeftGUI = 227;
static const GCKeyCode GCKeyCodeRightControl = 228;
static const GCKeyCode GCKeyCodeRightShift = 229;
static const GCKeyCode GCKeyCodeRightAlt = 230;
static const GCKeyCode GCKeyCodeRightGUI = 231;
@class GCKeyboardInput;
typedef void (^GCKeyboardValueChangedHandler)(GCKeyboardInput *keyboard, GCControllerButtonInput *key, GCKeyCode keyCode, BOOL pressed);
API_AVAILABLE(ios(14.0))
@interface GCKeyboardInput : GCPhysicalInputProfile
@property (nonatomic, copy, nullable) GCKeyboardValueChangedHandler keyChangedHandler;
@property (nonatomic, readonly, getter=isAnyKeyPressed) BOOL anyKeyPressed;
- (nullable GCControllerButtonInput *)buttonForKeyCode:(GCKeyCode)code;
@end
/* isim: the host keyboard while the device window has focus */
API_AVAILABLE(ios(14.0))
@interface GCKeyboard : NSObject <GCDevice>
@property (nonatomic, readonly, strong, nullable) GCKeyboardInput *keyboardInput;
@property (class, atomic, readonly, nullable) GCKeyboard *coalescedKeyboard;
@end
NS_ASSUME_NONNULL_END
#endif
