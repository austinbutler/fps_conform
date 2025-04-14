{
  description = "Conform between 23.976/24fps and 25fps";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
    git-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      git-hooks,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = { };
          overlays = [ (final: prev: { }) ];
        };
        pre-commit-check = git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            check-case-conflict = {
              enable = true;
              name = "check for case conflicts";
              description = "checks for files that would conflict in case-insensitive filesystems.";
              entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/check-case-conflict";
            };
            check-executables-have-shebangs = {
              enable = true;
              name = "check that executables have shebangs";
              description = "ensures that (non-binary) executables have a shebang.";
              entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/check-executables-have-shebangs";
              types = [
                "text"
                "executable"
              ];
            };
            check-merge-conflict = {
              enable = true;
              name = "check for merge conflicts";
              description = "checks for files that contain merge conflict strings.";
              entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/check-merge-conflict";
              types = [ "text" ];
            };
            check-shebang-scripts-are-executable = {
              enable = true;
              name = "check that scripts with shebangs are executable";
              description = "ensures that (non-binary) files with a shebang are executable.";
              entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/check-shebang-scripts-are-executable";
              types = [ "text" ];
            };
            check-vcs-permalinks = {
              enable = true;
              name = "check vcs permalinks";
              description = "ensures that links to vcs websites are permalinks.";
              entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/check-vcs-permalinks";
              types = [ "text" ];
            };
            detect-private-key = {
              enable = true;
              name = "detect private key";
              description = "detects the presence of private keys.";
              entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/detect-private-key";
              types = [ "text" ];
            };
            end-of-file-fixer = {
              enable = true;
              name = "fix end of files";
              description = "ensures that a file is either empty, or ends with one newline.";
              entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/end-of-file-fixer";
              types = [ "text" ];
            };
            mixed-line-ending = {
              enable = true;
              name = "mixed line ending";
              description = "replaces or checks mixed line ending.";
              entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/mixed-line-ending --fix=lf";
              types = [ "text" ];
            };
            nixfmt-rfc-style.enable = true;
            nil.enable = true;
            prettier = {
              enable = true;
              types = [ "markdown" ];
            };
            shellcheck = {
              enable = true;
              types_or = nixpkgs.lib.mkForce [ "shell" ];
            };
            shfmt.enable = true;
            statix.enable = true;
            trailing-whitespace = {
              enable = true;
              name = "trim trailing whitespace";
              description = "trims trailing whitespace.";
              entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/trailing-whitespace-fixer";
              types = [ "text" ];
            };
          };
        };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "fps_conform";

          buildInputs = with pkgs; [
            ffmpeg
            git
            just
            mkvtoolnix-cli
            nixfmt-rfc-style
            nodePackages.prettier
            perl
            pre-commit
            shellcheck
            shfmt
          ];

          shellHook = ''
            ${pre-commit-check.shellHook}
          '';
        };
        packages.default = pkgs.writeShellApplication {
          name = "fps-conform";
          runtimeInputs = with pkgs; [
            (stdenv.mkDerivation {
              name = "srtshift";
              src = ./srt;
              buildPhase = "";
              installPhase = ''
                mkdir -p $out/bin
                cp srtshift.pl $out/bin/srtshift
              '';
            })
            ffmpeg
            perl
          ];
          text = builtins.readFile ./fps_conform.sh;
        };
      }
    );
}
