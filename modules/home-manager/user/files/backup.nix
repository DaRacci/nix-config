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
  options.user.files.backup = {
    enable = mkEnableOption "backup";
  };

  config = mkIf config.user.files.backup.enable {
    home.packages = [
      kopia
      kopia-ui
    ];

    user.files.persistence.directories = [ ".config/kopia" ];
  };
}
