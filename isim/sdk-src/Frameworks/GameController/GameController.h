#pragma once
/* isim GameController for Objective-C: the classes are the GameController Swift overlay's (GameController.framework
   re-exports libswiftGameController.dylib): the host's gamepads, keyboard and mouse, and GCVirtualController's on-screen
   controller. Swift uses the overlay; these declarations are hidden from Swift. The iOS 17 physical-input API
   (GCDevicePhysicalInput and its protocols), GCEventViewController and GCEventInteraction are Swift-only. The classes are
   not subclassable from Objective-C. */
#import <GameController/GCExtern.h>
#import <GameController/GCControllerElement.h>
#import <GameController/GCPhysicalInputProfile.h>
#import <GameController/GCController.h>
#import <GameController/GCKeyboard.h>
#import <GameController/GCMouse.h>
#import <GameController/GCVirtualController.h>
