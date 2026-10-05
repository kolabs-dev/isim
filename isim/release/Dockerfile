# Release build environment for isim's host runtime: Ubuntu 22.04 (glibc 2.35) so the bundled
# binary runs on most current Linux distributions. SDL3 is built from source (not packaged in 22.04).
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential gcc-12 clang cmake ninja-build git ca-certificates pkg-config patchelf file \
      libcairo2-dev libpango1.0-dev librsvg2-dev libgdk-pixbuf-2.0-dev \
      libwayland-dev libxkbcommon-dev wayland-protocols libegl1-mesa-dev libgles2-mesa-dev \
      libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxss-dev libxtst-dev libxfixes-dev libdecor-0-dev \
      libpulse-dev libasound2-dev libdbus-1-dev libudev-dev \
    && rm -rf /var/lib/apt/lists/*
ARG SDL_TAG=release-3.2.24
RUN git clone --depth 1 --branch ${SDL_TAG} https://github.com/libsdl-org/SDL.git /src/SDL \
    && cmake -S /src/SDL -B /src/SDL/build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
         -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF \
    && cmake --build /src/SDL/build && cmake --install /src/SDL/build && ldconfig
