{ flake, inputs, pkgs, ... }: {

  imports = [
    ./hardware.nix
    inputs.jovian.nixosModules.default
    inputs.arion.nixosModules.arion

    "${flake}/hosts/shared/optional/containers.nix"
    "${flake}/hosts/shared/optional/virtualisation.nix"

    "${flake}/hosts/shared/optional/hyprland.nix"

    "${flake}/hosts/shared/optional/pipewire.nix"
    "${flake}/hosts/shared/optional/gaming.nix"
    "${flake}/hosts/shared/optional/tailscale.nix"
  ];

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

      autoStart = false;
      user = "racci";
      desktopSession = "hyprland";
    };

    decky-loader = {
      enable = true;
    };
  };

  programs.nix-ld.enable = true;

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
      allowedUDPPorts = [ 9944 8082 9942 9943 7860 11434 ];
      allowedTCPPorts = [ 9999 22 5990 9944 8082 9942 9943 8080 7860 11434 ];
    };

    nat = {
      enable = true;
      internalInterfaces = [ "ve-+" ];
      externalInterface = "eth0";
      enableIPv6 = false;
    };
  };

  # services.netdata = {
  #   enable = true;
  # };

  services.ollama = {
    enable = true;
    package = pkgs.unstable.ollama;
    acceleration = "cuda";
    environmentVariables = {
      OLLAMA_ORIGINS = "http://192.168.0.0:*,app://obsidian.md:*";
    };
  };

  virtualisation.arion = {
    backend = "docker";
    projects = {
      ai = {
        settings = {
          imports = [
            "${flake}/containers/web-servers/open-webui.nix"
          ];
        };
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
