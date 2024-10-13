{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkMerge mkForce;

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
        default = !builtins.hasAttr "wsl" config; # Disable network support on WSL, its already handled by Windows.
      };
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
        jack.enable = false;
        extraConfig.pipewire."92-low-latency" = {
          "context.properties" = {
            "default.clock.rate" = 44100;
            "default.clock.quantum" = 512;
            "default.clock.min-quantum" = 512;
            "default.clock.max-quantum" = 512;
          };
        };
      };

      services.udev.extraRules = ''
        KERNEL=="rtc0", GROUP="audio"
        KERNEL=="hpet", GROUP="audio"
      '';

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
      hardware.bluetooth.enable = true;
    })
    (mkIf cfg.network.enable {
      networking.networkmanager.enable = true;
    })
    (mkIf (config.host.device.role != "server") {
      services = {
        dleyna-renderer.enable = true;
        dleyna-server.enable = true;

        gnome.gnome-keyring.enable = true;
        udisks2.enable = true;
        xserver.updateDbusEnvironment = true;
        colord.enable = true;
      };

      security.polkit.enable = true;
    })
  ]);
}
