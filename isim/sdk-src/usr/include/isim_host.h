#pragma once
/* isim private host bridge (libisim_host). Used by the isim UIKit implementation only. */
#include <_isim_cdefs.h>
__BEGIN_DECLS
struct isim_device { double width, height, scale, safe_top, safe_bottom, corner_radius; int has_island; char name[48]; };
struct isim_event { int type, pad; double x, y, timestamp; int key, mods; char text[32]; };
enum { ISIM_EV_NONE, ISIM_EV_TOUCH_DOWN, ISIM_EV_TOUCH_MOVE, ISIM_EV_TOUCH_UP, ISIM_EV_QUIT, ISIM_EV_KEY, ISIM_EV_TEXT, ISIM_EV_REDRAW };
void isim_device_metrics(struct isim_device *out);
int isim_display_open(const char *title);
void isim_frame_begin(void);
void isim_frame_end(void);
double isim_time(void);
void isim_gfx_save(void);
void isim_gfx_restore(void);
void isim_gfx_translate(double x, double y);
void isim_gfx_scale(double sx, double sy);
void isim_gfx_clip_rounded(double x, double y, double w, double h, double r);
void isim_gfx_fill_rounded(double x, double y, double w, double h, double r, const double *rgba);
void isim_gfx_stroke_rounded(double x, double y, double w, double h, double r, double lw, const double *rgba);
void isim_gfx_fill_ellipse(double x, double y, double w, double h, const double *rgba);
void isim_gfx_push_group(void);
void isim_gfx_pop_group(double alpha);
void isim_path_begin(void);
void isim_path_move(double x, double y);
void isim_path_line(double x, double y);
void isim_path_curve(double x1, double y1, double x2, double y2, double x, double y);
void isim_path_arc(double cx, double cy, double r, double a0, double a1, int clockwise);
void isim_path_close(void);
void isim_path_rect(double x, double y, double w, double h, double r);
void isim_path_fill(const double *rgba);
void isim_path_stroke(double lw, const double *rgba);
void isim_text_measure(const char *utf8, double size, double weight, int mono, double maxw, int lines, double *w, double *h);
void isim_text_draw(const char *utf8, double x, double y, double w, double size, double weight, int mono, int align, int lines, const double *rgba);
void isim_set_status_bar_style(int dark_content);
int isim_next_event(struct isim_event *ev, double timeout);
void isim_text_input(int on);
const char *isim_bundle_path(void);
__END_DECLS
