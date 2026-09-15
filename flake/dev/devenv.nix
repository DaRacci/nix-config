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
      devenv.shells = rec {
        default = {
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
              lix
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

          env = {
            NIX_CONFIG = "extra-experimental-features = nix-command flakes pipe-operator pipe-operators";
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

          tasks = {
            "bash:linkSkills" = {
              before = [ "devenv:enterShell" ];
              exec = ''
                skills_src="$DEVENV_ROOT/modules/home-manager/purpose/development/editors/ai/skills"
                skills_dst="$DEVENV_ROOT/.opencode/skills"

                mkdir -p "$skills_dst"
                touch "$skills_dst/.keep"

                if [ ! -f "$skills_dst/.gitignore" ]; then
                  touch "$skills_dst/.gitignore"
                  cat > "$skills_dst/.gitignore" <<EOF
                .gitignore
                .keep
                EOF
                fi

                SKILLS_TO_LINK=$(find "$skills_src" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)

                for skill in $SKILLS_TO_LINK; do
                  target="$skills_dst/$skill"

                  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
                    echo "Linking skill: $skill"
                    rel_path=$(realpath --relative-to="$skills_dst" "$skills_src/$skill")
                    ln -s "$rel_path" "$target"
                  fi

                  if ! grep -Fxq "$skill" "$skills_dst/.gitignore"; then
                    echo "$skill" >> "$skills_dst/.gitignore"
                  fi
                done
              '';
            };

            "bash:generateLuaStub" = {
              before = [ "devenv:enterShell" ];
              exec = ''
                cat > "$DEVENV_ROOT/.luarc.json" <<'EOF'
                {
                  "workspace": {
                    "library": [
                      "${pkgs.hyprland}/share/hypr/stubs/"
                    ]
                  }
                }
                EOF
              '';
            };
          };
        };

        python = {
          inherit (default)
            containers
            env
            git-hooks
            tasks
            packages
            ;

          languages.python = {
            enable = true;
            package = pkgs.python3.withPackages (ps: [
              ps.pip
              ps.pytest
              ps.black
              ps.ruff
              ps.mypy

              ps.anyio
              ps.cryptography
              ps.pillow
              ps.pystemd
              ps.python-magic
              ps.pyyaml
              ps.requests
              ps.rich
              ps.websockets
            ]);
          };
        };
      };
    };
}
