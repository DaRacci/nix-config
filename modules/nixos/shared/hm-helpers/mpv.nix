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
  inherit (lib) mkIf;

  cfg = config.custom.hm-helpers;
  ff2mpvCfg = cfg.ff2mpv;
in
{
  options.custom.hm-helpers.ff2mpv = {
    enable = lib.mkEnableOption "Enable ff2mpv native messaging host for Firefox." // {
      default = anyoneHasPackage pkgs.ff2mpv-rust;
    };
  };

  config = mkIf (cfg.enable && ff2mpvCfg.enable) {
    programs.firefox.nativeMessagingHosts.packages = [ pkgs.ff2mpv-rust ];
  };
}
