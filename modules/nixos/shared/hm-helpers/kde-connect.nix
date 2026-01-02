{
  anyoneHasOption,
  ...
}:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.custom.hm-helpers;
  connectCfg = cfg.kde-connect;
in
{
  options.custom.hm-helpers.kde-connect = {
    enable =
      lib.mkEnableOption "Enable KDE Connect firewall rules if any user has KDE Connect enabled."
      // {
        default = anyoneHasOption (user: user.services.kdeconnect.enable);
      };
  };

  config = mkIf (cfg.enable && connectCfg.enable) {
    networking.firewall = rec {
      allowedUDPPortRanges = allowedTCPPortRanges;
      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
    };
  };
}
