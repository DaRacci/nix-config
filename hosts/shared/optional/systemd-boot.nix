{ lib, ... }:
let inherit (lib) mkDefault; in {
  boot = {
    loader = {
      systemd-boot.enable = mkDefault true;
      efi.canTouchEfiVariables = true;
      systemd-boot.editor = false;
    };

    kernelParams = [ "quiet" "rd.systemd.show_status=false" "rd.udev.log_level=3" "udev.log_priority=3" ];
    consoleLogLevel = 0;

    initrd = {
      verbose = false;
      systemd.enable = mkDefault true;
    };
  };

  systemd.watchdog.rebootTime = "0";

  # console = {
  #   font = "JetBrainsMono Nerd Font";
  #   packages = [ (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; }) ];
  # };
}