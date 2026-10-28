// isim FileProvider: the initial enumeration pages, NSData objects (made at load; the header declares them const).
// FileProvider.h is not imported here, so these definitions can be written once the data exists.
#import <Foundation/Foundation.h>

NSData *NSFileProviderInitialPageSortedByDate;
NSData *NSFileProviderInitialPageSortedByName;

__attribute__((constructor)) static void isim_fp_pages(void) {
    NSFileProviderInitialPageSortedByDate = [@"NSFileProviderInitialPageSortedByDate" dataUsingEncoding:NSUTF8StringEncoding];
    NSFileProviderInitialPageSortedByName = [@"NSFileProviderInitialPageSortedByName" dataUsingEncoding:NSUTF8StringEncoding];
}
