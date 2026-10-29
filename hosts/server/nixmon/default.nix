_: {
  sops.secrets = { };

  server.sshGuard.endpoints = [
    "http://127.0.0.1:9090/-/healthy"
    "http://127.0.0.1:9090/-/ready"
    "http://127.0.0.1:9093/-/healthy"
    "http://127.0.0.1:3100/ready"
    "http://127.0.0.1:3000/api/health"
  ];

  server = {
    dashboard = {
      icon = "mdi-monitor-dashboard";
      items.uptime = {
        title = "Uptime Kuma";
        icon = "sh-uptime-kuma";
      };
      items.grafana = {
        title = "Grafana";
        icon = "sh-grafana";
      };
    };

    proxy.virtualHosts = {
      uptime.extraConfig = ''
        reverse_proxy http://localhost:3001
      '';
    };
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
