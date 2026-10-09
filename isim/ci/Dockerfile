# CI environment for isim: a stock Ubuntu 24.04 with distribution packages (plus clang from LLVM's apt repository),
# so CI proves isim builds and runs on an ordinary Linux. SDL3 is built from source (Ubuntu 24.04 does not package it). isim renders with its bundled fonts
# (isim/fonts), so layout does not depend on the distribution's fonts. Swift compiles in the swift:6.2 image through
# the host's Docker socket (see `build.py ci`).
# Docker Hub rate-limits the shared runners (429), so the same official image comes from Google's mirror of it
FROM mirror.gcr.io/library/ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake ninja-build git ca-certificates gnupg pkg-config python3 python3-venv rsync curl \
      docker.io \
      libcairo2-dev libpango1.0-dev librsvg2-dev libgdk-pixbuf-2.0-dev libfontconfig-dev \
      libwayland-dev libxkbcommon-dev wayland-protocols libegl1-mesa-dev libgles2-mesa-dev \
      libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxss-dev libxtst-dev libxfixes-dev \
      libpulse-dev libasound2-dev libdbus-1-dev libudev-dev \
      fontconfig fonts-noto-core fonts-noto-color-emoji fonts-dejavu-core adwaita-icon-theme imagemagick \
      ffmpeg espeak-ng libzbar0 zbar-tools qrencode libssl3 libcurl4 libpcre2-8-0 libsqlite3-0 \
      libwebkitgtk-6.0-dev libgtk-4-dev libgtk-4-bin libpoppler-glib8 \
    && rm -rf /var/lib/apt/lists/*
# clang/lld 22 from LLVM's official apt repository: isim's SDK ships libc++ 22, whose headers need clang 21 or newer
ARG LLVM=22
RUN curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor -o /usr/share/keyrings/llvm.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/llvm.gpg] http://apt.llvm.org/noble/ llvm-toolchain-noble-${LLVM} main" \
       > /etc/apt/sources.list.d/llvm.list \
    && apt-get update && apt-get install -y --no-install-recommends clang-${LLVM} lld-${LLVM} llvm-${LLVM} \
    && rm -rf /var/lib/apt/lists/*
ARG SDL_TAG=release-3.2.24
RUN git clone --depth 1 --branch ${SDL_TAG} https://github.com/libsdl-org/SDL.git /src/SDL \
    && cmake -S /src/SDL -B /src/SDL/build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
         -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF \
    && cmake --build /src/SDL/build && cmake --install /src/SDL/build && ldconfig && rm -rf /src/SDL
# ImageMagick 7's `magick` entry point (Ubuntu ships ImageMagick 6): some sample builds draw their icons with it
RUN printf '#!/bin/sh\nif [ "$1" = identify ] || [ "$1" = montage ] || [ "$1" = compare ]; then c=$1; shift; exec "$c" "$@"; fi\nexec convert "$@"\n' > /usr/local/bin/magick \
    && chmod +x /usr/local/bin/magick
# LLVM tools under their plain names (clang, ld64.lld, llvm-nm, …)
ENV PATH=/usr/lib/llvm-22/bin:$PATH
ENV SDL_AUDIO_DRIVER=dummy
# WebKitGTK's web-process sandbox (bubblewrap) cannot create namespaces in an unprivileged container; CI only loads
# the tests' own local pages
ENV WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
