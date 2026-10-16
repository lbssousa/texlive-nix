# Instantiates the vendored TeX Live package set inside a package set.
#
# `attr` is the name under which the result is stored in `final`; the
# vendored default.nix refers to itself through its `texlive` argument
# (fixpoint), so it must point back at that attribute.
final: attr:
final.callPackage ../pkgs/texlive {
  lib = import ./extend-lib.nix final.lib;
  texlive = final.${attr};
}
