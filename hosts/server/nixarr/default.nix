{
  inputs,
  config,
  lib,
  ...
}:
{
  imports = [
    inputs.nixarr.nixosModules.default
    ./arr
  ];

  # wg service fails to start on boot due to network not being ready
  # The upstream VPN-Confinement module only retries 5 times with 1s delays,
  # which is too short during early boot. Adding restart settings ensures
  # the service will eventually succeed once networking is available.
  systemd.services.wg.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "10s";
  };

  users.users.jellyfin.extraGroups = [ "video" ];

  sops.secrets.wireguard = {
    format = "binary";
    sopsFile = ./wg.conf;
    restartUnits = [ "wg.service" ];
  };

  vpnNamespaces.wg.accessibleFrom = lib.mkForce [
    "192.168.0.0/16"
    "100.100.0.0/16"
    "127.0.0.1"
  ];

  hardware.graphics = {
    enable = true;
  };

  nixarr = {
    enable = true;

    vpn = {
      enable = true;
      vpnTestService.enable = true;
      wgConf = config.sops.secrets.wireguard.path;
    };

    jellyfin.enable = true;
    seerr.enable = true;
  };

  services.jellyfin = {
    hardwareAcceleration = {
      enable = true;
      device = "/dev/dri/renderD128";
    };

    forceEncodingConfig = true;
    transcoding = {
      enableHardwareEncoding = true;
      maxConcurrentStreams = null;
      throttleTranscoding = true;
      hardwareEncodingCodecs = {
        hevc = true;
        av1 = true;
      };
      hardwareDecodingCodecs = {
        av1 = true;
        h264 = true;
        hevc = true;
        vp9 = true;
      };
    };
  };

  server = {
    dashboard.icon = "sh-mediamanager";

    tests.units = {
      jellyfin = {
        testScript = ''
          nixarr.succeed("systemctl show jellyfin.service | grep -i loadstate")
        '';
      };

      seerr = {
        testScript = ''
          nixarr.succeed("systemctl show seerr.service | grep -i loadstate")
        '';
      };

      samba = {
        testScript = ''
          nixarr.succeed("systemctl show samba.service | grep -i loadstate")
        '';
      };

      wireguard = {
        testScript = ''
          nixarr.succeed("systemctl show wg.service | grep -i loadstate")
        '';
      };

      sonarr = {
        testScript = ''
          nixarr.succeed("systemctl show sonarr.service | grep -i loadstate")
        '';
      };

      radarr = {
        testScript = ''
          nixarr.succeed("systemctl show radarr.service | grep -i loadstate")
        '';
      };

      lidarr = {
        testScript = ''
          nixarr.succeed("systemctl show lidarr.service | grep -i loadstate")
        '';
      };

      prowlarr = {
        testScript = ''
          nixarr.succeed("systemctl show prowlarr.service | grep -i loadstate")
        '';
      };

      bazarr = {
        testScript = ''
          nixarr.succeed("systemctl show bazarr.service | grep -i loadstate")
        '';
      };
    };

    proxy.virtualHosts = {
      jellyfin = {
        public = true;
        ports = [ config.nixarr.jellyfin.port ];
        extraConfig = ''
          reverse_proxy localhost:${toString config.nixarr.jellyfin.port}
        '';
      };
      seerr = {
        public = true;
        ports = [ config.nixarr.seerr.port ];
        extraConfig = ''
          reverse_proxy localhost:${toString config.nixarr.seerr.port}
        '';
      };
    };
  };
}
