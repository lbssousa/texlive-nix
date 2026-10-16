# texlive-nix

The latest [TeX Live](https://tug.org/texlive/) for Nix, ahead of nixpkgs.

nixpkgs updates TeX Live once a year, and the update usually lands months after the upstream release. This flake vendors nixpkgs' own TeX Live expressions (`pkgs/tools/typesetting/tex/texlive`) and moves them to the newest TeX Live year and snapshot. You get the **same API** as nixpkgs (`texlive.withPackages`, `texliveSmall`, `texliveFull`, `texlivePackages.<name>`, …), so switching back and forth is transparent.

The name has no year on purpose. The flake starts with **TeX Live 2026** and follows every later release.

## Usage

```sh
nix shell github:lbssousa/texlive-nix#texliveFull
nix build github:lbssousa/texlive-nix#texliveSmall
nix build github:lbssousa/texlive-nix#texlivePackages.<name>    # any single package
nix build github:lbssousa/texlive-nix#texlive.bin.core
```

### As a flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    texlive-nix = {
      url = "github:lbssousa/texlive-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, texlive-nix, ... }: {
    # NixOS: nixpkgs.overlays = [ texlive-nix.overlays.default ];
    # then e.g. (pkgs.texliveSmall.withPackages (ps: [ ps.latexmk ps.gregoriotex ]))
  };
}
```

Packages are fixed-output derivations, so the binary cache serves them even with `follows`. Only `texlive.bin` (the compiled programs) is rebuilt when your nixpkgs differs from the one in this flake's `flake.lock`.

### Overlays

| Overlay | Effect |
|---|---|
| `overlays.default` | Replaces `texlive`, `texlive{Basic,Small,Medium,Full,…}`, `texliveFullWithDocs` and `texlivePackages`, and adds `texliveFullUnfree`. **If nixpkgs already ships a TeX Live at least as recent, it steps aside** (with a warning) and leaves nixpkgs untouched. |
| `overlays.additive` | Leaves nixpkgs alone and adds `texliveLatest`, `texliveLatest{Small,Full,…}`, `texliveLatestFullUnfree` and `texliveLatestPackages`. |

### Flake outputs

- `packages.<system>`: the schemes (`texliveSmall`, `texliveFull`, …), `texliveFullWithDocs`, and `default` (= `texliveSmall`).
- `legacyPackages.<system>`:
  - `texlive`: the package set, with `.pkgs`, `.withPackages` and `.bin`;
  - `texlivePackages.<name>`: every individual package;
  - `texliveFullUnfree`: needs `allowUnfree`;
  - `maintainers`: helpers for the update scripts.
- `devShells.<system>.default`: `texliveSmall` + `latexmk`.
- `checks.<system>`:
  - the nixpkgs TeX Live test suite (`texlive-*`);
  - `completeness`: every package of `texlive.tlpdb` is packaged;
  - `allPackages`: every output of every package builds.

### Binary cache

CI pushes everything to Cachix (`lbssousa-texlive`). Use it with:

```nix
nix.settings = {
  extra-substituters = [ "https://lbssousa-texlive.cachix.org" ];
  extra-trusted-public-keys = [ "lbssousa-texlive.cachix.org-1:<key from app.cachix.org>" ];
};
```

## Packages

- Every package in the TeX Live database (`texlive.tlpdb`) of the packaged snapshot is available on its own. That includes packages added to CTAN after the previous year's freeze and packages that belong to no collection. `NEW-PACKAGES.md` lists what was added and removed compared to nixpkgs.
- Unfree packages (in TeX Live 2026: `utbmciad-report`) are kept out of collections and schemes, so `texliveFull` stays free. They remain available individually and through `texliveFullUnfree`.
- Schemes removed upstream (in TeX Live 2026: `scheme-bookpub`) disappear from `packages`. In the overlays, `texliveBookPub` throws with an explanation.

## Repository layout

```
pkgs/texlive/        vendored nixpkgs expressions (see UPSTREAM for the revisions)
  local-overrides.nix   texlive-nix specific changes (unfree packages)
  extra-licenses.nix    licenses not yet in nixpkgs' lib.licenses
lib/                 overlay plumbing (mk-texlive, top-level attributes, versions)
overlays/            overlays.default and overlays.additive
tests/               flake checks; texlive.nix is vendored from nixpkgs
scripts/             update-snapshot.sh, sync-upstream.sh, check-cycle.sh
```

Changes to vendored files are kept small and marked with `texlive-nix:` comments, so merges from nixpkgs stay easy.

## Maintenance

Local commands run inside the `nix-dev` distrobox container through `just`. Set `NIX_DEV=` to run them directly on a host with Nix.

| Command | What it does |
|---|---|
| `just update [YYYY-MM-DD]` | New tlpdb snapshot (default: yesterday). Regenerates `tlpdb.nix` and `fixed-hashes.nix`, checks completeness, and writes `NEW-PACKAGES.md`. |
| `just check` | Evaluates all systems and runs the test suite. |
| `just build-all` | Builds every individual package. |
| `just sync` | Three-way merges the latest nixpkgs texlive expressions. |
| `just cycle` | Reports where we are in the yearly cycle. |

CI (`.github/workflows`):

- **`ci.yml`**: evaluates, then builds `bin`, the schemes and the test suite on x86_64-linux and aarch64-linux. On `main` and on `snapshot` PRs it also builds `allPackages`. Everything goes to Cachix.
- **`update-snapshot.yml`**: monthly. Opens a PR with a new snapshot, with `NEW-PACKAGES.md` as the description. Can also be run manually with `date`, `year` and `freeze`.
- **`sync-upstream.yml`**: weekly.
  - Opens a PR merging the nixpkgs changes (a draft if there are conflicts).
  - Opens an issue when the yearly cycle needs attention.
  - Updates `flake.lock`.

Required secret: `CACHIX_AUTH_TOKEN`.

### Snapshots

Until a TeX Live year is frozen (around February/March of the next year), packages come from daily snapshots. The `tlnet` on CTAN mirrors changes constantly, so `pkgs/texlive/default.nix` pins a day of `https://texlive.info/tlnet-archive/YYYY/MM/DD`, and package tarballs come from CTAN or that archive. That archive is not meant for heavy traffic. The fixed hashes plus the binary cache mean users rarely hit it.

### Yearly cycle

1. **Freeze** (≈ Feb/Mar): when `tlnet-final` of the current year is on the historic mirrors, run `just update -- --freeze`.
2. **New release** (≈ March): when TeX Live `YYYY+1` is out:
   - bump the `texlive-source` tarball in `pkgs/texlive/bin.nix`, and with it ConTeXt/LuaMetaTeX and Asymptote (see `pkgs/texlive/UPGRADING.md`);
   - run `just update -- --year YYYY+1 <date>`;
   - fix the scheme license lists that the `texlive-licenses` check reports;
   - review the new binaries with `texlive-shebangs` and `texlive-binaries`.
3. **nixpkgs catches up**: `overlays.default` steps aside automatically for users, and the flake simply moves on to the next year.

## Credits

- The TeX Live expressions come from [nixpkgs](https://github.com/NixOS/nixpkgs) (maintained by @veprbl, @xworld21 and contributors).
- The initial TeX Live 2026 port comes from [chrjabs/nixpkgs@texlive-2026](https://github.com/chrjabs/nixpkgs/tree/texlive-2026).
- Licensed under MIT, like nixpkgs.
