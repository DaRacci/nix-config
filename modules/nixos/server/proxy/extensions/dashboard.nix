_:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkDefault mkIf mkMerge;
  cfg = config.server.proxy;
in
{
  config = mkMerge [
    {
      server.proxy.extensions.dashboard = {
        priority = 200;
        enable = mkDefault (cfg.virtualHosts != { });
        config =
          _name: _vh: _hostCfg:
          "";
        globalConfig = _hostCfg: "";
        vhostModule = null;
      };
    }

    (mkIf config.server.proxy.extensions.dashboard.enable {
      server.dashboard.items = builtins.mapAttrs (_name: vhCfg: {
        title = mkDefault (lib.mine.strings.capitalise _name);
        url = mkDefault "https://${vhCfg.baseUrl}/";
        icon = mkDefault "sh-${_name}";
      }) cfg.virtualHosts;
    })
  ];
}
