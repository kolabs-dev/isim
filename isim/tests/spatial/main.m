// Spatial from C and Objective-C (SpatialCTest.app, issue #692): points, vectors, rotations (Euler angles, slerp,
// splines, look-at), boxes, rays, affine and projective transforms, poses and spherical coordinates from
// <Spatial/Spatial.h>, once in double precision and once with the …Float types. test_spatial.py compares the double
// lines with SpatialSwiftTest's, which computes the same with Swift's Spatial, and the float lines with the double ones.
#import <Foundation/Foundation.h>
#include <Spatial/Spatial.h>
#include <stdarg.h>
#include <stdio.h>

static const char *prefix = "";

static void L(const char *name, int n, ...) {
    va_list ap;
    va_start(ap, n);
    printf("%s%s", prefix, name);
    for (int i = 0; i < n; i++) { double x = va_arg(ap, double); printf(" %.4f", fabs(x) < 5e-5 ? 0.0 : x); }
    va_end(ap);
    printf("\n");
}
#define V3(name, v) L(name, 3, (double)(v).x, (double)(v).y, (double)(v).z)
#define S3(name, s) L(name, 3, (double)(s).width, (double)(s).height, (double)(s).depth)
#define Q(name, q) L(name, 4, (double)(q).vector.x, (double)(q).vector.y, (double)(q).vector.z, (double)(q).vector.w)
#define R(name, r) L(name, 6, (double)(r).origin.x, (double)(r).origin.y, (double)(r).origin.z, \
                     (double)(r).size.width, (double)(r).size.height, (double)(r).size.depth)

int main(void) {
    @autoreleasepool {
#define SUF
#define SP_FLOAT 0
#include "SpatialCases.h"
#undef SUF
#undef SP_FLOAT
        prefix = "float ";
#define SUF Float
#define SP_FLOAT 1
#include "SpatialCases.h"
#undef SUF
        printf("SpatialCTest: done\n");
    }
    return 0;
}
