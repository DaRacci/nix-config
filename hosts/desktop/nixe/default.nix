{
  flake,
  inputs,
  pkgs,
  ...
}:
{

  imports = [
    ./hardware.nix
    inputs.jovian.nixosModules.default
    inputs.arion.nixosModules.arion

    "${flake}/hosts/shared/optional/containers.nix"
    "${flake}/hosts/shared/optional/virtualisation.nix"

    "${flake}/hosts/shared/optional/hyprland.nix"

    "${flake}/hosts/shared/optional/gaming.nix"
    "${flake}/hosts/shared/optional/tailscale.nix"

    "${inputs.lact-module}/nixos/modules/services/hardware/lact.nix"
  ];

  services.lact = {
    enable = true;
    gpuOverclock.enable = true;
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
      updater.splash = "vendor";

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
      mesa
      nspr
      nss
      openssl
      pango
      pipewire
      stdenv.cc.cc
      systemd
      vulkan-loader
      xorg.libX11
      xorg.libXScrnSaver
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libXrender
      xorg.libXtst
      xorg.libxcb
      xorg.libxkbfile
      xorg.libxshmfence
      zlib
    ];
    alvr = {
      enable = true;
      openFirewall = true;
    };
    adb.enable = true;
  };

  host = {
    drive = {
      enable = true;

      format = "btrfs";
      name = "Nix";
    };

    persistence = {
      enable = true;
      type = "tmpfs";

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

        # Immersed-VR
        21000
        21010
        34817
        42470
        60942
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

        # Immersed-VR
        21000
        48847
        47849
        42956
      ];
    };

    nat = {
      enable = true;
      internalInterfaces = [ "ve-+" ];
      externalInterface = "eth0";
      enableIPv6 = true;
    };
  };

  # services.netdata = {
  #   enable = true;
  # };

  services = {
    ollama = {
      enable = true;
      openFirewall = true;
      host = "0.0.0.0";
      package = pkgs.ollama;
      environmentVariables = {
        OLLAMA_ORIGINS = "http://192.168.0.0:*,app://obsidian.md:*";
      };
    };

    tailscale = {
      extraUpFlags = [
        "--accept-dns=true"
        "--accept-routes"
      ];
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
