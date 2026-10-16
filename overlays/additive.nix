# Adds the vendored TeX Live next to the one from nixpkgs, as texliveLatest,
# texliveLatest{Basic,Small,Medium,Full,...}, texliveLatestFullWithDocs,
# texliveLatestFullUnfree and texliveLatestPackages.
final: prev:
{
  texliveLatest = import ../lib/mk-texlive.nix final "texliveLatest";
}
// import ../lib/top-level.nix { inherit (prev) lib; } {
  texlive = final.texliveLatest;
  prefix = "texliveLatest";
}
