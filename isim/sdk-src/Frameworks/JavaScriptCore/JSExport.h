#pragma once
#import <Foundation/Foundation.h>
/* Methods and properties of an Objective-C class that it declares in a protocol conforming to JSExport are visible to
   JavaScript: a selector becomes a function named by its parts ("doFoo:withBar:" -> doFooWithBar), or by JSExportAs. */
@protocol JSExport
@end
#define JSExportAs(PropertyName, Selector) \
    @optional Selector __JS_EXPORT_AS__##PropertyName:(id)argument; @required Selector
