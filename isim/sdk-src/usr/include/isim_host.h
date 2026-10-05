#pragma once
/* isim private host bridge (libisim_host). Used by the isim UIKit implementation only. */
#include <_isim_cdefs.h>
__BEGIN_DECLS
struct isim_device { double width, height, scale, safe_top, safe_bottom, corner_radius; int has_island; char name[48]; };
struct isim_event { int type, pad; double x, y, timestamp; int key, mods; char text[1024]; };
enum { ISIM_EV_NONE, ISIM_EV_TOUCH_DOWN, ISIM_EV_TOUCH_MOVE, ISIM_EV_TOUCH_UP, ISIM_EV_QUIT, ISIM_EV_KEY, ISIM_EV_TEXT, ISIM_EV_REDRAW, ISIM_EV_ID_DOWN, ISIM_EV_ID_UP, ISIM_EV_DUMP, ISIM_EV_TEXT_DOWN, ISIM_EV_TEXT_UP,
       ISIM_EV_BACKGROUND, ISIM_EV_FOREGROUND, ISIM_EV_SETTINGS, ISIM_EV_LAUNCH_ID, ISIM_EV_OPEN_URL };
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
void isim_gfx_rotate(double radians);
void isim_gfx_concat(double a, double b, double c, double d, double tx, double ty);
void isim_gfx_clip_path(void);
double isim_gfx_get_alpha(void);
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
void isim_text_end_point(const char *utf8, double size, double weight, int mono, double maxw, double *x, double *y);
void isim_text_draw(const char *utf8, double x, double y, double w, double size, double weight, int mono, int align, int lines, const double *rgba);
/* text with a font family (NULL = system font); fonts registered by the app or installed on the host */
void isim_text_measure_f(const char *utf8, const char *family, double size, double weight, int mono, double maxw, int lines, double *w, double *h);
void isim_text_end_point_f(const char *utf8, const char *family, double size, double weight, int mono, double maxw, double *x, double *y);
void isim_text_draw_f(const char *utf8, const char *family, double x, double y, double w, double size, double weight, int mono, int align, int lines, const double *rgba);
int isim_font_register(const char *path);
int isim_font_lookup(const char *name, char *family, int famlen, double *weight, int *italic);
int isim_font_has_char(const char *family, unsigned codepoint);
void isim_set_status_bar_style(int dark_content);
void isim_set_status_bar_hidden(int hidden);
int isim_next_event(struct isim_event *ev, double timeout);
void isim_text_input(int on);
const char *isim_bundle_path(void);
void isim_post_wakeup(void);          /* any thread: wake the UI loop */
int isim_open_url(const char *url);
/* shell (isim boot): is this app running under the shell; requests to it */
int isim_shell_present(void);
enum { ISIM_SHELL_LAUNCH = 3, ISIM_SHELL_SETTINGS = 4, ISIM_SHELL_HOME = 5, ISIM_SHELL_TERMINATE_OTHERS = 6, ISIM_SHELL_TERMINATE_APP = 7, ISIM_SHELL_ICON = 8,
       ISIM_SHELL_RESTART_SYSTEM = 9 /* e.g. after a language change: quit apps, relaunch the home screen and the sender */ };
void isim_shell_request(int type, const char *a, const char *b, const char *c);
/* images (handles > 0). Sizes: pixels for files/data; per 1pt of font size for symbols. */
int isim_image_load(const char *path, double *w, double *h);
int isim_image_load_data(const void *data, unsigned long len, double *w, double *h);
int isim_image_symbol(const char *name, double *w, double *h);
void isim_image_draw(int handle, double x, double y, double w, double h, const double *tint_rgba, double alpha);
int isim_image_is_template(int handle);
void isim_image_free(int handle);
void isim_image_draw_part(int handle, double sx, double sy, double sw, double sh, double x, double y, double w, double h,
                          int nearest, const double *blend_rgba, double blend_factor, double alpha);
void isim_image_pixel_size(int handle, double *w, double *h);
/* audio: PCM buffers (float, interleaved) played as mixed voices. Voice handles are longs (> 0). */
int isim_audio_available(void);
int isim_audio_buffer_create(const float *pcm, long frames, int channels, double rate);
void isim_audio_buffer_release(int buffer);
long isim_audio_play(int buffer, double volume, int loops);      /* loops: 0 once, n extra times, -1 forever */
void isim_audio_stop(long voice);
void isim_audio_pause(long voice, int paused);
void isim_audio_set_volume(long voice, double volume);
int isim_audio_is_playing(long voice);
double isim_audio_position(long voice);
void isim_audio_seek(long voice, double seconds);
void isim_audio_suspend(int suspended);
__END_DECLS
