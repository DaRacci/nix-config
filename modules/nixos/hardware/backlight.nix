{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkMerge mkEnableOption;

  cfg = config.hardware;
in
{
  options.hardware.backlight = {
    enable = mkEnableOption "enable backlight support";
  };

  config = mkMerge [
    {
      hardware.backlight = !(config.host.device.isHeadless || config.host.device.isVirtual);
    }

    (mkIf cfg.backlight.enable {
      programs.light.enable = true;

      environment.systemPackages = with pkgs; [
        ddcutil
        luminance
      ];

      boot = {
        extraModulePackages = [ config.boot.kernelPackages.ddcci-driver ];
        kernelModules = [
          "i2c-dev"
          "ddcci_backlight"
        ];
      };

      services.udev.extraRules = ''
        KERNEL=="i2c-[0-9]*", GROUP="users"
      '';
    })
  ];
}
