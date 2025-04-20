{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption optionalString;
  cfg = config.hardware;

  enableNvidia = cfg.graphics.hasNvidia && !config.host.device.isHeadless;
in
{
  options.hardware.backlight = {
    enable = mkEnableOption "enable backlight support";
  };

  config = mkIf cfg.backlight.enable {
    programs.light.enable = true;

    environment.systemPackages = with pkgs; [ ddcutil ];

    boot.extraModulePackages = [ config.boot.kernelPackages.ddcci-driver ];
    boot.kernelModules = [
      "i2c-dev"
      "ddcci_backlight"
    ];

    #region Nvidia Specific fix from https://discourse.nixos.org/t/ddcci-kernel-driver/22186/4
    services.udev.extraRules = optionalString enableNvidia ''
      SUBSYSTEM=="i2c-dev", ACTION=="add",\
        ATTR{name}=="NVIDIA i2c adapter*",\
        TAG+="ddcci",\
        TAG+="systemd",\
        ENV{SYSTEMD_WANTS}+="ddcci@$kernel.service"
    '';

    systemd.services."ddcci@" = mkIf enableNvidia {
      scriptArgs = "%i";
      script = ''
        echo Trying to attach ddcci to $1
        i=0
        id=$(echo $1 | cut -d "-" -f 2)
        if ${pkgs.ddcutil}/bin/ddcutil getvcp 10 -b $id; then
          echo ddcci 0x37 > /sys/bus/i2c/devices/$1/new_device
        fi
      '';
      serviceConfig.Type = "oneshot";
    };
    #endregion
  };
}
