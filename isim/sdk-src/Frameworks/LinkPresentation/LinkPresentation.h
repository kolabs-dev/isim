#pragma once
/* isim LinkPresentation for Objective-C: the classes are the LinkPresentation Swift overlay's (LinkPresentation.framework
   re-exports libswiftLinkPresentation.dylib): LPMetadataProvider fetches a page through URLSession and reads its title,
   Open Graph / Twitter card tags and icon links; LPLinkView draws the link card (isim's drawing of iOS's). Swift uses the
   overlay; these declarations are hidden from Swift. The classes are not subclassable from Objective-C. */
#import <LinkPresentation/LPError.h>
#import <LinkPresentation/LPLinkMetadata.h>
#import <LinkPresentation/LPMetadataProvider.h>
#import <LinkPresentation/LPLinkView.h>
