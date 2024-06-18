{ modulesPath, ... }: {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
  ];

  services = {
    coder = {
      enable = true;
      accessUrl = "https://coder.racci.dev";
      listenAddress = "0.0.0.0:8080";
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 8080 ];
  };
}
