#!/usr/bin/env bash
# Moves the vendored TeX Live to a new tlpdb snapshot, following
# pkgs/texlive/UPGRADING.md:
#   1. set `version` in pkgs/texlive/default.nix
#   2. update the hash of texlive.tlpdb.xz
#   3. regenerate tlpdb.nix
#   4. build the new packages and regenerate fixed-hashes.nix
#   5. check that every package is packaged; write NEW-PACKAGES.md
#
# Usage: scripts/update-snapshot.sh [options] [YYYY-MM-DD]
#   YYYY-MM-DD    snapshot day on texlive.info/tlnet-archive (default: yesterday)
#   --year YYYY   switch to another TeX Live year (annual cycle)
#   --freeze      use the final (historic) tlnet of the current year
#   --jobs N      parallel builds while generating fixed hashes (default: nproc)
#   --skip-hashes stop after regenerating tlpdb.nix
set -euo pipefail

cd "$(dirname "$0")/.."

default=pkgs/texlive/default.nix
system=$(nix eval --impure --raw --expr builtins.currentSystem)
jobs=$(nproc)
year=
final=false
skip_hashes=
date=

while (($#)); do
  case "$1" in
    --year) year=$2; shift ;;
    --freeze) final=true ;;
    --jobs) jobs=$2; shift ;;
    --skip-hashes) skip_hashes=1 ;;
    -h | --help) sed -n '2,/^set /p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
    *) date=$1 ;;
  esac
  shift
done

date=${date:-$(date -d yesterday +%F)}
IFS=- read -r y m d <<<"$date"

log() { printf '\e[1m==> %s\e[0m\n' "$*" >&2; }

log "Setting snapshot ${date} (final=${final}${year:+, year=$year})"
sed -i -E "/^  version = \{/,/^  \};/{
  s/^(    year = )\"[0-9]+\";/\1\"$y\";/
  s/^(    month = )\"[0-9]+\";/\1\"$m\";/
  s/^(    day = )\"[0-9]+\";/\1\"$d\";/
  s/^(    final = )(true|false);/\1$final;/
  ${year:+s/^(    texliveYear = )[0-9]+;/\\1$year;/}
}" "$default"

log "Updating the hash of texlive.tlpdb.xz"
fake=sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
set_tlpdb_hash() {
  sed -i -E "/^  tlpdbxz = fetchurl \{/,/^  \};/s|hash = \"[^\"]*\";|hash = \"$1\";|" "$default"
}
set_tlpdb_hash "$fake"
hash=$(nix build --no-link ".#texlive.tlpdb.xz" 2>&1 | sed -nE 's/^ *got: *(sha256-.*)$/\1/p' || true)
if [[ -z $hash ]]; then
  log "could not fetch texlive.tlpdb.xz for ${date}"
  exit 1
fi
set_tlpdb_hash "$hash"

log "Regenerating tlpdb.nix"
out=$(nix build --no-link --print-out-paths ".#texlive.tlpdb.nix")
install -m 644 "$out" pkgs/texlive/tlpdb.nix

log "Matching LuaMetaTeX to the ConTeXt sources of the snapshot"
src=$(nix build --no-link --print-out-paths ".#texlive.pkgs.context.texsource")/source/context/base
zip=$(ls "$src"/luametatex-*.src.zip)
level=${zip##*/luametatex-}
level=${level%.src.zip}
lmtx_version=$(nix shell nixpkgs#unzip -c unzip -p "$zip" '*luametatex.h' |
  sed -nE 's/^# *define luametatex_version_string +"([^"]+)".*/\1/p')
sed -i -E "/^  context =/,/^    in/{
  s/^(      version = )\"[^\"]*\";/\1\"$lmtx_version\";/
  s/^(      level = )\"[^\"]*\";/\1\"$level\";/
}" pkgs/texlive/bin.nix

if [[ -n $skip_hashes ]]; then
  exit 0
fi

log "Building new packages to compute their fixed hashes (-j ${jobs})"
nix build --no-link -j "$jobs" --keep-going ".#maintainers.newHashes"

log "Regenerating fixed-hashes.nix"
out=$(nix build --no-link --print-out-paths ".#maintainers.fixedHashesNix")
install -m 644 "$out" pkgs/texlive/fixed-hashes.nix

log "Checking that every package in texlive.tlpdb is packaged"
nix build --no-link -L ".#checks.${system}.completeness"
nix build --no-link -L ".#checks.${system}.texlive-fixedHashes"

log "Writing NEW-PACKAGES.md"
nix eval --raw ".#maintainers.packageReport" >NEW-PACKAGES.md

log "Done: review the diff, then build .#checks.${system}.allPackages and the test suite"
