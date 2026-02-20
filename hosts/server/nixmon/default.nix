_: {
  sops.secrets = { };

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

      grafana = {
        public = true;
        extraConfig = ''
          reverse_proxy http://localhost:3000
        '';
      };

      prometheus = {
        extraConfig = ''
          reverse_proxy http://localhost:9090
        '';
      };

      loki = {
        extraConfig = ''
          reverse_proxy http://localhost:3100
        '';
      };
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
