// Extra.bundle (MH_BUNDLE in PlugIns/): no NSPrincipalClass, so the principal class is the first class it defines
#import <Foundation/Foundation.h>
@interface ExtraFirst : NSObject - (int)answer; @end
@implementation ExtraFirst - (int)answer { return 7; } @end
@interface ExtraSecond : NSObject @end
@implementation ExtraSecond @end
