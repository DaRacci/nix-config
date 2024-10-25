{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.boot.quiet;
in
{
  options.boot.quiet = {
    enable = mkEnableOption "enable quiet boot";
  };

  config = mkIf cfg.enable {
    console = {
      useXkbConfig = true;
      earlySetup = false;
    };

    boot = {
      plymouth = {
        enable = true;
        # theme = "spinner-monochrome";
        themePackages = [
          (pkgs.adi1090x-plymouth-themes.override {
            selected_themes = [ "spinner_alt" ];
          })
        ];
      };
      loader.timeout = lib.mkDefault 5; # Allow for overriding in the ISO image builders.
      kernelParams = [
        "quiet"
        "loglevel=3"
        "systemd.show_status=auto"
        "udev.log_level=3"
        "rd.udev.log_level=3"
        "vt.global_cursor_default=0"
      ];
      consoleLogLevel = 0;
      initrd.verbose = false;
    };
  };
}
