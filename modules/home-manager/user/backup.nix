{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs) kopia kopia-ui;
  inherit (lib) mkIf mkEnableOption;
in
{
  options.user.backup = {
    enable = mkEnableOption "backup";
  };

  config = mkIf config.user.backup.enable {
    home.packages = [
      kopia
      kopia-ui
    ];

    user.persistence.directories = [
      ".config/kopia"
    ];
  };
}
