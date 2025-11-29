{
  self,
  ...
}:
{
  perSystem =
    {
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
              const HOSTS = [${builtins.attrNames self.nixosConfigurations |> builtins.concatStringsSep " "}]
              let selected = $HOSTS | input list -f
            '';
          in
          {
            nix-tree-host = {
              package = pkgs.nushell;
              exec = ''
                def main [...args: string] {
                  ${nuSelectHost}
                  let top_level = $".#nixosConfigurations.($selected).config.system.build.toplevel"
                  nix build --no-link --accept-flake-config $top_level
                  ${lib.getExe pkgs.nix-tree} $top_level
                }
              '';
            };

            rebuild-target = {
              package = pkgs.nushell;
              exec = ''
                use std/log

                def --wrapped main [...args: string] {
                  ${nuSelectHost}

                  let command_args = [
                    "os"
                    "switch"
                    $".#nixosConfigurations.($selected)"
                  ]

                  let passthrough_args = [
                    "--"
                    "--accept-flake-config"
                    ...($args)
                  ]

                  log info $"Selected host: ($selected)"
                  log info $"Command: ($command_args) with passthrough ($passthrough_args)"

                  let current_host = cat /etc/hostname | str trim
                  if $selected == $current_host {
                    log info "Rebuilding current host"
                    nh ...$command_args ...$passthrough_args
                  } else {
                    log info $"Rebuilding selected host: ($selected)"
                    nh ...$command_args --target-host $"root@($selected)" ...$passthrough_args
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
