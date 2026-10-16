# Licenses used by the vendored tlpdb.nix that are not (yet) part of
# nixpkgs' lib.licenses. Entries already defined upstream take precedence
# (see lib/mk-texlive.nix), so this file can be pruned when nixpkgs catches up.
{ lib }:
lib.mapAttrs (shortName: license: lib.licenses.mkLicense ({ inherit shortName; } // license)) {
  lppl11 = {
    spdxId = "LPPL-1.1";
    fullName = "LaTeX Project Public License v1.1";
  };

  lppl13b = {
    spdxId = "LPPL-1.3b";
    fullName = "LaTeX Project Public License v1.3b";
  };
}
