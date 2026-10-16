{
  description = "The latest TeX Live for Nix, ahead of nixpkgs, with the nixpkgs texlive API";

  nixConfig = {
    extra-substituters = [ "https://lbssousa-texlive.cachix.org" ];
    extra-trusted-public-keys = [ "lbssousa-texlive.cachix.org-1:uRToqIsCIAfEOw+7I9q2CGyL5BOLJTFtBf1bJR/ut9Q=" ];
  };

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # the additive overlay never steps aside, so the flake outputs always
      # expose the vendored TeX Live
      latestFor = pkgs: pkgs.extend self.overlays.additive;

      # texliveLatestFoo -> texliveFoo
      unprefix = lib.mapAttrs' (
        name: lib.nameValuePair ("texlive" + lib.removePrefix "texliveLatest" name)
      );
    in
    {
      overlays = {
        default = import ./overlays/default.nix;
        additive = import ./overlays/additive.nix;
      };

      packages = forAllSystems (
        pkgs:
        let
          latest = latestFor pkgs;
          top = unprefix (
            import ./lib/top-level.nix { inherit lib; } {
              texlive = latest.texliveLatest;
              prefix = "texliveLatest";
            }
          );
        in
        # drop schemes that no longer exist upstream (they throw)
        lib.filterAttrs (_: drv: (builtins.tryEval drv).success) (removeAttrs top [
          "texlivePackages"
          # needs allowUnfree; exposed via legacyPackages to keep `nix flake check` happy
          "texliveFullUnfree"
        ])
        // {
          default = latest.texliveLatestSmall;
        }
      );

      # texlive itself and the individual packages are attribute sets, not
      # derivations, so they live here:
      #   nix build .#texlive.bin.core
      #   nix build .#texlivePackages.<name>
      legacyPackages = forAllSystems (
        pkgs:
        let
          latest = latestFor pkgs;
        in
        {
          texlive = latest.texliveLatest;
          texlivePackages = latest.texliveLatestPackages;
          texliveFullUnfree = latest.texliveLatestFullUnfree;
          maintainers = import ./lib/maintainers.nix { inherit pkgs latest; };
        }
      );

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = [
            ((latestFor pkgs).texliveLatestSmall.withPackages (ps: [ ps.latexmk ]))
            pkgs.nixfmt
          ];
        };
      });

      checks = forAllSystems (pkgs: import ./tests { inherit pkgs self; });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
