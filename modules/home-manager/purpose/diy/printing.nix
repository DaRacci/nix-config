{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.purpose.diy;
in
{
  options.purpose.diy.printing = {
    enable = mkEnableOption "Enable 3D printing support";
  };

  config = mkIf cfg.printing.enable {
    assertions = [
      {
        assertion = cfg.enable;
        message = ''
          You have enabled 3D Printing support but not DIY.
          Ensure that `purpose.diy.printing` is set to true.
        '';
      }
    ];

    home.packages = [
      pkgs.orca-slicer-zink
    ];

    user.persistence.directories = [
      ".config/OrcaSlicer"
      ".local/share/orca-slicer"
    ];
  };
}
