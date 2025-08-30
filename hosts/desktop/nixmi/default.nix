{
  self,
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.jovian.nixosModules.default

    ./hardware.nix

    "${self}/hosts/shared/optional/containers.nix"
    "${self}/hosts/shared/optional/virtualisation.nix"

    "${self}/hosts/desktop/shared/sessions/hyprland.nix"

    "${self}/hosts/shared/optional/gaming.nix"
    "${self}/hosts/shared/optional/tailscale.nix"
  ];

  services = {
    hardware.bolt.enable = true;
    metrics = {
      enable = true;
      upgradeStatus.enable = true;
      hacompanion = {
        enable = true;
        sensor = {
          webcam.enable = true;
          cpu_temp.enable = true;
          cpu_usage.enable = true;
          uptime.enable = true;
          memory.enable = true;
          power.enable = true;
          audio_volume.enable = true;
        };
      };
    };
  };

  custom.remote = {
    enable = true;
    streaming.enable = true;
  };

  boot = {
    quiet.enable = true;
    secure.enable = true;
    systemd.enable = true;
  };

  jovian = {
    steamos = {
      useSteamOSConfig = true;
      enableDefaultCmdlineConfig = false;
    };

    steam = {
      enable = true;
      updater.splash = "steamos";

      autoStart = false;
      user = "racci";
      desktopSession = "hyprland";
    };

    decky-loader = {
      enable = true;
    };
  };

  programs = {
    nix-ld.enable = true;
    nix-ld.libraries = with pkgs; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      curl
      dbus
      expat
      fontconfig
      freetype
      fuse3
      gdk-pixbuf
      glib
      gtk3
      gtk4
      icu
      libGL
      libappindicator-gtk3
      libdrm
      libglvnd
      libnotify
      libpulseaudio
      libunwind
      libusb1
      libuuid
      libxkbcommon
      libxml2
      config.hardware.graphics.package
      config.hardware.graphics.package32
      nspr
      nss
      openssl
      pango
      pipewire
      stdenv.cc.cc
      systemd
      vulkan-loader
      zlib
    ];
    alvr = {
      enable = true;
      openFirewall = true;
    };
    adb.enable = true;
  };

  host = {
    persistence = {
      enable = true;
      directories = [
        "/var/lib/decky-loader"
        "/var/lib/private/ollama"
      ];
    };
  };

  networking = {
    firewall = {
      allowedUDPPorts = [
        # ALVR
        9942 # OSC
        9944 # Stream
        8082 # Web

        7860
        11434
        27031
        27036
      ];
      allowedTCPPorts = [
        9999
        22
        5990
        9943
        8080
        7860
        11434
        27036
        27037
        10400
        10401

        # ALVR
        9942
        9944
        8082
      ];
    };

    nat = {
      enable = true;
      internalInterfaces = [ "ve-+" ];
      externalInterface = "eth0";
      enableIPv6 = true;
    };
  };

  services = {
    ollama = {
      enable = true;
      openFirewall = true;
      host = "0.0.0.0";
      package = pkgs.ollama;
      environmentVariables = {
        OLLAMA_ORIGINS = "http://192.168.0.0:*,app://obsidian.md:*";
        OLLAMA_KV_CACHE_TYPE = "q8_0";
        OLLAMA_FLASH_ATTENTION = "1";
      };
    };
  };

  virtual-machines = {
    enable = true;
    guests = {
      gaming = {
        os = {
          type = "windows";
        };

        cpu = {
          threads = 12;
        };

        memory = {
          sharedMemory = true;
          reservedMemory = 60;
          maxMemory = 16 * 1024 * 1024 * 1024;
        };

        storage = { };

        graphics = {
          enable = true;
          method = "passthrough";
        };

        audio = true;
      };
    };
  };
}
