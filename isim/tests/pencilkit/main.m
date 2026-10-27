// PencilKit from Objective-C (PencilKitTest.app, issue #360): stroke points and paths (interpolation by parametric
// value, distance and time; Bézier conversion; subpaths), inks and their content versions, strokes (render bounds,
// masks, substrokes), drawings (data in isim's format, secure coding, transforms, appending, erasing, images), the
// tools and the tool picker's items.
#import <PencilKit/PencilKit.h>
#include <math.h>
#include <stdio.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"   /* the test calls the iOS 18 and 26 API too */

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[220]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)
static BOOL near(double a, double b, double tol) { return fabs(a - b) <= tol; }

static PKStrokePoint *point(CGFloat x, CGFloat y, NSTimeInterval t, CGFloat w) {
    return [[PKStrokePoint alloc] initWithLocation:CGPointMake(x, y) timeOffset:t size:CGSizeMake(w, w) opacity:1 force:1 azimuth:0 altitude:M_PI_2];
}
/* a straight path along y = `y` from x0 to x1, one control point every 50 points, 0.5 s apart */
static PKStrokePath *line(CGFloat x0, CGFloat x1, CGFloat y, CGFloat w) {
    NSMutableArray *pts = [NSMutableArray array];
    for (int i = 0; x0 + 50 * i <= x1 + 1e-9; i++) [pts addObject:point(x0 + 50 * i, y, 0.5 * i, w)];
    return [[PKStrokePath alloc] initWithControlPoints:pts creationDate:[NSDate date]];
}
static PKStroke *stroke(PKInkType ink, UIColor *color, PKStrokePath *path) {
    return [[PKStroke alloc] initWithInk:[[PKInk alloc] initWithInkType:ink color:color] strokePath:path transform:CGAffineTransformIdentity mask:nil];
}

static void paths(void) {
    PKStrokePath *p = line(0, 200, 10, 4);
    CHECK(p.count == 5, "a path of 5 control points (%lu)", (unsigned long)p.count);
    CHECK(near(p[2].location.x, 100, 1e-9) && near(p[2].timeOffset, 1, 1e-9), "subscripting gives the control points");
    CGPoint mid = [p interpolatedLocationAt:1.5];
    CHECK(near(mid.x, 75, 1e-6) && near(mid.y, 10, 1e-6), "the curve passes between the points (%.2f, %.2f)", mid.x, mid.y);
    CHECK(near([p interpolatedPointAt:1.5].timeOffset, 0.75, 1e-9), "the time is linear between points");
    CHECK(near([p parametricValue:0 offsetByDistance:125], 2.5, 0.01), "125 points along is parametric value 2.5 (%.3f)", [p parametricValue:0 offsetByDistance:125]);
    CHECK(near([p parametricValue:1 offsetByTime:0.25], 1.5, 1e-9), "a quarter second on is half a segment");
    PKFloatRange *all = [[PKFloatRange alloc] initWithLowerBound:0 upperBound:4];
    __block int n = 0; __block CGFloat lastX = -1;
    [p enumerateInterpolatedPointsInRange:all strideByDistance:20 usingBlock:^(PKStrokePoint *pt, BOOL *stop) { n++; lastX = pt.location.x; }];
    CHECK(n == 11 && near(lastX, 200, 0.01), "every 20 points along: 11 points to the end (%d, last x %.2f)", n, lastX);
    n = 0;
    [p enumerateInterpolatedPointsInRange:all strideByTime:0.1 usingBlock:^(PKStrokePoint *pt, BOOL *stop) { n++; if (n == 3) *stop = YES; }];
    CHECK(n == 3, "the enumeration stops when asked");
    n = 0;
    [p enumerateInterpolatedPointsInRange:[[PKFloatRange alloc] initWithLowerBound:1 upperBound:3] strideByParametricStep:0.5
                               usingBlock:^(PKStrokePoint *pt, BOOL *stop) { n++; }];
    CHECK(n == 5, "parametric steps of 0.5 from 1 to 3: 5 points (%d)", n);
    PKStrokePath *sub = [p subpathWithRange:[[PKFloatRange alloc] initWithLowerBound:0.5 upperBound:2.5]];
    CHECK(sub.count == 4 && near(sub[0].location.x, [p interpolatedLocationAt:0.5].x, 1e-9) && near(sub[1].location.x, 50, 1e-9) &&
          near(sub[3].location.x, [p interpolatedLocationAt:2.5].x, 1e-9), "a subpath from 0.5 to 2.5 (%lu points)", (unsigned long)sub.count);
    CGRect bb = CGPathGetBoundingBox(p.bezierRepresentation);
    CHECK(near(bb.origin.x, 0, 1e-6) && near(CGRectGetMaxX(bb), 200, 1e-6), "the Bézier representation spans the path");

    CGMutablePathRef bez = CGPathCreateMutable();
    CGPathMoveToPoint(bez, NULL, 0, 0); CGPathAddLineToPoint(bez, NULL, 100, 0); CGPathAddLineToPoint(bez, NULL, 100, 100);
    __block NSInteger count = 0, lastSegment = -1;
    PKStrokePath *converted = [[PKStrokePath alloc] initWithBezierPath:bez creationDate:[NSDate date] pointProvider:^PKStrokePoint *(PKConvertedBezierPoint *c) {
        count = c.pointCount; lastSegment = c.bezierSegmentIndex;
        return point(c.location.x, c.location.y, c.index * 0.1, 3);
    }];
    CGPathRelease(bez);
    CHECK(converted.count == 3 && count == 3 && lastSegment == 2 && near(converted[2].location.y, 100, 1e-9), "a Bézier path becomes stroke points (%lu)",
          (unsigned long)converted.count);
}

static void inks_and_tools(void) {
    CHECK([[PKInk alloc] initWithInkType:PKInkTypePen color:UIColor.redColor].requiredContentVersion == PKContentVersion1, "the pen needs version 1");
    CHECK([[PKInk alloc] initWithInkType:PKInkTypeWatercolor color:UIColor.redColor].requiredContentVersion == PKContentVersion2, "watercolor needs version 2");
    CHECK([[PKInk alloc] initWithInkType:PKInkTypeReed color:UIColor.redColor].requiredContentVersion == PKContentVersion4, "the reed needs version 4");
    PKInkingTool *pen = [[PKInkingTool alloc] initWithInkType:PKInkTypePen color:UIColor.blueColor width:100];
    CHECK(pen.width == [PKInkingTool maximumWidthForInkType:PKInkTypePen], "an inking tool's width is clamped (%.0f)", pen.width);
    CHECK([[[PKInkingTool alloc] initWithInkType:PKInkTypeMarker color:UIColor.blueColor] width] == [PKInkingTool defaultWidthForInkType:PKInkTypeMarker],
          "the default width");
    CHECK([pen.ink.inkType isEqualToString:PKInkTypePen] && [pen.ink.color isEqual:UIColor.blueColor], "the tool's ink");
    CHECK([pen isEqual:[[PKInkingTool alloc] initWithInk:pen.ink width:25]], "equal tools");
    UIColor *dark = [PKInkingTool convertColor:UIColor.blackColor fromUserInterfaceStyle:UIUserInterfaceStyleLight to:UIUserInterfaceStyleDark];
    CGFloat w = 0, a = 0;
    [dark getWhite:&w alpha:&a];
    CHECK(w > 0.95, "black ink shows white in dark mode (%.2f)", w);
    PKEraserTool *vec = [[PKEraserTool alloc] initWithEraserType:PKEraserTypeVector], *bit = [[PKEraserTool alloc] initWithEraserType:PKEraserTypeBitmap width:200];
    CHECK(vec.eraserType == PKEraserTypeVector && vec.width == [PKEraserTool defaultWidthForEraserType:PKEraserTypeVector], "a vector eraser");
    CHECK(bit.width == [PKEraserTool maximumWidthForEraserType:PKEraserTypeBitmap], "a bitmap eraser's width is clamped");
    CHECK([[[PKLassoTool alloc] init] isKindOfClass:[PKTool class]], "the lasso is a tool");
}

static void strokes(void) {
    PKStroke *s = stroke(PKInkTypePen, UIColor.redColor, line(0, 200, 10, 6));
    CGRect r = s.renderBounds;
    CHECK(r.origin.x <= -2.9 && CGRectGetMaxX(r) >= 202.9 && r.origin.y <= 7.1 && CGRectGetMaxY(r) >= 12.9, "the render bounds hold the stroke's width");
    CHECK(s.maskedPathRanges.count == 1 && s.maskedPathRanges[0].upperBound == 4, "an unmasked stroke shows its whole path");
    PKStroke *masked = [[PKStroke alloc] initWithInk:s.ink strokePath:s.path transform:CGAffineTransformIdentity
                                                mask:[UIBezierPath bezierPathWithRect:CGRectMake(-10, 0, 110, 20)]];
    NSArray<PKFloatRange *> *ranges = masked.maskedPathRanges;
    CHECK(ranges.count == 1 && ranges[0].lowerBound == 0 && near(ranges[0].upperBound, 2, 0.06), "a mask hides part of the path (to %.2f)",
          ranges.count ? ranges[0].upperBound : -1);
    CHECK(CGRectGetMaxX(masked.renderBounds) <= 100.01, "a masked stroke's bounds stop at the mask");
    PKStroke *moved = [[PKStroke alloc] initWithInk:s.ink strokePath:s.path transform:CGAffineTransformMakeTranslation(0, 100) mask:nil randomSeed:42];
    CHECK(near(moved.renderBounds.origin.y, r.origin.y + 100, 1e-6) && moved.randomSeed == 42, "a transformed stroke");
    PKStroke *part = [s substrokeWithRange:[[PKFloatRange alloc] initWithLowerBound:1 upperBound:2]];
    CHECK(part.path.count == 2 && near(part.path[1].location.x, 100, 1e-9) && ![part.strokeID isEqual:s.strokeID], "a substroke");
}

/* the RGBA pixel at (x, y) of an image (top-left origin) */
static void pixel(UIImage *image, int x, int y, unsigned char out[4]) {
    unsigned char px[4] = { 0 };
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef c = CGBitmapContextCreate(px, 1, 1, 8, 4, cs, kCGImageAlphaPremultipliedLast);
    CGImageRef cg = image.CGImage;
    CGFloat s = image.scale;
    CGContextDrawImage(c, CGRectMake(-x * s, -((CGFloat)CGImageGetHeight(cg) - (y + 1) * s), CGImageGetWidth(cg), CGImageGetHeight(cg)), cg);
    CGContextRelease(c); CGColorSpaceRelease(cs);
    memcpy(out, px, 4);
}

static void drawings(void) {
    PKStroke *a = stroke(PKInkTypePen, UIColor.redColor, line(0, 200, 20, 8));
    PKStroke *b = [[PKStroke alloc] initWithInk:[[PKInk alloc] initWithInkType:PKInkTypeMarker color:[UIColor colorWithRed:0 green:0 blue:1 alpha:1]]
                                     strokePath:line(0, 100, 60, 10) transform:CGAffineTransformMakeTranslation(10, 0)
                                           mask:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 40, 80, 40)] randomSeed:7
                                       strokeID:[NSUUID UUID] renderGroupID:[NSUUID UUID]
                                    renderState:[[PKStrokeRenderState alloc] initWithGrainOffset:CGPointMake(3, 4)]];
    PKDrawing *d = [[PKDrawing alloc] initWithStrokes:@[ a, b ]];
    CHECK(d.strokes.count == 2 && d.requiredContentVersion == PKContentVersion4, "a drawing of 2 strokes (version %ld)", (long)d.requiredContentVersion);
    CHECK(CGRectContainsRect(d.bounds, a.renderBounds) && CGRectContainsRect(d.bounds, b.renderBounds), "its bounds hold its strokes");

    NSData *data = d.dataRepresentation;
    NSError *error = nil;
    PKDrawing *back = [[PKDrawing alloc] initWithData:data error:&error];
    CHECK(back && !error && [back isEqual:d], "the data reads back to an equal drawing (%lu bytes)", (unsigned long)data.length);
    PKStroke *b2 = back.strokes[1];
    CHECK([b2.ink.inkType isEqualToString:PKInkTypeMarker] && b2.randomSeed == 7 && [b2.renderGroupID isEqual:b.renderGroupID] &&
          CGPointEqualToPoint(b2.renderState.grainOffset, CGPointMake(3, 4)) && b2.mask && b2.transform.tx == 10,
          "a stroke's ink, seed, group, render state, mask and transform survive");
    CHECK([back.strokes[0].path.creationDate isEqual:a.path.creationDate] && back.strokes[0].path.count == 5, "the points and creation date survive");
    error = nil;
    CHECK(![[PKDrawing alloc] initWithData:[@"not a drawing" dataUsingEncoding:NSUTF8StringEncoding] error:&error] && error,
          "other data is refused with an error");
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:d requiringSecureCoding:YES error:NULL];
    PKDrawing *unarchived = [NSKeyedUnarchiver unarchivedObjectOfClass:[PKDrawing class] fromData:archived error:NULL];
    CHECK([unarchived isEqual:d], "secure coding");

    PKDrawing *moved = [d drawingByApplyingTransform:CGAffineTransformMakeTranslation(50, 0)];
    CHECK(near(moved.bounds.origin.x, d.bounds.origin.x + 50, 1e-6), "a transformed drawing moves");
    PKDrawing *more = [d drawingByAppendingDrawing:[[PKDrawing alloc] initWithStrokes:@[ a ]]];
    NSArray *twice = @[ a, a ];
    CHECK(more.strokes.count == 3 && [[d drawingByAppendingStrokes:twice] strokes].count == 4, "appending drawings and strokes");

    /* a vertical eraser stroke across the middle of the line splits it */
    PKStrokePath *eraser = [[PKStrokePath alloc] initWithControlPoints:@[ point(100, -20, 0, 10), point(100, 40, 0.2, 10) ] creationDate:[NSDate date]];
    PKDrawing *one = [[PKDrawing alloc] initWithStrokes:@[ a ]];
    PKDrawing *erased = [one drawingByErasingStrokePath:eraser mask:nil transform:CGAffineTransformIdentity];
    CHECK(erased.strokes.count == 2, "erasing across a stroke leaves 2 strokes (%lu)", (unsigned long)erased.strokes.count);
    if (erased.strokes.count == 2) {
        CGRect l = erased.strokes[0].renderBounds, r = erased.strokes[1].renderBounds;
        CHECK(CGRectGetMaxX(l) < 100 && r.origin.x > 100 && CGRectGetMaxX(l) > 80 && r.origin.x < 120, "the gap is under the eraser (%.1f to %.1f)",
              CGRectGetMaxX(l), r.origin.x);
    }
    CHECK([[one drawingByErasingStrokePath:eraser mask:nil transform:CGAffineTransformMakeTranslation(500, 0)] strokes].count == 1,
          "an eraser elsewhere erases nothing");

    UIImage *image = [one imageFromRect:CGRectMake(0, 0, 220, 40) scale:1];
    unsigned char on[4], off[4];
    pixel(image, 100, 20, on);
    pixel(image, 100, 35, off);
    CHECK(image.size.width == 220 && on[0] > 200 && on[1] < 40 && on[3] > 200, "the image draws the red ink (%d %d %d %d)", on[0], on[1], on[2], on[3]);
    CHECK(off[3] < 10, "and nothing beside it (alpha %d)", off[3]);
    PKDrawing *marker = [[PKDrawing alloc] initWithStrokes:@[ stroke(PKInkTypeMarker, UIColor.blackColor, line(0, 100, 20, 20)) ]];
    pixel([marker imageFromRect:CGRectMake(0, 0, 120, 40) scale:1], 50, 20, on);
    CHECK(on[3] > 90 && on[3] < 170, "the marker is translucent (alpha %d)", on[3]);
}

static void picker_items(void) {
    PKToolPickerInkingItem *ink = [[PKToolPickerInkingItem alloc] initWithInkType:PKInkTypePencil color:UIColor.greenColor];
    CHECK([ink.identifier isEqualToString:PKInkTypePencil] && [ink.inkingTool.inkType isEqualToString:PKInkTypePencil] && ink.allowsColorSelection,
          "an inking item (%s)", ink.identifier.UTF8String);
    PKToolPickerInkingItem *named = [[PKToolPickerInkingItem alloc] initWithInkType:PKInkTypePen color:nil width:0 identifier:@"my-pen"];
    CHECK([named.identifier isEqualToString:@"my-pen"] && named.inkingTool.width == [PKInkingTool defaultWidthForInkType:PKInkTypePen], "a named item");
    PKToolPickerEraserItem *eraser = [[PKToolPickerEraserItem alloc] initWithEraserType:PKEraserTypeBitmap];
    CHECK(eraser.eraserTool.eraserType == PKEraserTypeBitmap && [eraser.tool isKindOfClass:[PKEraserTool class]], "an eraser item");
    CHECK(PKToolPickerRulerItem.new.tool == nil && [PKToolPickerLassoItem.new.lassoTool isKindOfClass:[PKLassoTool class]], "ruler and lasso items");
    PKToolPickerCustomItemConfiguration *config = [[PKToolPickerCustomItemConfiguration alloc] initWithIdentifier:@"stamp" name:@"Stamp"];
    config.defaultColor = UIColor.orangeColor;
    PKToolPickerCustomItem *custom = [[PKToolPickerCustomItem alloc] initWithConfiguration:config];
    CHECK([custom.identifier isEqualToString:@"stamp"] && [custom.configuration.name isEqualToString:@"Stamp"] && [custom.color isEqual:UIColor.orangeColor],
          "a custom item");
    config.allowsColorSelection = NO;
    CHECK(custom.allowsColorSelection && ![[PKToolPickerCustomItem alloc] initWithConfiguration:config].allowsColorSelection,
          "a custom item offers colors as its configuration says");

    PKToolPicker *picker = [[PKToolPicker alloc] initWithToolItems:@[ ink, eraser, custom ]];
    CHECK(picker.toolItems.count == 3 && picker.selectedToolItem == ink && !picker.isVisible, "a picker of 3 items, the first selected");
    picker.selectedToolItemIdentifier = @"stamp";
    CHECK(picker.selectedToolItem == custom, "selecting by identifier");
    picker.selectedTool = [[PKEraserTool alloc] initWithEraserType:PKEraserTypeBitmap];
    CHECK([picker.selectedTool isKindOfClass:[PKEraserTool class]] && picker.selectedToolItem == eraser, "selecting a tool selects its item");
    CHECK(PKToolPicker.defaultToolItems.count >= 5, "the default items (%lu)", (unsigned long)PKToolPicker.defaultToolItems.count);
}

int main(void) {
    @autoreleasepool {
        paths();
        inks_and_tools();
        strokes();
        drawings();
        picker_items();
        printf("pencilkit: %d/%d passed\n", checks - failures, checks);
    }
    return failures ? 1 : 0;
}
