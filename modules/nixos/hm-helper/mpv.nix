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
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkMerge
    ;

  cfg = config.core.hm-helper;
  ff2mpvCfg = cfg.ff2mpv;
in
{
  options.core.hm-helper.ff2mpv = {
    enable = mkEnableOption "Enable ff2mpv native messaging host for Firefox." // {
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
