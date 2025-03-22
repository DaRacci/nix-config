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

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      orca-slicer
    ];

    user.persistence.directories = [
      ".config/OrcaSlicer"
      ".local/share/orca-slicer"
    ];
  };
}
