# Release build environment for isim's host runtime: Ubuntu 22.04 (glibc 2.35) so the bundled
# binary runs on most current Linux distributions. SDL3 is built from source (not packaged in 22.04), and so is
# HarfBuzz: 22.04 ships 2.7.4, the runtime needs the draw / style / COLRv1 API (>= 7.0; CI's Ubuntu 24.04 has 8.3.0).
# It installs to /usr/local, ahead of the system copy for pkg-config and ld.so, and is bundled as lib/libharfbuzz.so.0.
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential gcc-12 g++-12 clang cmake ninja-build meson git ca-certificates pkg-config patchelf file \
      libcairo2-dev libpango1.0-dev libfreetype-dev libglib2.0-dev librsvg2-dev libgdk-pixbuf-2.0-dev \
      libwayland-dev libxkbcommon-dev wayland-protocols libegl1-mesa-dev libgles2-mesa-dev \
      libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxss-dev libxtst-dev libxfixes-dev libdecor-0-dev \
      libpulse-dev libasound2-dev libdbus-1-dev libudev-dev \
    && rm -rf /var/lib/apt/lists/*
ARG SDL_TAG=release-3.2.24
RUN git clone --depth 1 --branch ${SDL_TAG} https://github.com/libsdl-org/SDL.git /src/SDL \
    && cmake -S /src/SDL -B /src/SDL/build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
         -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF \
    && cmake --build /src/SDL/build && cmake --install /src/SDL/build && ldconfig
ARG HARFBUZZ_TAG=8.3.0
RUN git clone --depth 1 --branch ${HARFBUZZ_TAG} https://github.com/harfbuzz/harfbuzz.git /src/harfbuzz \
    && CC=gcc-12 CXX=g++-12 meson setup /src/harfbuzz/build /src/harfbuzz --buildtype=release --prefix=/usr/local \
         --libdir=lib/x86_64-linux-gnu -Dfreetype=enabled -Dglib=enabled -Dgobject=disabled -Dcairo=disabled \
         -Dchafa=disabled -Dicu=disabled -Dtests=disabled -Dintrospection=disabled -Ddocs=disabled -Dutilities=disabled \
    && ninja -C /src/harfbuzz/build install && ldconfig
