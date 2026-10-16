# Flake checks:
#  - the nixpkgs TeX Live test suite (tests/texlive.nix, vendored from
#    nixpkgs pkgs/test/texlive) run against the vendored TeX Live
#  - completeness: every package of texlive.tlpdb is packaged individually
#  - allPackages: every output of every individual package builds
{ pkgs, self }:
let
  inherit (pkgs) lib;

  latest = pkgs.extend self.overlays.additive;
  inherit (latest) texliveLatest;

  # build all packages, including the unfree ones kept out of the schemes
  latestUnfree =
    (import pkgs.path {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).extend
      self.overlays.additive;

  upstreamTests = latest.callPackage ./texlive.nix {
    texlive = texliveLatest;
    texliveInfraOnly = latest.texliveLatestInfraOnly;
    texliveConTeXt = latest.texliveLatestConTeXt;
    texliveSmall = latest.texliveLatestSmall;
    texliveMedium = latest.texliveLatestMedium;
    texliveFull = latest.texliveLatestFull;
  };

  # flatten nested test sets into "a-b-c" names, as `checks` must be flat
  flatten =
    prefix: set:
    lib.concatMapAttrs (
      name: value:
      if lib.isDerivation value then
        { ${prefix + name} = value; }
      else if value.recurseForDerivations or false then
        flatten "${prefix}${name}-" value
      else
        { }
    ) set;

  # package names as tl2nix.sed selects them: no "." except texlive.infra
  completeness =
    pkgs.runCommand "texlive-test-completeness"
      {
        tlpdbxz = texliveLatest.tlpdb.xz;
        packaged = pkgs.writeText "packaged" (lib.concatLines (lib.attrNames texliveLatest.pkgs));
      }
      ''
        xzcat "$tlpdbxz" | sed -rn 's/^name ([^.]+|texlive\.infra)$/\1/p' | sort -u > upstream
        sort -u "$packaged" > packaged
        comm -23 upstream packaged > missing
        if [[ -s missing ]]; then
          echo "packages in texlive.tlpdb missing from texlive.pkgs:"
          cat missing
          exit 1
        fi
        echo "$(wc -l < upstream) packages in texlive.tlpdb, all packaged" | tee "$out"
      '';

  allOutputs = drv: map (output: drv.${output}) (drv.outputs or [ "out" ]);

  allPackages = pkgs.linkFarm "texlive-all-packages" (
    lib.concatMap (
      drv:
      lib.imap0 (i: path: {
        name = "${drv.pname}-${toString i}";
        inherit path;
      }) (allOutputs drv)
    ) (lib.attrValues latestUnfree.texliveLatestPackages)
  );
in
lib.mapAttrs' (name: lib.nameValuePair "texlive-${name}") (flatten "" upstreamTests)
// {
  inherit completeness allPackages;
}
