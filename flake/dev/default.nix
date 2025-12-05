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
          nix-diff
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

                def perform-action [
                  action: string # "switch" | "boot" | "test" | "build-vm"
                  args: list<string>
                ] {
                  ${nuSelectHost}

                  let command_args = [
                    "os"
                    $action
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
                  if $action != "build-vm" {
                    if $selected == $current_host {
                      log info $"Performing ($action) on current host"
                      nh ...$command_args ...($passthrough_args)
                    } else {
                      log info $"Performing ($action) on selected host: ($selected)"
                      nh ...$command_args --target-host $"root@($selected)" ...($passthrough_args)
                    }
                  } else {
                    log info $"Building VM for selected host: ($selected)"
                    nh ...$command_args ...($passthrough_args)
                  }
                }

                def --wrapped main [...args: string] {
                  perform-action "switch" $args
                }

                def --wrapped "main build-vm" [...args: string] {
                  perform-action "build-vm" $args
                }

                def --wrapped "main test" [...args: string] {
                  perform-action "test" $args
                }

                def --wrapped "main build" [...args: string] {
                  perform-action "build" $args
                }

                def --wrapped "main boot" [...args: string] {
                  perform-action "boot" $args
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
