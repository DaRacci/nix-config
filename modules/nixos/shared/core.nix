{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkMerge mkForce;

  cfg = config.custom.core;
in
{
  options.custom.core = {
    enable = (mkEnableOption "Enable core features") // { default = true; };

    audio = {
      enable = mkEnableOption "Enable audio support";
    };

    bluetooth = {
      enable = mkEnableOption "Enable Bluetooth support";
    };

    network = {
      enable = (mkEnableOption "Enable network support") // { default = true; };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.audio.enable {
      security.rtkit.enable = mkForce true;
      hardware.pulseaudio.enable = mkForce false;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
      };
    })
    (mkIf cfg.bluetooth.enable {
      hardware.bluetooth.enable = true;
    })
    (mkIf cfg.network.enable {
      networking.networkmanager.enable = true;
    })
    {
      services = {
        dleyna-renderer.enable = true;
        dleyna-server.enable = true;

        gnome.gnome-keyring.enable = true;
        udisks2.enable = true;
        xserver.updateDbusEnvironment = true;
        colord.enable = true;
      };

      security.polkit.enable = true;
    }
  ]);
}
