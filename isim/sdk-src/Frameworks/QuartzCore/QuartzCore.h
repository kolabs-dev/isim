#pragma once
/* isim QuartzCore for Objective-C: Core Animation (CALayer and its subclasses, the animations, CATransaction,
 * CADisplayLink, CATransform3D, CAMediaTiming) is implemented in isim's UIKit; QuartzCore.framework re-exports it,
 * so `#import <QuartzCore/QuartzCore.h>` and `-framework QuartzCore` work as on iOS. Swift uses the QuartzCore
 * overlay, which re-exports UIKit, so these headers are hidden from Swift. Not in isim: CAMetalLayer, CAEAGLLayer. */
#import <QuartzCore/CABase.h>
#import <QuartzCore/CATransform3D.h>
#import <QuartzCore/CAMediaTiming.h>
#import <QuartzCore/CALayer.h>
#import <QuartzCore/CAAnimation.h>
#import <QuartzCore/CAMediaTimingFunction.h>
#import <QuartzCore/CADisplayLink.h>
#import <QuartzCore/CATransaction.h>
#import <QuartzCore/CAShapeLayer.h>
#import <QuartzCore/CAGradientLayer.h>
#import <QuartzCore/CATextLayer.h>
#import <QuartzCore/CAReplicatorLayer.h>
#import <QuartzCore/CATransformLayer.h>
#import <QuartzCore/CAScrollLayer.h>
#import <QuartzCore/CAEmitterLayer.h>
#import <QuartzCore/CAEmitterCell.h>
#import <QuartzCore/CAValueFunction.h>
