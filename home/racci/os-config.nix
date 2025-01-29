{
  config,
  pkgs,
  lib,
  ...
}:
let
  # WSL is fucky with nu so we use fish instead.
  useFish = builtins.hasAttr "wsl" config;
in
{
  users.users.racci = {
    uid = 1000;
    shell = if useFish then pkgs.fish else pkgs.nushell;
  };

  programs.fish.enable = useFish;

  environment.shells = [ config.users.users.racci.shell ];

  hardware.keyboard.qmk.enable = true;

  services = {
    gnome = lib.mkIf (!config.host.device.isHeadless) {
      gnome-online-accounts.enable = true;
      evolution-data-server.enable = true;
    };

    kanata = lib.mkIf (!config.host.device.isHeadless) {
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
  };
}
