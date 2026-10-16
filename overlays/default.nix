# Replaces texlive, the texlive{Basic,Small,Medium,Full,...} schemes,
# texliveFullWithDocs and texlivePackages with the vendored TeX Live, and
# adds texliveFullUnfree.
#
# When nixpkgs already ships a TeX Live at least as recent as the vendored
# one, the overlay steps aside (with a warning) and nixpkgs is used as is.
final: prev:
let
  inherit (prev) lib;
  version = import ../lib/version.nix { inherit lib; };
  useUpstream = version.upstreamIsCurrent prev;

  # attribute names must not depend on `useUpstream`, only values may
  topLevel = import ../lib/top-level.nix { inherit lib; } { inherit (final) texlive; };
in
lib.mapAttrs (name: value: if useUpstream then prev.${name} or value else value) topLevel
// {
  texlive =
    if useUpstream then
      lib.warn "texlive-nix: nixpkgs already provides TeX Live ${version.upstream prev} (vendored: ${version.ours}); using the nixpkgs version" prev.texlive
    else
      import ../lib/mk-texlive.nix final "texlive";
}
