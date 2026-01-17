{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
in
{
  options.user.backup = {
    enable = mkEnableOption "backup";
  };

  config = mkIf config.user.backup.enable {
    home.packages = with pkgs; [
      kopia
      kopia-ui
    ];

    user.persistence.directories = [
      ".config/kopia"
    ];
  };
}
