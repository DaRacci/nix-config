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
  options.purpose.diy.cad = {
    enable = lib.mkEnableOption "CAD Software";
  };

  config = lib.mkIf cfg.cad.enable {
    assertions = [
      {
        assertion = cfg.enable;
        message = "You must set `purpose.diy.enable` to true in order to use this module";
      }
    ];

    home.packages = [
      # pkgs.freecad
      pkgs.meshlab
      pkgs.kicad
    ];

    user.persistence.directories = [
      ".config/FreeCAD"
      ".local/share/FreeCAD"
    ];
  };
}
