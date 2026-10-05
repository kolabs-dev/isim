# Third-party licenses

Release packages copy this folder to `licenses/`, next to isim's own `LICENSE` and `NOTICE`.

| Component | Where it ships | License |
|---|---|---|
| Swift runtime and standard library, swift-6.2.4-RELEASE | `sdk/usr/lib/swift`, `swift/resource` | Apache-2.0 with Runtime Library Exception (`swift-LICENSE.txt`) |
| libc++ and clang resource headers, llvmorg-22.1.8 | `sdk/usr/lib/libc++*`, `swift/resource/clang` | Apache-2.0 with LLVM Exceptions (`llvm-libcxx-LICENSE.txt`) |
| SDL3, release-3.2.24 | `lib/libSDL3.so*` | zlib (`SDL3-LICENSE.txt`) |
| Ubuntu 22.04 shared libraries (cairo, pango, librsvg, gdk-pixbuf, …) | `lib/` | per package; `release/package.sh` copies each package's Debian copyright file to `licenses/ubuntu/` |
