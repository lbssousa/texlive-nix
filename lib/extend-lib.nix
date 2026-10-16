# nixpkgs lib extended with the licenses from pkgs/texlive/extra-licenses.nix;
# licenses already defined upstream take precedence.
lib:
lib.extend (
  _: prev: {
    licenses = import ../pkgs/texlive/extra-licenses.nix { lib = prev; } // prev.licenses;
  }
)
