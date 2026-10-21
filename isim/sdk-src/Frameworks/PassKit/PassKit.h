#pragma once
/* isim PassKit for Objective-C: the classes are the PassKit Swift overlay's (PassKit.framework re-exports
 * libswiftPassKit.dylib): Apple Pay through isim's simulated payment sheet with the device's test cards (a payment's
 * token is isim's test token, so nothing can be charged), and Wallet passes in isim's Wallet. Swift uses the overlay;
 * these declarations are hidden from Swift. The classes are not subclassable from Objective-C. */
#import <PassKit/PKDefines.h>
#import <PassKit/PKConstants.h>
#import <PassKit/PKError.h>
#import <PassKit/PKPaymentRequest.h>
#import <PassKit/PKPayment.h>
#import <PassKit/PKPaymentAuthorizationController.h>
#import <PassKit/PKPaymentAuthorizationViewController.h>
#import <PassKit/PKPaymentButton.h>
#import <PassKit/PKPass.h>
