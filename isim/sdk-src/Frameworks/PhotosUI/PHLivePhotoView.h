#pragma once
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@protocol PHLivePhotoViewDelegate;
typedef NS_ENUM(NSInteger, PHLivePhotoViewPlaybackStyle) {
    PHLivePhotoViewPlaybackStyleUndefined = 0, PHLivePhotoViewPlaybackStyleFull = 1, PHLivePhotoViewPlaybackStyleHint = 2,
} API_AVAILABLE(ios(9.1));
typedef NS_OPTIONS(NSUInteger, PHLivePhotoBadgeOptions) {
    PHLivePhotoBadgeOptionsOverContent = 1 << 0, PHLivePhotoBadgeOptionsLiveOff = 1 << 1,
} API_AVAILABLE(ios(9.1));
/* a Live Photo's still; touching and holding, or startPlaybackWithStyle:, plays its movie over it */
API_AVAILABLE(ios(9.1))
@interface PHLivePhotoView : UIView
+ (UIImage *)livePhotoBadgeImageWithOptions:(PHLivePhotoBadgeOptions)badgeOptions;
@property (nonatomic, weak, nullable) id<PHLivePhotoViewDelegate> delegate;
@property (nonatomic, strong, nullable) PHLivePhoto *livePhoto;
@property (nonatomic, assign) CGRect contentsRect API_AVAILABLE(ios(17));
@property (nonatomic, assign, getter=isMuted) BOOL muted;
@property (nonatomic, assign) float audioVolume API_AVAILABLE(ios(17));
@property (nonatomic, strong, readonly) UIGestureRecognizer *playbackGestureRecognizer;
- (void)startPlaybackWithStyle:(PHLivePhotoViewPlaybackStyle)playbackStyle;
- (void)stopPlayback;
- (void)stopPlaybackAnimated:(BOOL)animated API_AVAILABLE(ios(17));
@end
API_AVAILABLE(ios(9.1))
@protocol PHLivePhotoViewDelegate <NSObject>
@optional
- (BOOL)livePhotoView:(PHLivePhotoView *)livePhotoView canBeginPlaybackWithStyle:(PHLivePhotoViewPlaybackStyle)playbackStyle API_AVAILABLE(ios(15));
- (void)livePhotoView:(PHLivePhotoView *)livePhotoView willBeginPlaybackWithStyle:(PHLivePhotoViewPlaybackStyle)playbackStyle;
- (void)livePhotoView:(PHLivePhotoView *)livePhotoView didEndPlaybackWithStyle:(PHLivePhotoViewPlaybackStyle)playbackStyle;
- (NSTimeInterval)livePhotoView:(PHLivePhotoView *)livePhotoView extraMinimumTouchDurationForTouch:(UITouch *)touch
    withStyle:(PHLivePhotoViewPlaybackStyle)playbackStyle API_AVAILABLE(ios(15));
@end
NS_ASSUME_NONNULL_END
#endif
