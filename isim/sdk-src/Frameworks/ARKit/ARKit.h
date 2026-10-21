#pragma once
/* isim ARKit for Objective-C: the classes are the ARKit Swift overlay's (ARKit.framework re-exports libswiftARKit.dylib),
 * answering like Apple's Simulator, which has no camera tracking either: every configuration's isSupported is NO, a
 * session that runs one fails with ARErrorCodeUnsupportedConfiguration, and no frames arrive; the value types hold their
 * data. Swift uses the overlay; these declarations are hidden from Swift. The classes are not subclassable from
 * Objective-C. */
#import <ARKit/ARError.h>
#import <ARKit/ARReferenceImage.h>
#import <ARKit/ARAnchor.h>
#import <ARKit/ARConfiguration.h>
#import <ARKit/ARFrame.h>
#import <ARKit/ARSession.h>
#import <ARKit/ARSCNView.h>
