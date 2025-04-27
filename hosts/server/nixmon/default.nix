_: {
  sops.secrets = { };

  server.proxy.virtualHosts = {
    uptime.extraConfig = ''
      reverse_proxy http://localhost:3001
    '';
  };

  services = {
    uptime-kuma = {
      enable = true;
      appriseSupport = true;
      settings = {
        HOST = "::";
      };
    };

    # netdata = {
    #   enable = true;
    #   config = {
    #     bind = "";
    #   };
    # };
  };

  networking.firewall.allowedTCPPorts = [ 3001 ];
}
