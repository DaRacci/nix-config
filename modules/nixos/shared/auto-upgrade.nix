{
  self,
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom.auto-upgrade;
in
{
  options.custom.auto-upgrade = {
    enable = (mkEnableOption "auto-upgrade") // {
      default = true;
    };

    hostName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      defaultText = literalExpression ''
        config.networking.hostName
      '';
      description = "The hostName to use for auto-upgrade";
    };
  };

  config = mkIf cfg.enable {
    system.autoUpgrade =
      let
        isClean = self ? rev;
      in
      {
        enable = isClean;
        dates = "04:00";
        randomizedDelaySec = "45min";
        flags = [
          "--refresh"
          "--accept-flake-config"
          "--no-update-lock-file"
        ];
        flake = "github:DaRacci/nix-config#${cfg.hostName}";

        allowReboot = false;
        rebootWindow = {
          lower = "02:00";
          upper = "05:00";
        };
      };

    systemd.services.nixos-upgrade.serviceConfig = {
      CPUWeight = [ "20" ];
      CPUQuota = [ "65%" ];
      IOWeight = [ "20" ];
    };
  };
}
