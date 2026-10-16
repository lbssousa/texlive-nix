# Version helpers shared by the overlays.
{ lib }:
let
  toVersion = config: "${toString config.year}.${toString config.revision}";

  vendored = (import ../pkgs/texlive/tlpdb.nix)."00texlive.config";

  # Read straight from the nixpkgs source tree: going through
  # prev.texlive* would recurse into the overlay itself.
  upstreamConfig =
    pkgs:
    let
      file = pkgs.path + "/pkgs/tools/typesetting/tex/texlive/tlpdb.nix";
    in
    if builtins.pathExists file then (import file)."00texlive.config" else null;
in
{
  # "<year>.<tlpdb revision>", comparable with lib.versionAtLeast
  ours = toVersion vendored;
  upstream = pkgs: lib.mapNullable toVersion (upstreamConfig pkgs);

  # true when the given nixpkgs already ships a TeX Live at least as recent
  # as the vendored one
  upstreamIsCurrent =
    pkgs:
    let
      config = upstreamConfig pkgs;
    in
    config != null && lib.versionAtLeast (toVersion config) (toVersion vendored);
}
