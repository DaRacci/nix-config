{ modulesPath, ... }: {

  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
  ];

  proxmoxLXC = {
    privileged = false;
    manageNetwork = false;
    manageHostName = false;
  };

  tailscale.enable = true;

  networking = {
    firewall = {
      allowedUDPPorts = [ ];
      allowedTCPPorts = [ ];
      allowedUDPPortRanges = [{ from = 0; to = 0; }];
      allowedTCPPortRanges = [{ from = 0; to = 0; }];
    };
  };
}
