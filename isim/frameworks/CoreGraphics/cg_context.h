/* isim CoreGraphics private: the CGContext object (shared by CGContext.c and CGBitmap.c). */
#pragma once
#include "cg_internal.h"

enum { CTX_UIKIT = 0, CTX_BITMAP = 1, CTX_PDF = 2 };
struct gstate {
    CGFloat fill[4], stroke[4], lw, alpha; int interp; int cap, join; CGFloat miter, dash[16], phase; int ndash;
    int blend;
    int shadow; CGSize soff; CGFloat sblur, scolor[4];
    CGImageRef mask; double mm[6]; CGRect mrect;          /* clip mask (retained) */
    CGPatternRef fillPat, strokePat;                       /* retained */
    CGFloat fillPatComps[5], strokePatComps[5];
    CGColorSpaceRef fillSpace, strokeSpace;                /* unretained shared spaces */
    int textMode; CGFloat charSpacing, fontSize; CGFontRef font;
    int layer;                                             /* this level was pushed by BeginTransparencyLayer */
};
struct CGContext {
    void *isa; void (*fin)(void *);
    int kind; void *target;
    int depth; struct gstate gs[32];
    CGPoint path_cur;
    CGAffineTransform textMatrix; CGPoint textPos; CGSize patternPhase;
    /* bitmap */
    void *data; size_t w, h, bpc, bpp, bpr; uint32_t info; CGColorSpaceRef cs; int owns;
    CGBitmapContextReleaseDataCallback releaseCb; void *releaseInfo;
    /* PDF */
    CGDataConsumerRef consumer; CGRect mediaBox; int pageOpen;
};
struct CGContext *isim_cg_ctx_new(int kind);
void isim_cg_gstate_reset(struct gstate *g);
