#!/usr/bin/env bash
# Reports where texlive-nix stands in the yearly TeX Live cycle.
# Prints one line per event that needs attention and exits 1 if any:
#   upstream-caught-up  nixpkgs ships a TeX Live at least as recent as ours
#   new-release         CTAN distributes a newer TeX Live year than ours
#   frozen              our year was frozen upstream: run update-snapshot.sh --freeze
set -euo pipefail

cd "$(dirname "$0")/.."

ours=$(nix eval --impure --expr '(import ./pkgs/texlive/tlpdb.nix)."00texlive.config".year')
frozen=$(nix eval --raw --impure --expr 'if (import ./pkgs/texlive/tlpdb.nix)."00texlive.config".frozen then "1" else "0"')
caught_up=$(nix eval --raw --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
    nixpkgs = flake.inputs.nixpkgs;
    version = import ./lib/version.nix { inherit (nixpkgs) lib; };
  in if version.upstreamIsCurrent nixpkgs.legacyPackages.${builtins.currentSystem} then "1" else "0"')

ctan=$(curl -fsSL https://mirror.ctan.org/systems/texlive/tlnet/tlpkg/texlive.tlpdb.xz | xz -dc |
  sed -n '/^name 00texlive.config$/,/^$/p' | sed -nE 's!^depend release/([0-9]+)$!\1!p')

status=0
if [[ $caught_up == 1 ]]; then
  echo "upstream-caught-up: nixpkgs ships TeX Live $ours or newer"
  status=1
fi
if ((ctan > ours)); then
  echo "new-release: CTAN distributes TeX Live $ctan (we package $ours)"
  status=1
  if [[ $frozen == 0 ]]; then
    echo "frozen: TeX Live $ours is final now, run scripts/update-snapshot.sh --freeze"
  fi
fi
exit $status
