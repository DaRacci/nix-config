{ config, lib, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkForce
    ;

  cfg = config.custom.core;
in
{
  options.custom.core = {
    enable = (mkEnableOption "Enable core features") // {
      default = true;
    };

    audio = {
      enable = mkEnableOption "Enable audio support" // {
        default = !config.host.device.isHeadless;
      };
    };

    bluetooth = {
      enable = mkEnableOption "Enable Bluetooth support" // {
        default = !config.host.device.isHeadless;
      };
    };

    network = {
      enable = (mkEnableOption "Enable network support") // {
        default = !config.host.device.isVirtual;
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.audio.enable {
      custom.defaultGroups = [
        "audio"
        "pipewire"
        "rtkit"
      ];

      security.rtkit.enable = mkForce true;

      services = {
        pulseaudio.enable = mkForce false;
        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          jack.enable = false;
        };

        udev.extraRules = ''
          KERNEL=="rtc0", GROUP="audio"
          KERNEL=="hpet", GROUP="audio"
        '';
      };

      security.pam.loginLimits = [
        {
          domain = "@audio";
          item = "memlock";
          type = "-";
          value = "unlimited";
        }
        {
          domain = "@audio";
          item = "rtprio";
          type = "-";
          value = "99";
        }
        {
          domain = "@audio";
          item = "nofile";
          type = "soft";
          value = "99999";
        }
        {
          domain = "@audio";
          item = "nofile";
          type = "hard";
          value = "524288";
        }
      ];
    })
    (mkIf cfg.bluetooth.enable {
      system.activationScripts = {
        rfkillUnblockBluetooth.text = ''
          rfkill unblock bluetooth
        '';
      };

      hardware.bluetooth = {
        enable = true;
        settings.General = {
          Experimental = true;
          KernelExperimental = lib.mkDefault true;
        };
      };

      services.blueman.enable = true;

      host.persistence.directories = [ "/var/lib/bluetooth" ];
    })

    (mkIf cfg.network.enable {
      custom.defaultGroups = [ "network" ];
      networking.networkmanager.enable = true;
    })

    (mkIf (!config.host.device.isHeadless) {
      custom.defaultGroups = [
        "video"
        "i2c"
      ];

      services = {
        dleyna.enable = true;

        gnome.gnome-keyring.enable = true;
        udisks2.enable = true;
        xserver.updateDbusEnvironment = true;
        colord.enable = true;
      };

      security.polkit.enable = true;
    })
  ]);
}
