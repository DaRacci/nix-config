{ config, pkgs, lib, ... }: {
  users.users.racci = {
    uid = 1000;
    shell = pkgs.nushell;
  };

  environment.shells = [ config.users.users.racci.shell ];

  hardware.keyboard.qmk.enable = true;

  services.kanata = lib.mkIf (!config.host.device.isHeadless) {
    enable = true;
    keyboards = {
      "megu-board" = {
        devices = [ "/dev/input/by-id/usb-mt_ymd75v3_0-event-kbd" ];
        config = ''
          (defsrc
            caps)

          (deflayermap (default-layer)
            ;; tap caps lock as escape, hold caps lock as left control
            caps (tap-hold 100 100 esc lctl))
        '';
      };
    };
  };
}
