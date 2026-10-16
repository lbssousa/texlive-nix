# The TeX Live attributes that nixpkgs' all-packages.nix derives from
# `texlive`, recreated for a given texlive set.
#
# `prefix` replaces the leading "texlive" of every attribute name, e.g.
# "texliveLatest" yields texliveLatestSmall, texliveLatestPackages, ...
#
# Attribute names must not depend on `texlive` (overlays need them before
# the fixpoint is known), hence the static list of schemes below; keep it in
# sync with `schemes` in pkgs/texlive/default.nix.
{ lib }:
{
  texlive,
  prefix ? "texlive",
}:
let
  schemes = [
    "Basic"
    "BookPub"
    "ConTeXt"
    "Full"
    "GUST"
    "InfraOnly"
    "Medium"
    "Minimal"
    "Small"
    "TeTeX"
  ];

  isUnfree = p: !lib.all (l: l.free or true) (lib.toList (p.meta.license or [ ]));

  # unfree packages are kept out of the schemes (see local-overrides.nix)
  unfreePackages = lib.filter isUnfree (lib.attrValues texlive.pkgs);
in
lib.listToAttrs (
  map (
    s:
    lib.nameValuePair (prefix + s) (
      texlive.schemes.${"texlive" + s}
        or (throw "${prefix + s}: scheme-${lib.toLower s} is not part of this TeX Live release anymore")
    )
  ) schemes
)
// {
  ${prefix + "FullWithDocs"} = texlive.schemes.texliveFull.overrideAttrs { withDocs = true; };
  ${prefix + "FullUnfree"} = texlive.schemes.texliveFull.withPackages (_: unfreePackages);
  ${prefix + "Packages"} = lib.recurseIntoAttrs (lib.mapAttrs (_: v: v.build) texlive.pkgs);
}
