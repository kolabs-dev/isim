#pragma once
/* isim PhotosUI for Objective-C: PHPickerViewController is the PhotosUI Swift overlay's (PhotosUI.framework re-exports
   libswiftPhotosUI.dylib); PHPickerConfiguration, PHPickerFilter and PHPickerResult are Objective-C classes of their own
   (frameworks/PhotosUI/PhotosUI.m), as Swift's are structs. Swift uses the overlay; these declarations are hidden from
   Swift. No PHLivePhotoView or PHContentEditingController. */
#import <PhotosUI/PHPicker.h>
