// Objective-C side: Xcode's GeneratedAssetSymbols.h names each asset (ACColorName..., ACImageName...).
#import <UIKit/UIKit.h>
#import "GeneratedAssetSymbols.h"

NSString *HelloObjCAssetNames(void) {
    UIColor *c = [UIColor colorNamed:ACColorNameBrandBlue];
    UIImage *i = [UIImage imageNamed:ACImageNameHeroImage];
    return [NSString stringWithFormat:@"%@ %@ color=%d image=%dx%d", ACColorNameBrandBlue, ACImageNameHeroImage, c != nil,
            (int)i.size.width, (int)i.size.height];
}
