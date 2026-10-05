# Runtime-only image: installs the official CI-built Darling .debs for pinned commit
# 60ba801decee7a00782f74f6be4c8ffb013f79ff (GitHub Actions run 34051607000, artifact "debs").
FROM ubuntu:24.04
COPY dl/debs/darling-core_*.deb dl/debs/darling-system_*.deb dl/debs/darling-cli_*.deb \
     dl/debs/darling-cli-gui-common_*.deb dl/debs/darling-cli-python2-common_*.deb /debs/
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends /debs/*.deb file binutils \
 && rm -rf /var/lib/apt/lists/* /debs
