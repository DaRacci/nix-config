{ flake, config, lib, ... }: with lib; let cfg = config.custom.auto-upgrade; in {
  options.custom.auto-upgrade = {
    enable = (mkEnableOption "auto-upgrade") // { default = true; };

    hostName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "The hostName to use for auto-upgrade";
    };
  };

  config = mkIf cfg.enable {
    system.autoUpgrade = let isClean = flake ? rev; in {
      enable = isClean;
      dates = "hourly";
      flags = [ "--refresh" ];
      flake = "github:DaRacci/nix-config#${hostName}";

      allowReboot = false;
      rebootWindow = { lower = "02:00"; upper = "05:00"; };
    };
  };
}