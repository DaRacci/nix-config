# Initially based on https://github.com/hyprwm/Hyprland/issues/6623#issuecomment-2709045321
# Modified to be more generic and reusable
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.hardware.display.virtual;
in
{
  options.hardware.display.virtual = {
    enable = lib.mkEnableOption "Enable Virtual Display Support";

    # TODO :: Validate that the resolution & refreshRate are available in the EDID using the edid-decode tool
    edidBinary = lib.mkOption {
      type = lib.types.path;
      description = ''
        The binary file containing the EDID data for the virtual display.
        This file can be generated using a tool like AW EDID Editor that can be ran under Wine.
      '';
    };

    # TODO :: Validate that its formatted correctly
    resolution = lib.mkOption {
      type = lib.types.string;
      example = "1920x1080";
      description = "Resolution of the virtual display";
    };

    refreshRate = lib.mkOption {
      type = lib.types.int;
      example = 60;
      description = "Refresh rate of the virtual display";
    };

    connector = lib.mkOption {
      type = lib.types.string;
      example = "HDMI-A-1";
      description = ''
        The connector to use for the virtual display.

        This must be a valid connector for your hardware.
        You can find the available connectors by running `for p in /sys/class/drm/*/status; do con=''${p%/status}; echo -n "''${con#*/card?-}: "; cat $p; done`
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.display = {
      outputs.${cfg.connector} = {
        mode = "${cfg.resolution}@${toString cfg.refreshRate}e";
        edid = "virtual.bin";
      };

      edid = {
        enable = true;
        packages = [
          (pkgs.runCommand "edid-virtual" { } ''
            mkdir -p "$out/lib/firmware/edid"
            base64 -d > "$out/lib/firmware/edid/virtual.bin" <<$(cat ${cfg.edidBinary})
          '')
        ];
      };
    };

    boot.kernelParams = [ "video=${cfg.connector}:${cfg.resolution}@${toString cfg.refreshRate}e" ];
  };
}
