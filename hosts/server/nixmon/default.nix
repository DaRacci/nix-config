_: {
  sops.secrets = { };

  server = {
    dashboard = {
      icon = "mdi-monitor-dashboard";
      items.uptime = {
        title = "Uptime Kuma";
        icon = "sh-uptime-kuma";
      };
    };

    proxy.virtualHosts.uptime.extraConfig = ''
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
  };

  networking.firewall.allowedTCPPorts = [ 3001 ];
}
