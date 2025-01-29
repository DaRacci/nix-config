{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.purpose.development.nix;
in
{
  options.purpose.development.nix = {
    enable = mkEnableOption "nix development";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      nvd
      nix-init
      nixpkgs-review
    ];

    xdg.configFile."nix-init/config.toml".text = pkgs.writers.writeTOML {
      maintainers = [ config.programs.git.userName ];
      nixpkgs = ''builtins.getFlake "nixpkgs"'';
    };
  };
}
