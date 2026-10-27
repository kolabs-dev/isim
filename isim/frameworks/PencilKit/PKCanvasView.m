// isim PencilKit: PKCanvasView. A scroll view whose content view draws the drawing (and the stroke in progress); its
// drawing gesture recognizer turns touches into stroke points (the Pencil's force, altitude and azimuth when it is
// the Pencil) for the current tool: inking tools add a stroke, the vector eraser removes the strokes it touches, the
// bitmap erasers remove the parts of strokes under them, the lasso selects the strokes whose centers it encloses.
// With finger drawing on, scrolling takes two fingers.
#import "pk_internal.h"
#import <UIKit/UIGestureRecognizerSubclass.h>

@interface _PKCanvasContentView : UIView
@property (nonatomic, weak) PKCanvasView *canvas;
@property (nonatomic, strong) PKStroke *liveStroke;           /* the stroke being drawn */
@property (nonatomic, strong) UIBezierPath *lasso;            /* the lasso being drawn */
@end

@interface _PKDrawingGestureRecognizer : UIGestureRecognizer
@property (nonatomic, weak) PKCanvasView *canvas;
@property (nonatomic, strong) UITouch *touch;
@end

@interface PKCanvasView ()
- (BOOL)_isim_accepts:(UITouch *)touch;
- (void)_isim_began:(UITouch *)touch;
- (void)_isim_moved:(UITouch *)touch;
- (void)_isim_ended:(UITouch *)touch cancelled:(BOOL)cancelled;
@end

@implementation _PKDrawingGestureRecognizer
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *t = touches.anyObject;
    if (self.touch || touches.count != 1 || event.allTouches.count > 1 || ![self.canvas _isim_accepts:t]) {
        for (UITouch *x in touches) [self ignoreTouch:x forEvent:event];
        if (self.touch && event.allTouches.count > 1) { [self.canvas _isim_ended:self.touch cancelled:YES]; self.touch = nil; self.state = UIGestureRecognizerStateCancelled; }
        else if (!self.touch) self.state = UIGestureRecognizerStateFailed;
        return;
    }
    self.touch = t;
    [self.canvas _isim_began:t];
    self.state = UIGestureRecognizerStateBegan;
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.touch || ![touches containsObject:self.touch]) return;
    [self.canvas _isim_moved:self.touch];
    self.state = UIGestureRecognizerStateChanged;
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.touch || ![touches containsObject:self.touch]) return;
    [self.canvas _isim_moved:self.touch];
    [self.canvas _isim_ended:self.touch cancelled:NO];
    self.touch = nil;
    self.state = UIGestureRecognizerStateEnded;
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.touch) return;
    [self.canvas _isim_ended:self.touch cancelled:YES];
    self.touch = nil;
    self.state = UIGestureRecognizerStateCancelled;
}
- (void)reset { [super reset]; self.touch = nil; }
@end

@implementation _PKCanvasContentView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) { self.opaque = NO; self.backgroundColor = UIColor.clearColor; self.userInteractionEnabled = NO; }
    return self;
}
- (void)drawRect:(CGRect)rect {
    PKCanvasView *canvas = self.canvas;
    CGContextRef c = UIGraphicsGetCurrentContext();
    NSSet *selected = canvas.selection;
    for (PKStroke *s in canvas.drawing.strokes) {
        if (!CGRectIntersectsRect(s.renderBounds, rect)) continue;
        pk_draw_stroke(s, c);
        if ([selected containsObject:s.strokeID]) {   /* selected strokes: a tinted outline of their bounds */
            CGContextSaveGState(c);
            CGContextSetRGBStrokeColor(c, 0, 0.48, 1, 0.8);
            CGContextSetLineWidth(c, 1);
            CGFloat dash[2] = { 4, 3 };
            CGContextSetLineDash(c, 0, dash, 2);
            CGContextStrokeRect(c, CGRectInset(s.renderBounds, -3, -3));
            CGContextRestoreGState(c);
        }
    }
    if (self.liveStroke) pk_draw_stroke(self.liveStroke, c);
    if (self.lasso) {
        CGContextSaveGState(c);
        CGContextSetRGBStrokeColor(c, 0.4, 0.4, 0.4, 1);
        CGContextSetLineWidth(c, 1.5);
        CGFloat dash[2] = { 5, 4 };
        CGContextSetLineDash(c, 0, dash, 2);
        CGContextAddPath(c, self.lasso.CGPath);
        CGContextStrokePath(c);
        CGContextRestoreGState(c);
    }
}
@end

@implementation PKCanvasView {
    _PKCanvasContentView *_content;
    _PKDrawingGestureRecognizer *_recognizer;
    PKDrawing *_drawing;
    PKTool *_tool;
    NSMutableArray<PKStrokePoint *> *_points;
    NSMutableData *_erasePoints;      /* CGPoint[]: the eraser's path in drawing coordinates */
    NSTimeInterval _start;
    NSSet<NSUUID *> *_selection;
}
@dynamic delegate;
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _drawing = [[PKDrawing alloc] init];
        _tool = [[PKInkingTool alloc] initWithInkType:PKInkTypePen color:UIColor.blackColor];
        _selection = [NSSet set];
        _drawingEnabled = YES;
        _maximumSupportedContentVersion = PKContentVersionLatest;
        _content = [[_PKCanvasContentView alloc] initWithFrame:self.bounds];
        _content.canvas = self;
        [self addSubview:_content];
        _recognizer = [[_PKDrawingGestureRecognizer alloc] initWithTarget:nil action:NULL];
        _recognizer.canvas = self;
        [self addGestureRecognizer:_recognizer];
        self.panGestureRecognizer.minimumNumberOfTouches = 2;   /* one finger draws */
        self.backgroundColor = UIColor.systemBackgroundColor;
    }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithFrame:CGRectZero]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize s = self.contentSize;
    CGRect f = CGRectMake(0, 0, fmax(s.width, self.bounds.size.width), fmax(s.height, self.bounds.size.height));
    if (!CGRectEqualToRect(_content.frame, f)) { _content.frame = f; [_content setNeedsDisplay]; }
}
- (BOOL)canBecomeFirstResponder { return YES; }
- (UIGestureRecognizer *)drawingGestureRecognizer { return _recognizer; }

/* ---- the drawing ---- */
- (PKDrawing *)drawing { return _drawing; }
- (void)setDrawing:(PKDrawing *)drawing { [self _isim_setDrawing:drawing]; }
- (void)_isim_setDrawing:(PKDrawing *)drawing {
    _drawing = [drawing copy] ?: [[PKDrawing alloc] init];
    [_content setNeedsDisplay];
    id<PKCanvasViewDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(canvasViewDrawingDidChange:)]) [d canvasViewDrawingDidChange:self];
    __weak PKCanvasView *weak = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        PKCanvasView *s = weak;
        id<PKCanvasViewDelegate> dd = s.delegate;
        if (s && [dd respondsToSelector:@selector(canvasViewDidFinishRendering:)]) [dd canvasViewDidFinishRendering:s];
    });
}
- (PKTool *)tool { return _tool; }
- (void)setTool:(PKTool *)tool { _tool = [tool copy] ?: _tool; }
- (NSSet<NSUUID *> *)selection { return _selection; }
- (void)setSelection:(NSSet<NSUUID *> *)selection {
    _selection = [selection copy] ?: [NSSet set];
    [_content setNeedsDisplay];
    id<PKCanvasViewDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(canvasViewSelectionDidChange:)]) [d canvasViewSelectionDidChange:self];
}
- (BOOL)allowsFingerDrawing { return _drawingPolicy != PKCanvasViewDrawingPolicyPencilOnly; }
- (void)setAllowsFingerDrawing:(BOOL)allows { self.drawingPolicy = allows ? PKCanvasViewDrawingPolicyAnyInput : PKCanvasViewDrawingPolicyPencilOnly; }
- (void)setDrawingPolicy:(PKCanvasViewDrawingPolicy)policy {
    _drawingPolicy = policy;
    self.panGestureRecognizer.minimumNumberOfTouches = policy == PKCanvasViewDrawingPolicyPencilOnly ? 1 : 2;
}

/* ---- touches ---- */
- (BOOL)_isim_accepts:(UITouch *)touch {
    if (!_drawingEnabled) return NO;
    BOOL pencil = touch.type == UITouchTypePencil;
    switch (_drawingPolicy) {
    case PKCanvasViewDrawingPolicyPencilOnly: return pencil;
    case PKCanvasViewDrawingPolicyAnyInput: return YES;
    default: return pencil || !UIPencilInteraction.prefersPencilOnlyDrawing;
    }
}
- (PKStrokePoint *)_isim_point:(UITouch *)touch {
    CGPoint p = [touch locationInView:_content];
    BOOL pencil = touch.type == UITouchTypePencil;
    PKInkingTool *ink = [_tool isKindOfClass:[PKInkingTool class]] ? (PKInkingTool *)_tool : nil;
    CGFloat width = ink ? ink.width : 1, force = pencil ? touch.force : 1;
    /* the Pencil's pressure thickens pressure-sensitive inks (not monoline) */
    if (pencil && ink && ![ink.inkType isEqualToString:PKInkTypeMonoline]) width *= fmin(fmax(0.5 + 0.5 * force, 0.5), 2);
    CGFloat azimuth = pencil ? [touch azimuthAngleInView:_content] : (ink ? ink.azimuth : 0);
    return [[PKStrokePoint alloc] initWithLocation:p timeOffset:touch.timestamp - _start size:CGSizeMake(width, width) opacity:1 force:force
                                           azimuth:azimuth altitude:pencil ? touch.altitudeAngle : M_PI_2];
}
- (void)_isim_began:(UITouch *)touch {
    _start = touch.timestamp;
    _points = [NSMutableArray arrayWithObject:[self _isim_point:touch]];
    _erasePoints = [NSMutableData data];
    id<PKCanvasViewDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(canvasViewDidBeginUsingTool:)]) [d canvasViewDidBeginUsingTool:self];
    [self _isim_apply:NO];
}
- (void)_isim_moved:(UITouch *)touch {
    PKStrokePoint *p = [self _isim_point:touch];
    PKStrokePoint *last = _points.lastObject;
    if (last && hypot(p.location.x - last.location.x, p.location.y - last.location.y) < 0.5) return;
    [_points addObject:p];
    [self _isim_apply:NO];
}
- (void)_isim_ended:(UITouch *)touch cancelled:(BOOL)cancelled {
    if (!cancelled) [self _isim_apply:YES];
    _content.liveStroke = nil; _content.lasso = nil;
    [_content setNeedsDisplay];
    _points = nil;
    id<PKCanvasViewDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(canvasViewDidEndUsingTool:)]) [d canvasViewDidEndUsingTool:self];
}
/* the tool's effect so far (done: the touch ended) */
- (void)_isim_apply:(BOOL)done {
    if ([_tool isKindOfClass:[PKInkingTool class]]) {
        PKStrokePath *path = [[PKStrokePath alloc] initWithControlPoints:_points creationDate:[NSDate date]];
        PKStroke *stroke = [[PKStroke alloc] initWithInk:((PKInkingTool *)_tool).ink strokePath:path transform:CGAffineTransformIdentity mask:nil];
        if (done) { _content.liveStroke = nil; [self _isim_setDrawing:[_drawing drawingByAppendingStrokes:@[ stroke ]]]; }
        else { _content.liveStroke = stroke; [_content setNeedsDisplay]; }
    } else if ([_tool isKindOfClass:[PKEraserTool class]]) {
        PKEraserTool *eraser = (PKEraserTool *)_tool;
        CGPoint p = _points.lastObject.location;
        [_erasePoints appendBytes:&p length:sizeof p];
        NSUInteger n = _erasePoints.length / sizeof(CGPoint);
        const CGPoint *pts = _erasePoints.bytes;
        const CGPoint *seg = n >= 2 ? pts + n - 2 : pts;           /* the last segment of the eraser's path */
        NSUInteger segN = n >= 2 ? 2 : 1;
        if (eraser.eraserType == PKEraserTypeVector) {
            NSMutableArray *keep = [NSMutableArray array];
            BOOL changed = NO;
            for (PKStroke *s in _drawing.strokes) {
                if (pk_ranges_hit(s, seg, segN, eraser.width).count) changed = YES; else [keep addObject:s];
            }
            if (changed) [self _isim_setDrawing:[[PKDrawing alloc] initWithStrokes:keep]];
        } else {
            NSMutableArray *ep = [NSMutableArray array];
            for (NSUInteger i = 0; i < segN; i++)
                [ep addObject:[[PKStrokePoint alloc] initWithLocation:seg[i] timeOffset:0 size:CGSizeMake(eraser.width, eraser.width) opacity:1 force:1 azimuth:0 altitude:M_PI_2]];
            PKDrawing *erased = [_drawing drawingByErasingStrokePath:[[PKStrokePath alloc] initWithControlPoints:ep creationDate:[NSDate date]]
                                                                mask:nil transform:CGAffineTransformIdentity];
            if (![erased.strokes isEqualToArray:_drawing.strokes]) [self _isim_setDrawing:erased];
        }
    } else if ([_tool isKindOfClass:[PKLassoTool class]]) {
        UIBezierPath *lasso = [UIBezierPath bezierPath];
        for (NSUInteger i = 0; i < _points.count; i++) {
            CGPoint p = _points[i].location;
            if (i) [lasso addLineToPoint:p]; else [lasso moveToPoint:p];
        }
        if (done) {
            [lasso closePath];
            NSMutableSet *sel = [NSMutableSet set];
            for (PKStroke *s in _drawing.strokes) {
                CGRect b = s.renderBounds;
                if (_points.count > 2 && [lasso containsPoint:CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b))]) [sel addObject:s.strokeID];
            }
            self.selection = sel;
        } else { _content.lasso = lasso; [_content setNeedsDisplay]; }
    }
}

/* ---- the tool picker ---- */
- (void)toolPickerSelectedToolItemDidChange:(PKToolPicker *)picker { PKTool *t = picker.selectedToolItem.tool; if (t) self.tool = t; }
- (void)toolPickerSelectedToolDidChange:(PKToolPicker *)picker {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (picker.selectedTool) self.tool = picker.selectedTool;
#pragma clang diagnostic pop
}
- (void)toolPickerIsRulerActiveDidChange:(PKToolPicker *)picker { self.rulerActive = picker.isRulerActive; }
@end
