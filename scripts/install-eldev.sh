#!/usr/bin/env sh

set -eu

install_dir="${1:-$HOME/.local/bin}"
tmpdir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmpdir"
}

trap cleanup EXIT INT TERM

mkdir -p "$install_dir"
git clone --depth=1 https://github.com/emacs-eldev/eldev.git "$tmpdir/eldev"
install -m 755 "$tmpdir/eldev/bin/eldev" "$install_dir/eldev"
