#!/bin/bash
# Setup script for a Claude Code cloud environment (claude.ai/code) that builds and tests isim: the same packages as
# CI's image (isim/ci/Dockerfile, keep the two in step), plus Docker and the swift:6.2 image. Paste it into the
# environment's settings (Edit environment → Setup script); it runs as root when a session starts. The environment
# variables to set there are in docs/BUILD.md ("Claude Code cloud environments"). Safe to run again.
set -e
export DEBIAN_FRONTEND=noninteractive

# System packages (the list in isim/ci/Dockerfile)
apt-get update
apt-get install -y --no-install-recommends \
  build-essential cmake ninja-build git ca-certificates gnupg pkg-config python3 python3-venv rsync curl \
  libcairo2-dev libpango1.0-dev librsvg2-dev libgdk-pixbuf-2.0-dev libfontconfig-dev \
  libwayland-dev libxkbcommon-dev wayland-protocols libegl1-mesa-dev libgles2-mesa-dev \
  libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxss-dev libxtst-dev libxfixes-dev \
  libpulse-dev libasound2-dev libdbus-1-dev libudev-dev \
  fontconfig fonts-noto-core fonts-noto-color-emoji fonts-dejavu-core adwaita-icon-theme imagemagick \
  ffmpeg espeak-ng libzbar0 zbar-tools qrencode libssl3 libcurl4 libpcre2-8-0 libsqlite3-0 \
  libwebkitgtk-6.0-dev libgtk-4-dev libgtk-4-bin libpoppler-glib8

# clang/lld 22 from LLVM's apt repository (Ubuntu 24.04 has clang 18; isim's libc++ 22 headers need 21 or newer)
curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor --yes -o /usr/share/keyrings/llvm.gpg
echo "deb [signed-by=/usr/share/keyrings/llvm.gpg] http://apt.llvm.org/noble/ llvm-toolchain-noble-22 main" \
  > /etc/apt/sources.list.d/llvm.list
apt-get update && apt-get install -y --no-install-recommends clang-22 lld-22 llvm-22
ln -sf /usr/lib/llvm-22/bin/* /usr/local/bin/      # plain names (clang, ld64.lld, llvm-nm, …) first on PATH

# SDL3 from source (Ubuntu 24.04 does not package it)
if ! pkg-config --exists sdl3; then
  rm -rf /opt/SDL
  git clone --depth 1 --branch release-3.2.24 https://github.com/libsdl-org/SDL.git /opt/SDL
  cmake -S /opt/SDL -B /opt/SDL/build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF
  cmake --build /opt/SDL/build && cmake --install /opt/SDL/build && ldconfig
fi

# ImageMagick 7's `magick` entry point (Ubuntu ships ImageMagick 6)
printf '#!/bin/sh\nif [ "$1" = identify ] || [ "$1" = montage ] || [ "$1" = compare ]; then c=$1; shift; exec "$c" "$@"; fi\nexec convert "$@"\n' \
  > /usr/local/bin/magick && chmod +x /usr/local/bin/magick

# Docker and the Swift 6.2 image. Docker Hub rate-limits shared egress (429), so pull the same official image from
# Google's mirror and tag it under the name the build uses
docker info >/dev/null 2>&1 || { nohup dockerd > /var/log/dockerd.log 2>&1 & }
for i in $(seq 30); do docker info >/dev/null 2>&1 && break; sleep 1; done
docker image inspect swift:6.2 >/dev/null 2>&1 \
  || { docker pull -q mirror.gcr.io/library/swift:6.2 && docker tag mirror.gcr.io/library/swift:6.2 swift:6.2; }
