{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.purpose.development.languages.nix;
  rootCfg = config.purpose.development;
in
{
  imports = [
    inputs.nix-index-database.homeModules.default
  ];

  options.purpose.development.languages.nix = {
    enable = mkEnableOption "nix development";
  };

  config = mkIf (rootCfg.enable && cfg.enable) {
    programs.nix-index.enable = true;

    home.packages = with pkgs; [
      dix
      nix-init
      nixpkgs-review
    ];

    xdg.configFile."nix-init/config.toml".text = pkgs.writers.writeTOML {
      maintainers = [ config.programs.git.userName ];
      nixpkgs = ''builtins.getFlake "nixpkgs"'';
    };
  };
}
