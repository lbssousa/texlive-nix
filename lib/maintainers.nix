# Helpers used by scripts/update-snapshot.sh, exposed as
# legacyPackages.<system>.maintainers.
{ pkgs, latest }:
let
  inherit (pkgs) lib;

  generator = import ../pkgs/texlive/generate-fixed-hashes.nix {
    pkgs = latest // {
      texlive = latest.texliveLatest;
    };
  };

  upstreamNames = lib.attrNames pkgs.texlive.pkgs;
  ourNames = lib.attrNames latest.texliveLatest.pkgs;
  added = lib.subtractLists upstreamNames ourNames;
  removed = lib.subtractLists ourNames upstreamNames;
  version = import ./version.nix { inherit lib; };

  describe =
    name:
    let
      p = latest.texliveLatest.pkgs.${name};
    in
    "| [`${name}`](https://ctan.org/pkg/${name}) | ${p.version or ""} | ${p.meta.description or ""} |";
in
{
  # nix build .#maintainers.newHashes -j N
  newHashes = pkgs.linkFarmFromDrvs "texlive-new-hashes" generator.newHashes;

  # nix build .#maintainers.fixedHashesNix (import from derivation, serial)
  inherit (generator) fixedHashesNix;

  # nix eval --raw .#maintainers.packageReport
  packageReport = ''
    # TeX Live packages: texlive-nix vs nixpkgs

    - nixpkgs: ${toString (version.upstream pkgs)} — ${toString (lib.length upstreamNames)} packages
    - texlive-nix: ${version.ours} — ${toString (lib.length ourNames)} packages

    ## Added (${toString (lib.length added)})

    | Package | Version | Description |
    |---|---|---|
    ${lib.concatMapStringsSep "\n" describe added}

    ## Removed (${toString (lib.length removed)})

    ${lib.concatMapStringsSep "\n" (n: "- `${n}`") removed}
  '';
}
