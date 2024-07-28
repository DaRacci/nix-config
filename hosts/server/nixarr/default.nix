{ modulesPath, inputs, config, ... }: {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"

    inputs.nixarr.nixosModules.default
  ];

  sops.secrets.wireguard = {
    format = "binary";
    sopsFile = ./wg.conf;
  };

  nixarr = {
    enable = true;
    mediaDir = "/data/media";
    stateDir = "/data/media/.state/nixarr";

    vpn = {
      enable = true;
      wgConf = config.sops.secrets.wireguard.path;
    };

    jellyfin = {
      enable = true;
    };

    transmission = {
      enable = true;
      vpn.enable = true;
      peerPort = 50000;
    };

    bazarr.enable = true;
    lidarr.enable = true;
    prowlarr.enable = true;
    radarr.enable = true;
    readarr.enable = true;
    sonarr.enable = true;
  };
}
