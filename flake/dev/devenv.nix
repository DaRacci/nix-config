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
            openspec

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
          OPENSPEC_TELEMETRY = "0";
        };

        git-hooks = {
          package = pkgs.prek;
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

        tasks."bash:linkSkills" = {
          before = [ "devenv:enterShell" ];
          exec = ''
            skills_src="$DEVENV_ROOT/modules/home-manager/purpose/development/editors/ai/skills"
            skills_dst="$DEVENV_ROOT/.opencode/skills"

            for skill_dir in "$skills_src"/*/; do
              [ -d "$skill_dir" ] || continue
              skill_name=$(basename "$skill_dir")
              target="$skills_dst/$skill_name"

              if [ ! -e "$target" ] && [ ! -L "$target" ]; then
                echo "Linking skill: $skill_name"
                rel_path=$(realpath --relative-to="$skills_dst" "$skill_dir")
                ln -s "$rel_path" "$target"
              fi
            done
          '';
        };
      };
    };
}
