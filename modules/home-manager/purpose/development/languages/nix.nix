{
  inputs,
  config,
  pkgs,
  lib,
  importExternals ? true,
  ...
}:
let
  inherit (lib) optional getExe;
in

import ./mkLanguage.nix rec {
  inherit
    config
    pkgs
    lib
    ;

  name = "nix";

  lspPackages = [
    pkgs.nixd
    pkgs.nil
  ];
  formatterPackages = [ pkgs.nixfmt ];

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

    programs.zed-editor = {
      extensions = [ "nix" ];
      userSettings = {
        languages.Nix.languag_servers = [
          "nixd"
          "nil"
        ];
        lsp = {
          nixd.binary.path = getExe pkgs.nixd;
          nil = {
            binnary.path = getExe pkgs.nil;
            initialization_options.formatting.command = [ (getExe pkgs.nixfmt) ];
          };
        };
      };
    };
  };
}
