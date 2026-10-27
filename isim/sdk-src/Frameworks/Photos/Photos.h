#pragma once
/* isim Photos for Objective-C: the classes are the Photos Swift overlay's (Photos.framework re-exports
   libswiftPhotos.dylib): the device photo library ($ISIM_DATA/Media, shared with UIKit's image picker), its permission
   alert, fetches, image and video requests, change requests (photos, videos, user albums) and resources. PHFetchResult and
   the change details are Objective-C classes of their own (frameworks/Photos/Photos.m), as Swift's are generic. Swift uses
   the overlay; these declarations are hidden from Swift. Live Photos and edits (PHContentEditingInput / Output); no
   iCloud, shared albums, folders (PHCollectionList) or persistent changes. The classes are not subclassable from
   Objective-C. */
#import <Photos/PhotosTypes.h>
#import <Photos/PHError.h>
#import <Photos/PHObject.h>
#import <Photos/PHFetchOptions.h>
#import <Photos/PHFetchResult.h>
#import <Photos/PHAsset.h>
#import <Photos/PHCollection.h>
#import <Photos/PHChange.h>
#import <Photos/PHPhotoLibrary.h>
#import <Photos/PHImageManager.h>
#import <Photos/PHAssetChangeRequest.h>
#import <Photos/PHAssetCollectionChangeRequest.h>
#import <Photos/PHAssetResource.h>
#import <Photos/PHAssetResourceManager.h>
#import <Photos/PHLivePhoto.h>
#import <Photos/PHContentEditing.h>
