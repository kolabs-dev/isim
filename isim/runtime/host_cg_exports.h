/* host_cg.c exports (Core Graphics bitmap/PDF contexts, pixel access, effects, Core Text layout, ImageIO
 * decoding/encoding, PDF reading). Prototypes for host.c's export table; the guest-side declarations are in
 * sdk-src/usr/include/isim_host_cg.h. */
#pragma once
struct isim_cg_fx;
struct isim_ct_run;
void *isim_cg_bitmap_create(void *data, int w, int h, int bpr, int fmt, int bpp);
void isim_cg_target_bind(void *t);
void isim_cg_target_unbind(void *t);
void isim_cg_target_free(void *t);
int isim_cg_target_image(void *t);
void isim_cg_target_sync(void *t);
void *isim_cg_pdf_create(const char *path, double w, double h);
void isim_cg_pdf_begin_page(void *t, double w, double h);
void isim_cg_pdf_end_page(void *t);
long isim_cg_pdf_finish(void *t, unsigned char **out);
int isim_image_from_pixels(const void *data, int w, int h, int bpr, int fmt, int bpp);
int isim_image_read_pixels(int handle, int x, int y, int w, int h, void *out, int bpr, int fmt, int bpp);
void isim_cg_set_blend(int mode);
void isim_cg_clear_rect(double x, double y, double w, double h);
void isim_cg_get_ctm(double *m);
void isim_cg_set_ctm(const double *m);
int isim_cg_query(int what, double x, double y, double *out);
int isim_cg_copy_path(double *out, int max);
void isim_cg_group_begin(void);
void isim_cg_group_end(const struct isim_cg_fx *fx);
void isim_cg_fill_pattern(int handle, double cw, double ch, const double *matrix, int mode, double lw, double alpha);
void isim_cg_draw_image_tiled(int handle, double sx, double sy, double sw, double sh, double x, double y, double w, double h, double tw, double th);
void *isim_ct_layout_create(const char *markup, double width, int align, double spacing, int single);
void isim_ct_layout_free(void *l);
int isim_ct_layout_lines(void *l);
void isim_ct_line_info(void *l, int line, double *ascent, double *descent, double *width, double *x, double *baseline, int *start, int *len, double *trailing_ws);
int isim_ct_line_runs(void *l, int line, struct isim_ct_run *out, int max);
int isim_ct_run_glyphs(void *l, int line, int run, unsigned short *glyphs, double *pos, double *adv, int *idx, int max);
int isim_ct_line_index_at(void *l, int line, double x);
double isim_ct_line_x_at(void *l, int line, int byte_index);
void isim_ct_line_draw(void *l, int line, double x, double y, const double *tm, const double *rgba);
int isim_imgsrc_info(const void *data, long len, int *frames, int *w, int *h, char *type, int typelen, int *orientation, int *alpha, int *loops);
int isim_imgsrc_frame(const void *data, long len, int index, double *delay);
long isim_image_encode_gif(const int *handles, int n, const double *delays, int loops, unsigned char **out);
void *isim_pdf_open(const void *data, long len, int *pages);
void isim_pdf_page_size(void *doc, int page, double *w, double *h);
void isim_pdf_page_render(void *doc, int page);
void isim_pdf_close(void *doc);
int isim_pdf_available(void);
#define ISIM_CG_EXPORTS(X) \
    X(isim_cg_bitmap_create), X(isim_cg_target_bind), X(isim_cg_target_unbind), X(isim_cg_target_free), X(isim_cg_target_image), \
    X(isim_cg_target_sync), X(isim_cg_pdf_create), X(isim_cg_pdf_begin_page), X(isim_cg_pdf_end_page), X(isim_cg_pdf_finish), \
    X(isim_image_from_pixels), X(isim_image_read_pixels), X(isim_cg_set_blend), X(isim_cg_clear_rect), X(isim_cg_get_ctm), X(isim_cg_set_ctm), X(isim_cg_query), X(isim_cg_copy_path), \
    X(isim_cg_group_begin), X(isim_cg_group_end), X(isim_cg_fill_pattern), X(isim_cg_draw_image_tiled), \
    X(isim_ct_layout_create), X(isim_ct_layout_free), X(isim_ct_layout_lines), X(isim_ct_line_info), X(isim_ct_line_runs), \
    X(isim_ct_run_glyphs), X(isim_ct_line_index_at), X(isim_ct_line_x_at), X(isim_ct_line_draw), \
    X(isim_imgsrc_info), X(isim_imgsrc_frame), X(isim_image_encode_gif), \
    X(isim_pdf_open), X(isim_pdf_page_size), X(isim_pdf_page_render), X(isim_pdf_close), X(isim_pdf_available)
