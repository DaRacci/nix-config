{
  anyoneHasPackage,
  ...
}:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkMerge literalExpression;

  cfg = config.custom.hm-helper;
  ff2mpvCfg = cfg.ff2mpv;
in
{
  options.custom.hm-helper.ff2mpv = {
    enable = lib.mkEnableOption "Enable ff2mpv native messaging host for Firefox." // {
      default = anyoneHasPackage pkgs.ff2mpv-rust;
      defaultText = literalExpression "anyoneHasPackage pkgs.ff2mpv-rust";
    };
  };

  config = mkMerge [
    (mkIf (cfg.enable && ff2mpvCfg.enable) {
      programs.firefox.nativeMessagingHosts.packages = [ pkgs.ff2mpv-rust ];
    })
  ];
}
