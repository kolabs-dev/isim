#pragma once
#import <UIKit/UIKit.h>
#import <PencilKit/PKDrawing.h>
#import <PencilKit/PKTool.h>
#import <PencilKit/PKToolPicker.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, PKCanvasViewDrawingPolicy) {
    PKCanvasViewDrawingPolicyDefault,       /* isim: fingers draw unless the tool picker's "Draw with Apple Pencil" is on */
    PKCanvasViewDrawingPolicyAnyInput,
    PKCanvasViewDrawingPolicyPencilOnly,
} API_AVAILABLE(ios(14.0));

@class PKCanvasView;
API_AVAILABLE(ios(13.0))
@protocol PKCanvasViewDelegate <NSObject, UIScrollViewDelegate>
@optional
- (void)canvasViewDrawingDidChange:(PKCanvasView *)canvasView;
- (void)canvasViewDidFinishRendering:(PKCanvasView *)canvasView;
- (void)canvasViewDidBeginUsingTool:(PKCanvasView *)canvasView NS_SWIFT_NAME(canvasViewDidBeginUsingTool(_:));
- (void)canvasViewDidEndUsingTool:(PKCanvasView *)canvasView NS_SWIFT_NAME(canvasViewDidEndUsingTool(_:));
- (void)canvasViewSelectionDidChange:(PKCanvasView *)canvasView API_AVAILABLE(ios(26.0));
@end

/* a scroll view that shows a drawing and draws into it with touches: inking tools add strokes, the eraser removes
 * strokes (vector) or the parts of them it passes over (bitmap), the lasso selects strokes. With finger drawing on,
 * two fingers scroll. */
API_AVAILABLE(ios(13.0))
@interface PKCanvasView : UIScrollView <PKToolPickerObserver>
@property (nonatomic, weak, nullable) id<PKCanvasViewDelegate> delegate;
@property (nonatomic, copy) PKDrawing *drawing;
@property (nonatomic, copy) PKTool *tool NS_REFINED_FOR_SWIFT;
@property (nonatomic, getter=isRulerActive) BOOL rulerActive;
@property (nonatomic, readonly) UIGestureRecognizer *drawingGestureRecognizer;
@property (nonatomic) BOOL allowsFingerDrawing API_DEPRECATED("use drawingPolicy", ios(13.0, 14.0));
@property (nonatomic) PKCanvasViewDrawingPolicy drawingPolicy API_AVAILABLE(ios(14.0));
@property (nonatomic) PKContentVersion maximumSupportedContentVersion API_AVAILABLE(ios(17.0));
@property (nonatomic, getter=isDrawingEnabled) BOOL drawingEnabled API_AVAILABLE(ios(18.0));
/* the selected strokes' identifiers */
@property (nonatomic, copy) NSSet<NSUUID *> *selection API_AVAILABLE(ios(26.0));
@end
NS_ASSUME_NONNULL_END
