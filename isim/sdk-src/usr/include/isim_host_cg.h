#pragma once
/* isim private host bridge, graphics part 2 (libisim_host, runtime/host_cg.c): Core Graphics bitmap and PDF
 * contexts, pixel formats, compositing effects, Core Text line layout, ImageIO decoding/encoding, PDF reading.
 * Used by isim's CoreGraphics, CoreText, ImageIO, CoreImage and UIKit implementations only. */
#include <_isim_cdefs.h>
__BEGIN_DECLS

/* Pixel formats as an int: byte offsets of R, G, B, A inside a pixel (3 bits each, 7 = none), flags.
 * bpp is the number of bytes per pixel (1...4). */
#define ISIM_PX(r, g, b, a) ((r) | (g) << 3 | (b) << 6 | (a) << 9)
#define ISIM_PX_NONE 7
#define ISIM_PX_PREMUL 0x1000      /* color is premultiplied by alpha */
#define ISIM_PX_GRAY 0x2000        /* one gray sample at the R offset */
#define ISIM_PX_ALPHAONLY 0x4000   /* only an alpha sample (A offset) */
#define ISIM_PX_SKIPALPHA 0x8000   /* the A byte is padding (opaque) */
#define ISIM_PX_INVERT 0x10000     /* image masks: sample 0 paints, 255 masks out */
#define ISIM_PX_RGBA_PREMUL (ISIM_PX(0, 1, 2, 3) | ISIM_PX_PREMUL)

/* targets: a cairo surface CG/UIKit draw into while bound (bind/unbind nest; binding makes it the host's current
   drawing target). Bitmap targets draw straight into `data` when the layout is cairo's (BGRA premultiplied, little
   endian) or A8; other layouts are converted in on bind (if the app changed the bytes) and out on unbind. */
void *_Nullable isim_cg_bitmap_create(void *data, int w, int h, int bpr, int fmt, int bpp);
void isim_cg_target_bind(void *t);
void isim_cg_target_unbind(void *t);
void isim_cg_target_free(void *_Nullable t);
int isim_cg_target_image(void *t);               /* copy of the pixels as a new image handle */
void isim_cg_target_sync(void *t);               /* re-read app bytes changed outside drawing */
/* PDF: path NULL = in memory (isim_cg_pdf_finish returns the bytes, malloc'd, free with isim_image_bytes_free) */
void *_Nullable isim_cg_pdf_create(const char *_Nullable path, double w, double h);
void isim_cg_pdf_begin_page(void *t, double w, double h);
void isim_cg_pdf_end_page(void *t);
long isim_cg_pdf_finish(void *t, unsigned char *_Nullable *_Nonnull out);

/* images <-> pixels (fmt/bpp as above; the host keeps premultiplied BGRA) */
int isim_image_from_pixels(const void *data, int w, int h, int bpr, int fmt, int bpp);
int isim_image_read_pixels(int handle, int x, int y, int w, int h, void *out, int bpr, int fmt, int bpp);

/* compositing on the current target */
void isim_cg_set_blend(int cgBlendMode);         /* CGBlendMode values, until restore */
void isim_cg_clear_rect(double x, double y, double w, double h);
void isim_cg_get_ctm(double *m);                 /* m[7]: [a b c d tx ty] user -> device (y down), device height in pixels */
void isim_cg_set_ctm(const double *m);
/* what: 0 path extents (returns 1 if a path), 1 current point, 2 clip extents, 3 (x,y) in fill, 4 in stroke, 5 antialias (x != 0) */
int isim_cg_query(int what, double x, double y, double *out);
int isim_cg_copy_path(double *_Nullable out, int max);   /* elements of 7 doubles: type 0 move 1 line 3 curve 4 close, points */
struct isim_cg_fx {
    double alpha;                                /* group opacity */
    int shadow, flip; double sdx, sdy, sblur, srgba[4];   /* shadow offset/blur in base units (flip: base space is y-up) */
    int mask_handle; double msx, msy, msw, msh;  /* clip mask image (pixel rect of the host image) */
    double mm[6], mx, my, mw, mh;                /* CTM when the mask was set and the mask rect in that space */
    int mask_luminance;                          /* opaque mask image: luminance is coverage */
};
void isim_cg_group_begin(void);
void isim_cg_group_end(const struct isim_cg_fx *fx);
/* fills (mode 0) / strokes (1, width lw) the current path, or paints the clip (2), with a repeating image cell
   (cw x ch user units, matrix: pattern space -> user space) */
void isim_cg_fill_pattern(int handle, double cw, double ch, const double *matrix, int mode, double lw, double alpha);
/* draws the source rect of an image repeated with tiles of tw x th inside (x, y, w, h) */
void isim_cg_draw_image_tiled(int handle, double sx, double sy, double sw, double sh, double x, double y, double w, double h, double tw, double th);

/* Core Text: Pango layouts of markup. width 0 = unwrapped; single: 1 one paragraph (CTLine), 2/3/4 one line truncated at start/middle/end */
/* a run: UTF-8 byte range, the font Pango used (family, size, Pango weight / stretch), its metrics, bidi direction;
 * font is the run's PangoFont, valid while the layout lives (isim_ct_font_retain keeps it) */
struct isim_ct_run { int start, len, glyphs, weight, italic, has_color; double x, width, size, rgba[4]; char family[96];
                     int stretch, rtl; double ascent, descent, leading; void *_Nullable font; };
/* a paragraph layout: width 0 = unwrapped; indent = Pango indent (first line minus other lines); align: CTTextAlignment
 * (only justified (3) matters, lines are placed by the caller); wrap: 0 words, 1 characters, 2 none (clip), 3/4/5 one
 * line truncated at the start / end / middle; dir: -1 natural, 0 left-to-right, 1 right-to-left; tabs: -1 Pango's
 * default, else tab stops (tab_align: CTTextAlignment, 5 = decimal); family / weight / italic / size: the layout's
 * default font (empty family: the system font, 12 pt) */
struct isim_ct_para { double width, indent; int align, wrap, dir, single, tabs; double tab_pos[64]; int tab_align[64];
                      char family[160]; int weight, italic; double size; };
/* line metrics without any placement: ink is (x, y, w, h) y-up from the baseline; start/len in UTF-8 bytes */
struct isim_ct_line { double ascent, descent, leading, width, trailing, ink[4]; int start, len, rtl, para_start; };
/* a font's metrics (points), names and face: face_weight is the OpenType weight of the face file, synthetic 1 = bold
 * synthesized, 2 = oblique synthesized */
struct isim_ct_font_info { double size, ascent, descent, leading, cap_height, x_height, underline_position, underline_thickness, slant_angle, bbox[4];
                           int units_per_em, glyph_count, mono, color, weight, italic, stretch, face_weight, face_italic, face_width, synthetic;
                           char family[96], style[64], psname[128], file[512]; };
void *_Nullable isim_ct_layout_create(const char *markup, double width, int align, double spacing, int single);
void isim_ct_layout_free(void *_Nullable l);
int isim_ct_layout_lines(void *l);
/* metrics of a line; x: offset of the line inside the layout, baseline: from the layout top; start/len in UTF-8 bytes */
void isim_ct_line_info(void *l, int line, double *ascent, double *descent, double *width, double *x, double *baseline, int *start, int *len, double *trailing_ws);
int isim_ct_line_runs(void *l, int line, struct isim_ct_run *_Nullable out, int max);
int isim_ct_run_glyphs(void *l, int line, int run, unsigned short *_Nullable glyphs, double *_Nullable pos, double *_Nullable adv, int *_Nullable idx, int max);
int isim_ct_line_index_at(void *l, int line, double x);          /* UTF-8 byte index */
double isim_ct_line_x_at(void *l, int line, int byte_index);
/* draws a line with its baseline origin at (x, y) in user space, glyphs y-up (Core Graphics text space), tm = text matrix */
void isim_ct_line_draw(void *l, int line, double x, double y, const double *_Nullable tm, const double *rgba);
void *_Nullable isim_ct_layout_create_para(const char *markup, const struct isim_ct_para *p);
void isim_ct_line_metrics(void *l, int line, struct isim_ct_line *out);
/* ink bounds (x, y, w, h; y-up) of glyphs [start, start + len) of a run, x from the line start */
void isim_ct_run_ink(void *l, int line, int run, int start, int len, double *rect);
/* fonts: a PangoFont for a family list (NULL: the system font), Pango weight (0: regular), italic, Pango stretch, size */
void *_Nullable isim_ct_font_load(const char *_Nullable family, int weight, int italic, int stretch, double size);
void isim_ct_font_retain(void *_Nullable f);
void isim_ct_font_free(void *_Nullable f);
void isim_ct_font_info(void *_Nullable f, struct isim_ct_font_info *out);
/* nominal glyphs of code points (0 = none); returns how many were found */
int isim_ct_font_glyphs(void *_Nullable f, const unsigned *cps, unsigned short *glyphs, int n);
/* advances and bounding rects (x, y, w, h; y-up), points */
void isim_ct_font_glyph_metrics(void *_Nullable f, const unsigned short *glyphs, int n, double *_Nullable adv, double *_Nullable rects);
/* outline: 0 move x y, 1 line x y, 2 quad cx cy x y, 3 cubic x1 y1 x2 y2 x y, 4 close; returns the doubles needed */
int isim_ct_font_glyph_path(void *_Nullable f, unsigned short glyph, double *_Nullable ops, int max);
/* OpenType feature tags (GSUB, GPOS); returns the count, which may exceed max */
int isim_ct_font_features(void *_Nullable f, unsigned *_Nullable tags, int max);
/* draws glyphs at text-space positions (y-up), transformed by tm, at (x, y) in user space */
void isim_ct_font_draw(void *_Nullable f, const unsigned short *glyphs, const double *pos, int n, double x, double y, const double *_Nullable tm, const double *rgba);
/* the faces of a family, one per line: PostScript name, style, family, OpenType weight, italic, fontconfig width (tabs) */
int isim_ct_font_faces(const char *_Nullable family, char *_Nullable out, int outlen);

/* ImageIO: container info and frames (PNG, JPEG, GIF, WebP, BMP, TIFF, ICO via gdk-pixbuf; HEIC via ffmpeg) */
int isim_imgsrc_info(const void *data, long len, int *frames, int *w, int *h, char *type, int typelen, int *orientation, int *alpha, int *loops);
int isim_imgsrc_frame(const void *data, long len, int index, double *delay);
long isim_image_encode_gif(const int *handles, int n, const double *delays, int loops, unsigned char *_Nullable *_Nonnull out);

/* PDF reading through the host's poppler-glib (dlopen'd); 0/NULL when it is not installed */
int isim_pdf_available(void);
void *_Nullable isim_pdf_open(const void *data, long len, int *pages);
void isim_pdf_page_size(void *doc, int page, double *w, double *h);
void isim_pdf_page_render(void *doc, int page);   /* into the current target, y-down from the page's top-left */
void isim_pdf_close(void *_Nullable doc);
__END_DECLS
