// Objective-C availability checks (@available -> __isPlatformVersionAtLeast in isim's libSystem), called from Swift.
#import <Foundation/Foundation.h>

int hov_objc_available(int major) {
    switch (major) {
    case 18: if (@available(iOS 18.0, *)) return 1; return 0;
    case 26: if (@available(iOS 26.0, *)) return 1; return 0;
    case 27: if (@available(iOS 27.0, *)) return 1; return 0;
    default: return -1;
    }
}
