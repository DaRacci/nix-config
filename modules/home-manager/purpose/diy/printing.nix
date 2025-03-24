{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.purpose.diy;
in
{
  options.purpose.diy.printing = {
    enable = lib.mkEnableOption "Enable 3D printing support";
  };

  config = lib.mkIf cfg.printing.enable {
    assertions = [
      {
        assertion = cfg.enable;
        message = ''
          You have enabled 3D Printing support but not DIY.
          Ensure that `purpose.diy.printing` is set to true.
        '';
      }
    ];

    home.packages = with pkgs; [
      orca-slicer
    ];

    user.persistence.directories = [
      ".config/OrcaSlicer"
      ".local/share/orca-slicer"
    ];
  };
}
