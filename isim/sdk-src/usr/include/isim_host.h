#pragma once
/* isim private host bridge (libisim_host). Used by the isim UIKit implementation only. */
#include <_isim_cdefs.h>
#include <stddef.h>
#include <stdint.h>
__BEGIN_DECLS
struct isim_device { double width, height, scale, safe_top, safe_bottom, corner_radius; int has_island; char name[48];
                     double safe_left, safe_right; int orientation; };   /* orientation: UIInterfaceOrientation of the screen */
struct isim_event { int type, pad; double x, y, timestamp; int key, mods; char text[1024]; };
enum { ISIM_EV_NONE, ISIM_EV_TOUCH_DOWN, ISIM_EV_TOUCH_MOVE, ISIM_EV_TOUCH_UP, ISIM_EV_QUIT, ISIM_EV_KEY, ISIM_EV_TEXT, ISIM_EV_REDRAW, ISIM_EV_ID_DOWN, ISIM_EV_ID_UP, ISIM_EV_DUMP, ISIM_EV_TEXT_DOWN, ISIM_EV_TEXT_UP,
       ISIM_EV_BACKGROUND, ISIM_EV_FOREGROUND, ISIM_EV_SETTINGS, ISIM_EV_LAUNCH_ID, ISIM_EV_OPEN_URL,
       ISIM_EV_KEY_UP = 19 /* key released; for ISIM_EV_KEY / ISIM_EV_KEY_UP `pad` is the USB HID usage (0 if unknown) */
       , ISIM_EV_NOTIFICATION_RESPONSE = 20 /* text: request identifier (18 is shell-internal) */
       , ISIM_EV_DEVICE_ORIENTATION = 21 /* key: UIDeviceOrientation (the device was turned) */
       /* touch events: `pad` is the finger (0 first, 1 second: Option-drag / script pinch, rotate2, twofinger) */
       , ISIM_EV_HOVER = 40 /* pointer moved without touching (x, y); pad 1: the pointer left */
       , ISIM_EV_TEXT_EDITING = 41 /* IME composition: text = marked text, key = cursor (characters), mods = selected length */
       , ISIM_EV_VOICEOVER = 42 /* text: on|off|next|prev|activate|read (script `voiceover`) */
       , ISIM_EV_TEXT_SERVICE = 43 /* text: dictate:TEXT | dictate-fail | scribble:X Y TEXT | sms:TEXT (script `dictate`, `scribble`, `sms`) */
       , ISIM_EV_SYSTEM = 50 /* text: a system message from the shell ("bgtask ID", "discard-scenes", ...; shell_system.inc) */ };
void isim_device_metrics(struct isim_device *out);
int isim_os_version(void);                            /* the iOS version isim emulates (--os): major*10000 + minor*100 + patch */
void isim_gfx_glass(double x, double y, double w, double h, double r, const double *tint, int flags);   /* Liquid Glass; flags 1 dark, 2 clear, 4 no shadow, 8 pressed */
/* several glass shapes (5 doubles each: x y w h corner) that merge when closer than `spacing`; tints 4 each or NULL,
   pressed per shape or NULL (UIGlassContainerEffect) */
void isim_gfx_glass_shapes(int n, const double *shapes, const double *tints, const int *pressed, double spacing, int flags);
int isim_set_orientation(int interfaceOrientation);   /* the screen takes this UIInterfaceOrientation; 1 if it changed */
int isim_device_orientation(void);                    /* current UIDeviceOrientation */
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
/* blurs what is drawn under the rounded rect by `radius` points (materials / UIVisualEffectView) */
void isim_gfx_backdrop_blur(double x, double y, double w, double h, double corner, double radius);
void isim_gfx_push_group(void);
void isim_gfx_pop_group(double alpha);
void isim_gfx_pop_group_masked(double alpha);   /* after push_group (content) + push_group (mask): content through the mask's alpha */
void isim_gfx_set_blend(int mode);   /* until restore: 0 over, 1 add, 2 subtract, 3 multiply, 4 screen, 5 replace */
void isim_path_begin(void);
void isim_path_move(double x, double y);
void isim_path_line(double x, double y);
void isim_path_curve(double x1, double y1, double x2, double y2, double x, double y);
void isim_path_arc(double cx, double cy, double r, double a0, double a1, int clockwise);
void isim_path_close(void);
void isim_path_rect(double x, double y, double w, double h, double r);
/* rounded rect with a radius per corner (top-left, top-right, bottom-left, bottom-right) */
void isim_path_corners(double x, double y, double w, double h, const double *radii);
/* rounded-rect corners from now on: 1 continuous (the default), 0 circular, -1 unchanged; returns the previous */
int isim_gfx_corner_curve(int continuous);
void isim_path_fill(const double *rgba);
void isim_path_stroke(double lw, const double *rgba);
/* stroke style of the graphics state: cap 0 butt 1 round 2 square; join 0 miter 1 round 2 bevel; dash lengths (ndash 0 = solid) */
void isim_path_set_line_style(int cap, int join, double miter, const double *_Nullable dash, int ndash, double phase);
/* fill rule of the graphics state for fills and clips: 0 nonzero winding, 1 even-odd */
void isim_path_set_fill_rule(int even_odd);
/* gradient paint of the current path (kept): mode 0 fill, 1 stroke (width lw), 2 paint the clip area.
   kind 0 linear (geom x0 y0 x1 y1), 1 radial (cx0 cy0 r0 cx1 cy1 r1), 2 conic (cx cy startAngle endAngle, radians, y-down).
   n stops: locs[n], rgba[4n]; extend 0 none 1 pad 2 repeat 3 reflect; matrix: optional gradient -> user space [a b c d tx ty] */
void isim_path_gradient(int mode, int kind, const double *geom, int n, const double *locs, const double *rgba, int extend, double lw, const double *_Nullable matrix);
void isim_text_measure(const char *utf8, double size, double weight, int mono, double maxw, int lines, double *w, double *h);
void isim_text_end_point(const char *utf8, double size, double weight, int mono, double maxw, double *x, double *y);
void isim_text_draw(const char *utf8, double x, double y, double w, double size, double weight, int mono, int align, int lines, const double *rgba);
/* text with a font family (NULL = system font); fonts registered by the app or installed on the host.
   mono is a style mask: ISIM_TEXT_MONO, ISIM_TEXT_ITALIC, ISIM_TEXT_TABULAR (monospaced digits); 0 / 1 as before */
enum { ISIM_TEXT_MONO = 1, ISIM_TEXT_ITALIC = 2, ISIM_TEXT_TABULAR = 4 };
void isim_text_measure_f(const char *utf8, const char *family, double size, double weight, int mono, double maxw, int lines, double *w, double *h);
void isim_text_end_point_f(const char *utf8, const char *family, double size, double weight, int mono, double maxw, double *x, double *y);
void isim_text_draw_f(const char *utf8, const char *family, double x, double y, double w, double size, double weight, int mono, int align, int lines, const double *rgba);
int isim_font_register(const char *path);
int isim_font_app_face(int i, char *family, int famlen, char *ps, int pslen);   /* registered app fonts, in order */
int isim_font_lookup(const char *name, char *family, int famlen, double *weight, int *italic);
int isim_font_has_char(const char *family, unsigned codepoint);
void isim_set_status_bar_style(int dark_content);
void isim_set_status_bar_hidden(int hidden);
void isim_set_home_indicator_autohide(int hide);      /* the home indicator fades 2 s after the last touch */
void isim_set_deferred_system_edges(int edges);       /* UIRectEdge bits: the system gesture from those edges needs a second swipe */
int isim_next_event(struct isim_event *ev, double timeout);
void isim_text_input(int on);
const char *isim_bundle_path(void);
void isim_post_wakeup(void);          /* any thread: wake the UI loop */
int isim_open_url(const char *url);
/* shell (isim boot): is this app running under the shell; requests to it */
int isim_shell_present(void);
enum { ISIM_SHELL_LAUNCH = 3, ISIM_SHELL_SETTINGS = 4, ISIM_SHELL_HOME = 5, ISIM_SHELL_TERMINATE_OTHERS = 6, ISIM_SHELL_TERMINATE_APP = 7, ISIM_SHELL_ICON = 8,
       ISIM_SHELL_RESTART_SYSTEM = 9 /* e.g. after a language change: quit apps, relaunch the home screen and the sender */,
       ISIM_SHELL_NOTIFY = 10 /* banner from a background app: a = identifier "\x1f" icon path, b = title, c = body */,
       ISIM_SHELL_SYSTEM = 40 /* system integration: a = verb, b/c = arguments (see runtime/shell_system.inc) */ };
void isim_shell_request(int type, const char *a, const char *b, const char *c);
/* images (handles > 0). Sizes: pixels for files/data; per 1pt of font size for symbols. */
int isim_image_load(const char *path, double *w, double *h);
int isim_image_load_data(const void *data, unsigned long len, double *w, double *h);
int isim_image_symbol(const char *name, double *w, double *h);
void isim_image_draw(int handle, double x, double y, double w, double h, const double *tint_rgba, double alpha);
/* symbols: draw with a UIImageSymbolWeight (0 unspecified, 1 ultraLight ... 9 black) */
void isim_image_draw_symbol(int handle, double x, double y, double w, double h, const double *tint_rgba, double alpha, int weight);
/* symbol rendering modes: layers (2: glyph in an enclosure, else 1) and drawing with rgba[8] (primary, secondary) */
int isim_image_symbol_layers(int handle);
void isim_image_draw_symbol_layered(int handle, double x, double y, double w, double h, const double *rgba2, double alpha, int weight);
int isim_image_is_template(int handle);
void isim_image_free(int handle);
void isim_image_draw_part(int handle, double sx, double sy, double sw, double sh, double x, double y, double w, double h,
                          int nearest, const double *blend_rgba, double blend_factor, double alpha);
void isim_image_pixel_size(int handle, double *w, double *h);
/* offscreen drawing: begin pushes an image surface (w x h points at scale) as the drawing target; snapshot copies
   it into a new image handle; end pops it. encode: fmt 0 PNG, 1 JPEG; returns the length, *out freed with bytes_free */
int isim_gfx_offscreen_begin(double w, double h, double scale, int opaque);
int isim_gfx_offscreen_snapshot(void);
void isim_gfx_offscreen_end(void);
int isim_gfx_offscreen_depth(void);
long isim_image_encode(int handle, int fmt, double quality, unsigned char *_Nullable *_Nonnull out);
void isim_image_bytes_free(unsigned char *_Nullable bytes);
/* attributed text as Pango markup (<span font_family= size= weight= foreground= ...>); align 0 left 1 center 2 right */
void isim_text_measure_markup(const char *markup, double maxw, int lines, int align, double spacing, double *w, double *h);
void isim_text_draw_markup(const char *markup, double x, double y, double w, int lines, int align, double spacing, const double *rgba);
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
int isim_audio_active(void);        /* voices and streams playing (not paused) in this process: 0 without an audio device */
/* decodes a compressed audio file (AAC/ALAC m4a, MP3, FLAC, ...) to interleaved float PCM with the host's
   ffmpeg or gst-launch-1.0 (48 kHz stereo); returns 0 if it cannot. Free the samples with isim_audio_free. */
int isim_audio_decode_file(const char *path, float *_Nullable *_Nonnull out, long *frames, int *channels, double *rate);
void isim_audio_free(float *_Nullable pcm);
/* networking (host libcurl, dlopen'd): HTTP(S) transfers read with blocking calls from a background thread.
   Errors are NSURLError codes (< 0). isim_http_start returns NULL when the host has no libcurl. */
struct isim_http;
struct isim_http *_Nullable isim_http_start(const char *method, const char *url, const char *_Nullable headers, const void *_Nullable body, long body_len,
                                            double timeout, double resource_timeout, int flags);   /* flags: 1 = do not follow redirects, 2 = accept any certificate */
int isim_http_response(struct isim_http *h, long *status, char *_Nullable *_Nonnull url, char *_Nullable *_Nonnull headers);
long isim_http_read(struct isim_http *h, void *buf, long cap);
const char *isim_http_error_message(struct isim_http *h);
void isim_http_cancel(struct isim_http *h);
void isim_http_close(struct isim_http *_Nullable h);
/* after the body: timings in seconds (t[7]: total, lookup, connect, TLS, request sent, first byte, redirects; -1 unknown),
   ints[4]: HTTP version, new connections (0 = reused), remote port, local port; remote and local IP */
void isim_http_metrics(struct isim_http *h, double *t, long *ints, char *remote, int rlen, char *local, int llen);
struct isim_ws;
struct isim_ws *_Nullable isim_ws_open(const char *url, const char *_Nullable headers, double timeout, int *err);
int isim_ws_send(struct isim_ws *w, int kind, const void *_Nullable data, long len);    /* kind: 1 text, 2 binary, 8 close, 9 ping */
int isim_ws_recv(struct isim_ws *w, int *kind, unsigned char *_Nullable *_Nonnull data, long *len);
void isim_ws_close(struct isim_ws *_Nullable w);
int isim_net_path(int *_Nullable flags);   /* 1 = connected; flags: 1 Wi-Fi, 2 wired, 4 IPv4, 8 IPv6, 16 other (VPN) */
/* file attributes (NSFileManager): account names (group 0 user, 1 group; 1 if found), ids by name (-1 if none),
   and a file system's size, free size (available to the user), nodes and free nodes in out[0..3] (0 or -errno) */
int isim_account_name(int group, unsigned id, char *buf, int n);
long isim_account_id(int group, const char *name);
int isim_fs_stats(const char *path, unsigned long long *out);
/* crypto for isim's CryptoKit (host OpenSSL libcrypto). Return 1 on success, 0 on failure.
   aead alg: 0 AES-GCM, 1 ChaCha20-Poly1305 (16-byte tag; -1 if libcrypto is missing). EC curve: 256, 384 or 521
   (n = 32, 48, 66 bytes: private scalar n, public X9.63 1+2n uncompressed or 1+n compressed, ECDSA signature r||s 2n).
   25519 kind: 0 X25519, 1 Ed25519 (32-byte keys, 64-byte signatures). */
int isim_crypto_available(void);
int isim_crypto_aead(int alg, int encrypt, const void *key, size_t keylen, const void *nonce, size_t noncelen,
                     const void *_Nullable aad, size_t aadlen, const void *_Nullable in, size_t inlen, void *_Nullable out, void *tag);
int isim_crypto_ec_generate(int curve, uint8_t *priv);
int isim_crypto_ec_public(int curve, const uint8_t *priv, uint8_t *pub);
int isim_crypto_ec_import_public(int curve, const uint8_t *pub, size_t len, uint8_t *uncompressed);
int isim_crypto_ec_compress(int curve, const uint8_t *pub, size_t len, uint8_t *compressed);
int isim_crypto_ec_sign(int curve, const uint8_t *priv, const uint8_t *digest, size_t dlen, uint8_t *sig);
int isim_crypto_ec_verify(int curve, const uint8_t *pub, size_t publen, const uint8_t *digest, size_t dlen, const uint8_t *sig);
int isim_crypto_ec_ecdh(int curve, const uint8_t *priv, const uint8_t *pub, size_t publen, uint8_t *shared);
int isim_crypto_25519_public(int kind, const uint8_t *priv, uint8_t *pub);
int isim_crypto_25519_check_public(int kind, const uint8_t *pub);
int isim_crypto_x25519(const uint8_t *priv, const uint8_t *pub, uint8_t *shared);
int isim_crypto_ed25519_sign(const uint8_t *priv, const void *_Nullable msg, size_t len, uint8_t *sig);
int isim_crypto_ed25519_verify(const uint8_t *pub, const void *_Nullable msg, size_t len, const uint8_t *sig);
/* public-key infrastructure for isim's Security module (host_pki.c, host OpenSSL). Return 1 on success, 0 on failure
   (isim_pki_error: why). Key type 0 RSA, 1 EC. Keys in Apple's external representation: RSA PKCS#1 DER; EC X9.63
   04|X|Y (public) / 04|X|Y|D (private). Sizes are in/out: capacity in, length out.
   sign/verify alg: digest (0 none, 1 SHA-1, 2 SHA-224, 3 SHA-256, 4 SHA-384, 5 SHA-512) | 16 if the data is a message
   | scheme << 8 (0 RSA PKCS#1 v1.5, 1 RSA PSS, 2 ECDSA DER signature, 3 ECDSA r||s, 4 RSA raw).
   encrypt/decrypt alg (RSA): 0 PKCS#1 v1.5, 1 raw, 2..6 OAEP SHA-1/224/256/384/512. */
int isim_pki_available(void);
const char *isim_pki_error(void);
int isim_pki_generate(int type, int bits, uint8_t *_Nullable out, size_t *outlen);
int isim_pki_public(int type, const uint8_t *priv, size_t len, uint8_t *_Nullable out, size_t *outlen);
int isim_pki_key_bits(int type, const uint8_t *key, size_t len, int isPrivate);
int isim_pki_sign(int type, const uint8_t *priv, size_t len, int alg, const uint8_t *_Nullable data, size_t dlen, uint8_t *sig, size_t *siglen);
int isim_pki_verify(int type, const uint8_t *pub, size_t len, int alg, const uint8_t *_Nullable data, size_t dlen, const uint8_t *sig, size_t siglen);
int isim_pki_encrypt(const uint8_t *pub, size_t len, int alg, const uint8_t *_Nullable in, size_t inlen, uint8_t *out, size_t *outlen);
int isim_pki_decrypt(const uint8_t *priv, size_t len, int alg, const uint8_t *in, size_t inlen, uint8_t *out, size_t *outlen);
int isim_pki_ecdh(const uint8_t *priv, size_t len, const uint8_t *pub, size_t publen, uint8_t *out, size_t *outlen);
/* certificate description as JSON (see host_pki.c) */
int isim_pki_cert_parse(const uint8_t *der, size_t len, char *json, size_t cap);
/* chain verification: DER certificates (leaf first) and anchors, each concatenated with their sizes in lens */
int isim_pki_trust(const uint8_t *certs, const size_t *lens, int ncerts, const uint8_t *_Nullable anchors, const size_t *_Nullable alens, int nanchors,
                   int useSystemAnchors, int sslServer, const char *_Nullable hostname, double when, char *err, size_t errcap, int *chainlen);
/* PKCS#12: private key (+ type) and certificates (identity certificate first); ncerts -1 if not PKCS#12 */
int isim_pki_pkcs12(const uint8_t *data, size_t len, const char *_Nullable password, uint8_t *key, size_t *keylen, int *keytype,
                    uint8_t *certs, size_t certscap, size_t *certlens, int *ncerts);
/* media (host_media.c): video/audio files and http(s) URLs through the host's ffprobe/ffmpeg */
struct isim_media_info { double duration, width, height, fps; int has_video, has_audio; };
int isim_media_probe(const char *url, struct isim_media_info *info);            /* 0: unreadable / no ffprobe */
/* playback session from `start` seconds: video frames (if want_video) and the soundtrack to the mixer (if want_audio) */
int isim_media_open(const char *url, double start, double width, double height, double fps, int want_video, int want_audio, double volume);
/* UI thread: image handle of the frame for time t (0 before the first frame); eof once all frames were shown */
int isim_media_video_frame(int media, double t, int *eof, double *pts);
void isim_media_set_audio(int media, int paused, double volume);
void isim_media_close(int media);
int isim_media_thumbnail_png(const char *url, double t, double max_side, void *_Nullable *_Nonnull out, long *len);
int isim_media_transcode(const char *in, const char *out);
void isim_media_free(void *_Nullable p);
/* text to speech with espeak-ng/espeak: mono float PCM (free with isim_media_free); 0 if no TTS on the host */
int isim_tts_synthesize(const char *text, const char *voice, double wpm, double pitch, float *_Nullable *_Nonnull out, long *frames, double *rate);
/* audio input (ISIM_AUDIO_INPUT=file|mic): 48 kHz stereo float, paced in real time. start returns 2 mic, 1 file, 0 silence */
int isim_audio_input_start(void);
long isim_audio_input_read(float *out, long max_frames);
void isim_audio_input_stop(void);
/* Core Animation (host_ca.c): perspective warp of a raster image onto a quad (tl, tr, br, bl in user space);
   pop a group as a blurred, tinted, offset drop shadow of its alpha */
void isim_image_draw_quad(int handle, const double *quad, double alpha);
void isim_gfx_pop_group_shadow(const double *rgba, double radius, double dx, double dy);
int isim_gfx_screen_snapshot(double x, double y, double w, double h);   /* what is on the target under the rect (the last frame) */
void isim_gfx_pop_group_tinted(const double *rgba, double alpha);       /* group painted with its pixels multiplied by rgba */
/* group painted through SwiftUI-style effects (colour matrix, blur, drop shadow of its alpha, blend mode; layout of
   the 32 values in host_ca.c), limited to the rect (user space) and what blur/shadow need around it */
void isim_gfx_pop_group_filtered(const double *v, double alpha, double x, double y, double w, double h);
/* remote-control commands queued by the `remote NAME` script command */
int isim_remote_command_poll(char *buf, int len);
/* AVAudioSession events queued by the `audio` script command ("interrupt begin", "interrupt end resume", "route headphones") */
int isim_audio_session_poll(char *buf, int len);
/* audio streams (AudioQueue output): 48 kHz interleaved stereo float drained by the mixer in real time. open returns 0
   when there is no audio device (headless); write returns how many frames fit (0 = full, try later) */
int isim_audio_stream_open(double volume);
long isim_audio_stream_write(int stream, const float *pcm, long frames);
void isim_audio_stream_control(int stream, int paused, double volume);
void isim_audio_stream_close(int stream);
/* stereo balance of a playing voice: -1 left .. 1 right */
void isim_audio_set_pan(long voice, double pan);
/* copies pixels of an image as premultiplied BGRA (rows packed, w*4 bytes) */
int isim_image_read_bgra(int handle, int x, int y, int w, int h, unsigned char *out);
/* simulated camera (host_capture.c): ISIM_CAMERA=<image|video file> or webcam[:/dev/videoN]. source kind: 0 none,
   1 image, 2 video, 3 webcam. frame copies the newest BGRA frame newer than seq (waiting up to timeout s) and returns
   its sequence number, 0 if none; preview (UI thread) returns an image handle of the newest frame */
int isim_camera_source(char *_Nullable desc, int len);
int isim_camera_open(int max_side, double fps, int *w, int *h);
long isim_camera_frame(int camera, unsigned char *_Nullable out, long seq, double timeout);
int isim_camera_preview(int camera);
void isim_camera_close(int camera);
/* runs ffmpeg with args (no shell); progress in seconds of output; *cancel != 0 stops it. 0 ok, -1 no ffmpeg, -2 cancelled */
int isim_ffmpeg_run(const char *_Nullable const *_Nonnull args, int nargs, double *_Nullable progress, volatile int *_Nullable cancel, char *_Nullable err, long errlen);
/* decoded media streams: kind 0 video (BGRA w x h at rate fps), 1 audio (float32 interleaved at rate Hz, channels) */
int isim_media_reader_open(const char *url, int kind, double start, double duration, int w, int h, double rate, int channels);
long isim_media_reader_read(int reader, void *buf, long n);
void isim_media_reader_close(int reader);
/* Vision backends: available kind 1 barcodes (libzbar), 2 text (tesseract), 3 faces (none). Results are malloc'd
   text (free with isim_media_free), NULL when the backend is missing */
int isim_vision_available(int kind);
char *_Nullable isim_vision_barcodes(const unsigned char *bgra, int w, int h, int stride);
char *_Nullable isim_vision_text(const unsigned char *bgra, int w, int h, int stride, const char *_Nullable langs);
char *_Nullable isim_vision_text_languages(void);
/* speech recognition: 1 whisper.cpp (ISIM_WHISPER_MODEL), 2 vosk (ISIM_VOSK_MODEL), 0 none; transcribe takes 16 kHz mono */
int isim_speech_available(void);
char *_Nullable isim_speech_transcribe(const float *pcm, long frames, const char *_Nullable lang);
/* XCUITest (isim XCTest): run the app under test as a child process driven through a control FIFO.
 * argv/envp are NULL-terminated (envp: KEY=VALUE added to the environment); snapshot returns the app's
 * accessibility snapshot text (free with isim_xcui_free) or NULL. */
int isim_xcui_launch(const char *exe, const char *const *argv, const char *const *envp);
int isim_xcui_running(int handle);
int isim_xcui_send(int handle, const char *script_command);
char *isim_xcui_snapshot(int handle, double timeout);
void isim_xcui_free(char *text);
void isim_xcui_terminate(int handle);
/* host game controllers (SDL3 gamepads; ISIM_GAMEPADS=0 disables). buttons: bit i = SDL_GamepadButton i (0 south/A,
   1 east/B, 2 west/X, 3 north/Y, 4 back, 5 guide, 6 start, 7/8 stick clicks, 9/10 shoulders, 11-14 dpad up/down/left/right);
   axes: left x, left y, right x, right y (-1...1, y down), left / right trigger (0...1) */
struct isim_gamepad { int id, vendor, product; unsigned int buttons; float axes[6]; char name[64]; char type[24]; };
int isim_gamepad_poll(struct isim_gamepad *out, int max);   /* connected pads (count), -1 when disabled */
int isim_gamepad_rumble(int id, double low, double high, double seconds);
/* raster image from 32-bit premultiplied BGRA pixels (rows top-down), updated in place */
int isim_image_create_bgra(int w, int h);
void isim_image_update_bgra(int hd, const unsigned char *px, int w, int h);
/* web engine for WKWebView (host_web.c + the isim-webkit helper, WebKitGTK): line protocol, TAB-separated escaped fields.
   available: 1 if the engine can run (reason for 0 in why); next: next event line or NULL (wait up to timeout s; free it);
   frame: image handle of a view's newest page frame (pixels in *w x *h; acknowledges it); release: forget a closed view */
int isim_web_available(char *_Nullable why, int cap);
void isim_web_send(const char *line);
char *_Nullable isim_web_next(double timeout);
void isim_web_free(char *_Nullable s);
int isim_web_frame(int view, int *_Nullable w, int *_Nullable h);
void isim_web_release(int view);
/* TLS client sessions on a connected socket (host_tls.c, the host's OpenSSL libssl) for NWConnection.
   verify 1: CA store + host name; 0: any certificate. alpn: comma-separated or NULL; min_version: 0 or 0x0303/0x0304.
   connect returns NULL with a message (and an OSStatus-style code) on failure; read returns 0 at close, < 0 on error */
struct isim_tls;
struct isim_tls *_Nullable isim_tls_connect(int fd, const char *_Nullable host, int verify, const char *_Nullable alpn, int min_version,
                                            char *err, int errlen, int *_Nullable code);
long isim_tls_read(struct isim_tls *t, void *buf, long n);
long isim_tls_write(struct isim_tls *t, const void *buf, long n);
void isim_tls_info(struct isim_tls *t, char *version, int vlen, char *alpn, int alen);
void isim_tls_close(struct isim_tls *_Nullable t);
__END_DECLS
