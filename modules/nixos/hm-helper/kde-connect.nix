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
  inherit (lib) mkIf mkMerge literalExpression;

  cfg = config.custom.hm-helper;
  connectCfg = cfg.kde-connect;
in
{
  options.custom.hm-helper.kde-connect = {
    enable = lib.mkEnableOption "Enable KDE Connect firewall rules if any user has KDE Connect enabled." // {
      default = anyoneHasOption (user: user.services.kdeconnect.enable);
      defaultText = literalExpression "anyoneHasOption (user: user.services.kdeconnect.enable)";
    };
  };

  config = mkMerge [
    (mkIf (cfg.enable && connectCfg.enable) {
      networking.firewall = rec {
        allowedUDPPortRanges = allowedTCPPortRanges;
        allowedTCPPortRanges = [
          {
            from = 1714;
            to = 1764;
          }
        ];
      };
    })
  ];
}
