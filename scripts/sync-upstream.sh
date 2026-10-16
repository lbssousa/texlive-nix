#!/usr/bin/env bash
# Brings changes made to nixpkgs' TeX Live expressions into the vendored copy
# with a three-way merge per file:
#   base   = nixpkgs at the revision recorded in pkgs/texlive/UPSTREAM
#   theirs = nixpkgs at REV (default: master)
#   ours   = the files in this repository
# Generated files (tlpdb.nix, fixed-hashes.nix) always keep our version.
#
# Usage: scripts/sync-upstream.sh [REV]
# Exit status: 0 = merged cleanly (or nothing to do), 1 = conflicts left in files
set -euo pipefail

cd "$(dirname "$0")/.."

upstream_file=pkgs/texlive/UPSTREAM
rev=${1:-master}
base=$(awk '$1 == "nixpkgs" && $4 == "pkgs/tools/typesetting/tex/texlive" { print $3 }' "$upstream_file")
new=$(git ls-remote https://github.com/NixOS/nixpkgs.git "$rev" | awk 'NR == 1 { print $1 }')
new=${new:-$rev}

if [[ $base == "$new" ]]; then
  echo "already at nixpkgs $new"
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fetch() {
  mkdir -p "$tmp/$1"
  curl -fsSL "https://codeload.github.com/NixOS/nixpkgs/tar.gz/$2" |
    tar -xz -C "$tmp/$1" --strip-components=1 \
      --wildcards '*/pkgs/tools/typesetting/tex/texlive/*' '*/pkgs/test/texlive/*'
}
fetch base "$base" &
fetch theirs "$new" &
wait

conflicts=0
merge() { # ours base theirs
  local ours=$1 base=$2 theirs=$3
  if [[ ! -e $theirs ]]; then
    [[ -e $base ]] && echo "removed upstream (kept here, please review): $ours"
    return
  fi
  if [[ ! -e $ours ]]; then
    echo "new upstream file: $ours"
    cp "$theirs" "$ours"
    return
  fi
  if ! git merge-file -L ours -L "nixpkgs ${base##*/}" -L "nixpkgs $new" "$ours" "$base" "$theirs"; then
    echo "CONFLICT: $ours"
    conflicts=1
  fi
}

src=pkgs/tools/typesetting/tex/texlive
declare -A seen
for f in "$tmp"/base/$src/* "$tmp"/theirs/$src/*; do
  name=${f##*/}
  case $name in tlpdb.nix | fixed-hashes.nix) continue ;; esac
  [[ -n ${seen[$name]:-} ]] && continue
  seen[$name]=1
  merge "pkgs/texlive/$name" "$tmp/base/$src/$name" "$tmp/theirs/$src/$name"
done
merge tests/texlive.nix "$tmp/base/pkgs/test/texlive/default.nix" "$tmp/theirs/pkgs/test/texlive/default.nix"
# the vendored tests point at our tlpdb.nix
sed -i 's|\.\./\.\./tools/typesetting/tex/texlive/tlpdb\.nix|../pkgs/texlive/tlpdb.nix|' tests/texlive.nix

sed -i "s|$base|$new|g" "$upstream_file"
echo "synced with nixpkgs $new (was $base)"
exit $conflicts
