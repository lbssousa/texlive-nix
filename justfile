# Local development runs inside the distrobox container "nix-dev".
# Set NIX_DEV= (empty) to run the commands directly on a host with Nix.

container := env("NIX_DEV", "nix-dev")
jobs := num_cpus()

_run cmd:
    @{{ if container == "" { cmd } else { "distrobox enter " + container + " -- bash -lc " + quote("cd " + justfile_directory() + " && " + cmd) } }}

# list recipes
default:
    @just --list

# evaluate every output and build the test suite (without allPackages)
check:
    @just _run "nix flake check --no-build --all-systems"
    @just _run "nix build --no-link -L --keep-going -j {{ jobs }} \$(nix eval --json .#checks.x86_64-linux --apply builtins.attrNames | jq -r '.[] | select(. != \"allPackages\") | \".#checks.x86_64-linux.\" + .')"

# build one flake attribute, e.g. `just build texliveFull`
build attr="texliveSmall":
    @just _run "nix build -L -j {{ jobs }} .#{{ attr }}"

# build every individual package (all outputs, unfree included)
build-all:
    @just _run "nix build --no-link -L --keep-going -j {{ jobs }} .#checks.x86_64-linux.allPackages"

# move to a new snapshot, e.g. `just update 2026-11-01` or `just update -- --freeze`
update *args:
    @just _run "scripts/update-snapshot.sh --jobs {{ jobs }} {{ args }}"

# write NEW-PACKAGES.md (packages added/removed w.r.t. nixpkgs)
new-packages:
    @just _run "nix eval --raw .#maintainers.packageReport > NEW-PACKAGES.md"

# merge changes of nixpkgs' texlive expressions into the vendored copy
sync rev="master":
    @just _run "scripts/sync-upstream.sh {{ rev }}"

# where are we in the yearly TeX Live cycle?
cycle:
    @just _run "scripts/check-cycle.sh"

# format the Nix files
fmt:
    @just _run "nix fmt"
