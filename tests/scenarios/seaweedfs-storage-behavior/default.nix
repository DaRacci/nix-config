{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.seaweedfs.outPath ];

  services.seaweedfs = {
    enable = true;
    openFirewall = true;

    master = {
      enable = true;
      ip = "127.0.0.1";
      port = 9333;
    };

    volume = {
      enable = true;
      ip = "127.0.0.1";
      port = 8080;
      master = [ "localhost:9333" ];
      idxDir = "/var/lib/seaweedfs/idx";
      maxVolumes = 0;
    };

    filer = {
      enable = true;
      ip = "127.0.0.1";
      port = 8888;
      master = [ "localhost:9333" ];
      s3 = {
        enable = true;
        port = 8333;
      };
      tomlConfig = ''
        [leveldb2]
        enabled = true
        dir = "/var/lib/seaweedfs/filerdb"
      '';
    };
  };

  environment.systemPackages = [
    pkgs.awscli
    pkgs.seaweedfs
  ];

  # Override WorkingDirectory to base dir — StateDirectory creates it.
  systemd.services.seaweedfs-master.serviceConfig.WorkingDirectory = lib.mkForce "/var/lib/seaweedfs";
  systemd.services.seaweedfs-volume.serviceConfig.WorkingDirectory = lib.mkForce "/var/lib/seaweedfs";
  systemd.services.seaweedfs-filer.serviceConfig.WorkingDirectory = lib.mkForce "/var/lib/seaweedfs";

  systemd.services.seaweedfs-admin = {
    description = "SeaweedFS Admin UI Server";
    after = [ "seaweedfs-master.service" ];
    wants = [ "seaweedfs-master.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.seaweedfs}/bin/weed admin -port=23646 -dataDir=/var/lib/seaweedfs/admin -masters=localhost:9333";
      User = "seaweedfs";
      Group = "seaweedfs";
      WorkingDirectory = "/var/lib/seaweedfs";
      Restart = "always";
      RestartSec = "30s";
    };
  };

  networking.firewall.allowedTCPPorts = [ 23646 ];

  # External module has wrong tmpfiles format (<type>.<path> vs nixpkgs <path>.<type>).
  # Override all seaweedfs entries with correct format.
  systemd.tmpfiles.settings = lib.mkForce {
    seaweedfs-base = {
      "/var/lib/seaweedfs".d = {
        mode = "0755";
        user = "seaweedfs";
        group = "seaweedfs";
      };
    };
    seaweedfs-master = {
      "/var/lib/seaweedfs/master".d = {
        mode = "0755";
        user = "seaweedfs";
        group = "seaweedfs";
      };
    };
    seaweedfs-volume = {
      "/var/lib/seaweedfs/volume".d = {
        mode = "0755";
        user = "seaweedfs";
        group = "seaweedfs";
      };
    };
    seaweedfs-filer = {
      "/var/lib/seaweedfs/filer".d = {
        mode = "0755";
        user = "seaweedfs";
        group = "seaweedfs";
      };
    };
    seaweedfs-idx = {
      "/var/lib/seaweedfs/idx".d = {
        mode = "0755";
        user = "seaweedfs";
        group = "seaweedfs";
      };
    };
    seaweedfs-config = {
      "/var/lib/seaweedfs/.seaweedfs".d = {
        mode = "0755";
        user = "seaweedfs";
        group = "seaweedfs";
      };
      "/var/lib/seaweedfs/.seaweedfs/filer.toml"."f+" = {
        mode = "0644";
        user = "seaweedfs";
        group = "seaweedfs";
        argument = config.services.seaweedfs.filer.tomlConfig;
      };
    };
  };
}
