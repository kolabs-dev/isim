#pragma once
/* isim Speech for Objective-C (issue #700): the classes are the Speech Swift overlay's (Speech.framework re-exports
   libswiftSpeech.dylib); Swift uses the overlay, so these declarations are hidden from Swift. Recognition runs on the
   host's speech-to-text engine (whisper.cpp or Vosk; see the Swift overlay). iOS 26's SpeechAnalyzer and its modules and
   SFCustomLanguageModelData are Swift only, like Apple's. */
#import <Foundation/Foundation.h>
#import <AVFAudio/AVFAudio.h>
#import <CoreMedia/CMSampleBuffer.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const SFSpeechErrorDomain API_AVAILABLE(ios(14.0));
typedef NS_ERROR_ENUM(SFSpeechErrorDomain, SFSpeechErrorCode) {
    SFSpeechErrorCodeInternalServiceError = 1,
    SFSpeechErrorCodeAudioReadFailed = 2,
    SFSpeechErrorCodeUndefinedTemplateClassName = 7,
    SFSpeechErrorCodeMalformedSupplementalModel = 8,
} API_AVAILABLE(ios(14.0));

typedef NS_ENUM(NSInteger, SFSpeechRecognizerAuthorizationStatus) {
    SFSpeechRecognizerAuthorizationStatusNotDetermined = 0,
    SFSpeechRecognizerAuthorizationStatusDenied,
    SFSpeechRecognizerAuthorizationStatusRestricted,
    SFSpeechRecognizerAuthorizationStatusAuthorized,
};
typedef NS_ENUM(NSInteger, SFSpeechRecognitionTaskHint) {
    SFSpeechRecognitionTaskHintUnspecified = 0,
    SFSpeechRecognitionTaskHintDictation = 1,
    SFSpeechRecognitionTaskHintSearch = 2,
    SFSpeechRecognitionTaskHintConfirmation = 3,
};
typedef NS_ENUM(NSInteger, SFSpeechRecognitionTaskState) {
    SFSpeechRecognitionTaskStateStarting = 0,
    SFSpeechRecognitionTaskStateRunning = 1,
    SFSpeechRecognitionTaskStateFinishing = 2,
    SFSpeechRecognitionTaskStateCanceling = 3,
    SFSpeechRecognitionTaskStateCompleted = 4,
};

@interface SFTranscriptionSegment : NSObject
@property (nonatomic, readonly, copy) NSString *substring;
@property (nonatomic, readonly) NSRange substringRange;
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) float confidence;
@property (nonatomic, readonly) NSArray<NSString *> *alternativeSubstrings;
@end

@interface SFTranscription : NSObject
@property (nonatomic, readonly, copy) NSString *formattedString;
@property (nonatomic, readonly, copy) NSArray<SFTranscriptionSegment *> *segments;
@end

@interface SFSpeechRecognitionResult : NSObject
@property (nonatomic, readonly, copy) SFTranscription *bestTranscription;
@property (nonatomic, readonly, copy) NSArray<SFTranscription *> *transcriptions;
@property (nonatomic, readonly, getter=isFinal) BOOL final;
@end

@interface SFSpeechLanguageModelConfiguration : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithLanguageModel:(NSURL *)languageModel;
- (instancetype)initWithLanguageModel:(NSURL *)languageModel vocabulary:(nullable NSURL *)vocabulary;
- (instancetype)initWithLanguageModel:(NSURL *)languageModel vocabulary:(nullable NSURL *)vocabulary weight:(nullable NSNumber *)weight API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly, copy) NSURL *languageModel;
@property (nonatomic, readonly, nullable, copy) NSURL *vocabulary;
@property (nonatomic, readonly, nullable, copy) NSNumber *weight API_AVAILABLE(ios(26.0));
@end

API_AVAILABLE(ios(17.0))
@interface SFSpeechLanguageModel : NSObject
+ (void)prepareCustomLanguageModelForUrl:(NSURL *)asset configuration:(SFSpeechLanguageModelConfiguration *)configuration
                              completion:(void (^)(NSError * _Nullable error))completion;
+ (void)prepareCustomLanguageModelForUrl:(NSURL *)asset configuration:(SFSpeechLanguageModelConfiguration *)configuration
                            ignoresCache:(BOOL)ignoresCache completion:(void (^)(NSError * _Nullable error))completion;
+ (void)prepareCustomLanguageModelForUrl:(NSURL *)asset clientIdentifier:(NSString *)clientIdentifier
                           configuration:(SFSpeechLanguageModelConfiguration *)configuration
                              completion:(void (^)(NSError * _Nullable error))completion API_DEPRECATED("", ios(17.0, 26.0));
+ (void)prepareCustomLanguageModelForUrl:(NSURL *)asset clientIdentifier:(NSString *)clientIdentifier
                           configuration:(SFSpeechLanguageModelConfiguration *)configuration ignoresCache:(BOOL)ignoresCache
                              completion:(void (^)(NSError * _Nullable error))completion API_DEPRECATED("", ios(17.0, 26.0));
@end

@interface SFSpeechRecognitionRequest : NSObject
@property (nonatomic) SFSpeechRecognitionTaskHint taskHint;
@property (nonatomic) BOOL shouldReportPartialResults;
@property (nonatomic, copy) NSArray<NSString *> *contextualStrings;
@property (nonatomic) BOOL requiresOnDeviceRecognition;
@property (nonatomic) BOOL addsPunctuation;
@property (nonatomic, copy, nullable) SFSpeechLanguageModelConfiguration *customizedLanguageModel API_AVAILABLE(ios(17.0));
@end

@interface SFSpeechURLRecognitionRequest : SFSpeechRecognitionRequest
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithURL:(NSURL *)URL;
@property (nonatomic, readonly, copy) NSURL *URL;
@end

@interface SFSpeechAudioBufferRecognitionRequest : SFSpeechRecognitionRequest
@property (nonatomic, readonly) AVAudioFormat *nativeAudioFormat;
- (void)appendAudioPCMBuffer:(AVAudioPCMBuffer *)audioPCMBuffer;
- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)endAudio;
@end

@class SFSpeechRecognitionTask;
@protocol SFSpeechRecognitionTaskDelegate <NSObject>
@optional
- (void)speechRecognitionDidDetectSpeech:(SFSpeechRecognitionTask *)task;
- (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didHypothesizeTranscription:(SFTranscription *)transcription;
- (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishRecognition:(SFSpeechRecognitionResult *)recognitionResult;
- (void)speechRecognitionTaskFinishedReadingAudio:(SFSpeechRecognitionTask *)task;
- (void)speechRecognitionTaskWasCancelled:(SFSpeechRecognitionTask *)task;
- (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishSuccessfully:(BOOL)successfully;
@end

@interface SFSpeechRecognitionTask : NSObject
@property (nonatomic, readonly) SFSpeechRecognitionTaskState state;
@property (nonatomic, readonly, getter=isFinishing) BOOL finishing;
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;
@property (nonatomic, readonly, nullable, copy) NSError *error;
- (void)finish;
- (void)cancel;
@end

@class SFSpeechRecognizer;
@protocol SFSpeechRecognizerDelegate <NSObject>
@optional
- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available;
@end

@interface SFSpeechRecognizer : NSObject
+ (NSSet<NSLocale *> *)supportedLocales;
+ (SFSpeechRecognizerAuthorizationStatus)authorizationStatus;
+ (void)requestAuthorization:(void (^)(SFSpeechRecognizerAuthorizationStatus status))handler;
- (nullable instancetype)init;
- (nullable instancetype)initWithLocale:(NSLocale *)locale;
@property (nonatomic, readonly, getter=isAvailable) BOOL available;
@property (nonatomic, readonly, copy) NSLocale *locale;
@property (nonatomic) BOOL supportsOnDeviceRecognition;
@property (nonatomic, weak, nullable) id<SFSpeechRecognizerDelegate> delegate;
@property (nonatomic) SFSpeechRecognitionTaskHint defaultTaskHint;
@property (nonatomic, strong) NSOperationQueue *queue;
- (SFSpeechRecognitionTask *)recognitionTaskWithRequest:(SFSpeechRecognitionRequest *)request
                                          resultHandler:(void (^)(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error))resultHandler;
- (SFSpeechRecognitionTask *)recognitionTaskWithRequest:(SFSpeechRecognitionRequest *)request delegate:(id<SFSpeechRecognitionTaskDelegate>)delegate;
@end

NS_ASSUME_NONNULL_END
#endif
