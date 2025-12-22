{ inputs, ... }:
{
  imports = [
    inputs.devenv.flakeModule
  ];

  perSystem =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    {
      devenv.shells.default = {
        # Fixes https://github.com/cachix/devenv/issues/528
        containers = lib.mkForce { };

        packages =
          with pkgs;
          [
            # Cli Tools
            act # Github Action testing
            hyperfine # Benchmarking
            cocogitto # Conventional Commits
            dive

            # Nix tools
            dix
            nix-tree
            nix-diff
            nil
            nixd
            nix-init
            nh
            nix-update

            # Required Tools
            nix
            git
            home-manager

            # Converting to Nix
            dconf2nix

            # Install & Setup Tools
            sbctl
            disko
            cryptsetup

            # Sops-nix
            age
            sops
            ssh-to-age
          ]
          ++ config.treefmt.build.devShell.buildInputs
          ++ (import ./scripts { inherit pkgs lib; } |> builtins.attrValues);

        languages = {
          nix.enable = false;
        };

        env = {
          NIX_CONFIG = "extra-experimental-features = nix-command flakes pipe-operator";
        };

        git-hooks = {
          hooks = {
            check-added-large-files.enable = true;
            check-case-conflicts.enable = true;
            check-executables-have-shebangs.enable = true;
            check-shebang-scripts-are-executable.enable = true;
            check-merge-conflicts.enable = true;
            detect-private-keys.enable = true;
            fix-byte-order-marker.enable = true;
            mixed-line-endings.enable = true;
            trim-trailing-whitespace.enable = true;

            nil.enable = true;
            treefmt = {
              enable = true;
              packageOverrides.treefmt = config.treefmt.build.wrapper;
            };
          };
        };
      };
    };
}
