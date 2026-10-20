// Core Graphics paths from C (CGPathTest.app, issue #273): arcs to a point, stroked and dashed copies (caps, joins,
// the miter limit, dash phases), transformed copies, CGPathIsRect, and the iOS 16 boolean operations (union,
// intersection, subtraction, symmetric difference, normalizing under both fill rules), line operations, components,
// flattening and intersection tests. Areas are measured by sampling CGPathContainsPoint on a grid.
#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdio.h>

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[200]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)

static bool near(double a, double b, double tol) { return fabs(a - b) <= tol; }
static bool rect_near(CGRect a, CGRect b, double tol) {
    return near(a.origin.x, b.origin.x, tol) && near(a.origin.y, b.origin.y, tol) &&
           near(a.size.width, b.size.width, tol) && near(a.size.height, b.size.height, tol);
}
static bool has(CGPathRef p, double x, double y) { return CGPathContainsPoint(p, NULL, CGPointMake(x, y), false); }

/* the area inside a path (non-zero rule), sampled at half-unit cell centres over its bounding box */
static double area(CGPathRef p) {
    CGRect b = CGPathGetPathBoundingBox(p);
    double n = 0;
    for (double y = floor(b.origin.y) + 0.25; y < CGRectGetMaxY(b); y += 0.5)
        for (double x = floor(b.origin.x) + 0.25; x < CGRectGetMaxX(b); x += 0.5) n += has(p, x, y);
    return n * 0.25;
}

typedef struct { int moves, lines, curves, closes; } counts;
static void count_element(void *info, const CGPathElement *e) {
    counts *c = info;
    switch (e->type) {
    case kCGPathElementMoveToPoint: c->moves++; break;
    case kCGPathElementAddLineToPoint: c->lines++; break;
    case kCGPathElementAddQuadCurveToPoint: case kCGPathElementAddCurveToPoint: c->curves++; break;
    case kCGPathElementCloseSubpath: c->closes++; break;
    }
}
static counts elements(CGPathRef p) { counts c = {0}; CGPathApply(p, &c, count_element); return c; }

static CGPathRef rect(double x, double y, double w, double h) { return CGPathCreateWithRect(CGRectMake(x, y, w, h), NULL); }

static void arcs(void) {
    CGMutablePathRef p = CGPathCreateMutable();
    CGPathMoveToPoint(p, NULL, 0, 0);
    CGPathAddArcToPoint(p, NULL, 10, 0, 10, 10, 5);
    CGPoint end = CGPathGetCurrentPoint(p);
    CHECK(near(end.x, 10, 1e-6) && near(end.y, 5, 1e-6), "addArc(tangent1End:) ends on the second tangent (%g,%g)", end.x, end.y);
    CGRect b = CGPathGetPathBoundingBox(p);
    CHECK(rect_near(b, CGRectMake(0, 0, 10, 5), 1e-3), "addArc(tangent1End:) line then quarter circle %gx%g", b.size.width, b.size.height);
    CGPathMoveToPoint(p, NULL, 0, 20);
    CGPathAddArcToPoint(p, NULL, 10, 20, 20, 20, 5);      /* collinear tangents: a straight line to the corner */
    end = CGPathGetCurrentPoint(p);
    CHECK(near(end.x, 10, 1e-6) && near(end.y, 20, 1e-6), "addArc(tangent1End:) with collinear tangents lines to tangent1End");
    CGAffineTransform t = CGAffineTransformMakeTranslation(100, 0);
    CGMutablePathRef q = CGPathCreateMutable();
    CGPathMoveToPoint(q, &t, 0, 0);
    CGPathAddArcToPoint(q, &t, 10, 0, 10, 10, 5);
    end = CGPathGetCurrentPoint(q);
    CHECK(near(end.x, 110, 1e-6) && near(end.y, 5, 1e-6), "addArc(tangent1End:) applies its transform");
    CGPathRelease(p);
    CGPathRelease(q);
}

static void stroking(void) {
    CGMutablePathRef line = CGPathCreateMutable();
    CGPathMoveToPoint(line, NULL, 0, 0);
    CGPathAddLineToPoint(line, NULL, 100, 0);
    CGPathRef butt = CGPathCreateCopyByStrokingPath(line, NULL, 10, kCGLineCapButt, kCGLineJoinMiter, 10);
    CHECK(rect_near(CGPathGetPathBoundingBox(butt), CGRectMake(0, -5, 100, 10), 0.01), "stroke: butt cap box");
    CHECK(has(butt, 50, 4) && !has(butt, 50, 6) && !has(butt, -1, 0), "stroke: butt cap insides");
    CHECK(near(area(butt), 1000, 1), "stroke: area width x length (%g)", area(butt));
    CGPathRef square = CGPathCreateCopyByStrokingPath(line, NULL, 10, kCGLineCapSquare, kCGLineJoinMiter, 10);
    CHECK(rect_near(CGPathGetPathBoundingBox(square), CGRectMake(-5, -5, 110, 10), 0.01) && has(square, -4, 4), "stroke: square cap");
    CGPathRef round = CGPathCreateCopyByStrokingPath(line, NULL, 10, kCGLineCapRound, kCGLineJoinMiter, 10);
    CHECK(has(round, -4, 0) && !has(round, -4, 4) && near(CGPathGetPathBoundingBox(round).origin.x, -5, 0.05), "stroke: round cap");

    CGMutablePathRef corner = CGPathCreateMutable();
    CGPathMoveToPoint(corner, NULL, 0, 0);
    CGPathAddLineToPoint(corner, NULL, 100, 0);
    CGPathAddLineToPoint(corner, NULL, 100, 100);
    CGPathRef miter = CGPathCreateCopyByStrokingPath(corner, NULL, 10, kCGLineCapButt, kCGLineJoinMiter, 10);
    CHECK(has(miter, 104.5, -4.5), "stroke: miter join fills the corner");
    CGPathRef bevel = CGPathCreateCopyByStrokingPath(corner, NULL, 10, kCGLineCapButt, kCGLineJoinBevel, 10);
    CHECK(!has(bevel, 104.5, -4.5) && has(bevel, 102, -2), "stroke: bevel join cuts the corner");
    CGPathRef rjoin = CGPathCreateCopyByStrokingPath(corner, NULL, 10, kCGLineCapButt, kCGLineJoinRound, 10);
    CHECK(has(rjoin, 103, -3) && !has(rjoin, 104.5, -4.5), "stroke: round join");
    CGPathRef limited = CGPathCreateCopyByStrokingPath(corner, NULL, 10, kCGLineCapButt, kCGLineJoinMiter, 1.2);
    CHECK(!has(limited, 104.5, -4.5), "stroke: a miter over the limit becomes a bevel");
    CHECK(near(area(miter), 100 * 10 + 100 * 10, 2), "stroke: overlapping bands count once (%g)", area(miter));

    CGPathRef ring = CGPathCreateCopyByStrokingPath(rect(0, 0, 50, 50), NULL, 4, kCGLineCapButt, kCGLineJoinMiter, 10);
    CHECK(has(ring, 0, 25) && !has(ring, 25, 25) && rect_near(CGPathGetPathBoundingBox(ring), CGRectMake(-2, -2, 54, 54), 0.01),
          "stroke: closed rectangle is a ring");
    CGAffineTransform s = CGAffineTransformMakeScale(2, 2);
    CGPathRef scaled = CGPathCreateCopyByStrokingPath(line, &s, 10, kCGLineCapButt, kCGLineJoinMiter, 10);
    CHECK(rect_near(CGPathGetPathBoundingBox(scaled), CGRectMake(0, -10, 200, 20), 0.05), "stroke: the transform maps the outline (width too)");
    CGFloat lengths[] = {10, 10};
    CGPathRef dashed = CGPathCreateCopyByDashingPath(line, &s, 0, lengths, 2);
    CHECK(elements(dashed).moves == 5 && near(CGRectGetMaxX(CGPathGetPathBoundingBox(dashed)), 180, 1e-6), "dash: lengths along the path, then the transform");
    CGPathRelease(dashed);
    CGPathRelease(butt); CGPathRelease(square); CGPathRelease(round); CGPathRelease(miter); CGPathRelease(bevel);
    CGPathRelease(rjoin); CGPathRelease(limited); CGPathRelease(ring); CGPathRelease(scaled);
    CGPathRelease(line); CGPathRelease(corner);
}

static void dashing(void) {
    CGMutablePathRef line = CGPathCreateMutable();
    CGPathMoveToPoint(line, NULL, 0, 0);
    CGPathAddLineToPoint(line, NULL, 100, 0);
    CGFloat lengths[] = {10, 10};
    CGPathRef d = CGPathCreateCopyByDashingPath(line, NULL, 0, lengths, 2);
    counts c = elements(d);
    CHECK(c.moves == 5, "dash: 5 dashes over 100 (%d)", c.moves);
    CGPathRef shifted = CGPathCreateCopyByDashingPath(line, NULL, 5, lengths, 2);
    c = elements(shifted);
    CGRect b = CGPathGetPathBoundingBox(shifted);
    CHECK(c.moves == 6 && near(b.origin.x, 0, 1e-6) && near(CGRectGetMaxX(b), 100, 1e-6), "dash: phase 5 starts mid-dash (%d dashes)", c.moves);
    CGPathRef sq = CGPathCreateCopyByDashingPath(rect(0, 0, 40, 40), NULL, 0, lengths, 2);
    CHECK(elements(sq).moves == 8, "dash: closed rectangle's perimeter 160 = 8 dashes (%d)", elements(sq).moves);
    CGPathRef none = CGPathCreateCopyByDashingPath(line, NULL, 0, NULL, 0);
    CHECK(none && elements(none).moves == 1, "dash: no lengths copies the path");
    CGPathRelease(d); CGPathRelease(shifted); CGPathRelease(sq); CGPathRelease(none); CGPathRelease(line);
}

static void copies(void) {
    CGAffineTransform t = CGAffineTransformMakeTranslation(10, 20);
    CGPathRef r = rect(0, 0, 5, 5);
    CGPathRef moved = CGPathCreateCopyByTransformingPath(r, &t);
    CHECK(rect_near(CGPathGetBoundingBox(moved), CGRectMake(10, 20, 5, 5), 1e-9), "copy(using:) translates");
    CGMutablePathRef m = CGPathCreateMutableCopyByTransformingPath(r, &t);
    CGPathAddLineToPoint(m, NULL, 0, 0);
    CHECK(rect_near(CGPathGetBoundingBox(m), CGRectMake(0, 0, 15, 25), 1e-9), "mutableCopy(using:) can be extended");
    CGRect got;
    CHECK(CGPathIsRect(r, &got) && rect_near(got, CGRectMake(0, 0, 5, 5), 1e-9), "isRect: a rectangle");
    CHECK(CGPathIsRect(moved, &got) && rect_near(got, CGRectMake(10, 20, 5, 5), 1e-9), "isRect: a translated rectangle");
    CGAffineTransform rot = CGAffineTransformMakeRotation(M_PI / 4);
    CGPathRef turned = CGPathCreateCopyByTransformingPath(r, &rot);
    CHECK(!CGPathIsRect(turned, NULL), "isRect: a rotated rectangle is not");
    CGMutablePathRef tri = CGPathCreateMutable();
    CGPathMoveToPoint(tri, NULL, 0, 0); CGPathAddLineToPoint(tri, NULL, 10, 0); CGPathAddLineToPoint(tri, NULL, 0, 10);
    CGPathCloseSubpath(tri);
    CHECK(!CGPathIsRect(tri, NULL), "isRect: a triangle is not");
    CGMutablePathRef lines = CGPathCreateMutable();
    CGPathMoveToPoint(lines, NULL, 1, 1); CGPathAddLineToPoint(lines, NULL, 4, 1); CGPathAddLineToPoint(lines, NULL, 4, 3);
    CGPathAddLineToPoint(lines, NULL, 1, 3); CGPathCloseSubpath(lines);
    CHECK(CGPathIsRect(lines, &got) && rect_near(got, CGRectMake(1, 1, 3, 2), 1e-9), "isRect: four lines and a close");
    CGPathRelease(r); CGPathRelease(moved); CGPathRelease(m); CGPathRelease(turned); CGPathRelease(tri); CGPathRelease(lines);
}

static void booleans(void) {
    CGPathRef a = rect(0, 0, 10, 10), b = rect(5, 0, 10, 10), far = rect(40, 40, 5, 5);
    CGPathRef u = CGPathCreateCopyByUnioningPath(a, b, false);
    CHECK(rect_near(CGPathGetPathBoundingBox(u), CGRectMake(0, 0, 15, 10), 1e-6) && near(area(u), 150, 0.5), "union: area 150 (%g)", area(u));
    CHECK(elements(u).moves == 1, "union: one outline (%d)", elements(u).moves);
    CGPathRef i = CGPathCreateCopyByIntersectingPath(a, b, false);
    CHECK(rect_near(CGPathGetPathBoundingBox(i), CGRectMake(5, 0, 5, 10), 1e-6) && near(area(i), 50, 0.5), "intersection: area 50 (%g)", area(i));
    CGPathRef s = CGPathCreateCopyBySubtractingPath(a, b, false);
    CHECK(rect_near(CGPathGetPathBoundingBox(s), CGRectMake(0, 0, 5, 10), 1e-6) && !has(s, 7, 5) && has(s, 2, 5), "subtracting: left half");
    CGPathRef x = CGPathCreateCopyBySymmetricDifferenceOfPath(a, b, false);
    CHECK(has(x, 2, 5) && has(x, 12, 5) && !has(x, 7, 5) && near(area(x), 100, 0.5), "symmetricDifference: area 100 (%g)", area(x));
    CGPathRef none = CGPathCreateCopyByIntersectingPath(a, far, false);
    CHECK(none && CGPathIsEmpty(none), "intersection: disjoint is empty");

    CGMutablePathRef holed = CGPathCreateMutable();                                      /* a ring under even-odd */
    CGPathAddRect(holed, NULL, CGRectMake(0, 0, 30, 30));
    CGPathAddRect(holed, NULL, CGRectMake(10, 10, 10, 10));
    CGPathRef eo = CGPathCreateCopyByNormalizing(holed, true), nz = CGPathCreateCopyByNormalizing(holed, false);
    CHECK(!has(eo, 15, 15) && has(eo, 5, 5) && near(area(eo), 800, 0.5), "normalized: even-odd keeps the hole (%g)", area(eo));
    CHECK(has(nz, 15, 15) && near(area(nz), 900, 0.5), "normalized: winding fills it (%g)", area(nz));
    CGPathRef ring = CGPathCreateCopyBySubtractingPath(rect(0, 0, 30, 30), rect(10, 10, 10, 10), false);
    CHECK(!has(ring, 15, 15) && near(area(ring), 800, 0.5), "subtracting: a hole (%g)", area(ring));
    CGPathRef ellipse = CGPathCreateWithEllipseInRect(CGRectMake(0, 0, 20, 20), NULL);
    CGPathRef half = CGPathCreateCopyByIntersectingPath(ellipse, rect(0, 0, 10, 20), false);
    CHECK(near(area(half), M_PI * 100 / 2, 2), "intersection: half a circle (%g)", area(half));

    CHECK(CGPathIntersectsPath(a, b, false) && !CGPathIntersectsPath(a, far, false), "intersects: overlap and disjoint");
    CGPathRef inner = rect(2, 2, 2, 2);
    CHECK(CGPathIntersectsPath(a, inner, false), "intersects: containment");

    CGMutablePathRef two = CGPathCreateMutable();
    CGPathAddRect(two, NULL, CGRectMake(0, 0, 10, 10));
    CGPathAddRect(two, NULL, CGRectMake(40, 40, 5, 5));
    CFArrayRef parts = CGPathCreateSeparateComponentsOfPath(two, false);
    CHECK(parts && CFArrayGetCount(parts) == 2, "componentsSeparated: 2 (%ld)", parts ? (long)CFArrayGetCount(parts) : -1L);
    CFArrayRef one = CGPathCreateSeparateComponentsOfPath(holed, true);
    CHECK(one && CFArrayGetCount(one) == 1, "componentsSeparated: a ring is one piece (%ld)", one ? (long)CFArrayGetCount(one) : -1L);

    CGMutablePathRef line = CGPathCreateMutable();
    CGPathMoveToPoint(line, NULL, -10, 5);
    CGPathAddLineToPoint(line, NULL, 20, 5);
    CGPathRef in = CGPathCreateCopyOfLineByIntersectingPath(line, a, false), out = CGPathCreateCopyOfLineBySubtractingPath(line, a, false);
    CHECK(rect_near(CGPathGetPathBoundingBox(in), CGRectMake(0, 5, 10, 0), 1e-6), "lineIntersection: the inside segment");
    CHECK(elements(out).moves == 2 && rect_near(CGPathGetPathBoundingBox(out), CGRectMake(-10, 5, 30, 0), 1e-6), "lineSubtracting: two outside segments");

    CGPathRef flat = CGPathCreateCopyByFlattening(ellipse, 0.1);
    counts c = elements(flat);
    CHECK(c.curves == 0 && c.lines > 16 && rect_near(CGPathGetPathBoundingBox(flat), CGRectMake(0, 0, 20, 20), 0.15), "flattened: lines only (%d)", c.lines);

    CGPathRelease(a); CGPathRelease(b); CGPathRelease(far); CGPathRelease(u); CGPathRelease(i); CGPathRelease(s); CGPathRelease(x);
    CGPathRelease(none); CGPathRelease(holed); CGPathRelease(eo); CGPathRelease(nz); CGPathRelease(ring); CGPathRelease(ellipse);
    CGPathRelease(half); CGPathRelease(inner); CGPathRelease(two); CFRelease(parts); CFRelease(one); CGPathRelease(line);
    CGPathRelease(in); CGPathRelease(out); CGPathRelease(flat);
}

int main(void) {
    @autoreleasepool {
        arcs();
        stroking();
        dashing();
        copies();
        booleans();
        printf("cgpath: %d/%d passed\n", checks - failures, checks);
    }
    return failures ? 1 : 0;
}
