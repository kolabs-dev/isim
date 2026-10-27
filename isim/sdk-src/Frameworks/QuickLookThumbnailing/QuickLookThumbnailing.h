#pragma once
/* QuickLookThumbnailing (issue #359): thumbnails and icons of files, made by isim (adapted): an app's Thumbnail
 * extension for the file's type first (com.apple.quicklook.thumbnail, loaded into the app like Quick Look Preview
 * extensions), else images through ImageIO, PDFs through PDFKit (the first page), videos through the host's ffmpeg
 * (a frame), text files drawn, and for everything an icon (a document with its filename extension). */
#import <QuickLookThumbnailing/QLThumbnailErrors.h>
#import <QuickLookThumbnailing/QLThumbnailRepresentation.h>
#import <QuickLookThumbnailing/QLThumbnailGenerator.h>
#import <QuickLookThumbnailing/QLThumbnailGenerationRequest.h>
#import <QuickLookThumbnailing/QLFileThumbnailRequest.h>
#import <QuickLookThumbnailing/QLThumbnailReply.h>
#import <QuickLookThumbnailing/QLThumbnailProvider.h>
