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
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkMerge
    ;

  cfg = config.core.hm-helper;
  connectCfg = cfg.kde-connect;
in
{
  options.core.hm-helper.kde-connect = {
    enable =
      (mkEnableOption "Enable KDE Connect firewall rules if any user has KDE Connect enabled.")
      // {
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
