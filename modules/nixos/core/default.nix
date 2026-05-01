{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkDefault
    mkEnableOption
    mkForce
    mkIf
    mkMerge
    ;

  cfg = config.core;
in
{
  imports = [
    ./boot
    ./hardware
    ./host
    ./networking

    ./activation.nix
    ./auto-upgrade.nix
    ./containers.nix
    ./display-manager.nix
    ./gaming.nix
    ./generators.nix
    ./groups.nix
    ./locale.nix
    ./nix.nix
    ./openssh.nix
    ./printing.nix
    ./remote.nix
    ./security.nix
    ./sops.nix
    ./stylix.nix
    ./virtualisation.nix
    ./wsl.nix
  ];

  options.core = {
    enable = (mkEnableOption "Enable core features") // {
      default = true;
    };

    audio = {
      enable = mkEnableOption "Enable audio support" // {
        default = !config.host.device.isHeadless;
        defaultText = literalExpression "!config.host.device.isHeadless";
      };
    };

    bluetooth = {
      enable = mkEnableOption "Enable Bluetooth support" // {
        default = !config.host.device.isHeadless;
        defaultText = literalExpression "!config.host.device.isHeadless";
      };
    };

    network = {
      enable = (mkEnableOption "Enable network support") // {
        default = !config.host.device.isVirtual;
        defaultText = literalExpression "!config.host.device.isVirtual";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.dbus.implementation = "broker";
    }

    (mkIf cfg.audio.enable {
      core.defaultGroups = [
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
          ${lib.getExe' pkgs.util-linux "rfkill"} unblock bluetooth
        '';
      };

      hardware.bluetooth = {
        enable = true;
        settings.General = {
          Experimental = true;
          KernelExperimental = mkDefault true;
        };
      };

      services.blueman.enable = true;

      host.persistence.directories = [ "/var/lib/bluetooth" ];
    })

    (mkIf cfg.network.enable {
      core.defaultGroups = [ "network" ];
      networking.networkmanager.enable = true;
    })

    (mkIf (!config.host.device.isHeadless) {
      core.defaultGroups = [
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
