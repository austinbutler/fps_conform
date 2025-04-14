_default:
    @just --list

# Build with Nix
build:
    nix build .

# Run pre-commit hooks
lint:
    pre-commit run --all-files

# Run test against included video clip
test:
    ./test/test.sh

# Update Nix revisions
update:
    nix flake update
