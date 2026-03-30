{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    mkEnableOption
    literalExpression
    ;

  cfg = config.hardware;
in
{
  options.hardware.backlight = {
    enable = mkEnableOption "enable backlight support" // {
      default = !(config.host.device.isHeadless || config.host.device.isVirtual);
      defaultText = literalExpression ''
        !(config.host.device.isHeadless || config.host.device.isVirtual)
      '';
    };
  };

  config = mkMerge [
    (mkIf cfg.backlight.enable {
      hardware.acpilight.enable = true;

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
