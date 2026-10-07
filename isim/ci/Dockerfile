# CI environment for isim: the same toolchain and libraries as the development machines (Arch Linux): clang/lld,
# SDL3, cairo/pango, ImageMagick 7, the Adwaita fonts and icons the pixel tests expect, and the optional host
# libraries the tests exercise (ffmpeg, espeak-ng, zbar, OpenSSL, curl, PCRE2, SQLite, WebKitGTK, poppler).
# Swift compiles in the swift:6.2 image through the host's Docker socket (see ci/run.sh).
FROM archlinux:latest
RUN pacman -Syu --noconfirm --needed \
      base-devel git clang lld llvm python rsync pkgconf docker \
      sdl3 cairo pango librsvg gdk-pixbuf2 fontconfig \
      imagemagick adwaita-fonts adwaita-icon-theme noto-fonts \
      ffmpeg espeak-ng zbar qrencode openssl curl pcre2 sqlite \
      webkitgtk-6.0 gtk4 poppler-glib \
    && pacman -Scc --noconfirm
ENV SDL_AUDIO_DRIVER=dummy
