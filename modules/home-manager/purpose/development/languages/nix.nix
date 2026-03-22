{
  inputs,
  config,
  pkgs,
  lib,
  importExternals ? true,
  ...
}:
let
  inherit (lib) optional;
in

import ./mkLanguage.nix {
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

    home.packages = [
      pkgs.dix
      pkgs.nix-init
      pkgs.nixpkgs-review
    ];

    xdg.configFile."nix-init/config.toml".text = pkgs.writers.writeTOML {
      maintainers = [ config.programs.git.userName ];
      nixpkgs = ''builtins.getFlake "nixpkgs"'';
    };
  };
}
