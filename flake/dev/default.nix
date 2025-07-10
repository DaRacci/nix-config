{
  self,
  ...
}:
{
  perSystem =
    {
      inputs',
      pkgs,
      lib,
      ...
    }:
    rec {
      treefmt = {
        projectRootFile = ".git/config";

        programs = {
          actionlint.enable = true;
          deadnix.enable = true;
          nixfmt.enable = true;
          shellcheck.enable = true;
          statix.enable = true;
          mdformat.enable = true;
          mdsh.enable = true;
        };

        settings.formatter.shellcheck.excludes = [ ".envrc" ];
        settings.global.excludes = [
          "**/secrets.yaml"
          "**/ssh_host_ed25519_key.pub"
          "modules/home-manager/purpose/development/editors/vscode/extensions.nix"
        ];
      };

      devenv.shells.default = {
        # Fixes https://github.com/cachix/devenv/issues/528
        containers = lib.mkForce { };

        packages = with pkgs; [
          # Cli Tools
          act # Github Action testing
          hyperfine # Benchmarking
          cocogitto # Conventional Commits

          # Nix tools
          nvd
          nix-tree
          nil
          nixd
          nixfmt-rfc-style
          nix-init

          # Required Tools
          nix
          git
          home-manager
          inputs'.nix4vscode.packages.nix4vscode

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
        ];

        languages = {
          nix.enable = false;
        };

        env = {
          NIX_CONFIG = "extra-experimental-features = nix-command flakes pipe-operator";
        };

        scripts =
          let
            nuSelectHost = ''
              const HOSTS = [${builtins.attrNames self.nixosConfigurations |> builtins.concatStringsSep " "}]]
              let selected = $HOSTS | input list -f
            '';
          in
          {
            update-vscode.exec = ''
              DIR="modules/home-manager/purpose/development/editors/vscode"
              CONFIG="$DIR/config.toml"
              NIX_FILE="$DIR/extensions.nix"
              VSCODE_VERSION=${pkgs.vscode.version}

              sed -i "s/vscode_version = \".*\"/vscode_version = \"$VSCODE_VERSION\"/" "$CONFIG"
              nix4vscode "$CONFIG" -o "$NIX_FILE"
            '';
            dump-vscode.exec = ''
              echo 'vscode_version = "'${pkgs.vscode.version}'"'
              echo
              echo 'extensions = ['
              (code --list-extensions 2>/dev/null) | while read extension; do
                publisher_name=$(echo "$extension" | cut -d '.' -f 1)
                extension_name=$(echo "$extension" | cut -d '.' -f 2-)
                echo "  \"$publisher_name.$extension_name\""
              done
              echo ']'
              echo
            '';

            nix-tree-host = {
              package = pkgs.nushell;
              exec = ''
                def main [...args: string] {
                  ${nuSelectHost}
                  let top_level = $".#nixosConfigurations.($selected).config.system.build.toplevel"
                  nix build --no-link --accept-flake-config $top_level
                  ${lib.getExe inputs'.nix-tree.packages.default} $top_level
                }
              '';
            };

            rebuild-target = {
              package = pkgs.nushell;
              exec = ''
                use std/log

                def main [...args: string] {
                  ${nuSelectHost}

                  let command_args = [
                    "switch"
                    "--accept-flake-config"
                    "--flake"
                    $".#($selected)"
                    ...($args)
                  ]

                  log info $"Selected host: ($selected)"
                  log info $"Command: ($command_args)"

                  let current_host = cat /etc/hostname | str trim
                  if $selected == $current_host {
                    log info "Rebuilding current host"
                    sudo nixos-rebuild ...$command_args
                  } else {
                    log info $"Rebuilding selected host: ($selected)"
                    nixos-rebuild ...$command_args --target-host $"root@($selected)"
                  }
                }
              '';
            };
          };

        git-hooks = {
          excludes = [
            "modules/home-manager/purpose/development/editors/vscode/extensions.nix"
          ];

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
            actionlint.enable = true;
            deadnix.enable = true;
            nixfmt-rfc-style.enable = true;
            shellcheck.enable = true;
            statix = {
              enable = false; # Disabled until https://github.com/oppiliappan/statix/issues/88 is resolved.
              settings.ignore = treefmt.settings.global.excludes;
            };
          };
        };
      };
    };
}
