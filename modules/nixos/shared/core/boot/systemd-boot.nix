{ config, lib, ... }:
let
  inherit (lib) mkDefault mkIf mkEnableOption;
  cfg = config.boot.systemd;
in
{
  options.boot.systemd = {
    enable = mkEnableOption "enable systemdboot";
  };

  config = mkIf cfg.enable {
    boot = {
      loader = {
        # must be mkDefault as secure boot disables this.
        systemd-boot.enable = mkDefault true;
        efi.canTouchEfiVariables = true;
        systemd-boot.editor = false;
      };

      initrd.systemd.enable = mkDefault true;
    };

    systemd.settings.Manager.RebootWatchdogSec = "0";

    # console = {
    #   font = "JetBrainsMono Nerd Font";
    #   packages = [ (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; }) ];
    # };
  };
}