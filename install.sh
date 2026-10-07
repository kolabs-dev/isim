#!/usr/bin/env bash
# Install or update isim (Linux x86_64) from the GitHub releases.
#
#   curl -fsSL https://raw.githubusercontent.com/kolabs-dev/isim/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/kolabs-dev/isim/main/install.sh | bash -s -- 0.5.0   # a given version
#
# Releases are unpacked to $ISIM_HOME/<version> (default ~/.local/lib/isim), $ISIM_HOME/current points at the active
# one and the `isim` command is linked into $ISIM_BIN_DIR (default ~/.local/bin). Device data (~/.local/share/isim)
# is shared by all versions. `isim update`, `isim versions` and `isim use VERSION` manage installed versions later.
set -euo pipefail
REPO=${ISIM_REPO:-kolabs-dev/isim}
ISIM_HOME=${ISIM_HOME:-$HOME/.local/lib/isim}
BIN_DIR=${ISIM_BIN_DIR:-$HOME/.local/bin}
want=${1:-latest}; want=${want#v}

say() { printf 'isim install: %s\n' "$*" >&2; }
die() { say "$*"; exit 1; }
[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] || die "isim releases are for Linux x86_64 (this is $(uname -s) $(uname -m))"
command -v curl >/dev/null || die "needs curl"
command -v tar >/dev/null || die "needs tar"

if [ "$want" = latest ]; then
  want=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -1)
  [ -n "$want" ] || die "could not find the latest release of $REPO"
fi
name=isim-$want-linux-x86_64
dest=$ISIM_HOME/$want

if [ -x "$dest/bin/isim" ]; then
  say "isim $want is already installed in $dest"
else
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  url=https://github.com/$REPO/releases/download/v$want/$name.tar.gz
  say "downloading $url"
  curl -fL --progress-bar -o "$tmp/$name.tar.gz" "$url" || die "download failed (is $want a released version?)"
  if curl -fsSL -o "$tmp/$name.tar.gz.sha256" "$url.sha256" 2>/dev/null; then
    (cd "$tmp" && sha256sum -c --quiet "$name.tar.gz.sha256") || die "checksum mismatch for $name.tar.gz"
  else
    say "warning: no checksum published for $want; not verified"
  fi
  mkdir -p "$ISIM_HOME"
  tar -xzf "$tmp/$name.tar.gz" -C "$tmp"
  rm -rf "$dest.partial"; mv "$tmp/$name" "$dest.partial"; mv "$dest.partial" "$dest"
fi

ln -sfn "$want" "$ISIM_HOME/current"
mkdir -p "$BIN_DIR"
ln -sfn "$ISIM_HOME/current/bin/isim" "$BIN_DIR/isim"
say "isim $want is active: $BIN_DIR/isim -> $ISIM_HOME/current/bin/isim"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) say "add $BIN_DIR to your PATH, e.g.: echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc" ;;
esac
say "try: isim boot"
