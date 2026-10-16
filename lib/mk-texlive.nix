# Instantiates the vendored TeX Live package set inside a package set.
#
# `attr` is the name under which the result is stored in `final`; the
# vendored default.nix refers to itself through its `texlive` argument
# (fixpoint), so it must point back at that attribute.
final: attr:
let
  texliveDir = ../pkgs/texlive;
  lib = final.lib.extend (
    _: prev: {
      licenses = import (texliveDir + "/extra-licenses.nix") { lib = prev; } // prev.licenses;
    }
  );
in
final.callPackage texliveDir {
  inherit lib;
  texlive = final.${attr};
}
