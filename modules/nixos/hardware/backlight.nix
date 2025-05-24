{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.hardware;
in
{
  options.hardware.backlight = {
    enable = lib.mkEnableOption "enable backlight support" // {
      default = !(config.host.device.isHeadless || config.host.device.isVirtual);
    };
  };

  config = lib.mkIf cfg.backlight.enable {
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
  };
}
