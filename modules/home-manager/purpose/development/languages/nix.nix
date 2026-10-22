{
  inputs,
  config,
  pkgs,
  lib,
  importExternals ? true,
  ...
}:
let
  inherit (lib) getExe optional;
in

import ./mkLanguage.nix rec {
  inherit
    config
    pkgs
    lib
    ;

  name = "nix";

  lsp = [
    {
      name = "nixd";
      package = pkgs.nixd;
      filetypes = [ ".nix" ];
      editors.opencode.command = [
        "nixd"
        "--semantic-tokens"
        "--inlay-hints"
      ];
      settings = {
        nixpkgs.expr = "import (builtins.getFlake \"/persist/nix-config\").inputs.nixpkgs { }";
        options = rec {
          nixos.expr = "(builtins.getFlake \"/persist/nix-config\").nixosConfigurations.(builtins.replaceStrings [\"\\n\"] [\"\"] (builtins.readFile /etc/hostname)).options";
          home-manager.expr = "${nixos.expr}.home-manager.users.type.getSubOptions []";
          flake-parts.expr = "(builtins.getFlake \"/persist/nix-config\").debug.options";
          flake-parts2.expr = "(builtins.getFlake \"/persist/nix-config\").currentSystem.options";
        };
      };
    }
    {
      name = "nil";
      package = pkgs.nil;
      filetypes = [ ".nix" ];
      initializationOptions.formatting.command = [ "nixfmt" ];
    }
  ];

  formatters = [
    {
      name = "nixfmt";
      package = pkgs.nixfmt;
      filetypes = [ ".nix" ];
    }
  ];

  editors = {
    zed.extensions = [ "nix" ];

    vscode = {
      profile = "default";
      extensions = [ "jnoortheen.nix-ide" ];
      settings = {
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = getExe pkgs.nil;
        "nix.serverSettings" = {
          nil = {
            diagnostics = {
              ignored = [ ];
            };
            formatting = {
              command = [ (getExe pkgs.nixfmt) ];
            };
          };

          nixd = {
            formatting.command = getExe pkgs.nixfmt;
            eval = {
              enable = true;
              targets = {
                args = [
                  "-f"
                  "default.nix"
                ];
                installable = "";
              };
            };
            options = {
              enable = true;
              targets = {
                args = [
                  "-f"
                  "default.nix"
                ];
                installable = "";
              };
            };
          };
        };
      };
    };
  };

  extraPackages = [
    pkgs.dix
    pkgs.nix-init
    pkgs.nixpkgs-review
  ];

  imports = optional importExternals inputs.nix-index-database.homeModules.default;

  extraConfig = {
    programs.nix-index.enable = true;

    home.packages = extraPackages;

    xdg.configFile."nix-init/config.toml".text = pkgs.writers.writeTOML {
      maintainers = [ config.programs.git.userName ];
      nixpkgs = ''builtins.getFlake "nixpkgs"'';
    };
  };
}
