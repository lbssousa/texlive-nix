# texlive-nix: adjustments applied on top of tlpdb-overrides.nix.
#
# Kept in a separate file so that the vendored nixpkgs files stay as close
# to upstream as possible.
{ lib }:
tlpdb:
let
  isFree =
    pname: lib.all (l: (lib.licenses.${l} or { free = true; }).free) (tlpdb.${pname}.license or [ ]);

  # every package whose license is not free (e.g. utbmciad-report in TL2026)
  unfree = lib.filter (pname: !isFree pname) (lib.attrNames tlpdb);

  isBundle = pname: lib.hasPrefix "collection-" pname || lib.hasPrefix "scheme-" pname;
in
# Unfree packages are dropped from collections and schemes, so that
# texliveFull and friends stay free and buildable by default. They remain
# available individually (texlive.pkgs.<name>) and through texliveFullUnfree.
lib.mapAttrs (
  pname: attrs:
  if isBundle pname && attrs ? deps then
    attrs // { deps = lib.subtractLists unfree attrs.deps; }
  else
    attrs
) tlpdb
