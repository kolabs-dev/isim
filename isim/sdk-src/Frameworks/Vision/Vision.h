#pragma once
/* isim Vision for Objective-C: the classes are the Vision Swift overlay's (Vision.framework re-exports
   libswiftVision.dylib): barcodes through the host's libzbar / zxing-cpp, text through the host's tesseract, faces and
   landmarks through Core Image's detector, rectangles, text rectangles, contours, the horizon and saliency through
   isim's own CPU detectors; Core ML, classification, feature prints, human rectangles and face capture quality fail
   with VNErrorUnsupportedRequest. Coordinates are normalized to the image, origin at the lower left. Swift uses the
   overlay; these declarations are hidden from Swift. No CMSampleBufferRef handlers (isim's CoreMedia has no C sample
   buffers). The classes are not subclassable from Objective-C. */
#import <Vision/VNDefines.h>
#import <Vision/VNError.h>
#import <Vision/VNTypes.h>
#import <Vision/VNUtils.h>
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#import <Vision/VNFaceLandmarks.h>
#import <Vision/VNRequestHandler.h>
#import <Vision/VNDetectBarcodesRequest.h>
#import <Vision/VNRecognizeTextRequest.h>
#import <Vision/VNDetectFaceRectanglesRequest.h>
#import <Vision/VNDetectFaceLandmarksRequest.h>
#import <Vision/VNDetectFaceCaptureQualityRequest.h>
#import <Vision/VNDetectHumanRectanglesRequest.h>
#import <Vision/VNClassifyImageRequest.h>
#import <Vision/VNGenerateImageFeaturePrintRequest.h>
#import <Vision/VNCoreMLRequest.h>
#import <Vision/VNDetectRectanglesRequest.h>
#import <Vision/VNDetectTextRectanglesRequest.h>
#import <Vision/VNDetectContoursRequest.h>
#import <Vision/VNDetectHorizonRequest.h>
#import <Vision/VNGenerateAttentionBasedSaliencyImageRequest.h>
